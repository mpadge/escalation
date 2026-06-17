#!/usr/bin/env Rscript
# Consolidated Gini estimand analysis using the adaptive design from gp_explore.R.
# Fits Matern-5/2 ARD GPs for:
#   - gini_k_final         (equilibrium degree-centrality Gini)
#   - gini_dissipative     (gini_peak - gini_k_final)
#
# Uses the same bivariate parameter set as gp_explore.R / gp_train.R, enabling
# direct ARD sensitivity comparison across all three estimands (Psi, edeg, Gini).
#
# Outputs:
#   results/gp_gini.rds                          — Gini GP
#   results/gp_gini_dissip.rds                   — dissipative Gini GP
#   results/gp_phase/gini_k_final_lambda_alpha.csv
#   results/gp_phase/gini_dissipative_lambda_alpha.csv
#   results/gp_hyperparams_all.csv               — ARD comparison across estimands
#
# Prerequisites: install.packages(c("DiceKriging", "dplyr", "cli", "RcppTOML"))
# Run from project root: Rscript analysis/gini.R
# Requires: make explore completed

library (DiceKriging)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)

source ("analysis/utils.R")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

load_inputs <- function (results_dir) {
    design_file <- file.path (results_dir, "adaptive_design.csv")
    raw_file    <- file.path (results_dir, "gp_train_raw.csv")
    for (f in c (design_file, raw_file)) {
        if (!file.exists (f))
            cli_abort ("{.file {f}} not found — run {.code make explore} first")
    }
    list (design = read.csv (design_file), raw = read.csv (raw_file))
}

aggregate_gini <- function (raw, design, param_names, n_rep) {
    for (col in c ("gini_k_final", "gini_peak")) {
        if (!col %in% colnames (raw))
            cli_abort (
                "Column {.field {col}} not in gp_train_raw.csv — \\
                ensure binary outputs Gini metrics."
            )
    }
    raw <- raw |>
        mutate (
            pair_idx         = ceiling (row_number () / (2L * n_rep)),
            is_lo            = (row_number () %% 2L == 1L),
            gini_dissipative = gini_peak - gini_k_final
        )
    gp_data <- raw |>
        filter (is_lo) |>
        group_by (pair_idx) |>
        summarise (
            gini_mean        = mean (gini_k_final,     na.rm = TRUE),
            gini_dissip_mean = mean (gini_dissipative, na.rm = TRUE),
            .groups = "drop"
        )
    n_pts <- nrow (gp_data)
    if (n_pts != nrow (design))
        cli_alert_warning (
            "Design has {.val {nrow(design)}} rows but got \\
            {.val {n_pts}} aggregated points"
        )
    bind_cols (design [seq_len (n_pts), param_names, drop = FALSE], gp_data)
}

split_train_test <- function (gp_data, param_names, response_col) {
    n        <- nrow (gp_data)
    quintile <- dplyr::ntile (gp_data [[response_col]], 5L)
    set.seed (123L)
    train_idx <- unlist (lapply (
        split (seq_len (n), quintile),
        function (idx) sample (idx, size = floor (0.8 * length (idx)))
    ))
    test_idx <- setdiff (seq_len (n), train_idx)
    list (
        X_train = gp_data [train_idx, param_names, drop = FALSE],
        X_test  = gp_data [test_idx,  param_names, drop = FALSE],
        y_train = gp_data [[response_col]] [train_idx],
        y_test  = gp_data [[response_col]] [test_idx]
    )
}

fit_and_save <- function (gp_data, param_names, response_col, label, out_rds) {
    splits <- split_train_test (gp_data, param_names, response_col)
    fit    <- fit_gp_surface (splits$X_train, splits$y_train, label)
    validate_gp_surface (fit, splits$X_test, splits$y_test, label)
    hp <- print_hyperparams (fit, label)
    saveRDS (fit, out_rds)
    cli_alert_info ("Saved {.file {out_rds}}")
    list (fit = fit, hp = hp)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)
cli_h1 (col_yellow ("Gini estimand GP analysis"))

results_dir <- "results"
phase_dir   <- file.path (results_dir, "gp_phase")
dir.create (phase_dir, recursive = TRUE, showWarnings = FALSE)

pars   <- RcppTOML::parseTOML ("defaults.toml")
pars_a <- pars$analysis
n_rep  <- as.integer (
    if (!is.null (pars$gp$n_rep_gp)) pars$gp$n_rep_gp else 20L
)

dat <- load_inputs (results_dir)
param_names <- setdiff (colnames (dat$design), c ("pair_idx", "psi_mean"))
cli_alert_info ("Parameters in adaptive design: {.field {param_names}}")

get_range <- function (nm) {
    r <- pars$ranges [[nm]]
    if (!is.null (r)) return (r)
    stop ("No range found in defaults.toml for: ", nm)
}
binf <- setNames (
    vapply (param_names, function (nm) get_range (nm) [1L], numeric (1)),
    param_names
)
bsup <- setNames (
    vapply (param_names, function (nm) get_range (nm) [2L], numeric (1)),
    param_names
)

all_mid <- list (
    gamma       = pars_a$mid_gamma,
    lambda      = pars_a$mid_lambda,
    alpha       = pars_a$mid_alpha,
    theta       = as.integer (pars_a$mid_theta),
    beta        = pars_a$mid_beta,
    w_win       = pars_a$mid_w_win,
    b           = pars_a$mid_b,
    w_loss      = pars_a$mid_w_loss,
    dw_obs      = pars_a$mid_dw_obs,
    dw_bridge   = pars_a$mid_dw_bridge,
    mu_sigma    = pars_a$mid_mu_sigma,
    sigma_sigma = pars_a$mid_sigma_sigma,
    eta_sigma   = pars_a$mid_eta_sigma,
    sigma_decay = pars_a$mid_sigma_decay
)
mid_vals <- all_mid [param_names]

# ---------------------------------------------------------------------------
# Aggregate Gini estimands
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("Aggregate Gini from raw training data"))
gp_data <- aggregate_gini (dat$raw, dat$design, param_names, n_rep)
cli_alert_info (
    "gini_k_final range: [{round(min(gp_data$gini_mean,na.rm=TRUE),3)}, \\
    {round(max(gp_data$gini_mean,na.rm=TRUE),3)}]"
)
cli_alert_info (
    "gini_dissipative range: [{round(min(gp_data$gini_dissip_mean,na.rm=TRUE),3)}, \\
    {round(max(gp_data$gini_dissip_mean,na.rm=TRUE),3)}]"
)

# ---------------------------------------------------------------------------
# Fit GPs
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("Fit GP: gini_k_final"))
res_gini <- fit_and_save (
    gp_data, param_names, "gini_mean",
    "gini_k_final", file.path (results_dir, "gp_gini.rds")
)

cli_h2 (col_yellow ("Fit GP: gini_dissipative"))
res_diss <- fit_and_save (
    gp_data, param_names, "gini_dissip_mean",
    "gini_dissipative", file.path (results_dir, "gp_gini_dissip.rds")
)

# ---------------------------------------------------------------------------
# Phase CSVs over lambda x alpha
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("Phase diagrams"))

phase_grid <- build_phase_grid (
    "lambda", "alpha", binf, bsup, mid_vals, param_names, n_grid = 50L
)

pred_gini <- predict (
    res_gini$fit,
    newdata    = phase_grid [, param_names, drop = FALSE],
    type       = "UK",
    checkNames = FALSE
)
write_phase_csv (
    phase_grid, "lambda", "alpha",
    pred_gini$mean, phase_dir, "gini_k_final_lambda_alpha"
)

pred_diss <- predict (
    res_diss$fit,
    newdata    = phase_grid [, param_names, drop = FALSE],
    type       = "UK",
    checkNames = FALSE
)
write_phase_csv (
    phase_grid, "lambda", "alpha",
    pred_diss$mean, phase_dir, "gini_dissipative_lambda_alpha"
)

# ---------------------------------------------------------------------------
# ARD sensitivity comparison across all estimands
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("ARD sensitivity comparison across estimands"))

collect_ard <- function (rds_path, label) {
    fit <- readRDS (rds_path)
    ell <- fit@covariance@range.val
    data.frame (
        estimand    = label,
        param       = colnames (fit@X),
        ell         = ell,
        sensitivity = round (1 / ell, 3)
    )
}

ard_files <- list (
    psi          = file.path (results_dir, "gp_psi.rds"),
    edeg         = file.path (results_dir, "gp_edeg.rds"),
    psi_sigma    = file.path (results_dir, "gp_psi_sigma.rds"),
    gini_k_final = file.path (results_dir, "gp_gini.rds"),
    gini_dissip  = file.path (results_dir, "gp_gini_dissip.rds")
)

ard_all <- do.call (rbind, lapply (names (ard_files), function (label) {
    path <- ard_files [[label]]
    if (!file.exists (path)) {
        cli_alert_warning ("{.file {path}} not found — skipping {label}")
        return (NULL)
    }
    collect_ard (path, label)
}))

write.csv (
    ard_all,
    file.path (results_dir, "gp_hyperparams_all.csv"),
    row.names = FALSE
)

cli_alert_info ("ARD sensitivity rankings across estimands:")
print (
    ard_all [order (ard_all$estimand, ard_all$ell), c ("estimand", "param", "sensitivity")],
    digits = 3, row.names = FALSE
)

cli_alert_success (col_green ("Wrote gp_hyperparams_all.csv"))
cli_alert_success (col_green ("Gini GP analysis complete."))
