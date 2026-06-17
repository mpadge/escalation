#!/usr/bin/env Rscript
# GP emulators and emulator-based Sobol sensitivity for gini_k_final and
# gini_dissipative (gini_peak - gini_k_final) in the bivariate (ε, σ) model.
# Joins gp_bivar_train.csv to design_gp_bivar.csv on (lambda, alpha) — which
# uniquely identifies the 1000 LHS design points — to recover mu_sigma,
# sigma_sigma, dw_obs, dw_bridge.
#
# Prerequisites: install.packages(c("DiceKriging", "sensitivity", "dplyr", "RcppTOML", "cli"))
# Run from project root: Rscript analysis/gp_gini_bivar.R
# Requires: results/gp_bivar_train.csv, results/design_gp_bivar.csv

library (DiceKriging)
library (sensitivity)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)

set.seed (42)
cli_h1 (col_yellow ("Bivariate Gini GP: gini_k_final and gini_dissipative"))

results_dir <- "results"
pars        <- RcppTOML::parseTOML ("defaults.toml")
n_sobol     <- as.integer (pars$gp$n_sobol_gp)
batch_size  <- as.integer (pars$gp$batch_size_gp)

BIVAR_PARAMS <- c ("mu_sigma", "lambda", "sigma_sigma", "dw_obs", "dw_bridge", "alpha") # nolint

# ---------------------------------------------------------------------------
# Load and join
# ---------------------------------------------------------------------------

train_file  <- file.path (results_dir, "gp_bivar_train.csv")
design_file <- file.path (results_dir, "design_gp_bivar.csv")
for (f in c (train_file, design_file))
    if (!file.exists (f)) cli_abort ("{.file {f}} not found")

cli_alert_info ("Reading {.file {train_file}}...")
raw <- read.csv (train_file)
cli_alert_info ("Rows: {.val {nrow(raw)}}")

cli_alert_info ("Reading {.file {design_file}}...")
design <- read.csv (design_file) |>
    select (all_of (BIVAR_PARAMS)) |>
    distinct () |>
    mutate (pair_idx = row_number ())

# (lambda, alpha) uniquely identify design points — verified in exploratory analysis
raw <- raw |>
    left_join (design, by = c ("lambda", "alpha")) |>
    mutate (gini_dissipative = gini_peak - gini_k_final)

n_unmatched <- sum (is.na (raw$pair_idx))
if (n_unmatched > 0)
    cli_alert_warning ("{.val {n_unmatched}} rows failed to match design — check parameter precision")

cli_alert_info ("Matched {.val {nrow(raw) - n_unmatched}} / {.val {nrow(raw)}} rows")

# ---------------------------------------------------------------------------
# Aggregate per design point per mu0 condition
# ---------------------------------------------------------------------------

aggregate_bivar <- function (raw, response_col) {
    design_pts <- raw |>
        filter (mu0 < 0.5) |>
        group_by (pair_idx) |>
        slice (1L) |>
        ungroup () |>
        select (pair_idx, all_of (BIVAR_PARAMS))

    y_lo <- raw |>
        filter (mu0 < 0.5) |>
        group_by (pair_idx) |>
        summarise (y_lo = mean (.data [[response_col]], na.rm = TRUE), .groups = "drop")

    y_hi <- raw |>
        filter (mu0 > 0.5) |>
        group_by (pair_idx) |>
        summarise (y_hi = mean (.data [[response_col]], na.rm = TRUE), .groups = "drop")

    gp_data <- design_pts |>
        left_join (y_lo, by = "pair_idx") |>
        left_join (y_hi, by = "pair_idx")

    cli_alert_info (
        "{response_col}: {.val {nrow(gp_data)}} design points  \\
        y_lo=[{round(min(gp_data$y_lo,na.rm=T),3)}, {round(max(gp_data$y_lo,na.rm=T),3)}]  \\
        y_hi=[{round(min(gp_data$y_hi,na.rm=T),3)}, {round(max(gp_data$y_hi,na.rm=T),3)}]"
    )
    gp_data
}

cli_h2 (col_yellow ("Aggregate gini_k_final"))
gp_gini_data <- aggregate_bivar (raw, "gini_k_final")
write.csv (gp_gini_data, file.path (results_dir, "gp_gini_bivar_data.csv"), row.names = FALSE)
cli_alert_info ("Wrote gp_gini_bivar_data.csv")

cli_h2 (col_yellow ("Aggregate gini_dissipative"))
gp_diss_data <- aggregate_bivar (raw, "gini_dissipative")

# ---------------------------------------------------------------------------
# Train/test split (stratified by y_avg quintile)
# ---------------------------------------------------------------------------

split_tt_bivar <- function (gp_data) {
    n     <- nrow (gp_data)
    y_avg <- (gp_data$y_lo + gp_data$y_hi) / 2
    quintile <- cut (
        y_avg,
        breaks         = quantile (y_avg, probs = seq (0, 1, 0.2), na.rm = TRUE),
        include.lowest = TRUE,
        labels         = FALSE
    )
    set.seed (42)
    train_idx <- unlist (lapply (
        split (seq_len (n), quintile),
        function (idx) sample (idx, size = floor (0.8 * length (idx)))
    ))
    test_idx <- setdiff (seq_len (n), train_idx)
    cli_alert_info ("Train: {.val {length(train_idx)}}  Test: {.val {length(test_idx)}}")
    X <- gp_data [, BIVAR_PARAMS, drop = FALSE]
    list (
        X_train    = X [train_idx, , drop = FALSE],
        X_test     = X [test_idx,  , drop = FALSE],
        y_lo_train = gp_data$y_lo [train_idx],
        y_lo_test  = gp_data$y_lo [test_idx],
        y_hi_train = gp_data$y_hi [train_idx],
        y_hi_test  = gp_data$y_hi [test_idx]
    )
}

fit_gp <- function (X_train, y_train, label) {
    cli_alert_info (
        "Fitting GP {label} (n_train={.val {nrow(X_train)}}, p={.val {ncol(X_train)}})..."
    )
    km (
        formula      = ~1,
        design       = X_train,
        response     = y_train,
        covtype      = "matern5_2",
        nugget.estim = TRUE,
        control      = list (trace = FALSE)
    )
}

validate_gp <- function (fit, X_test, y_test, label) {
    pred <- predict (fit, newdata = X_test [, colnames (fit@X), drop = FALSE],
                     type = "UK", checkNames = TRUE)
    rmse <- sqrt (mean ((pred$mean - y_test)^2, na.rm = TRUE))
    cov  <- mean (abs (pred$mean - y_test) <= 1.96 * pred$sd, na.rm = TRUE)
    cli_alert_info ("{label}: RMSE={.val {round(rmse,4)}}  Coverage(95%)={.val {round(cov,3)}}")
}

# ---------------------------------------------------------------------------
# Fit GPs
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("Fit GPs for gini_k_final"))
sp_gini <- split_tt_bivar (gp_gini_data)

fit_gini_lo <- fit_gp (sp_gini$X_train, sp_gini$y_lo_train, "gini_bivar_lo")
saveRDS (fit_gini_lo, file.path (results_dir, "gp_gini_bivar_lo.rds"))
fit_gini_hi <- fit_gp (sp_gini$X_train, sp_gini$y_hi_train, "gini_bivar_hi")
saveRDS (fit_gini_hi, file.path (results_dir, "gp_gini_bivar_hi.rds"))
validate_gp (fit_gini_lo, sp_gini$X_test, sp_gini$y_lo_test, "gini_bivar_lo")
validate_gp (fit_gini_hi, sp_gini$X_test, sp_gini$y_hi_test, "gini_bivar_hi")

cli_h2 (col_yellow ("Fit GPs for gini_dissipative"))
sp_diss <- split_tt_bivar (gp_diss_data)

fit_diss_lo <- fit_gp (sp_diss$X_train, sp_diss$y_lo_train, "diss_bivar_lo")
saveRDS (fit_diss_lo, file.path (results_dir, "gp_diss_bivar_lo.rds"))
fit_diss_hi <- fit_gp (sp_diss$X_train, sp_diss$y_hi_train, "diss_bivar_hi")
saveRDS (fit_diss_hi, file.path (results_dir, "gp_diss_bivar_hi.rds"))
validate_gp (fit_diss_lo, sp_diss$X_test, sp_diss$y_lo_test, "diss_bivar_lo")
validate_gp (fit_diss_hi, sp_diss$X_test, sp_diss$y_hi_test, "diss_bivar_hi")

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
    vapply (BIVAR_PARAMS, function (nm) pars$ranges [[nm]] [1L], numeric (1)),
    BIVAR_PARAMS
)
all_bsup <- setNames (
    vapply (BIVAR_PARAMS, function (nm) pars$ranges [[nm]] [2L], numeric (1)),
    BIVAR_PARAMS
)

set.seed (42)
sobol_gini_lo <- run_gp_sobol (fit_gini_lo, BIVAR_PARAMS, all_binf, all_bsup, n_sobol, batch_size, "gini_k_final (lo)")
sobol_gini_hi <- run_gp_sobol (fit_gini_hi, BIVAR_PARAMS, all_binf, all_bsup, n_sobol, batch_size, "gini_k_final (hi)")
sobol_diss_lo <- run_gp_sobol (fit_diss_lo, BIVAR_PARAMS, all_binf, all_bsup, n_sobol, batch_size, "gini_dissipative (lo)")
sobol_diss_hi <- run_gp_sobol (fit_diss_hi, BIVAR_PARAMS, all_binf, all_bsup, n_sobol, batch_size, "gini_dissipative (hi)")

sobol_gini_lo$condition <- "lo"; sobol_gini_lo$estimand <- "gini_k_final"
sobol_gini_hi$condition <- "hi"; sobol_gini_hi$estimand <- "gini_k_final"
sobol_diss_lo$condition <- "lo"; sobol_diss_lo$estimand <- "gini_dissipative"
sobol_diss_hi$condition <- "hi"; sobol_diss_hi$estimand <- "gini_dissipative"

sobol_all <- rbind (sobol_gini_lo, sobol_gini_hi, sobol_diss_lo, sobol_diss_hi)
write.csv (sobol_all, file.path (results_dir, "sobol_gini_bivar.csv"), row.names = FALSE)
cli_alert_success (col_green ("Wrote sobol_gini_bivar.csv"))
cli_alert_info ("Sobol indices (bivariate Gini):")
print (sobol_all [, c ("estimand", "condition", "param", "S1", "ST")], digits = 3, row.names = FALSE)
