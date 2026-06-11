#!/usr/bin/env Rscript
# Stage 2: Two-GP emulator training on absolute equilibrium escalation surfaces.
# Reads Stage 1 simulation data (gp_train_raw.csv), splits by mu0 condition,
# and fits separate Matern-5/2 ARD GPs for E_lo (mu0=0.4) and E_hi (mu0=0.6).
#
# Prerequisites: install.packages(c("DiceKriging", "dplyr", "RcppTOML", "cli"))
# Run from project root: Rscript analysis/gp_train2.R
# Requires: results/gp_train_raw.csv (from Stage 1 make gp)

library (DiceKriging)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)

# Top-4 parameters identified by Stage 1 Sobol analysis
TOP_PARAMS <- c ("alpha", "gamma", "lambda", "eta_obs") # nolint

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

load_and_aggregate <- function (results_dir, n_rep) {
    raw_file <- file.path (results_dir, "gp_train_raw.csv")
    if (!file.exists (raw_file)) {
        cli_abort (
            "{.file {raw_file}} not found — run Stage 1 {.code make gp} first"
        )
    }
    cli_alert_info ("Reading {.file {raw_file}}...")
    raw <- read.csv (raw_file)

    n_rows  <- nrow (raw)
    n_pairs <- n_rows / (2L * n_rep)
    cli_alert_info (
        "Rows: {.val {n_rows}} ({.val {n_pairs}} design points × \\
        {.val {n_rep}} replicates × 2 conditions)"
    )

    raw <- raw |>
        mutate (pair_idx = ceiling (row_number () / (2L * n_rep)))

    # Reconstruct eta_obs from kappa = eta_obs / eta (eta fixed at pars$analysis$eta)
    eta_fixed <- RcppTOML::parseTOML ("defaults.toml")$analysis$eta
    raw <- raw |> mutate (eta_obs = kappa * eta_fixed)

    # Design-point parameter values from the first lo row of each pair
    design_pts <- raw |>
        filter (mu0 < 0.5) |>
        group_by (pair_idx) |>
        slice (1L) |>
        ungroup () |>
        select (pair_idx, all_of (TOP_PARAMS))

    y_lo <- raw |>
        filter (mu0 < 0.5) |>
        group_by (pair_idx) |>
        summarise (y_lo = mean (mean_epsilon_final, na.rm = TRUE), .groups = "drop")

    y_hi <- raw |>
        filter (mu0 > 0.5) |>
        group_by (pair_idx) |>
        summarise (y_hi = mean (mean_epsilon_final, na.rm = TRUE), .groups = "drop")

    gp2_data <- design_pts |>
        left_join (y_lo, by = "pair_idx") |>
        left_join (y_hi, by = "pair_idx")

    cli_alert_info ("Aggregated: {.val {nrow (gp2_data)}} design points")
    cli_alert_info (
        "E_lo range: [{round (min (gp2_data$y_lo, na.rm = TRUE), 3)}, \\
        {round (max (gp2_data$y_lo, na.rm = TRUE), 3)}]"
    )
    cli_alert_info (
        "E_hi range: [{round (min (gp2_data$y_hi, na.rm = TRUE), 3)}, \\
        {round (max (gp2_data$y_hi, na.rm = TRUE), 3)}]"
    )
    gp2_data
}

split_train_test2 <- function (gp2_data) {
    n     <- nrow (gp2_data)
    y_avg <- (gp2_data$y_lo + gp2_data$y_hi) / 2

    quintile <- cut (
        y_avg,
        breaks = quantile (y_avg, probs = seq (0, 1, 0.2), na.rm = TRUE),
        include.lowest = TRUE, labels = FALSE
    )
    set.seed (42)
    train_idx <- unlist (lapply (
        split (seq_len (n), quintile),
        function (idx) sample (idx, size = floor (0.8 * length (idx)))
    ))
    test_idx <- setdiff (seq_len (n), train_idx)
    cli_alert_info (
        "Train: {.val {length (train_idx)}}  Test: {.val {length (test_idx)}}"
    )

    X <- gp2_data [, TOP_PARAMS, drop = FALSE]
    list (
        X_train      = X [train_idx, , drop = FALSE],
        X_test       = X [test_idx,  , drop = FALSE],
        y_lo_train   = gp2_data$y_lo [train_idx],
        y_lo_test    = gp2_data$y_lo [test_idx],
        y_hi_train   = gp2_data$y_hi [train_idx],
        y_hi_test    = gp2_data$y_hi [test_idx]
    )
}

fit_gp_surface <- function (X_train, y_train, label) {
    cli_alert_info (
        "Fitting GP on {label} \\
        (n_train={.val {nrow (X_train)}}, p={.val {ncol (X_train)}})..."
    )
    cli_alert_info ("DiceKriging Cholesky is O(n^3) — may take several minutes")
    km (
        formula      = ~1,
        design       = X_train,
        response     = y_train,
        covtype      = "matern5_2",
        nugget.estim = TRUE,
        control      = list (trace = FALSE)
    )
}

validate_gp_surface <- function (fit, X_test, y_test, label) {
    pred <- predict (
        fit,
        newdata = X_test [, colnames (fit@X), drop = FALSE],
        type    = "UK",
        checkNames = TRUE
    )
    rmse     <- sqrt (mean ((pred$mean - y_test)^2, na.rm = TRUE))
    coverage <- mean (
        abs (pred$mean - y_test) <= 1.96 * pred$sd,
        na.rm = TRUE
    )
    cli_alert_info (
        "{label}: RMSE={.val {round (rmse, 4)}}  \\
        Coverage(95%)={.val {round (coverage, 3)}}"
    )
    list (rmse = rmse, coverage = coverage)
}

print_hyperparams <- function (fit, label) {
    ell    <- fit@covariance@range.val
    sigma2 <- fit@covariance@sd2
    nugget <- fit@covariance@nugget
    df <- data.frame (
        param       = colnames (fit@X),
        ell         = ell,
        sensitivity = round (1 / ell, 3)
    )
    df <- df [order (df$ell), ]
    cli_alert_info ("{label} ARD length scales:")
    print (df, digits = 3, row.names = FALSE)
    cli_alert_info (
        "{label}: sigma2={.val {round (sigma2, 4)}}  \\
        nugget={.val {round (nugget, 6)}}"
    )
    list (ell = setNames (ell, colnames (fit@X)), sigma2 = sigma2, nugget = nugget)
}

save_hyperparams <- function (hp_lo, hp_hi, val_lo, val_hi, results_dir) {
    rows <- lapply (c ("lo", "hi"), function (cond) {
        hp  <- if (cond == "lo") hp_lo else hp_hi
        val <- if (cond == "lo") val_lo else val_hi
        data.frame (
            condition = cond,
            param     = names (hp$ell),
            ell       = hp$ell,
            sigma2    = hp$sigma2,
            nugget    = hp$nugget,
            rmse      = val$rmse,
            coverage  = val$coverage
        )
    })
    df <- do.call (rbind, rows)
    write.csv (df, file.path (results_dir, "gp2_hyperparams.csv"),
               row.names = FALSE)
    cli_alert_info ("Wrote {.file gp2_hyperparams.csv}")
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)
cli_h1 (col_yellow ("Stage 2: Two-GP training on absolute escalation surfaces"))

results_dir <- "results"
pars        <- RcppTOML::parseTOML ("defaults.toml")
n_rep       <- as.integer (pars$gp$n_rep_gp)

cli_h2 (col_yellow ("Load and aggregate Stage 1 data"))
gp2_data <- load_and_aggregate (results_dir, n_rep)
write.csv (gp2_data, file.path (results_dir, "gp2_data.csv"), row.names = FALSE)
cli_alert_info ("Wrote {.file gp2_data.csv}")

cli_h2 (col_yellow ("Train-test split"))
splits <- split_train_test2 (gp2_data)

cli_h2 (col_yellow ("Fit GP on E_lo (mu0 = 0.4)"))
fit_lo <- fit_gp_surface (splits$X_train, splits$y_lo_train, "E_lo")
saveRDS (fit_lo, file.path (results_dir, "gp_lo.rds"))
cli_alert_info ("Saved {.file gp_lo.rds}")

cli_h2 (col_yellow ("Fit GP on E_hi (mu0 = 0.6)"))
fit_hi <- fit_gp_surface (splits$X_train, splits$y_hi_train, "E_hi")
saveRDS (fit_hi, file.path (results_dir, "gp_hi.rds"))
cli_alert_info ("Saved {.file gp_hi.rds}")

cli_h2 (col_yellow ("Validation"))
val_lo <- validate_gp_surface (fit_lo, splits$X_test, splits$y_lo_test, "E_lo")
val_hi <- validate_gp_surface (fit_hi, splits$X_test, splits$y_hi_test, "E_hi")

cli_h2 (col_yellow ("Hyperparameters"))
hp_lo <- print_hyperparams (fit_lo, "E_lo")
hp_hi <- print_hyperparams (fit_hi, "E_hi")
save_hyperparams (hp_lo, hp_hi, val_lo, val_hi, results_dir)

cli_alert_success (col_green ("Done. Run {.code make gp2_phase} next."))
