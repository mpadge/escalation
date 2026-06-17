#!/usr/bin/env Rscript
# Shared utilities for analysis scripts.

library (DiceKriging)
library (cli)

safe_clear_done_files <- function (log_dir, expected_n) {
    old_done <- list.files (log_dir, pattern = "\\.done$", full.names = TRUE)
    n <- length (old_done)
    if (n == 0L) return (invisible (NULL))
    if (n == expected_n) {
        chk <- file.remove (old_done)
        return (invisible (NULL))
    }
    cli_alert_warning (
        "Found {.val {n}} of {.val {expected_n}} expected .done files in \\
        {.file {log_dir}} — a previous run was interrupted."
    )
    response <- readline ("Overwrite partial results and re-run from scratch? [y/N] ")
    if (!tolower (trimws (response)) %in% c ("y", "yes")) {
        cli_abort ("Aborted. Clean {.file {log_dir}} manually and re-run.")
    }
    chk <- file.remove (old_done)
    invisible (NULL)
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
        newdata    = X_test [, colnames (fit@X), drop = FALSE],
        type       = "UK",
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
    cli_alert_info ("{label} ARD length scales (short = sensitive):")
    print (df, digits = 3, row.names = FALSE)
    cli_alert_info (
        "{label}: sigma2={.val {round (sigma2, 4)}}  \\
        nugget={.val {round (nugget, 6)}}"
    )
    list (ell = setNames (ell, colnames (fit@X)), sigma2 = sigma2, nugget = nugget)
}

build_phase_grid <- function (p_a, p_b, binf, bsup, fixed_vals,
                               param_names, n_grid = 50L) {
    seq_a <- seq (binf [p_a], bsup [p_a], length.out = n_grid)
    seq_b <- seq (binf [p_b], bsup [p_b], length.out = n_grid)
    grid  <- expand.grid (A = seq_a, B = seq_b)
    colnames (grid) <- c (p_a, p_b)
    for (nm in param_names) {
        if (!(nm %in% c (p_a, p_b))) grid [[nm]] <- fixed_vals [[nm]]
    }
    grid
}

write_phase_csv <- function (grid, p_a, p_b, pred_mean, out_dir, name) {
    df      <- grid [, c (p_a, p_b)]
    df$val  <- pred_mean
    path    <- file.path (out_dir, paste0 (name, ".csv"))
    write.csv (df, path, row.names = FALSE)
    cli_alert_info ("Wrote {.file {path}}")
    invisible (path)
}
