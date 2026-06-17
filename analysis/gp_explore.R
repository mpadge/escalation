#!/usr/bin/env Rscript
# Adaptive phase exploration for the bivariate (ε, σ) escalation model.
# Replaces brute-force LHS with iterative gradient ascent on the GP posterior mean:
#   1. Coarse LHS (N=200) → fit GP on Psi.
#   2. Evaluate posterior mean on 30x30 lambda x alpha grid; locate peak.
#   3. Sample N=300 new points in shrinking hypercube around peak; retrain GP.
#   4. Repeat until peak location moves < 1% of parameter range, or K=5 iterations.
#
# Outputs:
#   results/adaptive_design.csv   — final combined design (scaled param values)
#   results/gp_train_raw.csv      — raw binary output for all iterations combined
#   results/gp_psi.rds            — final fitted GP for Psi
#   results/gp_phase/             — 50x50 phase CSVs over lambda x alpha
#
# Prerequisites: install.packages(c("lhs", "DiceKriging", "dplyr", "cli", "RcppTOML"))
# Run from project root: Rscript analysis/gp_explore.R
# Requires: cargo build --release (and make sobol recommended)

library (lhs)
library (DiceKriging)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)
library (processx)

source ("analysis/utils.R")

# ---------------------------------------------------------------------------
# Algorithm constants
# ---------------------------------------------------------------------------

N_INIT        <- 200L   # coarse LHS design size
N_REFINE      <- 300L   # new points per adaptive iteration
K_MAX         <- 5L     # maximum iterations
CONV_THRESH   <- 0.01   # convergence: max peak movement as fraction of range
INIT_WIDTH    <- 0.40   # initial hypercube half-side as fraction of range
WIDTH_SHRINK  <- 0.80   # per-iteration shrink factor
N_GRID        <- 30L    # grid resolution for peak detection
N_PHASE_GRID  <- 50L    # resolution for saved phase CSVs

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

select_gp_params <- function (results_dir, top_n) {
    sobol_file <- file.path (results_dir, "sobol_results.csv")
    fallback   <- c ("mu_sigma", "lambda", "sigma_sigma", "dw_obs", "dw_bridge", "alpha")
    if (!file.exists (sobol_file)) {
        cli_alert_warning (
            "sobol_results.csv not found; using known bivariate top-6 params"
        )
        return (fallback)
    }
    df <- read.csv (sobol_file)
    df <- df [df$estimand == "psi_sigma", ]
    df <- df [order (-df$ST), ]
    param_names <- df$param [seq_len (min (top_n, nrow (df)))]
    cli_alert_info (
        "Using top {.val {length(param_names)}} parameters from Sobol \\
        (psi_sigma ST ranking): {.field {param_names}}"
    )
    param_names
}

make_lhs_scaled <- function (n, param_names, binf, bsup) {
    p        <- length (param_names)
    lhs_unit <- maximinLHS (n, p)
    df       <- as.data.frame (lhs_unit)
    colnames (df) <- param_names
    for (nm in param_names)
        df [[nm]] <- binf [nm] + (bsup [nm] - binf [nm]) * df [[nm]]
    df
}

make_lhs_in_hypercube <- function (n, param_names, center, half_width,
                                   binf, bsup) {
    p        <- length (param_names)
    lhs_unit <- randomLHS (n, p)
    df       <- as.data.frame (lhs_unit)
    colnames (df) <- param_names
    for (nm in param_names) {
        lo        <- max (binf [nm], center [nm] - half_width [nm])
        hi        <- min (bsup [nm], center [nm] + half_width [nm])
        df [[nm]] <- lo + (hi - lo) * df [[nm]]
    }
    df
}

make_design_full <- function (design_scaled, fixed, param_names) {
    design_full <- design_scaled
    for (nm in names (fixed)) design_full [[nm]] <- fixed [[nm]]
    for (nm in param_names)   design_full [[nm]] <- design_scaled [[nm]]
    design_full$theta <-
        pmax (1L, pmin (4L, as.integer (round (design_full$theta))))
    design_full$n     <- as.integer (design_full$n)
    design_full$t_max <- as.integer (design_full$t_max)
    design_full
}

run_binary_batch <- function (binary, design_full, out_file, log_dir, n_rep) {
    batch_design_file <- tempfile (fileext = ".csv")
    write.csv (design_full, batch_design_file, row.names = FALSE)
    old_done <- list.files (log_dir, pattern = "\\.done$", full.names = TRUE)
    if (length (old_done) > 0L) chk <- file.remove (old_done)

    result <- processx::run (
        binary,
        c (
            "gp-train",
            "--design",     batch_design_file,
            "--replicates", as.character (n_rep),
            "--output",     out_file,
            "--log-dir",    log_dir
        ),
        echo = TRUE, error_on_status = FALSE
    )
    unlink (batch_design_file)
    if (result$status != 0) stop ("Binary failed: ", result$stderr)
    invisible (NULL)
}

aggregate_psi <- function (raw_file, design_scaled, param_names, n_rep) {
    raw <- read.csv (raw_file)
    raw <- raw |>
        mutate (
            pair_idx = ceiling (row_number () / (2L * n_rep)),
            is_lo    = (row_number () %% 2L == 1L)
        )
    gp_data <- raw |>
        filter (is_lo) |>
        group_by (pair_idx) |>
        summarise (psi_mean = mean (psi, na.rm = TRUE), .groups = "drop")
    stopifnot (nrow (gp_data) == nrow (design_scaled))
    bind_cols (design_scaled, gp_data)
}

split_train_test <- function (gp_data, param_names) {
    n        <- nrow (gp_data)
    quintile <- dplyr::ntile (gp_data$psi_mean, 5L)
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
        y_train = gp_data$psi_mean [train_idx],
        y_test  = gp_data$psi_mean [test_idx]
    )
}

find_peak_on_grid <- function (fit_psi, param_names, binf, bsup, mid_vals,
                                n_grid) {
    grid     <- build_phase_grid (
        "lambda", "alpha", binf, bsup, mid_vals, param_names, n_grid
    )
    pred     <- predict (
        fit_psi,
        newdata    = grid [, param_names, drop = FALSE],
        type       = "UK",
        checkNames = FALSE
    )
    peak_idx <- which.max (pred$mean)
    as.list (grid [peak_idx, param_names])
}

peak_moved_fraction <- function (loc_new, loc_old, binf, bsup) {
    if (is.null (loc_old)) return (Inf)
    focal <- intersect (names (loc_new), names (loc_old))
    max (vapply (focal, function (nm) {
        abs (loc_new [[nm]] - loc_old [[nm]]) / (bsup [nm] - binf [nm])
    }, numeric (1)))
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)
cli_h1 (col_yellow ("GP adaptive phase exploration"))

results_dir <- "results"
dir.create (results_dir, showWarnings = FALSE)
phase_dir <- file.path (results_dir, "gp_phase")
dir.create (phase_dir, recursive = TRUE, showWarnings = FALSE)

pars   <- RcppTOML::parseTOML ("defaults.toml")
pars_s <- pars$structural
pars_a <- pars$analysis

param_names <- select_gp_params (results_dir, pars$gp$top_n_gp)
p           <- length (param_names)

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

fixed <- c (
    list (
        n             = as.integer (pars_a$n),
        mu0           = pars_a$mu0,
        sigma0        = pars_a$sigma0,
        c             = pars_a$c,
        e             = pars_a$e,
        dw_coop       = pars_a$dw_coop,
        dw_sub        = pars_a$dw_sub,
        dw_excl       = pars_a$dw_excl,
        eta           = pars_a$eta,
        eta_obs       = pars_a$mid_eta_obs,
        delta_direct  = pars_a$delta_direct,
        delta_exploit = pars_a$delta_exploit,
        w_min         = pars_s$w_min,
        w_max         = pars_s$w_max,
        sigma_drift   = pars_s$sigma_drift,
        rho_contested = pars_s$rho_contested,
        eta_trauma    = pars_s$eta_trauma,
        delta         = pars_s$delta,
        t_max         = as.integer (pars_a$t_max_gp)
    ),
    all_mid [setdiff (names (all_mid), param_names)]
)

n_rep <- as.integer (
    if (!is.null (pars$gp$n_rep_gp)) pars$gp$n_rep_gp else 20L
)

binary <- "./target/release/escalation"
if (!file.exists (binary)) {
    cli_abort ("Binary not found — run 'cargo build --release'")
}

log_dir <- if (!is.null (pars_s$log_dir)) pars_s$log_dir else "/tmp/escalation"
dir.create (log_dir, recursive = TRUE, showWarnings = FALSE)

raw_combined    <- file.path (results_dir, "gp_train_raw.csv")
checkpoint_file <- file.path (results_dir, "gp_explore_checkpoint.rds")

# ---------------------------------------------------------------------------
# Check for existing checkpoint
# ---------------------------------------------------------------------------

if (file.exists (checkpoint_file)) {
    cli_alert_warning ("Found checkpoint — resuming from last saved state.")
    state             <- readRDS (checkpoint_file)
    design_scaled_all <- state$design_scaled_all
    gp_data_all       <- state$gp_data_all
    fit_psi           <- state$fit_psi
    peak_loc_prev     <- state$peak_loc
    start_iter        <- state$iter + 1L
    cli_alert_info (
        "Resuming from iteration {.val {start_iter}} \\
        ({.val {nrow(design_scaled_all)}} design points so far)"
    )
} else {
    cli_h2 (col_yellow ("Initial coarse LHS (N={N_INIT})"))
    design_scaled_init <- make_lhs_scaled (N_INIT, param_names, binf, bsup)
    design_full_init   <- make_design_full (design_scaled_init, fixed, param_names)

    batch_raw <- tempfile (fileext = ".csv")
    cli_alert_info (
        "Running binary on {.val {N_INIT}} initial points \\
        ({.val {n_rep}} replicates each)..."
    )
    run_binary_batch (binary, design_full_init, batch_raw, log_dir, n_rep)

    gp_data_init <- aggregate_psi (batch_raw, design_scaled_init, param_names, n_rep)
    file.copy (batch_raw, raw_combined, overwrite = TRUE)
    unlink (batch_raw)

    design_scaled_all <- design_scaled_init
    gp_data_all       <- gp_data_init

    cli_h2 (col_yellow ("Fit initial GP on Psi"))
    splits  <- split_train_test (gp_data_all, param_names)
    fit_psi <- fit_gp_surface (splits$X_train, splits$y_train, "psi")
    validate_gp_surface (fit_psi, splits$X_test, splits$y_test, "psi")

    peak_loc_prev <- NULL
    start_iter    <- 1L
}

# ---------------------------------------------------------------------------
# Adaptive iterations
# ---------------------------------------------------------------------------

for (iter in seq (start_iter, K_MAX)) {
    cli_h2 (col_yellow ("Adaptive iteration {iter} / {K_MAX}"))

    peak_loc <- find_peak_on_grid (
        fit_psi, param_names, binf, bsup, mid_vals, N_GRID
    )
    cli_alert_info (
        "Peak: lambda={.val {round(peak_loc$lambda, 3)}}  \\
        alpha={.val {round(peak_loc$alpha, 3)}}"
    )

    moved <- peak_moved_fraction (peak_loc, peak_loc_prev, binf, bsup)
    cli_alert_info ("Peak moved {.val {round(moved * 100, 2)}}% of parameter range")
    if (moved < CONV_THRESH) {
        cli_alert_success (
            col_green ("Converged at iteration {iter} (peak stable)")
        )
        break
    }

    shrink     <- WIDTH_SHRINK^(iter - 1L)
    half_width <- setNames (
        INIT_WIDTH * shrink * (bsup - binf) / 2,
        param_names
    )
    center <- setNames (
        vapply (param_names, function (nm) {
            if (!is.null (peak_loc [[nm]])) peak_loc [[nm]] else mid_vals [[nm]]
        }, numeric (1)),
        param_names
    )

    cli_alert_info (
        "Sampling {.val {N_REFINE}} new points in shrinking hypercube \\
        (shrink={.val {round(shrink, 3)}})"
    )
    set.seed (42L + iter)
    new_design_scaled <- make_lhs_in_hypercube (
        N_REFINE, param_names, center, half_width, binf, bsup
    )
    new_design_full <- make_design_full (new_design_scaled, fixed, param_names)

    batch_raw <- tempfile (fileext = ".csv")
    run_binary_batch (binary, new_design_full, batch_raw, log_dir, n_rep)

    new_gp_data <- aggregate_psi (batch_raw, new_design_scaled, param_names, n_rep)

    # Append raw rows (no header on append)
    new_raw_df <- read.csv (batch_raw)
    write.table (
        new_raw_df, raw_combined,
        sep = ",", row.names = FALSE,
        col.names = FALSE, append = TRUE
    )
    unlink (batch_raw)

    design_scaled_all <- rbind (design_scaled_all, new_design_scaled)
    new_gp_data$pair_idx <- new_gp_data$pair_idx + max (gp_data_all$pair_idx)
    gp_data_all <- bind_rows (gp_data_all, new_gp_data)

    cli_alert_info (
        "Retraining GP on {.val {nrow(gp_data_all)}} total design points..."
    )
    splits  <- split_train_test (gp_data_all, param_names)
    fit_psi <- fit_gp_surface (splits$X_train, splits$y_train, "psi")
    validate_gp_surface (fit_psi, splits$X_test, splits$y_test, "psi")

    peak_loc_prev <- peak_loc

    saveRDS (
        list (
            iter              = iter,
            design_scaled_all = design_scaled_all,
            gp_data_all       = gp_data_all,
            fit_psi           = fit_psi,
            peak_loc          = peak_loc
        ),
        checkpoint_file
    )
    cli_alert_info ("Checkpoint saved after iteration {iter}")
}

# ---------------------------------------------------------------------------
# Save final outputs
# ---------------------------------------------------------------------------

cli_h2 (col_yellow ("Saving final outputs"))

write.csv (
    design_scaled_all,
    file.path (results_dir, "adaptive_design.csv"),
    row.names = FALSE
)
cli_alert_info (
    "Wrote adaptive_design.csv ({.val {nrow(design_scaled_all)}} design points)"
)

saveRDS (fit_psi, file.path (results_dir, "gp_psi.rds"))
cli_alert_info ("Saved gp_psi.rds")

print_hyperparams (fit_psi, "psi")

# Phase diagrams: 50x50 lambda x alpha
phase_grid <- build_phase_grid (
    "lambda", "alpha", binf, bsup, mid_vals, param_names, N_PHASE_GRID
)
pred_phase <- predict (
    fit_psi,
    newdata    = phase_grid [, param_names, drop = FALSE],
    type       = "UK",
    checkNames = FALSE
)
write_phase_csv (
    phase_grid, "lambda", "alpha",
    pred_phase$mean, phase_dir, "phase_psi_lambda_alpha"
)
write_phase_csv (
    phase_grid, "lambda", "alpha",
    pred_phase$sd, phase_dir, "phase_psi_sd_lambda_alpha"
)

cli_alert_success (col_green (
    "GP adaptive exploration complete — \\
    {nrow(design_scaled_all)} total design points."
))
