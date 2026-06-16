#!/usr/bin/env Rscript
# GP emulator training for the bivariate (ε, σ) escalation model.
# Generates an LHS design over 6 bivariate parameters, runs the Rust gp-train
# subcommand, aggregates replicates, fits Matern-5/2 ARD GPs on psi_sigma and
# psi via DiceKriging, validates on hold-out, and saves model objects +
# diagnostics.
#
# Prerequisites: install.packages(c("lhs", "DiceKriging", "dplyr", "cli"))
# Run from project root: Rscript analysis/gp_train_bivar.R

library (lhs)
library (DiceKriging)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)
library (processx)

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

make_lhs_design_bivar <- function (param_names, binf, bsup, fixed, n_lhs,
                                    results_dir) {
    p <- length (param_names)
    cli_alert_info (
        "Generating LHS design (N={.val {n_lhs}}, p={.val {p}})..."
    )
    lhs_unit      <- maximinLHS (n_lhs, p)
    design_scaled <- as.data.frame (lhs_unit)
    colnames (design_scaled) <- param_names
    for (nm in param_names) {
        design_scaled [[nm]] <-
            binf [nm] + (bsup [nm] - binf [nm]) * design_scaled [[nm]]
    }
    design_full <- design_scaled
    for (nm in names (fixed)) design_full [[nm]] <- fixed [[nm]]
    for (nm in param_names)    design_full [[nm]] <- design_scaled [[nm]]
    design_full$n     <- as.integer (design_full$n)
    design_full$theta <- as.integer (design_full$theta)
    design_full$t_max <- as.integer (design_full$t_max)
    write.csv (design_full,
               file.path (results_dir, "design_gp_bivar.csv"),
               row.names = FALSE)
    cli_alert_info ("Wrote {.file design_gp_bivar.csv}")
    list (design_scaled = design_scaled, design_full = design_full)
}

run_gp_train_binary_bivar <- function (binary, results_dir, log_dir, n_lhs,
                                        n_rep) {
    out_file      <- file.path (results_dir, "gp_bivar_train.csv")
    expected_rows <- n_lhs * n_rep * 2L  # lo + hi per (design point, seed)

    n_existing  <- if (file.exists (out_file))
        length (readLines (out_file, warn = FALSE)) - 1L
    else 0L
    n_done      <- length (list.files (log_dir, pattern = "\\.done$"))
    has_partial <- n_existing > 0L || n_done > 0L

    if (n_existing >= expected_rows) {
        cli_alert_info (
            "{.file {out_file}} already complete; skipping binary run."
        )
        return (invisible (NULL))
    }

    resume <- FALSE
    if (has_partial) {
        cli_alert_warning (col_yellow (
            "Existing state: {.val {n_existing}}/{.val {expected_rows}} \\
            CSV rows, {.val {n_done}} .done files."
        ))
        response <- tolower (trimws (readline (
            "Resume from checkpoint? [Y/n/restart] "
        )))
        if (response %in% c ("restart", "r")) {
            cli_alert_info ("Restarting from scratch...")
            if (file.exists (out_file)) chk <- file.remove (out_file)
            old_done <- list.files (
                log_dir,
                pattern    = "\\.done$",
                full.names = TRUE
            )
            if (length (old_done) > 0L) chk <- file.remove (old_done)
        } else if (response %in% c ("", "y", "yes")) {
            resume <- TRUE
            cli_alert_info (
                "Resuming from row {.val {n_existing / (n_rep * 2L) + 1L}}..."
            )
        } else {
            cli_abort ("Aborted.")
        }
    }

    cli_alert_info (
        "Running binary ({.val {n_lhs}} design points x \\
        {.val {n_rep}} replicates = {.val {n_lhs * n_rep}} pairs)..."
    )
    cli_alert_info (
        "Expected {.val {n_lhs * n_rep}} progress files \\
        — use {.code make progress} to see."
    )
    result <- processx::run (
        binary,
        c (
            "gp-train",
            "--design",     file.path (results_dir, "design_gp_bivar.csv"),
            "--replicates", as.character (n_rep),
            "--output",     out_file,
            "--log-dir",    log_dir,
            if (resume) "--resume" else character (0)
        ),
        echo = TRUE, error_on_status = FALSE
    )
    if (result$status != 0) stop ("Binary failed: ", result$stderr)
}

aggregate_replicates_bivar <- function (results_dir, design_scaled, param_names,
                                         n_lhs, n_rep) {
    out_file <- file.path (results_dir, "gp_bivar_data.csv")
    if (file.exists (out_file)) {
        cli_alert_warning (col_red (
            "{.file {out_file}} already exists; loading from disk."
        ))
        return (read.csv (out_file))
    }
    raw <- read.csv (file.path (results_dir, "gp_bivar_train.csv"))
    raw <- raw |>
        mutate (
            pair_idx = ceiling (row_number () / (2 * n_rep)),
            is_lo    = (row_number () %% 2 == 1)
        )
    gp_data <- raw |>
        filter (is_lo) |>
        group_by (pair_idx) |>
        summarise (
            psi_mean       = mean (psi,       na.rm = TRUE),
            psi_sigma_mean = mean (psi_sigma, na.rm = TRUE),
            .groups = "drop"
        )
    stopifnot (nrow (gp_data) == n_lhs)
    gp_data <- bind_cols (design_scaled [seq_len (n_lhs), ], gp_data)
    write.csv (gp_data, out_file, row.names = FALSE)
    cli_alert_info ("Wrote {.file {out_file}}")
    gp_data
}

split_train_test_bivar <- function (gp_data, n_lhs, param_names) {
    gp_data$quintile <- ntile (gp_data$psi_sigma_mean, 5L)
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
        X_train         = gp_data [train_idx, param_names, drop = FALSE],
        X_test          = gp_data [test_idx,  param_names, drop = FALSE],
        psi_train       = gp_data$psi_mean       [train_idx],
        psi_test        = gp_data$psi_mean       [test_idx],
        psi_sigma_train = gp_data$psi_sigma_mean [train_idx],
        psi_sigma_test  = gp_data$psi_sigma_mean [test_idx]
    )
}

fit_gps_bivar <- function (x_train, psi_train, psi_sigma_train, results_dir) {
    p <- ncol (x_train)
    cli_alert_info (
        "Fitting GP on psi_sigma \\
        (n_train={.val {nrow(x_train)}}, p={.val {p}})..."
    )
    cli_alert_info ("DiceKriging Cholesky is O(n^3) — may take several minutes")
    fit_psi_sigma <- km (
        formula = ~1, design = x_train, response = psi_sigma_train,
        covtype = "matern5_2", nugget.estim = TRUE,
        control = list (trace = FALSE)
    )
    cli_alert_info ("Fitting GP on psi...")
    fit_psi <- km (
        formula = ~1, design = x_train, response = psi_train,
        covtype = "matern5_2", nugget.estim = TRUE,
        control = list (trace = FALSE)
    )
    saveRDS (fit_psi_sigma, file.path (results_dir, "gp_bivar_psi_sigma.rds"))
    saveRDS (fit_psi,       file.path (results_dir, "gp_bivar_psi.rds"))
    cli_alert_info ("Saved gp_bivar_psi_sigma.rds and gp_bivar_psi.rds")
    list (fit_psi_sigma = fit_psi_sigma, fit_psi = fit_psi)
}

validate_gps_bivar <- function (fit_psi_sigma, fit_psi, splits, results_dir) {
    pred_ps <- predict (fit_psi_sigma, newdata = splits$X_test,
                        type = "UK", checkNames = FALSE)
    pred_p  <- predict (fit_psi,       newdata = splits$X_test,
                        type = "UK", checkNames = FALSE)
    rmse_ps <- sqrt (mean ((pred_ps$mean - splits$psi_sigma_test)^2, na.rm = TRUE))
    rmse_p  <- sqrt (mean ((pred_p$mean  - splits$psi_test)^2,       na.rm = TRUE))
    cov_ps  <- mean (
        abs (pred_ps$mean - splits$psi_sigma_test) <= 1.96 * pred_ps$sd,
        na.rm = TRUE
    )
    cov_p <- mean (
        abs (pred_p$mean - splits$psi_test) <= 1.96 * pred_p$sd,
        na.rm = TRUE
    )
    validation <- data.frame (
        metric = c ("rmse_psi_sigma", "rmse_psi",
                    "coverage_95_psi_sigma", "coverage_95_psi"),
        value  = c (rmse_ps, rmse_p, cov_ps, cov_p)
    )
    write.csv (validation,
               file.path (results_dir, "gp_bivar_validation.csv"),
               row.names = FALSE)
    cli_alert_info (
        "Validation: RMSE(psi_sigma)={.val {round(rmse_ps, 4)}} \\
        Coverage={.val {round(cov_ps, 3)}}"
    )
    cli_alert_info (
        "Validation: RMSE(psi)={.val {round(rmse_p, 4)}} \\
        Coverage={.val {round(cov_p, 3)}}"
    )
}

extract_hyperparams_bivar <- function (fit_psi_sigma, fit_psi, param_names,
                                        results_dir) {
    extract_one <- function (fit, label) {
        ell    <- fit@covariance@range.val
        sigma2 <- fit@covariance@sd2
        nugget <- fit@covariance@nugget
        df <- data.frame (
            estimand    = label,
            param       = param_names,
            ell         = ell,
            sensitivity = round (1 / ell, 3)
        )
        cli_alert_info ("{label} ARD length scales (short = sensitive):")
        print (df [, c ("param", "ell", "sensitivity")],
               digits = 3, row.names = FALSE)
        cli_alert_info (
            "{label}: sigma2={.val {round(sigma2, 4)}} \\
            nugget={.val {round(nugget, 6)}}"
        )
        df
    }
    hp <- rbind (
        extract_one (fit_psi_sigma, "psi_sigma"),
        extract_one (fit_psi,       "psi")
    )
    write.csv (hp, file.path (results_dir, "gp_bivar_hyperparams.csv"),
               row.names = FALSE)
    cli_alert_info ("Wrote {.file gp_bivar_hyperparams.csv}")
    invisible (hp)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)
cli_h1 (col_yellow ("GP bivariate training"))

results_dir <- "results"
if (!dir.exists (results_dir)) {
    cli_abort (
        "Output directory {.file {results_dir}} not found — \\
        run Stage 6 analysis first"
    )
}

# 6 bivariate Sobol params in Morris mu* order (Stage 6)
param_names <- c (
    "mu_sigma", "lambda", "sigma_sigma", "dw_obs", "dw_bridge", "alpha"
)

pars   <- RcppTOML::parseTOML ("defaults.toml")
pars_s <- pars$structural
pars_a <- pars$analysis

binf <- setNames (
    vapply (param_names, function (nm) pars$ranges [[nm]] [1L], numeric (1)),
    param_names
)
bsup <- setNames (
    vapply (param_names, function (nm) pars$ranges [[nm]] [2L], numeric (1)),
    param_names
)

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
    theta         = as.integer (pars_a$mid_theta),
    beta          = pars_a$mid_beta,
    w_win         = pars_a$mid_w_win,
    b             = pars_a$mid_b,
    w_loss        = pars_a$mid_w_loss,
    # fixed to avoid collinearity with mu_sigma
    eta_obs       = pars_a$mid_eta_obs
)

binary <- "./target/release/escalation"
if (!file.exists (binary)) {
    cli_abort ("Binary not found — run 'cargo build --release'")
}

N_LHS <- as.integer ( # nolint
    if (!is.null (pars$gp$n_lhs)) pars$gp$n_lhs else 1000L
)
n_rep <- as.integer (
    if (!is.null (pars$gp$n_rep_gp)) pars$gp$n_rep_gp else 20L
)

cli_h2 (col_yellow ("Design and progress data"))
cli_alert_info ("Progress files will be written to {.file {log_dir}}")
design <- make_lhs_design_bivar (
    param_names, binf, bsup, fixed, N_LHS, results_dir
)
cli_inform ("")

cli_h2 (col_yellow ("Run 'gp-train' Rust binary"))
run_gp_train_binary_bivar (binary, results_dir, log_dir, N_LHS, n_rep)
cli_inform ("")

cli_h2 (col_yellow ("Post-processing"))
gp_data <- aggregate_replicates_bivar (
    results_dir, design$design_scaled, param_names, N_LHS, n_rep
)
cli_inform ("")
splits <- split_train_test_bivar (gp_data, N_LHS, param_names)
fits   <- fit_gps_bivar (
    splits$X_train, splits$psi_train, splits$psi_sigma_train, results_dir
)
validate_gps_bivar (fits$fit_psi_sigma, fits$fit_psi, splits, results_dir)
extract_hyperparams_bivar (
    fits$fit_psi_sigma, fits$fit_psi, param_names, results_dir
)
cli_alert_success (col_green ("GP bivariate training complete."))
