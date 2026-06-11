#!/usr/bin/env Rscript
# GP emulator training for the escalation model.
# Generates an LHS design, runs the Rust gp-train subcommand for R=5 replicates,
# aggregates replicates, fits Matern-5/2 ARD GPs on Psi and tau_psi via
# DiceKriging, validates on hold-out, and saves model objects + diagnostics.
#
# Prerequisites: install.packages(c("lhs", "DiceKriging", "dplyr", "cli"))
# Run from project root: Rscript analysis/gp_train.R

library (lhs)
library (DiceKriging)
library (dplyr, warn.conflicts = FALSE)
library (jsonlite)
library (cli)

set.seed (42)

# ---------------------------------------------------------------------------
# Parameter space: use Sobol-ranked top parameters where available
# ---------------------------------------------------------------------------
# delta fixed at d$delta — suppresses Psi monotonically; held out of analyses
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

FIXED_EXCLUDE <- c ("delta") # fixed structural params excluded from all analyses

TOP_N <- 8 # parameters to include in GP (more than Sobol to preserve coverage)
if (file.exists ("sobol_results.csv")) {
    sobol_df <- read.csv ("sobol_results.csv")
    sobol_df <- sobol_df [!(sobol_df$param %in% FIXED_EXCLUDE), ]
    param_names <- sobol_df$param [seq_len (min (TOP_N, nrow (sobol_df)))]
    cli_alert_info (col_yellow (
        "Using top {length(param_names)} parameters from Sobol (delta excluded): {.field {param_names}}"
    ))
} else if (file.exists ("morris_results.csv")) {
    morris_df <- read.csv ("morris_results.csv")
    morris_df <- morris_df [!(morris_df$param %in% FIXED_EXCLUDE), ]
    param_names <- as.character (morris_df$param [seq_len (min (TOP_N, nrow (morris_df)))])
    cli_alert_warning ("sobol_results.csv not found; using top {length(param_names)} \\
                     parameters from Morris (delta excluded)")
} else {
    param_names <- all_param_names
    cli_alert_warning ("No prior results; using all {length(param_names)} parameters")
}
p <- length (param_names)

binf <- all_binf [param_names]
bsup <- all_bsup [param_names]

# Structural constants from defaults.json; inactive free params at midpoints.
d <- jsonlite::fromJSON ("defaults.json")
log_dir <- if (!is.null (d$log_dir)) d$log_dir else "/tmp/escalation"
dir.create (log_dir, recursive = TRUE, showWarnings = FALSE)
old_done <- list.files (log_dir, pattern = "\\.done$", full.names = TRUE)
if (length (old_done) > 0) file.remove (old_done)
cli_alert_info ("Progress files will be written to {log_dir}")

fixed <- list (
    n = as.integer (d$n), mu0 = 0.5, sigma0 = d$sigma0,
    c = d$c, e = d$e,
    dw_coop = d$dw_coop, dw_sub = d$dw_sub, dw_excl = d$dw_excl,
    eta = d$eta,
    delta_direct = d$delta_direct, delta_exploit = d$delta_exploit,
    w_min = d$w_min, w_max = d$w_max,
    sigma_drift = d$sigma_drift, rho_contested = d$rho_contested,
    eta_trauma = d$eta_trauma,
    delta = d$delta,
    t_max = 5000L,
    gamma = 3.0, lambda = 3.0, alpha = 1.0, theta = 2L, beta = 1.5,
    w_win = 1.0, b = 1.0, w_loss = 1.0, dw_obs = 0.1, dw_bridge = 0.1,
    eta_obs = 0.05
)

# ---------------------------------------------------------------------------
# LHS design
# ---------------------------------------------------------------------------
N_LHS <- as.integer (if (!is.null (d$n_lhs)) d$n_lhs else 1000L)
cli_alert_info ("Generating LHS design (N={N_LHS}, p={p})...")
lhs_unit <- maximinLHS (N_LHS, p)
design_scaled <- as.data.frame (lhs_unit)
colnames (design_scaled) <- param_names
for (nm in param_names) {
    design_scaled [[nm]] <- binf [nm] + (bsup [nm] - binf [nm]) * design_scaled [[nm]]
}

# Expand to full Params CSV
design_full <- design_scaled
for (nm in names (fixed)) design_full [[nm]] <- fixed [[nm]]
for (nm in param_names) design_full [[nm]] <- design_scaled [[nm]]
design_full$theta <- pmax (1L, pmin (4L, as.integer (round (design_full$theta))))
design_full$n <- as.integer (design_full$n)
design_full$t_max <- as.integer (design_full$t_max)

write.csv (design_full, "design_lhs.csv", row.names = FALSE)
cli_alert_info ("Wrote design_lhs.csv")

# ---------------------------------------------------------------------------
# Run Rust gp-train subcommand (5 replicates per design point)
# ---------------------------------------------------------------------------
binary <- "./target/release/escalation"
n_rep <- as.integer (if (!is.null (d$n_rep_gp)) d$n_rep_gp else 5L)
if (!file.exists (binary)) stop ("Binary not found — run 'cargo build --release'")

n_expected <- N_LHS * n_rep
cli_alert_info ("Running binary ({N_LHS} design points x {n_rep} replicates = {n_expected} pairs)...")
cli_alert_info ("Expected {n_expected} progress files — monitor: ls {log_dir}/*.done | wc -l")
result <- processx::run (
    binary,
    c (
        "gp-train",
        "--design", "design_lhs.csv",
        "--replicates", as.character (n_rep),
        "--output", "gp_train_raw.csv",
        "--log-dir", log_dir
    ),
    echo = TRUE, error_on_status = FALSE
)
if (result$status != 0) stop ("Binary failed: ", result$stderr)

# ---------------------------------------------------------------------------
# Aggregate R=5 replicates per design point
# ---------------------------------------------------------------------------
raw <- read.csv ("gp_train_raw.csv")

# Rows: for each design point, 2*(mu0 lo + hi) * n_rep = 2*n_rep rows
# mu0==0.4 rows have psi values; group by design_row index
# Assign a design_row id: row pairs (lo, hi) repeat for each seed then each design pt
# Layout: [pair1_seed0_lo, pair1_seed0_hi, pair1_seed1_lo, ..., pair2_seed0_lo, ...]
raw <- raw %>%
    mutate (
        pair_idx = ceiling (row_number () / (2 * n_rep)),
        is_lo    = (row_number () %% 2 == 1)
    )

gp_data <- raw %>%
    filter (is_lo) %>%
    group_by (pair_idx) %>%
    summarise (
        psi_mean = mean (psi, na.rm = TRUE),
        psi_sd = sd (psi, na.rm = TRUE),
        tau_psi_mean = mean (tau_psi, na.rm = TRUE),
        .groups = "drop"
    )
gp_data$psi_sd [is.na (gp_data$psi_sd)] <- 0 # sd is NA when only 1 valid value

# Attach design parameters
design_ids <- seq_len (N_LHS)
stopifnot (nrow (gp_data) == N_LHS)
gp_data <- bind_cols (design_scaled [design_ids, ], gp_data)
write.csv (gp_data, "gp_data.csv", row.names = FALSE)
cli_alert_info ("Wrote gp_data.csv")

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
train_idx <- unlist (lapply (split (seq_len (N_LHS), gp_data$quintile), function (idx) {
    sample (idx, size = floor (0.8 * length (idx)))
}))
test_idx <- setdiff (seq_len (N_LHS), train_idx)
cli_alert_info ("Train: {length(train_idx)}  Test: {length(test_idx)}")

X_train <- gp_data [train_idx, param_names, drop = FALSE]
X_test <- gp_data [test_idx, param_names, drop = FALSE]
y_train <- gp_data$psi_mean [train_idx]
y_test <- gp_data$psi_mean [test_idx]
tau_train <- gp_data$tau_psi_mean [train_idx]

# ---------------------------------------------------------------------------
# Fit GPs
# ---------------------------------------------------------------------------
cli_alert_info ("Fitting GP on Psi (n_train={nrow(X_train)}, p={p})...")
cli_alert_info ("DiceKriging Cholesky is O(n^3) — may take several minutes")

noise_var_train <- gp_data$psi_sd [train_idx]^2
noise_var_train [noise_var_train == 0] <- 1e-6 # avoid zero noise

fit_psi <- km (
    formula = ~1,
    design = X_train,
    response = y_train,
    covtype = "matern5_2",
    nugget.estim = TRUE,
    noise.var = noise_var_train,
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

saveRDS (fit_psi, "gp_psi.rds")
saveRDS (fit_tau, "gp_tau.rds")
cli_alert_info ("Saved gp_psi.rds and gp_tau.rds")

# ---------------------------------------------------------------------------
# Validation on hold-out
# ---------------------------------------------------------------------------
pred_psi <- predict (fit_psi, newdata = X_test, type = "UK", checkNames = FALSE)
pred_tau <- predict (fit_tau, newdata = X_test, type = "UK", checkNames = FALSE)

rmse_psi <- sqrt (mean ((pred_psi$mean - y_test)^2))
rmse_tau <- sqrt (mean ((pred_tau$mean - gp_data$tau_psi_mean [test_idx])^2, na.rm = TRUE))

# 95% prediction interval coverage
in_pi_psi <- abs (pred_psi$mean - y_test) <= 1.96 * pred_psi$sd
coverage_psi <- mean (in_pi_psi, na.rm = TRUE)

validation <- data.frame (
    metric = c ("rmse_psi", "rmse_tau", "coverage_95_psi"),
    value  = c (rmse_psi, rmse_tau, coverage_psi)
)
write.csv (validation, "gp_validation.csv", row.names = FALSE)
cli_alert_info ("Validation: RMSE(Psi)={round(rmse_psi, 4)}  Coverage(Psi)={round(coverage_psi, 3)}")

# ---------------------------------------------------------------------------
# Hyperparameters: ARD length scales and output variance
# ---------------------------------------------------------------------------
ell <- coef.cov (fit_psi) # ARD length scales (one per dimension)
sigma2 <- coef.var (fit_psi) # output variance
nugget <- fit_psi@covariance@nugget

hyperparams <- data.frame (
    param = param_names,
    ell = ell,
    sensitivity = 1 / ell # inverse length scale ~ influence
)
hyperparams <- hyperparams [order (hyperparams$ell), ] # short ell first = most sensitive

meta <- data.frame (
    param = c ("sigma2", "nugget"),
    ell = c (sigma2, nugget),
    sensitivity = NA
)
hyperparams <- rbind (hyperparams, meta)
write.csv (hyperparams, "gp_hyperparams.csv", row.names = FALSE)

cli_alert_info ("ARD length scales (short = sensitive):")
print (hyperparams [hyperparams$param %in% param_names, c ("param", "ell")], digits = 3)
cli_alert_info ("Wrote gp_hyperparams.csv")
