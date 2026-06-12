#!/usr/bin/env Rscript
# Stage 3: Phase diagrams for C_lo, C_hi, and difference = C_hi - C_lo
# across the top-4 parameter space.
#
# For each of the 6 pairs from {alpha, gamma, lambda, eta_obs}, builds a 50x50
# grid, predicts both GP surfaces, derives the difference, and writes three CSV
# files per pair to results/gp_phase3/. Reports whether the difference > 0
# (increased mu0 amplifies the network advantage of high-eps individuals) in
# any pair, and the maximum difference across all pairs.
#
# Prerequisites: install.packages(c("DiceKriging", "dplyr", "RcppTOML", "cli"))
# Run from project root: Rscript analysis/gp_phase3.R
# Requires: results/gp_corr_lo.rds, results/gp_corr_hi.rds (from gp_train3.R)

source ("analysis/gp_phase_utils.R")

set.seed (42)
cli_h1 (col_yellow ("Stage 3: Phase diagrams for C_lo, C_hi, difference surfaces"))

results_dir <- "results"
phase3_dir  <- file.path (results_dir, "gp_phase3")
dir.create (phase3_dir, recursive = TRUE, showWarnings = FALSE)

for (f in c ("gp_corr_lo.rds", "gp_corr_hi.rds")) {
    path <- file.path (results_dir, f)
    if (!file.exists (path)) {
        cli_abort ("{.file {path}} not found — run {.code make gp3} first")
    }
}
fit_corr_lo <- readRDS (file.path (results_dir, "gp_corr_lo.rds"))
fit_corr_hi <- readRDS (file.path (results_dir, "gp_corr_hi.rds"))
cli_alert_info ("Loaded fit_corr_lo (C_lo, mu0=0.4) and fit_corr_hi (C_hi, mu0=0.6)")

params <- load_phase_params ("defaults.toml", TOP_PARAMS)

pairs        <- combn (TOP_PARAMS, 2, simplify = FALSE)
diff_max_global <- -Inf
diff_positive   <- character (0)

cli_alert_info (
    "Building {.val {length (pairs)}} pairs × 3 surfaces (lo, hi, diff)..."
)

for (pair in pairs) {
    p_a <- pair [1]
    p_b <- pair [2]
    tag <- paste0 (p_a, "_vs_", p_b)
    cli_alert_info ("Pair: {tag}")

    grid    <- build_phase_grid (p_a, p_b, params$all_binf, params$all_bsup,
                                  params$mid_vals, TOP_PARAMS)
    pred_lo <- predict_gp_pair (fit_corr_lo, grid)
    pred_hi <- predict_gp_pair (fit_corr_hi, grid)

    diff_surface <- pred_hi$mean - pred_lo$mean

    write_phase_csvs (grid, p_a, p_b, pred_lo, pred_hi, diff_surface,
                      phase3_dir, prefix = "phase3", derived_col = "diff")

    diff_max        <- max (diff_surface, na.rm = TRUE)
    diff_max_global <- max (diff_max_global, diff_max)

    cli_alert_info (
        "  C_lo [{round (min (pred_lo$mean), 3)}, \\
        {round (max (pred_lo$mean), 3)}]  \\
        C_hi [{round (min (pred_hi$mean), 3)}, \\
        {round (max (pred_hi$mean), 3)}]  \\
        diff [{round (min (diff_surface), 3)}, \\
        {round (diff_max, 3)}]  \\
        diff>0: {any (diff_surface > 0)}"
    )

    if (any (diff_surface > 0)) {
        diff_positive <- c (diff_positive, tag)
    }
}

cli_h2 (col_yellow ("Summary"))
cli_alert_info (
    "Global difference maximum across all pairs: {round (diff_max_global, 4)}"
)
if (length (diff_positive) > 0) {
    cli_alert_success (col_green (
        "diff > 0 (mu0 increase benefits high-eps centrality) in \\
        {length (diff_positive)} pair(s):"
    ))
    for (p in diff_positive) cli_alert_success (col_green ("  {p}"))
} else {
    cli_alert_info (
        "diff <= 0 in all pairs — increased mu0 does not benefit high-eps centrality"
    )
}

cli_alert_success (col_green ("Done. Run {.code make plots3} next."))
