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

library (DiceKriging)
library (dplyr, warn.conflicts = FALSE)
library (cli)
library (RcppTOML)

TOP_PARAMS <- c ("alpha", "gamma", "lambda", "eta_obs") # nolint

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

load_gp2_inputs <- function (results_dir) {
    for (f in c ("gp_lo.rds", "gp_hi.rds")) {
        path <- file.path (results_dir, f)
        if (!file.exists (path)) {
            cli_abort ("{.file {path}} not found — run {.code make gp2} first")
        }
    }
    fit_lo <- readRDS (file.path (results_dir, "gp_lo.rds"))
    fit_hi <- readRDS (file.path (results_dir, "gp_hi.rds"))
    cli_alert_info ("Loaded fit_lo (E_lo, mu0=0.4) and fit_hi (E_hi, mu0=0.6)")
    list (fit_lo = fit_lo, fit_hi = fit_hi)
}

build_phase_grid <- function (p_a, p_b, all_binf, all_bsup, mid_vals,
                               n_grid = 50) {
    seq_a <- seq (all_binf [p_a], all_bsup [p_a], length.out = n_grid)
    seq_b <- seq (all_binf [p_b], all_bsup [p_b], length.out = n_grid)
    grid  <- expand.grid (A = seq_a, B = seq_b)
    colnames (grid) <- c (p_a, p_b)
    for (nm in TOP_PARAMS) {
        if (!(nm %in% c (p_a, p_b))) grid [[nm]] <- mid_vals [[nm]]
    }
    grid
}

build_phase_diagrams2 <- function (fit_lo, fit_hi, all_binf, all_bsup,
                                    mid_vals, phase2_dir) {
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

        grid <- build_phase_grid (p_a, p_b, all_binf, all_bsup, mid_vals)

        pred_lo <- predict (
            fit_lo,
            newdata    = grid [, colnames (fit_lo@X), drop = FALSE],
            type       = "UK",
            checkNames = TRUE
        )
        pred_hi <- predict (
            fit_hi,
            newdata    = grid [, colnames (fit_hi@X), drop = FALSE],
            type       = "UK",
            checkNames = TRUE
        )

        psi_surface <- (pred_hi$mean - pred_lo$mean) / 0.2

        df_lo        <- grid [, c (p_a, p_b)]
        df_lo$psi    <- pred_lo$mean
        df_lo$psi_sd <- pred_lo$sd
        write.csv (
            df_lo,
            file.path (phase2_dir, paste0 ("phase2_lo_", tag, ".csv")),
            row.names = FALSE
        )

        df_hi        <- grid [, c (p_a, p_b)]
        df_hi$psi    <- pred_hi$mean
        df_hi$psi_sd <- pred_hi$sd
        write.csv (
            df_hi,
            file.path (phase2_dir, paste0 ("phase2_hi_", tag, ".csv")),
            row.names = FALSE
        )

        df_psi      <- grid [, c (p_a, p_b)]
        df_psi$psi  <- psi_surface
        write.csv (
            df_psi,
            file.path (phase2_dir, paste0 ("phase2_psi_", tag, ".csv")),
            row.names = FALSE
        )

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

    invisible (list (psi_max = psi_max_global, psi_over1 = psi_over1))
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)
cli_h1 (col_yellow ("Stage 2: Phase diagrams for E_lo, E_hi, Psi surfaces"))

results_dir <- "results"
pars        <- RcppTOML::parseTOML ("defaults.toml")

all_binf <- setNames (
    vapply (TOP_PARAMS, function (nm) pars$ranges [[nm]] [1L], numeric (1)),
    TOP_PARAMS
)
all_bsup <- setNames (
    vapply (TOP_PARAMS, function (nm) pars$ranges [[nm]] [2L], numeric (1)),
    TOP_PARAMS
)

mid_vals <- list (
    alpha   = pars$analysis$mid_alpha,
    gamma   = pars$analysis$mid_gamma,
    lambda  = pars$analysis$mid_lambda,
    eta_obs = pars$analysis$mid_eta_obs
)

phase2_dir <- file.path (results_dir, "gp_phase2")
dir.create (phase2_dir, recursive = TRUE, showWarnings = FALSE)

inputs <- load_gp2_inputs (results_dir)

build_phase_diagrams2 (
    inputs$fit_lo, inputs$fit_hi,
    all_binf, all_bsup, mid_vals,
    phase2_dir
)

cli_alert_success (col_green ("Done. Run {.code make plots2} next."))
