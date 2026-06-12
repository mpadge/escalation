library (DiceKriging)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)

TOP_PARAMS <- c ("alpha", "gamma", "lambda", "eta_obs") # nolint

load_raw_data <- function (results_dir, n_rep) {
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

    eta_fixed <- RcppTOML::parseTOML ("defaults.toml")$analysis$eta
    raw |>
        mutate (pair_idx = ceiling (row_number () / (2L * n_rep))) |>
        mutate (eta_obs = kappa * eta_fixed)
}

build_design_matrix <- function (raw, response_col) {
    design_pts <- raw |>
        filter (mu0 < 0.5) |>
        group_by (pair_idx) |>
        slice (1L) |>
        ungroup () |>
        select (pair_idx, all_of (TOP_PARAMS))

    y_lo <- raw |>
        filter (mu0 < 0.5) |>
        group_by (pair_idx) |>
        summarise (
            y_lo = mean (.data [[response_col]], na.rm = TRUE),
            .groups = "drop"
        )

    y_hi <- raw |>
        filter (mu0 > 0.5) |>
        group_by (pair_idx) |>
        summarise (
            y_hi = mean (.data [[response_col]], na.rm = TRUE),
            .groups = "drop"
        )

    gp_data <- design_pts |>
        left_join (y_lo, by = "pair_idx") |>
        left_join (y_hi, by = "pair_idx")

    cli_alert_info ("Aggregated: {.val {nrow (gp_data)}} design points")
    cli_alert_info (
        "y_lo range: [{round (min (gp_data$y_lo, na.rm = TRUE), 3)}, \\
        {round (max (gp_data$y_lo, na.rm = TRUE), 3)}]"
    )
    cli_alert_info (
        "y_hi range: [{round (min (gp_data$y_hi, na.rm = TRUE), 3)}, \\
        {round (max (gp_data$y_hi, na.rm = TRUE), 3)}]"
    )
    gp_data
}

split_train_test <- function (gp_data) {
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
    cli_alert_info (
        "Train: {.val {length (train_idx)}}  Test: {.val {length (test_idx)}}"
    )

    X <- gp_data [, TOP_PARAMS, drop = FALSE]
    list (
        X_train    = X [train_idx, , drop = FALSE],
        X_test     = X [test_idx,  , drop = FALSE],
        y_lo_train = gp_data$y_lo [train_idx],
        y_lo_test  = gp_data$y_lo [test_idx],
        y_hi_train = gp_data$y_hi [train_idx],
        y_hi_test  = gp_data$y_hi [test_idx]
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
    cli_alert_info ("{label} ARD length scales:")
    print (df, digits = 3, row.names = FALSE)
    cli_alert_info (
        "{label}: sigma2={.val {round (sigma2, 4)}}  \\
        nugget={.val {round (nugget, 6)}}"
    )
    list (ell = setNames (ell, colnames (fit@X)), sigma2 = sigma2, nugget = nugget)
}

save_hyperparams_csv <- function (hp_lo, hp_hi, val_lo, val_hi, path) {
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
    write.csv (df, path, row.names = FALSE)
    cli_alert_info ("Wrote {.file {path}}")
}
