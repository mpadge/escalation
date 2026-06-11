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
library (processx)

source ("analysis/utils.R")

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

select_active_params <- function (results_dir, all_param_names, fixed_exclude,
                                  top_n) {
    if (file.exists (file.path (results_dir, "sobol_results.csv"))) {
        df <- read.csv (file.path (results_dir, "sobol_results.csv"))
        df <- df [!(df$param %in% fixed_exclude), ]
        param_names <- df$param [seq_len (min (top_n, nrow (df)))]
        cli_alert_info (col_yellow (
            "Using top {length(param_names)} parameters from Sobol \\
            (delta excluded): {.field {param_names}}"
        ))
    } else if (file.exists (file.path (results_dir, "morris_results.csv"))) {
        df <- read.csv (file.path (results_dir, "morris_results.csv"))
        df <- df [!(df$param %in% fixed_exclude), ]
        param_names <- df$param [seq_len (min (top_n, nrow (df)))]
        cli_alert_warning (col_yellow (
            "{.file sobol_results.csv} not found; using top \\
            {length(param_names)} parameters from Morris (delta excluded)"
        ))
    } else {
        param_names <- all_param_names
        cli_alert_warning (
            "No prior results; using all {length(param_names)} parameters"
        )
    }
    param_names
}

make_lhs_design <- function (param_names, binf, bsup, fixed, n_lhs,
                              results_dir) {
    p <- length (param_names)
    cli_alert_info (
        "Generating LHS design (N={.val {n_lhs}}, p={.val {p}})..."
    )
    lhs_unit <- maximinLHS (n_lhs, p)
    design_scaled <- as.data.frame (lhs_unit)
    colnames (design_scaled) <- param_names
    for (nm in param_names) {
        design_scaled [[nm]] <-
            binf [nm] + (bsup [nm] - binf [nm]) * design_scaled [[nm]]
    }
    design_full <- design_scaled
    for (nm in names (fixed)) design_full [[nm]] <- fixed [[nm]]
    for (nm in param_names)   design_full [[nm]] <- design_scaled [[nm]]
    design_full$theta <-
        pmax (1L, pmin (4L, as.integer (round (design_full$theta))))
    design_full$n     <- as.integer (design_full$n)
    design_full$t_max <- as.integer (design_full$t_max)
    write.csv (design_full, file.path (results_dir, "design_lhs.csv"),
               row.names = FALSE)
    cli_alert_info ("Wrote {.file design_lhs.csv}")
    list (design_scaled = design_scaled, design_full = design_full)
}

run_gp_binary <- function (binary, results_dir, log_dir, n_lhs, n_rep) {
    out_file      <- file.path (results_dir, "gp_train_raw.csv")
    expected_rows <- n_lhs * n_rep * 2L  # lo + hi per (design point, seed)

    resume <- FALSE
    if (file.exists (out_file)) {
        n_existing <- length (readLines (out_file, warn = FALSE)) - 1L
        if (n_existing >= expected_rows) {
            cli_alert_info ("{.file {out_file}} already complete; skipping binary run.")
            return (invisible (NULL))
        }
        cli_alert_warning (col_yellow (
            "{.file {out_file}} has {.val {n_existing}}/{.val {expected_rows}} rows — resuming."
        ))
        resume <- TRUE
    }

    if (!resume) {
        safe_clear_done_files (log_dir, expected_n = n_lhs * n_rep)
    }

    n_expected <- n_lhs * n_rep
    cli_alert_info (
        "Running binary ({.val {n_lhs}} design points x \\
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
            "--design",     file.path (results_dir, "design_lhs.csv"),
            "--replicates", as.character (n_rep),
            "--output",     out_file,
            "--log-dir",    log_dir,
            if (resume) "--resume" else character (0)
        ),
        echo = TRUE, error_on_status = FALSE
    )
    if (result$status != 0) stop ("Binary failed: ", result$stderr)
}

aggregate_replicates <- function (results_dir, design_scaled, param_names,
                                  n_lhs, n_rep) {
    out_file <- file.path (results_dir, "gp_data.csv")
    if (file.exists (out_file)) {
        cli_alert_warning (col_red (
            "{.file {out_file}} already exists; loading from disk."
        ))
        return (read.csv (out_file))
    }
    raw <- read.csv (file.path (results_dir, "gp_train_raw.csv"))
    # Layout per design point: [pair_seed0_lo, pair_seed0_hi, pair_seed1_lo,
    #   ...] for n_rep seeds, repeating for each design point.
    raw <- raw |>
        mutate (
            pair_idx = ceiling (row_number () / (2 * n_rep)),
            is_lo    = (row_number () %% 2 == 1)
        )
    gp_data <- raw |>
        filter (is_lo) |>
        group_by (pair_idx) |>
        summarise (
            psi_mean     = mean (psi,     na.rm = TRUE),
            psi_sd       = sd   (psi,     na.rm = TRUE),
            tau_psi_mean = mean (tau_psi, na.rm = TRUE),
            .groups = "drop"
        )
    gp_data$psi_sd [is.na (gp_data$psi_sd)] <- 0
    stopifnot (nrow (gp_data) == n_lhs)
    gp_data <- bind_cols (design_scaled [seq_len (n_lhs), ], gp_data)
    write.csv (gp_data, out_file, row.names = FALSE)
    cli_alert_info ("Wrote {.file {out_file}}")
    gp_data
}

split_train_test <- function (gp_data, n_lhs, param_names) {
    gp_data$quintile <- cut (
        gp_data$psi_mean,
        breaks = quantile (gp_data$psi_mean, probs = seq (0, 1, 0.2),
                           na.rm = TRUE),
        include.lowest = TRUE, labels = FALSE
    )
    set.seed (123)
    train_idx <- unlist (lapply (
        split (seq_len (n_lhs), gp_data$quintile),
        function (idx) sample (idx, size = floor (0.8 * length (idx)))
    ))
    test_idx <- setdiff (seq_len (n_lhs), train_idx)
    cli_alert_info (
        "Train: {.val {length(train_idx)}}  Test: {.val {length(test_idx)}}"
    )
    list (
        X_train   = gp_data [train_idx, param_names, drop = FALSE],
        X_test    = gp_data [test_idx,  param_names, drop = FALSE],
        y_train   = gp_data$psi_mean     [train_idx],
        y_test    = gp_data$psi_mean     [test_idx],
        tau_train = gp_data$tau_psi_mean [train_idx],
        tau_test  = gp_data$tau_psi_mean [test_idx]
    )
}

fit_gps <- function (X_train, y_train, tau_train, results_dir) {
    p <- ncol (X_train)
    cli_alert_info (
        "Fitting GP on Psi (n_train={.val {nrow(X_train)}}, p={.val {p}})..."
    )
    cli_alert_info ("DiceKriging Cholesky is O(n^3) — may take several minutes")
    fit_psi <- km (
        formula = ~1, design = X_train, response = y_train,
        covtype = "matern5_2", nugget.estim = TRUE,
        control = list (trace = FALSE)
    )
    cli_alert_info ("Fitting GP on tau_psi...")
    fit_tau <- km (
        formula = ~1, design = X_train, response = tau_train,
        covtype = "matern5_2", nugget.estim = TRUE,
        control = list (trace = FALSE)
    )
    saveRDS (fit_psi, file.path (results_dir, "gp_psi.rds"))
    saveRDS (fit_tau, file.path (results_dir, "gp_tau.rds"))
    cli_alert_info ("Saved gp_psi.rds and gp_tau.rds")
    list (fit_psi = fit_psi, fit_tau = fit_tau)
}

validate_gps <- function (fit_psi, fit_tau, splits, results_dir) {
    pred_psi <- predict (fit_psi, newdata = splits$X_test, type = "UK",
                         checkNames = FALSE)
    pred_tau <- predict (fit_tau, newdata = splits$X_test, type = "UK",
                         checkNames = FALSE)
    rmse_psi     <- sqrt (mean ((pred_psi$mean - splits$y_test)^2))
    rmse_tau     <- sqrt (mean ((pred_tau$mean - splits$tau_test)^2,
                                na.rm = TRUE))
    coverage_psi <- mean (
        abs (pred_psi$mean - splits$y_test) <= 1.96 * pred_psi$sd,
        na.rm = TRUE
    )
    validation <- data.frame (
        metric = c ("rmse_psi", "rmse_tau", "coverage_95_psi"),
        value  = c (rmse_psi, rmse_tau, coverage_psi)
    )
    write.csv (validation, file.path (results_dir, "gp_validation.csv"),
               row.names = FALSE)
    cli_alert_info (
        "Validation: RMSE(Psi)={.val {round(rmse_psi, 4)}}  \\
        Coverage(Psi)={.val {round(coverage_psi, 3)}}"
    )
}

extract_hyperparams <- function (fit_psi, param_names, results_dir) {
    ell    <- fit_psi@covariance@range.val
    sigma2 <- fit_psi@covariance@sd2
    nugget <- fit_psi@covariance@nugget
    hyperparams <- data.frame (
        param       = param_names,
        ell         = ell,
        sensitivity = 1 / ell
    )
    hyperparams <- hyperparams [order (hyperparams$ell), ]
    meta <- data.frame (
        param = c ("sigma2", "nugget"), ell = c (sigma2, nugget),
        sensitivity = NA
    )
    hyperparams <- rbind (hyperparams, meta)
    write.csv (hyperparams, file.path (results_dir, "gp_hyperparams.csv"),
               row.names = FALSE)
    cli_alert_info ("ARD length scales (short = sensitive):")
    print (hyperparams [hyperparams$param %in% param_names,
                        c ("param", "ell")], digits = 3)
    cli_alert_info ("Wrote gp_hyperparams.csv")
    invisible (hyperparams)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)
cli_h1 (col_yellow ("GP training"))

results_dir <- "results"
if (!dir.exists (results_dir)) {
    cli_abort (
        "Output directory {.file {results_dir}} not found — \\
        run {.file analysis/morris.R} first"
    )
}

# delta fixed at pars_s$delta — suppresses Psi monotonically; held out of analyses
all_param_names <- c (
    "gamma", "lambda", "alpha", "theta", "beta",
    "w_win", "b", "w_loss", "dw_obs", "dw_bridge", "eta_obs"
)
FIXED_EXCLUDE <- c ("delta") # nolint

pars   <- RcppTOML::parseTOML ("defaults.toml")
pars_s <- pars$structural
pars_a <- pars$analysis

all_binf <- setNames (
    vapply (all_param_names, function (nm) pars$ranges [[nm]] [1L], numeric (1)),
    all_param_names
)
all_bsup <- setNames (
    vapply (all_param_names, function (nm) pars$ranges [[nm]] [2L], numeric (1)),
    all_param_names
)

param_names <- select_active_params (
    results_dir, all_param_names, FIXED_EXCLUDE, pars$gp$top_n_gp
)
cli_inform ("")
p    <- length (param_names)
binf <- all_binf [param_names]
bsup <- all_bsup [param_names]

log_dir <- if (!is.null (pars_s$log_dir)) pars_s$log_dir else "/tmp/escalation"
dir.create (log_dir, recursive = TRUE, showWarnings = FALSE)

fixed <- list (
    n             = as.integer (pars_a$n),
    mu0           = pars_a$mu0,
    sigma0        = pars_a$sigma0,
    c             = pars_a$c,
    e             = pars_a$e,
    dw_coop       = pars_a$dw_coop,
    dw_sub        = pars_a$dw_sub,
    dw_excl       = pars_a$dw_excl,
    eta           = pars_a$eta,
    delta_direct  = pars_a$delta_direct,
    delta_exploit = pars_a$delta_exploit,
    w_min         = pars_s$w_min,
    w_max         = pars_s$w_max,
    sigma_drift   = pars_s$sigma_drift,
    rho_contested = pars_s$rho_contested,
    eta_trauma    = pars_s$eta_trauma,
    delta         = pars_s$delta,
    t_max         = as.integer (pars_a$t_max_gp),
    gamma         = pars_a$mid_gamma,
    lambda        = pars_a$mid_lambda,
    alpha         = pars_a$mid_alpha,
    theta         = as.integer (pars_a$mid_theta),
    beta          = pars_a$mid_beta,
    w_win         = pars_a$mid_w_win,
    b             = pars_a$mid_b,
    w_loss        = pars_a$mid_w_loss,
    dw_obs        = pars_a$mid_dw_obs,
    dw_bridge     = pars_a$mid_dw_bridge,
    eta_obs       = pars_a$mid_eta_obs
)

binary <- "./target/release/escalation"
if (!file.exists (binary)) {
    cli_abort ("Binary not found — run 'cargo build --release'")
}

N_LHS <- as.integer (if (!is.null (pars$gp$n_lhs))    pars$gp$n_lhs    else 1000L) # nolint
n_rep <- as.integer (if (!is.null (pars$gp$n_rep_gp)) pars$gp$n_rep_gp else 5L)

cli_h2 (col_yellow ("Design and progress data"))
cli_alert_info ("Progress files will be written to {.file {log_dir}}")
design <- make_lhs_design (param_names, binf, bsup, fixed, N_LHS, results_dir)
cli_inform ("")

cli_h2 (col_yellow ("Run 'gp-train' Rust binary"))
run_gp_binary (binary, results_dir, log_dir, N_LHS, n_rep)
cli_inform ("")

cli_h2 (col_yellow ("Post-processing"))
gp_data <- aggregate_replicates (
    results_dir, design$design_scaled, param_names, N_LHS, n_rep
)
cli_inform ("")
splits <- split_train_test (gp_data, N_LHS, param_names)
fits   <- fit_gps (splits$X_train, splits$y_train, splits$tau_train, results_dir)
validate_gps (fits$fit_psi, fits$fit_tau, splits, results_dir)
extract_hyperparams (fits$fit_psi, param_names, results_dir)
