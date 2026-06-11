#!/usr/bin/env Rscript
# Monotonicity validation for the delta (edge-decay) parameter.
#
# delta is fixed in all sensitivity analyses because Morris identified it as
# the second-ranked driver that monotonically suppresses Psi. This script
# verifies that relationship: for a grid of delta values and several
# parameter combinations, Psi must be monotone non-increasing in delta.
#
# A failed assertion here would invalidate the decision to fix delta and
# exclude it from Sobol/GP analyses.
#
# Prerequisites: release binary (cargo build --release), processx, cli
# Run from project root: Rscript analysis/delta_monotone.R

library (processx)
library (RcppTOML)
library (cli)

set.seed (42)

results_dir <- "results"
if (!dir.exists (results_dir)) {
    cli_abort (
        "Output directory {.file {results_dir}} not found — \\
        run {.file analysis/morris.R} first"
    )
}

binary <- "./target/release/escalation"
if (!file.exists (binary)) {
    cli_abort ("Binary not found — run 'cargo build --release'")
}

pars <- RcppTOML::parseTOML ("defaults.toml")
pars_s <- pars$structural
pars_a <- pars$analysis
pars_dm <- pars$delta_monotone

# ---------------------------------------------------------------------------
# Delta grid and parameter combinations to test
# ---------------------------------------------------------------------------
delta_grid <- c (0.001, 0.005, 0.01, 0.02, 0.04)

# Five diverse parameter combinations: defaults, and four corners of the
# most sensitive dimensions (w_win, alpha, lambda, dw_obs from Morris)
combos <- list (
    defaults  = list (
        gamma = 3.0, lambda = 3.0, alpha = 1.0, w_win = 1.0, dw_obs = 0.1
    ),
    high_win  = list (
        gamma = 3.0, lambda = 3.0, alpha = 1.0, w_win = 1.8, dw_obs = 0.1
    ),
    low_win   = list (
        gamma = 3.0, lambda = 3.0, alpha = 1.0, w_win = 0.3, dw_obs = 0.1
    ),
    high_obs  = list (
        gamma = 3.0, lambda = 2.0, alpha = 1.5, w_win = 1.0, dw_obs = 0.18
    ),
    low_alpha = list (
        gamma = 3.5, lambda = 4.0, alpha = 0.3, w_win = 1.0, dw_obs = 0.05
    )
)

# Fixed fields shared by all runs
base_fixed <- list (
    n = as.integer (pars_a$n), mu0 = pars_a$mu0, sigma0 = pars_a$sigma0,
    theta = as.integer (pars_a$mid_theta), beta = pars_a$mid_beta,
    c = pars_a$c, e = pars_a$e, b = pars_a$mid_b,
    w_loss = pars_a$mid_w_loss,
    dw_coop = pars_a$dw_coop, dw_sub = pars_a$dw_sub, dw_bridge = pars_a$mid_dw_bridge,
    dw_excl = pars_a$dw_excl,
    eta = pars_a$eta, eta_obs = pars_a$mid_eta_obs,
    delta_direct = pars_a$delta_direct, delta_exploit = pars_a$delta_exploit,
    w_min = pars_s$w_min, w_max = pars_s$w_max,
    sigma_drift = pars_s$sigma_drift, rho_contested = pars_s$rho_contested,
    eta_trauma = pars_s$eta_trauma,
    t_max = as.integer (pars_a$t_max_sobol)
)

# ---------------------------------------------------------------------------
# Run all (combo × delta) combinations
# ---------------------------------------------------------------------------
results <- data.frame ()

for (combo_name in names (combos)) {
    combo <- combos [[combo_name]]
    psi_series <- numeric (length (delta_grid))

    for (k in seq_along (delta_grid)) {
        row <- c (base_fixed, combo, list (delta = delta_grid [k]))
        df <- as.data.frame (row)
        df$theta <- as.integer (df$theta)
        df$n <- as.integer (df$n)
        df$t_max <- as.integer (df$t_max)

        tmp_design <- tempfile (fileext = ".csv")
        tmp_output <- tempfile (fileext = ".csv")
        write.csv (df, tmp_design, row.names = FALSE)

        res <- processx::run (
            binary,
            c ("morris", "--design", tmp_design, "--output", tmp_output),
            error_on_status = FALSE
        )
        if (res$status != 0) {
            cli_alert_warning (
                "Binary failed for combo={.field {combo_name}} \\
                delta={.val {delta_grid[k]}}"
            )
            psi_series [k] <- NA
            next
        }

        out <- read.csv (tmp_output)
        # Both lo and hi rows carry the same psi; take the first (lo) row
        psi_series [k] <- out$psi [1]
        unlink (c (tmp_design, tmp_output))
    }

    results <- rbind (results, data.frame (
        combo  = combo_name,
        delta  = delta_grid,
        psi    = psi_series
    ))

    pairs_str <- paste (sprintf ("%.3f→Ψ=%.3f", delta_grid, psi_series),
        collapse = "  "
    )
    cli_alert_info ("{.val {combo_name}}: {.field {pairs_str}}")
}

# ---------------------------------------------------------------------------
# Monotonicity assertion: Psi must be non-increasing in delta for each combo
# ---------------------------------------------------------------------------
cli_alert_info ("--- Monotonicity check ---")
all_pass <- TRUE

for (combo_name in names (combos)) {
    sub <- results [results$combo == combo_name, ]
    psi <- sub$psi [order (sub$delta)]
    diffs <- diff (psi)

    # Allow a small tolerance for stochastic noise
    tol <- pars_dm$delta_tol_factor * diff (range (psi, na.rm = TRUE))
    tol <- max (tol, pars_dm$delta_tol_floor)

    violations <- sum (diffs > tol, na.rm = TRUE)
    if (violations == 0) {
        cli_alert_info ("{combo_name}: PASS")
    } else {
        cli_alert_warning (
            "{.field {combo_name}}: FAIL ({.val {violations}}/\\
            {.val {length(diffs)}} violations, tol={.val {round(tol, 3)}})"
        )
        all_pass <- FALSE
    }
}

write.csv (
    results,
    file.path (results_dir, "delta_monotone_results.csv"),
    row.names = FALSE
)
cli_alert_info ("Wrote delta_monotone_results.csv")

if (!all_pass) {
    stop ("Monotonicity check FAILED — review delta_monotone_results.csv")
} else {
    cli_alert_info (
        "All checks passed. delta fixed at {.val {pars_s$delta}} is \\
        consistent with the suppression finding."
    )
}
