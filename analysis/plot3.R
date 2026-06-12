#!/usr/bin/env Rscript
# Stage 3: Three-panel phase diagram plots for C_lo, C_hi, and difference surfaces.
# For each of the 6 parameter pairs, produces a single figure with panels:
#   [C_lo (mu0=0.4)] | [C_hi (mu0=0.6)] | [diff = C_hi - C_lo]
# C_lo and C_hi share a viridis colour scale. The difference panel uses a
# diverging scale centred at 0; a contour is drawn at diff = 0 wherever both
# positive and negative values are present.
#
# Prerequisites: install.packages(c("ggplot2", "dplyr", "patchwork", "cli"))
# Run from project root: Rscript analysis/plot3.R

source ("analysis/plot_utils.R")

results_dir <- "results"
phase3_dir  <- file.path (results_dir, "gp_phase3")
plots_dir   <- file.path (results_dir, "plots")
dir.create (plots_dir, recursive = TRUE, showWarnings = FALSE)

theme_set (theme_minimal (base_size = 11))

hi_files <- list.files (phase3_dir, pattern = "^phase3_hi_.*\\.csv$")
if (length (hi_files) == 0) {
    cli_abort (
        "No phase3 CSV files found in {.file {phase3_dir}} \\
        — run {.code make gp3_phase} first"
    )
}

e_lim <- build_e_limits (phase3_dir, "phase3_lo", "phase3_hi")
cli_alert_info (
    "Shared C scale: [{round (e_lim [1], 3)}, {round (e_lim [2], 3)}]"
)

for (f in hi_files) {
    tag    <- sub ("^phase3_hi_", "", sub ("\\.csv$", "", f))
    params <- strsplit (tag, "_vs_") [[1]]
    if (length (params) != 2) next
    xvar <- params [1]
    yvar <- params [2]

    lo_f   <- file.path (phase3_dir, paste0 ("phase3_lo_",   tag, ".csv"))
    hi_f   <- file.path (phase3_dir, f)
    diff_f <- file.path (phase3_dir, paste0 ("phase3_diff_", tag, ".csv"))
    if (!all (file.exists (c (lo_f, hi_f, diff_f)))) {
        cli_alert_warning ("Missing files for {tag}, skipping")
        next
    }

    df_lo   <- read.csv (lo_f)
    df_hi   <- read.csv (hi_f)
    df_diff <- read.csv (diff_f)

    diff_range    <- range (df_diff$diff, na.rm = TRUE)
    has_both_sign <- diff_range [1] < 0 & diff_range [2] > 0
    diff_abs_max  <- max (abs (diff_range))
    diff_limits   <- c (-diff_abs_max, diff_abs_max)

    p_lo <- panel_sequential (
        df_lo, xvar, yvar, "val", e_lim,
        legend_title = expression (C [lo]),
        panel_title  = expression (C [lo] ~ (mu [0] == 0.4))
    )

    p_hi <- panel_sequential (
        df_hi, xvar, yvar, "val", e_lim,
        legend_title = expression (C [hi]),
        panel_title  = expression (C [hi] ~ (mu [0] == 0.6))
    )

    p_diff <- panel_diverging (
        df_diff, xvar, yvar, "diff",
        midpoint     = 0,
        legend_title = expression (Delta * C),
        panel_title  = expression (C [hi] - C [lo]),
        contour_at   = if (has_both_sign) 0 else NULL,
        limits       = diff_limits
    )

    out <- file.path (plots_dir, paste0 ("phase3_", tag, ".png"))
    save_three_panel (
        p_lo, p_hi, p_diff, out,
        title = paste ("Stage 3 phase diagrams:", xvar, "×", yvar)
    )
}

cli_alert_success (col_yellow ("Done."))
