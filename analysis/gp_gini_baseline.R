#!/usr/bin/env Rscript
# GP emulators and emulator-based Sobol sensitivity for gini_k_final and
# gini_dissipative (gini_peak - gini_k_final) in the baseline (ε-only) model.
# Uses Stage 003 raw training data (results/003-centrality-correlation/) and
# the same TOP_PARAMS as the Ψ/ε-degree analyses for direct comparability.
#
# Prerequisites: install.packages(c("DiceKriging", "sensitivity", "dplyr", "RcppTOML", "cli"))
# Run from project root: Rscript analysis/gp_gini_baseline.R
# Requires: results/003-centrality-correlation/gp_train_raw.csv

source ("analysis/gp_train_utils.R")
library (sensitivity)

set.seed (42)
cli_h1 (col_yellow ("Baseline Gini GP: gini_k_final and gini_dissipative"))

results_dir <- "results/003-centrality-correlation"
pars        <- RcppTOML::parseTOML ("defaults.toml")
n_rep       <- as.integer (pars$gp$n_rep_gp)
eta_fixed   <- pars$analysis$eta
n_sobol     <- as.integer (pars$gp$n_sobol_gp)
batch_size  <- as.integer (pars$gp$batch_size_gp)

# ---------------------------------------------------------------------------
# Load and prepare raw data
# ---------------------------------------------------------------------------

raw_file <- file.path (results_dir, "gp_train_raw.csv")
if (!file.exists (raw_file))
    cli_abort ("{.file {raw_file}} not found")
cli_alert_info ("Reading {.file {raw_file}}...")
raw <- read.csv (raw_file)

n_rows  <- nrow (raw)
n_pairs <- n_rows / (2L * n_rep)
cli_alert_info (
    "Rows: {.val {n_rows}} ({.val {n_pairs}} design points × \\
    {.val {n_rep}} replicates × 2 conditions)"
)

raw <- raw |>
    mutate (pair_idx         = ceiling (row_number () / (2L * n_rep))) |>
    mutate (eta_obs          = kappa * eta_fixed) |>
    mutate (gini_dissipative = gini_peak - gini_k_final)

# ---------------------------------------------------------------------------
# Aggregate design matrices
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("Aggregate gini_k_final"))
gp_gini_data <- build_design_matrix (raw, "gini_k_final")
write.csv (gp_gini_data, file.path (results_dir, "gp_gini_data.csv"), row.names = FALSE)
cli_alert_info ("Wrote gp_gini_data.csv")

cli_h2 (col_yellow ("Aggregate gini_dissipative"))
gp_diss_data <- build_design_matrix (raw, "gini_dissipative")

# ---------------------------------------------------------------------------
# Fit GPs
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("Fit GPs for gini_k_final"))
splits_gini <- split_train_test (gp_gini_data)

fit_gini_lo <- fit_gp_surface (splits_gini$X_train, splits_gini$y_lo_train, "gini_lo")
saveRDS (fit_gini_lo, file.path (results_dir, "gp_gini_lo.rds"))
cli_alert_info ("Saved gp_gini_lo.rds")

fit_gini_hi <- fit_gp_surface (splits_gini$X_train, splits_gini$y_hi_train, "gini_hi")
saveRDS (fit_gini_hi, file.path (results_dir, "gp_gini_hi.rds"))
cli_alert_info ("Saved gp_gini_hi.rds")

validate_gp_surface (fit_gini_lo, splits_gini$X_test, splits_gini$y_lo_test, "gini_lo")
validate_gp_surface (fit_gini_hi, splits_gini$X_test, splits_gini$y_hi_test, "gini_hi")

print_hyperparams (fit_gini_lo, "gini_lo")
print_hyperparams (fit_gini_hi, "gini_hi")

cli_h2 (col_yellow ("Fit GPs for gini_dissipative"))
splits_diss <- split_train_test (gp_diss_data)

fit_diss_lo <- fit_gp_surface (splits_diss$X_train, splits_diss$y_lo_train, "diss_lo")
saveRDS (fit_diss_lo, file.path (results_dir, "gp_diss_lo.rds"))
cli_alert_info ("Saved gp_diss_lo.rds")

fit_diss_hi <- fit_gp_surface (splits_diss$X_train, splits_diss$y_hi_train, "diss_hi")
saveRDS (fit_diss_hi, file.path (results_dir, "gp_diss_hi.rds"))
cli_alert_info ("Saved gp_diss_hi.rds")

validate_gp_surface (fit_diss_lo, splits_diss$X_test, splits_diss$y_lo_test, "diss_lo")
validate_gp_surface (fit_diss_hi, splits_diss$X_test, splits_diss$y_hi_test, "diss_hi")

print_hyperparams (fit_diss_lo, "diss_lo")
print_hyperparams (fit_diss_hi, "diss_hi")

# ---------------------------------------------------------------------------
# Emulator-based Sobol
# ---------------------------------------------------------------------------

run_gp_sobol <- function (fit, param_names, binf, bsup, n, batch_sz, label) {
    cli_h2 (col_yellow ("Emulator Sobol: {label}"))
    p <- length (param_names)
    make_sample <- function (nn) {
        df <- as.data.frame (matrix (NA_real_, nn, p))
        colnames (df) <- param_names
        for (nm in param_names)
            df [[nm]] <- binf [nm] + (bsup [nm] - binf [nm]) * runif (nn)
        df
    }
    s       <- sobol2007 (model = NULL,
                          X1 = make_sample (n), X2 = make_sample (n),
                          nboot = 100)
    n_pred  <- nrow (s$X)
    y_pred  <- numeric (n_pred)
    n_batch <- ceiling (n_pred / batch_sz)
    cli_progress_bar ("Predicting batches", total = n_batch)
    for (start in seq (1L, n_pred, by = batch_sz)) {
        end            <- min (start + batch_sz - 1L, n_pred)
        y_pred [start:end] <- predict (
            fit,
            newdata    = s$X [start:end, , drop = FALSE],
            type       = "SK",
            checkNames = TRUE
        )$mean
        cli_progress_update ()
    }
    cli_progress_done ()
    s <- tell (s, y_pred)
    data.frame (
        param    = param_names,
        S1       = s$S$original,
        S1_lower = s$S$`min. c.i.`,
        S1_upper = s$S$`max. c.i.`,
        ST       = s$T$original,
        ST_lower = s$T$`min. c.i.`,
        ST_upper = s$T$`max. c.i.`
    ) |>
        arrange (desc (ST))
}

all_binf <- setNames (
    vapply (TOP_PARAMS, function (nm) pars$ranges [[nm]] [1L], numeric (1)),
    TOP_PARAMS
)
all_bsup <- setNames (
    vapply (TOP_PARAMS, function (nm) pars$ranges [[nm]] [2L], numeric (1)),
    TOP_PARAMS
)

set.seed (42)
sobol_gini_lo <- run_gp_sobol (fit_gini_lo, TOP_PARAMS, all_binf, all_bsup, n_sobol, batch_size, "gini_k_final (lo)")
sobol_gini_hi <- run_gp_sobol (fit_gini_hi, TOP_PARAMS, all_binf, all_bsup, n_sobol, batch_size, "gini_k_final (hi)")
sobol_diss_lo <- run_gp_sobol (fit_diss_lo, TOP_PARAMS, all_binf, all_bsup, n_sobol, batch_size, "gini_dissipative (lo)")
sobol_diss_hi <- run_gp_sobol (fit_diss_hi, TOP_PARAMS, all_binf, all_bsup, n_sobol, batch_size, "gini_dissipative (hi)")

sobol_gini_lo$condition <- "lo"; sobol_gini_lo$estimand <- "gini_k_final"
sobol_gini_hi$condition <- "hi"; sobol_gini_hi$estimand <- "gini_k_final"
sobol_diss_lo$condition <- "lo"; sobol_diss_lo$estimand <- "gini_dissipative"
sobol_diss_hi$condition <- "hi"; sobol_diss_hi$estimand <- "gini_dissipative"

sobol_all <- rbind (sobol_gini_lo, sobol_gini_hi, sobol_diss_lo, sobol_diss_hi)
write.csv (sobol_all, file.path (results_dir, "sobol_gini_baseline.csv"), row.names = FALSE)
cli_alert_success (col_green ("Wrote sobol_gini_baseline.csv"))
cli_alert_info ("Sobol indices (baseline Gini):")
print (sobol_all [, c ("estimand", "condition", "param", "S1", "ST")], digits = 3, row.names = FALSE)
