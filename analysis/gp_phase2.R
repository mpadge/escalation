#!/usr/bin/env Rscript
# Stage 2: Phase diagrams for E_lo, E_hi, and Psi = (E_hi - E_lo) / 0.2
# across the top-4 parameter space.
#
# For each of the 6 pairs from {alpha, gamma, lambda, eta_obs}, builds a 50x50
# grid, predicts both GP surfaces, derives Psi, and writes three CSV files per
# pair to results/gp_phase2/. Reports whether Psi > 1 (amplification) is
# observed in any pair.
#
# Prerequisites: install.packages(c("DiceKriging", "dplyr", "RcppTOML", "cli"))
# Run from project root: Rscript analysis/gp_phase2.R
# Requires: results/gp_lo.rds, results/gp_hi.rds (from gp_train2.R)

source ("analysis/gp_phase_utils.R")

set.seed (42)
cli_h1 (col_yellow ("Stage 2: Phase diagrams for E_lo, E_hi, Psi surfaces"))

results_dir <- "results"
phase2_dir  <- file.path (results_dir, "gp_phase2")
dir.create (phase2_dir, recursive = TRUE, showWarnings = FALSE)

for (f in c ("gp_lo.rds", "gp_hi.rds")) {
    path <- file.path (results_dir, f)
    if (!file.exists (path)) {
        cli_abort ("{.file {path}} not found — run {.code make gp2} first")
    }
}
fit_lo <- readRDS (file.path (results_dir, "gp_lo.rds"))
fit_hi <- readRDS (file.path (results_dir, "gp_hi.rds"))
cli_alert_info ("Loaded fit_lo (E_lo, mu0=0.4) and fit_hi (E_hi, mu0=0.6)")

params <- load_phase_params ("defaults.toml", TOP_PARAMS)

pairs          <- combn (TOP_PARAMS, 2, simplify = FALSE)
psi_max_global <- -Inf
psi_over1      <- character (0)

cli_alert_info (
    "Building {.val {length (pairs)}} pairs × 3 surfaces (lo, hi, Psi)..."
)

for (pair in pairs) {
    p_a <- pair [1]
    p_b <- pair [2]
    tag <- paste0 (p_a, "_vs_", p_b)
    cli_alert_info ("Pair: {tag}")

    grid    <- build_phase_grid (p_a, p_b, params$all_binf, params$all_bsup,
                                  params$mid_vals, TOP_PARAMS)
    pred_lo <- predict_gp_pair (fit_lo, grid)
    pred_hi <- predict_gp_pair (fit_hi, grid)

    psi_surface <- (pred_hi$mean - pred_lo$mean) / 0.2

    write_phase_csvs (grid, p_a, p_b, pred_lo, pred_hi, psi_surface,
                      phase2_dir, prefix = "phase2", derived_col = "psi")

    psi_max        <- max (psi_surface, na.rm = TRUE)
    psi_max_global <- max (psi_max_global, psi_max)

    cli_alert_info (
        "  E_lo [{round (min (pred_lo$mean), 3)}, \\
        {round (max (pred_lo$mean), 3)}]  \\
        E_hi [{round (min (pred_hi$mean), 3)}, \\
        {round (max (pred_hi$mean), 3)}]  \\
        Psi [{round (min (psi_surface), 3)}, \\
        {round (psi_max, 3)}]"
    )

    if (psi_max > 1.0) {
        psi_over1 <- c (psi_over1, tag)
        cli_alert_warning (col_yellow (
            "  *** Psi > 1 in {tag} — max = {round (psi_max, 4)}"
        ))
    }
}

cli_h2 (col_yellow ("Summary"))
cli_alert_info (
    "Global Psi maximum across all pairs: {round (psi_max_global, 4)}"
)
if (length (psi_over1) > 0) {
    cli_alert_success (col_green (
        "AMPLIFICATION (Psi > 1) found in {length (psi_over1)} pair(s):"
    ))
    for (p in psi_over1) cli_alert_success (col_green ("  {p}"))
} else {
    cli_alert_info (
        "Psi <= 1 in all pairs — no amplification in top-4 subspace"
    )
}

cli_alert_success (col_green ("Done. Run {.code make plots2} next."))
