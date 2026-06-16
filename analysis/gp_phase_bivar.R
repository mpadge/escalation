#!/usr/bin/env Rscript
# GP phase diagrams for the bivariate (ε, σ) escalation model.
# Loads fitted GP objects from gp_train_bivar.R, generates 50×50 phase grids
# for three fixed axis pairs (mu_sigma × sigma_sigma, mu_sigma × alpha,
# mu_sigma × lambda) for both psi_sigma and psi estimands, and writes six
# phase CSVs to results/gp_bivar_phase/.
#
# Prerequisites: install.packages(c("DiceKriging", "dplyr", "cli", "RcppTOML"))
# Run from project root: Rscript analysis/gp_phase_bivar.R
# Requires: gp_bivar_psi_sigma.rds, gp_bivar_psi.rds (from gp_train_bivar.R)

library (DiceKriging)
library (dplyr, warn.conflicts = FALSE)
library (cli)
library (RcppTOML)

source ("analysis/gp_phase_utils.R")

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

load_gp_models_bivar <- function (results_dir) {
    for (f in c ("gp_bivar_psi_sigma.rds", "gp_bivar_psi.rds")) {
        path <- file.path (results_dir, f)
        if (!file.exists (path))
            cli_abort ("{.file {path}} not found — run gp_train_bivar.R first")
    }
    fit_psi_sigma <- readRDS (file.path (results_dir, "gp_bivar_psi_sigma.rds"))
    fit_psi       <- readRDS (file.path (results_dir, "gp_bivar_psi.rds"))
    list (fit_psi_sigma = fit_psi_sigma, fit_psi = fit_psi)
}

print_gp_diagnostics_bivar <- function (fit, label, param_names) {
    ell    <- fit@covariance@range.val
    sigma2 <- fit@covariance@sd2
    nugget <- fit@covariance@nugget
    cli_alert_info ("{label} ARD length scales:")
    df <- data.frame (param = param_names, ell = round (ell, 4),
                      sensitivity = round (1 / ell, 3))
    print (df, row.names = FALSE)
    cli_alert_info (
        "{label}: sigma2={.val {round(sigma2, 4)}} nugget={.val {round(nugget, 6)}}"
    )
}

build_phase_bivar <- function (fit_psi_sigma, fit_psi, param_names,
                                all_binf, all_bsup, mid_vals, phase_dir) {
    axis_pairs <- list (
        list (p_a = "mu_sigma", p_b = "sigma_sigma"),
        list (p_a = "mu_sigma", p_b = "alpha"),
        list (p_a = "mu_sigma", p_b = "lambda")
    )

    for (pair in axis_pairs) {
        p_a <- pair$p_a
        p_b <- pair$p_b
        tag <- paste0 (p_a, "_", p_b)
        cli_alert_info ("Phase grid: {tag}")

        grid <- build_phase_grid (
            p_a, p_b, all_binf, all_bsup, mid_vals, param_names
        )

        pred_ps <- predict_gp_pair (fit_psi_sigma, grid)
        pred_p  <- predict_gp_pair (fit_psi,       grid)

        df_ps        <- grid [, c (p_a, p_b)]
        df_ps$psi_sigma_mean <- pred_ps$mean

        df_p         <- grid [, c (p_a, p_b)]
        df_p$psi_mean <- pred_p$mean

        write.csv (df_ps,
                   file.path (phase_dir, paste0 ("phase_psi_sigma_", tag, ".csv")),
                   row.names = FALSE)
        write.csv (df_p,
                   file.path (phase_dir, paste0 ("phase_psi_", tag, ".csv")),
                   row.names = FALSE)
        cli_alert_info (
            "Wrote phase_psi_sigma_{tag}.csv and phase_psi_{tag}.csv"
        )
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)
cli_h1 (col_yellow ("GP bivariate phase diagrams"))

results_dir <- "results"
if (!dir.exists (results_dir)) {
    cli_abort (
        "Output directory {.file {results_dir}} not found — \\
        run Stage 6 analysis first"
    )
}
phase_dir <- file.path (results_dir, "gp_bivar_phase")
dir.create (phase_dir, recursive = TRUE, showWarnings = FALSE)

param_names <- c (
    "mu_sigma", "lambda", "sigma_sigma", "dw_obs", "dw_bridge", "alpha"
)

pars   <- RcppTOML::parseTOML ("defaults.toml")
pars_a <- pars$analysis

all_binf <- setNames (
    vapply (param_names, function (nm) pars$ranges [[nm]] [1L], numeric (1)),
    param_names
)
all_bsup <- setNames (
    vapply (param_names, function (nm) pars$ranges [[nm]] [2L], numeric (1)),
    param_names
)

mid_vals <- list (
    mu_sigma    = pars_a$mid_mu_sigma,
    lambda      = pars_a$mid_lambda,
    sigma_sigma = pars_a$mid_sigma_sigma,
    dw_obs      = pars_a$mid_dw_obs,
    dw_bridge   = pars_a$mid_dw_bridge,
    alpha       = pars_a$mid_alpha
)

cli_h2 (col_yellow ("Loading GP models"))
models <- load_gp_models_bivar (results_dir)

cli_h2 (col_yellow ("GP diagnostics"))
print_gp_diagnostics_bivar (models$fit_psi_sigma, "psi_sigma", param_names)
print_gp_diagnostics_bivar (models$fit_psi,       "psi",       param_names)

cli_h2 (col_yellow ("Phase grids"))
build_phase_bivar (
    models$fit_psi_sigma, models$fit_psi,
    param_names, all_binf, all_bsup, mid_vals, phase_dir
)

cli_alert_success (col_green ("GP bivariate phase diagrams complete."))
