#!/usr/bin/env Rscript
# GP emulator training for the escalation model.
# Generates an LHS design, runs the Rust gp-train subcommand for R replicates,
# aggregates replicates, fits Matern-5/2 ARD GPs on Psi and tau_psi via
# DiceKriging, validates on hold-out, and saves model objects + diagnostics.
#
# Prerequisites: install.packages(c("lhs", "DiceKriging", "dplyr", "cli"))
# Run from project root: Rscript analysis/gp_train.R

library (lhs)
library (DiceKriging)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)

set.seed (42)

results_dir <- "results"
if (!dir.exists (results_dir)) {
    cli_abort (
        "Output directory {.file {results_dir}} not found — \\
        run {.file analysis/morris.R} first"
    )
}

# ---------------------------------------------------------------------------
# Parameter space: use Sobol-ranked top parameters where available
# ---------------------------------------------------------------------------
# delta fixed at pars_s$delta — suppresses Psi monotonically; held out of analyses
all_param_names <- c (
    "gamma", "lambda", "alpha", "theta", "beta",
    "w_win", "b", "w_loss", "dw_obs", "dw_bridge", "eta_obs"
)
all_binf <- c (
    gamma = 2.0, lambda = 1.0, alpha = 0.1, theta = 1.0, beta = 0.0,
    w_win = 0.1, b = 0.0, w_loss = 0.1, dw_obs = 0.0, dw_bridge = 0.0,
    eta_obs = 0.001
)
all_bsup <- c (
    gamma = 4.0, lambda = 5.0, alpha = 2.0, theta = 4.0, beta = 3.0,
    w_win = 2.0, b = 2.0, w_loss = 2.0, dw_obs = 0.2, dw_bridge = 0.2,
    eta_obs = 0.1
)

# fixed structural params excluded from all analyses
FIXED_EXCLUDE <- c ("delta") # nolint

pars <- RcppTOML::parseTOML ("defaults.toml")
pars_s <- pars$structural
pars_a <- pars$analysis

# parameters to include in GP (more than Sobol to preserve coverage)
TOP_N <- pars$gp$top_n_gp # nolint
if (file.exists (file.path (results_dir, "sobol_results.csv"))) {
    sobol_df <- read.csv (file.path (results_dir, "sobol_results.csv"))
    sobol_df <- sobol_df [!(sobol_df$param %in% FIXED_EXCLUDE), ]
    param_names <- sobol_df$param [seq_len (min (TOP_N, nrow (sobol_df)))]
    cli_alert_info (col_yellow (
        "Using top {length(param_names)} parameters from Sobol \\
        (delta excluded): {.field {param_names}}"
    ))
} else if (file.exists (file.path (results_dir, "morris_results.csv"))) {
    morris_df <- read.csv (file.path (results_dir, "morris_results.csv"))
    morris_df <- morris_df [!(morris_df$param %in% FIXED_EXCLUDE), ]
    param_names <- morris_df$param [seq_len (min (TOP_N, nrow (morris_df)))]
    cli_alert_warning (col_yellow (
        "{.file sobol_results.csv} not found; using top {length(param_names)} \\
                     parameters from Morris (delta excluded)"
    ))
} else {
    param_names <- all_param_names
    cli_alert_warning (
        "No prior results; using all {length(param_names)} parameters"
    )
}
p <- length (param_names)

binf <- all_binf [param_names]
bsup <- all_bsup [param_names]

# Structural constants from defaults.toml; inactive free params at midpoints.
log_dir <- if (!is.null (pars_s$log_dir)) pars_s$log_dir else "/tmp/escalation"
dir.create (log_dir, recursive = TRUE, showWarnings = FALSE)
old_done <- list.files (log_dir, pattern = "\\.done$", full.names = TRUE)
if (length (old_done) > 0) file.remove (old_done)
cli_alert_info ("Progress files will be written to {.file {log_dir}}")

fixed <- list (
    n = as.integer (pars_a$n), mu0 = pars_a$mu0, sigma0 = pars_a$sigma0,
    c = pars_a$c, e = pars_a$e,
    dw_coop = pars_a$dw_coop, dw_sub = pars_a$dw_sub, dw_excl = pars_a$dw_excl,
    eta = pars_a$eta,
    delta_direct = pars_a$delta_direct, delta_exploit = pars_a$delta_exploit,
    w_min = pars_s$w_min, w_max = pars_s$w_max,
    sigma_drift = pars_s$sigma_drift, rho_contested = pars_s$rho_contested,
    eta_trauma = pars_s$eta_trauma,
    delta = pars_s$delta,
    t_max = as.integer (pars_a$t_max_gp),
    gamma = pars_a$mid_gamma, lambda = pars_a$mid_lambda, alpha = pars_a$mid_alpha,
    theta = as.integer (pars_a$mid_theta), beta = pars_a$mid_beta,
    w_win = pars_a$mid_w_win, b = pars_a$mid_b, w_loss = pars_a$mid_w_loss,
    dw_obs = pars_a$mid_dw_obs, dw_bridge = pars_a$mid_dw_bridge,
    eta_obs = pars_a$mid_eta_obs
)

# ---------------------------------------------------------------------------
# LHS design
# ---------------------------------------------------------------------------
N_LHS <- as.integer (if (!is.null (pars$gp$n_lhs)) pars$gp$n_lhs else 1000L) # nolint
cli_alert_info ("Generating LHS design (N={.val {N_LHS}}, p={.val {p}})...")
lhs_unit <- maximinLHS (N_LHS, p)
design_scaled <- as.data.frame (lhs_unit)
colnames (design_scaled) <- param_names
for (nm in param_names) {
    design_scaled [[nm]] <-
        binf [nm] + (bsup [nm] - binf [nm]) * design_scaled [[nm]]
}

# Expand to full Params CSV
design_full <- design_scaled
for (nm in names (fixed)) design_full [[nm]] <- fixed [[nm]]
for (nm in param_names) design_full [[nm]] <- design_scaled [[nm]]
design_full$theta <-
    pmax (1L, pmin (4L, as.integer (round (design_full$theta))))
design_full$n <- as.integer (design_full$n)
design_full$t_max <- as.integer (design_full$t_max)

write.csv (
    design_full,
    file.path (results_dir, "design_lhs.csv"),
    row.names = FALSE
)
cli_alert_info ("Wrote {.file design_lhs.csv}")

# ---------------------------------------------------------------------------
# Run Rust gp-train subcommand (R replicates per design point)
# ---------------------------------------------------------------------------
binary <- "./target/release/escalation"
n_rep <- as.integer (if (!is.null (pars$gp$n_rep_gp)) pars$gp$n_rep_gp else 5L)
if (!file.exists (binary)) {
    cli_abort ("Binary not found — run 'cargo build --release'")
}

n_expected <- N_LHS * n_rep
out_file <- file.path (results_dir, "gp_train_raw.csv")
if (!file.exists (out_file)) {
    cli_alert_info (
        "Running binary ({.val {N_LHS}} design points x \\
        {.val {n_rep}} replicates = {.val {n_expected}} pairs)..."
    )
    cli_alert_info (
        "Expected {.val {n_expected}} progress files \\
        — use {.code make progress} to see."
    )
    result <- processx::run (
        binary,
        c (
            "gp-train",
            "--design", file.path (results_dir, "design_lhs.csv"),
            "--replicates", as.character (n_rep),
            "--output", file.path (results_dir, "gp_train_raw.csv"),
            "--log-dir", log_dir
        ),
        echo = TRUE, error_on_status = FALSE
    )
    if (result$status != 0) stop ("Binary failed: ", result$stderr)
} else {
    cli_alert_warning (col_red (
        "Binary output file alread exists at {.file {out_file}}; \\
        will not be re-generated here."
    ))
}

# ---------------------------------------------------------------------------
# Aggregate replicates per design point
# ---------------------------------------------------------------------------
raw <- read.csv (file.path (results_dir, "gp_train_raw.csv"))

# Rows: for each design point, 2*(mu0 lo + hi) * n_rep = 2*n_rep rows
# mu0==0.4 rows have psi values; group by design_row index
# Assign a design_row id: row pairs (lo, hi) repeat for each seed then each
# design pt
# Layout: [pair1_seed0_lo, pair1_seed0_hi, pair1_seed1_lo, ...,
#          pair2_seed0_lo, ...]
out_file <- file.path (results_dir, "gp_data.csv")
if (!file.exists (out_file)) {
    raw <- raw |>
        mutate (
            pair_idx = ceiling (row_number () / (2 * n_rep)),
            is_lo    = (row_number () %% 2 == 1)
        )

    gp_data <- raw |>
        filter (is_lo) |>
        group_by (pair_idx) |>
        summarise (
            psi_mean = mean (psi, na.rm = TRUE),
            psi_sd = sd (psi, na.rm = TRUE),
            tau_psi_mean = mean (tau_psi, na.rm = TRUE),
            .groups = "drop"
        )
    # sd is NA when only 1 valid value
    gp_data$psi_sd [is.na (gp_data$psi_sd)] <- 0

    # Attach design parameters
    design_ids <- seq_len (N_LHS)
    stopifnot (nrow (gp_data) == N_LHS)
    gp_data <- bind_cols (design_scaled [design_ids, ], gp_data)
    write.csv (gp_data, out_file, row.names = FALSE)
    cli_alert_info ("Wrote {.file {out_file}}")
} else {
    cli_alert_warning (col_red (
        "Binary output file alread exists at {.file {out_file}}; \\
        will not be re-generated here."
    ))
    gp_data <- read.csv (out_file)
}

# ---------------------------------------------------------------------------
# 80/20 train/hold-out split stratified by psi_mean quintile
# ---------------------------------------------------------------------------
gp_data$quintile <- cut (gp_data$psi_mean,
    breaks = quantile (gp_data$psi_mean,
        probs = seq (0, 1, 0.2), na.rm = TRUE
    ),
    include.lowest = TRUE, labels = FALSE
)

set.seed (123)
train_idx <- unlist (lapply (
    split (seq_len (N_LHS), gp_data$quintile),
    function (idx) sample (idx, size = floor (0.8 * length (idx)))
))
test_idx <- setdiff (seq_len (N_LHS), train_idx)
cli_alert_info (
    "Train: {.val {length(train_idx)}}  Test: {.val {length(test_idx)}}"
)

X_train <- gp_data [train_idx, param_names, drop = FALSE] # nolint
X_test <- gp_data [test_idx, param_names, drop = FALSE] # nolint
y_train <- gp_data$psi_mean [train_idx]
y_test <- gp_data$psi_mean [test_idx]
tau_train <- gp_data$tau_psi_mean [train_idx]

# ---------------------------------------------------------------------------
# Fit GPs
# ---------------------------------------------------------------------------
cli_alert_info (
    "Fitting GP on Psi (n_train={.val {nrow(X_train)}}, p={.val {p}})..."
)
cli_alert_info ("DiceKriging Cholesky is O(n^3) — may take several minutes")

fit_psi <- km (
    formula = ~1,
    design = X_train,
    response = y_train,
    covtype = "matern5_2",
    nugget.estim = TRUE,
    control = list (trace = FALSE)
)

cli_alert_info ("Fitting GP on tau_psi...")
fit_tau <- km (
    formula = ~1,
    design = X_train,
    response = tau_train,
    covtype = "matern5_2",
    nugget.estim = TRUE,
    control = list (trace = FALSE)
)

saveRDS (fit_psi, file.path (results_dir, "gp_psi.rds"))
saveRDS (fit_tau, file.path (results_dir, "gp_tau.rds"))
cli_alert_info ("Saved gp_psi.rds and gp_tau.rds")

# ---------------------------------------------------------------------------
# Validation on hold-out
# ---------------------------------------------------------------------------
pred_psi <- predict (fit_psi, newdata = X_test, type = "UK", checkNames = FALSE)
pred_tau <- predict (fit_tau, newdata = X_test, type = "UK", checkNames = FALSE)

rmse_psi <- sqrt (mean ((pred_psi$mean - y_test)^2))
rmse_tau <- sqrt (mean (
    (pred_tau$mean - gp_data$tau_psi_mean [test_idx])^2, na.rm = TRUE
))

# 95% prediction interval coverage
in_pi_psi <- abs (pred_psi$mean - y_test) <= 1.96 * pred_psi$sd
coverage_psi <- mean (in_pi_psi, na.rm = TRUE)

validation <- data.frame (
    metric = c ("rmse_psi", "rmse_tau", "coverage_95_psi"),
    value  = c (rmse_psi, rmse_tau, coverage_psi)
)
write.csv (
    validation,
    file.path (results_dir, "gp_validation.csv"),
    row.names = FALSE
)
cli_alert_info (
    "Validation: RMSE(Psi)={.val {round(rmse_psi, 4)}}  \\
    Coverage(Psi)={.val {round(coverage_psi, 3)}}"
)

# ---------------------------------------------------------------------------
# Hyperparameters: ARD length scales and output variance
# ---------------------------------------------------------------------------
ell <- fit_psi@covariance@range.val  # ARD length scales (one per dimension)
sigma2 <- fit_psi@covariance@sd2     # output variance
nugget <- fit_psi@covariance@nugget

hyperparams <- data.frame (
    param = param_names,
    ell = ell,
    sensitivity = 1 / ell # inverse length scale ~ influence
)
# short ell first = most sensitive
hyperparams <- hyperparams [order (hyperparams$ell), ]

meta <- data.frame (
    param = c ("sigma2", "nugget"),
    ell = c (sigma2, nugget),
    sensitivity = NA
)
hyperparams <- rbind (hyperparams, meta)
write.csv (
    hyperparams,
    file.path (results_dir, "gp_hyperparams.csv"),
    row.names = FALSE
)

cli_alert_info ("ARD length scales (short = sensitive):")
print (
    hyperparams [hyperparams$param %in% param_names,
                 c ("param", "ell")], digits = 3
)
cli_alert_info ("Wrote gp_hyperparams.csv")
