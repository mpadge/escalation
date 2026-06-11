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

library (ggplot2)
library (dplyr, warn.conflicts = FALSE)
library (patchwork)
library (cli)

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

# Shared colour limits for E_lo and E_hi panels across all pairs
all_e <- numeric (0)
for (f in hi_files) {
    tag  <- sub ("^phase2_hi_", "", sub ("\\.csv$", "", f))
    lo_f <- file.path (phase2_dir, paste0 ("phase2_lo_", tag, ".csv"))
    if (file.exists (lo_f)) {
        all_e <- c (all_e,
                    read.csv (lo_f)$psi,
                    read.csv (file.path (phase2_dir, f))$psi)
    }
}
e_lim <- range (all_e, na.rm = TRUE)
cli_alert_info (
    "Shared E scale: [{round (e_lim [1], 3)}, {round (e_lim [2], 3)}]"
)

for (f in hi_files) {
    tag    <- sub ("^phase2_hi_", "", sub ("\\.csv$", "", f))
    params <- strsplit (tag, "_vs_") [[1]]
    if (length (params) != 2) next
    xvar <- params [1]
    yvar <- params [2]

    lo_f  <- file.path (phase2_dir, paste0 ("phase2_lo_",  tag, ".csv"))
    hi_f  <- file.path (phase2_dir, paste0 ("phase2_hi_",  tag, ".csv"))
    psi_f <- file.path (phase2_dir, paste0 ("phase2_psi_", tag, ".csv"))
    if (!all (file.exists (c (lo_f, hi_f, psi_f)))) {
        cli_alert_warning ("Missing files for {tag}, skipping")
        next
    }

    df_lo  <- read.csv (lo_f)
    df_hi  <- read.csv (hi_f)
    df_psi <- read.csv (psi_f)

    psi_range         <- range (df_psi$psi, na.rm = TRUE)
    has_amplification <- psi_range [2] > 1.0

    # E_lo panel
    p_lo <- ggplot (df_lo, aes (x = .data [[xvar]], y = .data [[yvar]])) +
        geom_tile (aes (fill = psi)) +
        scale_fill_viridis_c (
            option = "viridis",
            name   = expression (E[lo]),
            limits = e_lim
        ) +
        labs (
            title = expression (E[lo] ~ (mu[0] == 0.4)),
            x = xvar, y = yvar
        )

    # E_hi panel
    p_hi <- ggplot (df_hi, aes (x = .data [[xvar]], y = .data [[yvar]])) +
        geom_tile (aes (fill = psi)) +
        scale_fill_viridis_c (
            option = "viridis",
            name   = expression (E[hi]),
            limits = e_lim
        ) +
        labs (
            title = expression (E[hi] ~ (mu[0] == 0.6)),
            x = xvar, y = yvar
        )

    # Psi panel — diverging scale centred at 1
    psi_abs_max <- max (abs (psi_range - 1.0)) + 0.05
    psi_lo_lim  <- 1.0 - psi_abs_max
    psi_hi_lim  <- 1.0 + psi_abs_max

    p_psi <- ggplot (df_psi, aes (x = .data [[xvar]], y = .data [[yvar]])) +
        geom_tile (aes (fill = psi)) +
        scale_fill_gradient2 (
            low      = "#2166ac",
            mid      = "white",
            high     = "#d6604d",
            midpoint = 1.0,
            limits   = c (psi_lo_lim, psi_hi_lim),
            name     = expression (Psi)
        )

    if (has_amplification) {
        p_psi <- p_psi +
            geom_contour (aes (z = psi), breaks = 1.0,
                          colour = "black", linewidth = 0.9)
    }

    subtitle_psi <- if (has_amplification) {
        paste0 ("Black contour: Psi=1 | max=", round (psi_range [2], 3))
    } else {
        paste0 ("Psi < 1 throughout | max=", round (psi_range [2], 3))
    }

    p_psi <- p_psi +
        labs (
            title    = expression (Psi == (E[hi] - E[lo]) / 0.2),
            subtitle = subtitle_psi,
            x = xvar, y = yvar
        )

    combined <- (p_lo | p_hi | p_psi) +
        plot_annotation (
            title = paste ("Stage 2 phase diagrams:", xvar, "×", yvar),
            theme = theme (plot.title = element_text (size = 13, face = "bold"))
        )

    out <- file.path (plots_dir, paste0 ("phase2_", tag, ".png"))
    ggsave (out, combined, width = 18, height = 5.5, dpi = 300)
    cli_alert_info ("Saved {.file {out}}")
}

cli_alert_success (col_yellow ("Done."))
