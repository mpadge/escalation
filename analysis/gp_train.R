#!/usr/bin/env Rscript
# GP training on all estimands using the adaptive design from gp_explore.R.
# Loads results/gp_train_raw.csv and fits Matern-5/2 ARD GPs for:
#   - epsilon_k_corr_final (epsilon-degree correlation)
#   - psi_sigma (sigma-perturbation sensitivity)
#
# Also generates a sigma-degenerate slice: predicts Psi at (mu_sigma=1,
# sigma_sigma=0) across the lambda x alpha grid using the existing gp_psi.rds.
# This is a new result on the adaptive design — not a reproduction of Stage 2.
#
# Outputs:
#   results/gp_edeg.rds                         — epsilon-degree GP
#   results/gp_psi_sigma.rds                    — psi_sigma GP
#   results/gp_phase/phase_edeg_lambda_alpha.csv
#   results/gp_phase/phase_psi_sigma_lambda_alpha.csv
#   results/gp_phase/psi_degenerate.csv         — sigma-degenerate Psi slice
#
# Prerequisites: install.packages(c("DiceKriging", "dplyr", "cli", "RcppTOML"))
# Run from project root: Rscript analysis/gp_train.R
# Requires: make explore completed

library (DiceKriging)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)

source ("analysis/utils.R")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

load_design_and_raw <- function (results_dir) {
    design_file <- file.path (results_dir, "adaptive_design.csv")
    raw_file    <- file.path (results_dir, "gp_train_raw.csv")
    for (f in c (design_file, raw_file)) {
        if (!file.exists (f))
            cli_abort ("{.file {f}} not found — run {.code make explore} first")
    }
    list (
        design = read.csv (design_file),
        raw    = read.csv (raw_file)
    )
}

aggregate_estimand <- function (raw, design, param_names, metric_col, n_rep) {
    if (!metric_col %in% colnames (raw)) {
        cli_abort (
            "Column {.field {metric_col}} not found in gp_train_raw.csv. \\
            Ensure the Rust binary outputs this metric."
        )
    }
    raw <- raw |>
        mutate (
            pair_idx = ceiling (row_number () / (2L * n_rep)),
            is_lo    = (row_number () %% 2L == 1L)
        )
    gp_data <- raw |>
        filter (is_lo) |>
        group_by (pair_idx) |>
        summarise (
            y_mean = mean (.data [[metric_col]], na.rm = TRUE),
            .groups = "drop"
        )
    n_pts <- nrow (gp_data)
    if (n_pts != nrow (design)) {
        cli_alert_warning (
            "Design has {.val {nrow(design)}} rows but got \\
            {.val {n_pts}} aggregated points — check n_rep"
        )
    }
    bind_cols (design [seq_len (n_pts), param_names, drop = FALSE], gp_data)
}

split_train_test <- function (gp_data, param_names) {
    n        <- nrow (gp_data)
    quintile <- dplyr::ntile (gp_data$y_mean, 5L)
    set.seed (123L)
    train_idx <- unlist (lapply (
        split (seq_len (n), quintile),
        function (idx) sample (idx, size = floor (0.8 * length (idx)))
    ))
    test_idx <- setdiff (seq_len (n), train_idx)
    cli_alert_info (
        "Train: {.val {length(train_idx)}}  Test: {.val {length(test_idx)}}"
    )
    list (
        X_train = gp_data [train_idx, param_names, drop = FALSE],
        X_test  = gp_data [test_idx,  param_names, drop = FALSE],
        y_train = gp_data$y_mean [train_idx],
        y_test  = gp_data$y_mean [test_idx]
    )
}

fit_and_save <- function (gp_data, param_names, label, out_rds) {
    splits <- split_train_test (gp_data, param_names)
    fit    <- fit_gp_surface (splits$X_train, splits$y_train, label)
    validate_gp_surface (fit, splits$X_test, splits$y_test, label)
    print_hyperparams (fit, label)
    saveRDS (fit, out_rds)
    cli_alert_info ("Saved {.file {out_rds}}")
    fit
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)
cli_h1 (col_yellow ("GP training on all estimands"))

results_dir <- "results"
phase_dir   <- file.path (results_dir, "gp_phase")
dir.create (phase_dir, recursive = TRUE, showWarnings = FALSE)

pars   <- RcppTOML::parseTOML ("defaults.toml")
pars_a <- pars$analysis

n_rep <- as.integer (
    if (!is.null (pars$gp$n_rep_gp)) pars$gp$n_rep_gp else 20L
)

# Param names derived from adaptive_design.csv columns (exclude pair_idx if present)
dat <- load_design_and_raw (results_dir)
# param_names = columns of adaptive_design.csv (all are free params)
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
# Epsilon-degree correlation GP
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("epsilon_k_corr_final"))
gp_edeg_data <- aggregate_estimand (
    dat$raw, dat$design, param_names, "epsilon_k_corr_final", n_rep
)
fit_edeg <- fit_and_save (
    gp_edeg_data, param_names,
    "edeg", file.path (results_dir, "gp_edeg.rds")
)

# ---------------------------------------------------------------------------
# psi_sigma GP
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("psi_sigma"))
gp_psi_sigma_data <- aggregate_estimand (
    dat$raw, dat$design, param_names, "psi_sigma", n_rep
)
fit_psi_sigma <- fit_and_save (
    gp_psi_sigma_data, param_names,
    "psi_sigma", file.path (results_dir, "gp_psi_sigma.rds")
)

# ---------------------------------------------------------------------------
# Phase CSVs for edeg and psi_sigma over lambda x alpha
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("Phase diagrams: edeg and psi_sigma"))

phase_grid <- build_phase_grid (
    "lambda", "alpha", binf, bsup, mid_vals, param_names, n_grid = 50L
)

pred_edeg <- predict (
    fit_edeg,
    newdata    = phase_grid [, param_names, drop = FALSE],
    type       = "UK",
    checkNames = FALSE
)
write_phase_csv (
    phase_grid, "lambda", "alpha",
    pred_edeg$mean, phase_dir, "phase_edeg_lambda_alpha"
)

pred_psi_sigma <- predict (
    fit_psi_sigma,
    newdata    = phase_grid [, param_names, drop = FALSE],
    type       = "UK",
    checkNames = FALSE
)
write_phase_csv (
    phase_grid, "lambda", "alpha",
    pred_psi_sigma$mean, phase_dir, "phase_psi_sigma_lambda_alpha"
)

# ---------------------------------------------------------------------------
# Sigma-degenerate Psi slice
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("Sigma-degenerate Psi slice (mu_sigma=1, sigma_sigma=0)"))

fit_psi_path <- file.path (results_dir, "gp_psi.rds")
if (!file.exists (fit_psi_path)) {
    cli_abort ("{.file {fit_psi_path}} not found — run {.code make explore} first")
}
fit_psi <- readRDS (fit_psi_path)

# Build lambda x alpha grid with sigma params fixed at degenerate values
degen_vals <- mid_vals
degen_vals [["mu_sigma"]]    <- 1.0  # sigma present but uniform
degen_vals [["sigma_sigma"]] <- 0.0  # no inter-individual variation

degen_grid <- build_phase_grid (
    "lambda", "alpha", binf, bsup, degen_vals, param_names, n_grid = 50L
)
pred_degen <- predict (
    fit_psi,
    newdata    = degen_grid [, param_names, drop = FALSE],
    type       = "UK",
    checkNames = FALSE
)
write_phase_csv (
    degen_grid, "lambda", "alpha",
    pred_degen$mean, phase_dir, "psi_degenerate"
)

cli_alert_success (col_green ("GP training complete."))
