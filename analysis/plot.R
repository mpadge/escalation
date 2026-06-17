#!/usr/bin/env Rscript
# Consolidated figure generation for the Stage 010 pipeline.
# Reads phase CSVs from results/gp_phase/ and sensitivity CSVs from results/.
# Produces five figure types:
#   (a) Psi phase diagram (lambda x alpha) with Psi=1 contour
#   (b) Sigma-degenerate Psi slice (mu_sigma=1, sigma_sigma=0) for comparison
#   (c) Epsilon-degree correlation phase diagram
#   (d) Gini phase diagram
#   (e) ARD sensitivity bar chart comparing all estimands side by side
#
# Output: results/figures/*.png
#
# Prerequisites: install.packages(c("ggplot2", "dplyr", "tidyr", "cli"))
# Run from project root: Rscript analysis/plot.R
# Requires: make explore, make train, make gini completed

library (ggplot2)
library (dplyr, warn.conflicts = FALSE)
library (tidyr)
library (cli)

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

results_dir <- "results"
phase_dir   <- file.path (results_dir, "gp_phase")
fig_dir     <- file.path (results_dir, "figures")
dir.create (fig_dir, recursive = TRUE, showWarnings = FALSE)

require_csv <- function (path) {
    if (!file.exists (path))
        cli_abort ("{.file {path}} not found — ensure pipeline steps are complete")
    read.csv (path)
}

save_png <- function (p, name, width = 7, height = 5.5) {
    path <- file.path (fig_dir, paste0 (name, ".png"))
    ggsave (path, p, width = width, height = height, dpi = 150)
    cli_alert_info ("Wrote {.file {path}}")
    invisible (path)
}

# Shared theme: clean, publication-ready
theme_escalation <- function () {
    theme_minimal (base_size = 12) +
        theme (
            plot.title        = element_text (face = "bold", size = 13),
            axis.title        = element_text (size = 11),
            legend.title      = element_text (size = 10),
            legend.position   = "right",
            panel.grid.minor  = element_blank ()
        )
}

# ---------------------------------------------------------------------------
# (a) Psi phase diagram — high-Psi corner
# ---------------------------------------------------------------------------

cli_h2 ("(a) Psi phase diagram")
df_psi <- require_csv (
    file.path (phase_dir, "phase_psi_lambda_alpha.csv")
)

p_psi <- ggplot (df_psi, aes (x = lambda, y = alpha, fill = z)) +
    geom_tile () +
    geom_contour (aes (z = z), breaks = 1.0, colour = "white", linewidth = 0.8,
                  linetype = "dashed") +
    scale_fill_viridis_c (name = expression (Psi), option = "plasma") +
    labs (
        title    = expression ("Population amplification ratio"~Psi),
        subtitle = "Dashed contour: Psi = 1 (amplification threshold)",
        x        = expression (lambda~"(mean group size)"),
        y        = expression (alpha~"(locality)")
    ) +
    theme_escalation ()

save_png (p_psi, "psi_phase_lambda_alpha")

# ---------------------------------------------------------------------------
# (b) Sigma-degenerate Psi slice
# ---------------------------------------------------------------------------

cli_h2 ("(b) Sigma-degenerate Psi slice")
degen_path <- file.path (phase_dir, "psi_degenerate.csv")
if (file.exists (degen_path)) {
    df_degen <- read.csv (degen_path)

    p_degen <- ggplot (df_degen, aes (x = lambda, y = alpha, fill = z)) +
        geom_tile () +
        geom_contour (aes (z = z), breaks = 1.0, colour = "white",
                      linewidth = 0.8, linetype = "dashed") +
        scale_fill_viridis_c (name = expression (Psi), option = "plasma") +
        labs (
            title    = expression (
                "Psi at sigma-degenerate slice ("*mu[sigma]*"=1, "*sigma[sigma]*"=0)"
            ),
            subtitle = "Uniform status sensitivity — interpretive reference within bivariate model",
            x        = expression (lambda~"(mean group size)"),
            y        = expression (alpha~"(locality)")
        ) +
        theme_escalation ()

    save_png (p_degen, "psi_degenerate_lambda_alpha")
} else {
    cli_alert_warning ("{.file {degen_path}} not found — skipping panel (b)")
}

# ---------------------------------------------------------------------------
# (c) Epsilon-degree correlation phase diagram
# ---------------------------------------------------------------------------

cli_h2 ("(c) Epsilon-degree correlation phase diagram")
edeg_path <- file.path (phase_dir, "phase_edeg_lambda_alpha.csv")
if (file.exists (edeg_path)) {
    df_edeg <- read.csv (edeg_path)

    p_edeg <- ggplot (df_edeg, aes (x = lambda, y = alpha, fill = z)) +
        geom_tile () +
        scale_fill_distiller (
            name    = expression (r[epsilon * "-" * k]),
            palette = "RdYlBu", direction = 1
        ) +
        labs (
            title = expression (
                "Epsilon-degree correlation"~r[epsilon * "-" * k]
            ),
            x = expression (lambda~"(mean group size)"),
            y = expression (alpha~"(locality)")
        ) +
        theme_escalation ()

    save_png (p_edeg, "edeg_phase_lambda_alpha")
} else {
    cli_alert_warning ("{.file {edeg_path}} not found — skipping panel (c)")
}

# ---------------------------------------------------------------------------
# (d) Gini phase diagram
# ---------------------------------------------------------------------------

cli_h2 ("(d) Gini phase diagram")
gini_path <- file.path (phase_dir, "gini_k_final_lambda_alpha.csv")
if (file.exists (gini_path)) {
    df_gini <- read.csv (gini_path)

    p_gini <- ggplot (df_gini, aes (x = lambda, y = alpha, fill = z)) +
        geom_tile () +
        scale_fill_distiller (
            name    = "Gini",
            palette = "Reds", direction = 1
        ) +
        labs (
            title    = "Degree-centrality Gini inequality",
            subtitle = "Equilibrium Gini at simulation end",
            x        = expression (lambda~"(mean group size)"),
            y        = expression (alpha~"(locality)")
        ) +
        theme_escalation ()

    save_png (p_gini, "gini_phase_lambda_alpha")
} else {
    cli_alert_warning ("{.file {gini_path}} not found — skipping panel (d)")
}

# ---------------------------------------------------------------------------
# (e) ARD sensitivity bar chart across estimands
# ---------------------------------------------------------------------------

cli_h2 ("(e) ARD sensitivity comparison")
ard_path <- file.path (results_dir, "gp_hyperparams_all.csv")
if (file.exists (ard_path)) {
    df_ard <- read.csv (ard_path)

    estimand_labels <- c (
        psi          = "Psi (amplification)",
        psi_sigma    = "Psi_sigma (sigma sensitivity)",
        edeg         = "epsilon-degree correlation",
        gini_k_final = "Gini (equilibrium)",
        gini_dissip  = "Gini (dissipative)"
    )
    df_ard$estimand_lab <- estimand_labels [df_ard$estimand]
    df_ard$estimand_lab [is.na (df_ard$estimand_lab)] <- df_ard$estimand [is.na (df_ard$estimand_lab)]

    p_ard <- ggplot (df_ard, aes (
        x    = reorder (param, sensitivity),
        y    = sensitivity,
        fill = estimand_lab
    )) +
        geom_col (position = "dodge") +
        coord_flip () +
        scale_fill_brewer (palette = "Set2", name = "Estimand") +
        labs (
            title    = "ARD sensitivity by parameter and estimand",
            subtitle = "Sensitivity = 1/length-scale (larger = more influential)",
            x        = "Parameter",
            y        = "ARD sensitivity (1/l)"
        ) +
        theme_escalation () +
        theme (legend.position = "bottom")

    save_png (p_ard, "ard_sensitivity_all", width = 9, height = 6)
} else {
    cli_alert_warning ("{.file {ard_path}} not found — skipping panel (e)")
}

cli_alert_success (col_green (
    "All figures written to {.file {fig_dir}}"
))
