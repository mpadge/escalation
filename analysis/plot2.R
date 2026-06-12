#!/usr/bin/env Rscript
# Stage 2: Three-panel phase diagram plots for E_lo, E_hi, and Psi surfaces.
# For each of the 6 parameter pairs, produces a single figure with panels:
#   [E_lo (mu0=0.4)] | [E_hi (mu0=0.6)] | [Psi = (E_hi - E_lo) / 0.2]
# E_lo and E_hi share a viridis colour scale. Psi uses a diverging scale
# centred at 1 (the amplification boundary); a contour is drawn at Psi = 1
# wherever it is reached.
#
# Prerequisites: install.packages(c("ggplot2", "dplyr", "patchwork", "cli"))
# Run from project root: Rscript analysis/plot2.R

source ("analysis/plot_utils.R")

results_dir <- "results"
phase2_dir  <- file.path (results_dir, "gp_phase2")
plots_dir   <- file.path (results_dir, "plots")
dir.create (plots_dir, recursive = TRUE, showWarnings = FALSE)

theme_set (theme_minimal (base_size = 11))

hi_files <- list.files (phase2_dir, pattern = "^phase2_hi_.*\\.csv$")
if (length (hi_files) == 0) {
    cli_abort (
        "No phase2 CSV files found in {.file {phase2_dir}} \\
        — run {.code make gp2_phase} first"
    )
}

e_lim <- build_e_limits (phase2_dir, "phase2_lo", "phase2_hi")
cli_alert_info (
    "Shared E scale: [{round (e_lim [1], 3)}, {round (e_lim [2], 3)}]"
)

# Detect value column name (new: "val"; legacy: "psi")
coord_cols  <- c ("alpha", "gamma", "lambda", "eta_obs")
sample_lo   <- file.path (phase2_dir, paste0 ("phase2_lo_", sub ("^phase2_hi_", "", sub ("\\.csv$", "", hi_files [1])), ".csv"))
e_val_col   <- setdiff (names (read.csv (sample_lo, nrows = 1L)), coord_cols) [1L]

for (f in hi_files) {
    tag    <- sub ("^phase2_hi_", "", sub ("\\.csv$", "", f))
    params <- strsplit (tag, "_vs_") [[1]]
    if (length (params) != 2) next
    xvar <- params [1]
    yvar <- params [2]

    lo_f  <- file.path (phase2_dir, paste0 ("phase2_lo_",  tag, ".csv"))
    hi_f  <- file.path (phase2_dir, f)
    psi_f <- file.path (phase2_dir, paste0 ("phase2_psi_", tag, ".csv"))
    if (!all (file.exists (c (lo_f, hi_f, psi_f)))) {
        cli_alert_warning ("Missing files for {tag}, skipping")
        next
    }

    df_lo  <- read.csv (lo_f)
    df_hi  <- read.csv (hi_f)
    df_psi <- read.csv (psi_f)

    psi_val_col       <- setdiff (names (df_psi), coord_cols) [1L]
    psi_range         <- range (df_psi [[psi_val_col]], na.rm = TRUE)
    has_amplification <- psi_range [2] > 1.0

    p_lo <- panel_sequential (
        df_lo, xvar, yvar, e_val_col, e_lim,
        legend_title = expression (E [lo]),
        panel_title  = expression (E [lo] ~ (mu [0] == 0.4))
    )

    p_hi <- panel_sequential (
        df_hi, xvar, yvar, e_val_col, e_lim,
        legend_title = expression (E [hi]),
        panel_title  = expression (E [hi] ~ (mu [0] == 0.6))
    )

    psi_abs_max <- max (abs (psi_range - 1.0)) + 0.05
    psi_limits  <- c (1.0 - psi_abs_max, 1.0 + psi_abs_max)

    subtitle_psi <- if (has_amplification) {
        paste0 ("Black contour: Psi=1 | max=", round (psi_range [2], 3))
    } else {
        paste0 ("Psi < 1 throughout | max=", round (psi_range [2], 3))
    }

    p_psi <- panel_diverging (
        df_psi, xvar, yvar, psi_val_col,
        midpoint     = 1.0,
        legend_title = expression (Psi),
        panel_title  = expression (Psi == (E [hi] - E [lo]) / 0.2),
        contour_at   = if (has_amplification) 1.0 else NULL,
        limits       = psi_limits
    ) + labs (subtitle = subtitle_psi)

    out <- file.path (plots_dir, paste0 ("phase2_", tag, ".png"))
    save_three_panel (
        p_lo, p_hi, p_psi, out,
        title = paste ("Stage 2 phase diagrams:", xvar, "×", yvar)
    )
}

cli_alert_success (col_yellow ("Done."))
