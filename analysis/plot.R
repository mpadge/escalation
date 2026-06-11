#!/usr/bin/env Rscript
# Visualisation for the escalation sensitivity analysis pipeline.
# Produces:
#   plots/phase_{A}_vs_{B}.png  — Psi phase diagrams (geom_tile + geom_contour)
#   plots/ard_lengths.png       — ARD length scale bar chart
#   plots/sobol_comparison.png  — Grouped S_i / S_Ti comparison across methods
#
# Prerequisites: install.packages(c("ggplot2", "dplyr", "tidyr", "cli"))
# Run from project root: Rscript analysis/plot.R

library (ggplot2)
library (dplyr)
library (tidyr)
library (cli)

dir.create ("plots", showWarnings = FALSE)

theme_set (theme_minimal (base_size = 11))

# ---------------------------------------------------------------------------
# Phase diagrams
# ---------------------------------------------------------------------------
phase_files <- list.files (".", pattern = "^phase_.*\\.csv$")
phase_files <- phase_files [!grepl ("_tau\\.csv$", phase_files)]

if (length (phase_files) == 0) {
    cli_alert_warning ("No phase CSV files found — run gp_phase.R first")
} else {
    for (f in phase_files) {
        tag <- sub ("^phase_", "", sub ("\\.csv$", "", f))
        df <- read.csv (f)
        xy <- setdiff (names (df), c ("psi_mean", "psi_sd", "tau_mean", "tau_sd"))
        if (length (xy) < 2) next
        xvar <- xy [1]
        yvar <- xy [2]

        p_phase <- ggplot (df, aes (x = .data [[xvar]], y = .data [[yvar]])) +
            geom_tile (aes (fill = psi_mean)) +
            geom_contour (aes (z = psi_sd),
                colour = "white", alpha = 0.6,
                bins = 5, linewidth = 0.35
            ) +
            scale_fill_viridis_c (option = "plasma", name = expression (Psi ~ "mean")) +
            labs (
                title    = bquote ("Phase diagram: " ~ Psi ~ "(" * . (xvar) * ", " * . (yvar) * ")"),
                subtitle = "White contours = emulator uncertainty (Psi sd)",
                x        = xvar,
                y        = yvar
            )

        out <- file.path ("plots", paste0 ("phase_", tag, ".png"))
        ggsave (out, p_phase, width = 7, height = 5, dpi = 300)
        cli_alert_info ("Saved {out}")
    }
}

# ---------------------------------------------------------------------------
# ARD length scales
# ---------------------------------------------------------------------------
if (!file.exists ("gp_hyperparams.csv")) {
    cli_alert_warning ("gp_hyperparams.csv not found — skipping ARD plot")
} else {
    hp <- read.csv ("gp_hyperparams.csv") %>%
        filter (!is.na (sensitivity)) %>%
        arrange (ell)

    p_ard <- ggplot (hp, aes (x = reorder (param, ell), y = ell)) +
        geom_col (fill = "#2166ac", alpha = 0.85) +
        coord_flip () +
        labs (
            title    = "ARD length scales (GP Psi emulator)",
            subtitle = "Shorter bars = more sensitive parameter",
            x        = NULL,
            y        = expression ("Length scale " * ell [d])
        )

    ggsave ("plots/ard_lengths.png", p_ard, width = 6, height = 4, dpi = 300)
    cli_alert_info ("Saved plots/ard_lengths.png")
}

# ---------------------------------------------------------------------------
# Sobol comparison: Morris mu* vs Sobol S_T vs GP-Sobol S_T
# ---------------------------------------------------------------------------
sources <- list ()

if (file.exists ("morris_results.csv")) {
    m <- read.csv ("morris_results.csv") %>%
        transmute (param,
            value = mu_star / max (mu_star, na.rm = TRUE),
            method = "Morris mu*"
        )
    sources [["morris"]] <- m
}

if (file.exists ("sobol_results.csv")) {
    s <- read.csv ("sobol_results.csv") %>%
        transmute (param, value = ST, method = "Sobol ST")
    sources [["sobol"]] <- s
}

if (file.exists ("sobol_gp.csv")) {
    g <- read.csv ("sobol_gp.csv") %>%
        transmute (param, value = ST, method = "GP-Sobol ST")
    sources [["gp"]] <- g
}

if (length (sources) >= 2) {
    combined <- bind_rows (sources)
    top_params <- combined %>%
        group_by (param) %>%
        summarise (max_val = max (value, na.rm = TRUE)) %>%
        arrange (desc (max_val)) %>%
        slice_head (n = 10) %>%
        pull (param)

    combined <- combined %>% filter (param %in% top_params)

    p_sobol <- ggplot (
        combined,
        aes (
            x = reorder (param, value, FUN = max),
            y = value, fill = method
        )
    ) +
        geom_col (position = position_dodge (0.75), width = 0.65) +
        coord_flip () +
        scale_fill_brewer (palette = "Set1", name = NULL) +
        labs (
            title    = "Sensitivity index comparison",
            subtitle = "Morris mu* normalised to [0,1]; Sobol and GP-Sobol show S_T",
            x        = NULL,
            y        = "Index value"
        ) +
        theme (legend.position = "bottom")

    ggsave ("plots/sobol_comparison.png", p_sobol, width = 7, height = 5, dpi = 300)
    cli_alert_info ("Saved plots/sobol_comparison.png")
} else {
    cli_alert_warning (
        "Need at least 2 of {{morris_results.csv, sobol_results.csv, sobol_gp.csv}} \\
     for comparison plot"
    )
}

cli_alert_info ("Done.")
