#!/usr/bin/env Rscript
# Render figures for docs/report.md.
# Sources analysis/plot_utils.R; reads phase CSVs from results/; writes to docs/figures/.
# Run from project root: Rscript docs/plot_report.R

source ("analysis/plot_utils.R")

figures_dir <- "docs/figures"
dir.create (figures_dir, recursive = TRUE, showWarnings = FALSE)

# ---------------------------------------------------------------------------
# Figure 1: Stage 2 alpha × lambda — amplification regime
# Three panels: E_lo (mu0=0.4) | E_hi (mu0=0.6) | Psi = (E_hi - E_lo) / 0.2
# ---------------------------------------------------------------------------

lo_f  <- "results/gp_phase2/phase2_lo_alpha_vs_lambda.csv"
hi_f  <- "results/gp_phase2/phase2_hi_alpha_vs_lambda.csv"
psi_f <- "results/gp_phase2/phase2_psi_alpha_vs_lambda.csv"

df_lo  <- read.csv (lo_f)
df_hi  <- read.csv (hi_f)
df_psi <- read.csv (psi_f)

# Shared sequential scale across E_lo and E_hi
e_lim <- range (c (df_lo$psi, df_hi$psi), na.rm = TRUE)

fig1_labs <- labs (x = "Influence locality", y = "Encounter group size")

p_lo <- panel_sequential (
    df_lo, "alpha", "lambda", "psi", e_lim,
    legend_title = expression (E[lo]),
    panel_title  = expression (E[lo] ~ (mu[0] == 0.4))
) + fig1_labs

p_hi <- panel_sequential (
    df_hi, "alpha", "lambda", "psi", e_lim,
    legend_title = expression (E[hi]),
    panel_title  = expression (E[hi] ~ (mu[0] == 0.6))
) + fig1_labs

psi_range     <- range (df_psi$psi, na.rm = TRUE)
psi_abs_max   <- max (abs (psi_range - 1.0)) + 0.05
psi_limits    <- c (1.0 - psi_abs_max, 1.0 + psi_abs_max)
has_amplif    <- psi_range [2] > 1.0

p_psi <- panel_diverging (
    df_psi, "alpha", "lambda", "psi",
    midpoint     = 1.0,
    legend_title = expression (Psi),
    panel_title  = expression (Psi == (E[hi] - E[lo]) / 0.2),
    contour_at   = if (has_amplif) 1.0 else NULL,
    limits       = psi_limits
) + fig1_labs

save_three_panel (
    p_lo, p_hi, p_psi,
    out_path = file.path (figures_dir, "fig1_amplification_alpha_lambda.png"),
    title    = "Figure 1: Escalation amplification — group size × influence locality"
)

# ---------------------------------------------------------------------------
# Figure 3: Stage 3 gamma × lambda — dissociation finding
# Three panels: C_lo | C_hi | diff = C_hi - C_lo
# ---------------------------------------------------------------------------

lo_f   <- "results/gp_phase3/phase3_lo_gamma_vs_lambda.csv"
hi_f   <- "results/gp_phase3/phase3_hi_gamma_vs_lambda.csv"
diff_f <- "results/gp_phase3/phase3_diff_gamma_vs_lambda.csv"

df_lo   <- read.csv (lo_f)
df_hi   <- read.csv (hi_f)
df_diff <- read.csv (diff_f)

e_lim <- range (c (df_lo$val, df_hi$val), na.rm = TRUE)

fig2_labs <- labs (x = "Hierarchy steepness", y = "Encounter group size")

p_lo <- panel_sequential (
    df_lo, "gamma", "lambda", "val", e_lim,
    legend_title = expression (C[lo]),
    panel_title  = expression (C[lo] ~ (mu[0] == 0.4))
) + fig2_labs

p_hi <- panel_sequential (
    df_hi, "gamma", "lambda", "val", e_lim,
    legend_title = expression (C[hi]),
    panel_title  = expression (C[hi] ~ (mu[0] == 0.6))
) + fig2_labs

diff_range   <- range (df_diff$diff, na.rm = TRUE)
diff_abs_max <- max (abs (diff_range))
diff_limits  <- c (-diff_abs_max, diff_abs_max)
has_both     <- diff_range [1] < 0 & diff_range [2] > 0

p_diff <- panel_diverging (
    df_diff, "gamma", "lambda", "diff",
    midpoint     = 0,
    legend_title = expression (Delta * C),
    panel_title  = expression (C[hi] - C[lo]),
    contour_at   = if (has_both) 0 else NULL,
    limits       = diff_limits
) + fig2_labs

save_three_panel (
    p_lo, p_hi, p_diff,
    out_path = file.path (figures_dir, "fig3_dissociation_gamma_lambda.png"),
    title    = "Figure 3: Dissociation — hierarchy × group size (correlation surfaces)"
)

# ---------------------------------------------------------------------------
# Figure 2: Stage 3 alpha × gamma — locality governs centrality advantage
# Three panels: C_lo | C_hi | diff = C_hi - C_lo
# ---------------------------------------------------------------------------

lo_f   <- "results/gp_phase3/phase3_lo_alpha_vs_gamma.csv"
hi_f   <- "results/gp_phase3/phase3_hi_alpha_vs_gamma.csv"
diff_f <- "results/gp_phase3/phase3_diff_alpha_vs_gamma.csv"

df_lo   <- read.csv (lo_f)
df_hi   <- read.csv (hi_f)
df_diff <- read.csv (diff_f)

e_lim <- range (c (df_lo$val, df_hi$val), na.rm = TRUE)

fig2_labs <- labs (x = "Influence locality", y = "Hierarchy steepness")

p_lo <- panel_sequential (
    df_lo, "alpha", "gamma", "val", e_lim,
    legend_title = expression (C[lo]),
    panel_title  = expression (C[lo] ~ (mu[0] == 0.4))
) + fig2_labs

p_hi <- panel_sequential (
    df_hi, "alpha", "gamma", "val", e_lim,
    legend_title = expression (C[hi]),
    panel_title  = expression (C[hi] ~ (mu[0] == 0.6))
) + fig2_labs

diff_range   <- range (df_diff$diff, na.rm = TRUE)
diff_abs_max <- max (abs (diff_range))
diff_limits  <- c (-diff_abs_max, diff_abs_max)
has_both     <- diff_range [1] < 0 & diff_range [2] > 0

p_diff <- panel_diverging (
    df_diff, "alpha", "gamma", "diff",
    midpoint     = 0,
    legend_title = expression (Delta * C),
    panel_title  = expression (C[hi] - C[lo]),
    contour_at   = if (has_both) 0 else NULL,
    limits       = diff_limits
) + fig2_labs

save_three_panel (
    p_lo, p_hi, p_diff,
    out_path = file.path (figures_dir, "fig2_centrality_alpha_gamma.png"),
    title    = "Figure 2: Centrality concentration — influence locality × hierarchy steepness"
)

cli_alert_success (col_green ("Report figures written to {.file {figures_dir}}"))
