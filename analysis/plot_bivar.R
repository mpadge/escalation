#!/usr/bin/env Rscript
# Two-panel phase diagram plots for the bivariate GP emulators (Stage 7).
# For each of three axis pairs (mu_sigma × sigma_sigma, mu_sigma × alpha,
# mu_sigma × lambda) produces a PNG with panels: [psi_sigma | psi].
# Both panels use a diverging colour scale (midpoint = 0). On the psi panel
# for the alpha and lambda pairs, attempts to overlay the archived Stage 003
# Ψ=1 contour; warns and skips if the archived data cannot support it.
#
# Prerequisites: install.packages(c("ggplot2", "patchwork", "dplyr", "cli"))
# Run from project root: Rscript analysis/plot_bivar.R

source ("analysis/plot_utils.R")

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

load_archived_psi1_contour <- function (arch_phase_dir, axis_param,
                                         mid_other, other_param) {
    candidates <- list.files (
        arch_phase_dir,
        pattern    = paste0 ("(^|_)", axis_param, "(_vs_|_).*\\.csv$|",
                             ".*_vs_", axis_param, "\\.csv$"),
        full.names = TRUE
    )
    candidates <- candidates [!grepl ("_tau\\.csv$", candidates)]

    for (f in candidates) {
        df <- tryCatch (read.csv (f), error = function (e) NULL)
        if (is.null (df)) next
        if (!(other_param %in% names (df))) next
        val_col <- setdiff (names (df),
                            c ("alpha", "gamma", "lambda", "eta_obs",
                               "mu_sigma", "sigma_sigma", "dw_obs",
                               "dw_bridge", "psi_sd", "tau_mean",
                               "tau_sd")) [1L]
        if (is.na (val_col)) next
        tol <- (max (df [[other_param]]) - min (df [[other_param]])) * 0.05
        slice <- df [abs (df [[other_param]] - mid_other) <= tol, ]
        if (nrow (slice) == 0L) next
        if (max (slice [[val_col]], na.rm = TRUE) < 1.0) next
        return (list (df = slice, val_col = val_col, axis_col = axis_param))
    }
    NULL
}

two_panel_bivar <- function (df_ps, df_p, xvar, yvar,
                              ps_val_col, p_val_col,
                              psi1_contour_data) {
    shared_lo <- min (
        min (df_ps [[ps_val_col]], na.rm = TRUE),
        min (df_p  [[p_val_col]],  na.rm = TRUE)
    )
    shared_hi <- max (
        max (df_ps [[ps_val_col]], na.rm = TRUE),
        max (df_p  [[p_val_col]],  na.rm = TRUE)
    )
    abs_max <- max (abs (c (shared_lo, shared_hi)))
    limits  <- c (-abs_max, abs_max)

    p_ps <- panel_diverging (
        df_ps, xvar, yvar, ps_val_col,
        midpoint     = 0,
        legend_title = expression (psi [sigma]),
        panel_title  = expression (psi [sigma]),
        limits       = limits
    )

    p_p <- panel_diverging (
        df_p, xvar, yvar, p_val_col,
        midpoint     = 0,
        legend_title = expression (Psi),
        panel_title  = expression (Psi),
        limits       = limits
    )

    if (!is.null (psi1_contour_data)) {
        p_p <- p_p + geom_contour (
            data    = psi1_contour_data$df,
            mapping = aes (
                x = .data [[psi1_contour_data$axis_col]],
                z = .data [[psi1_contour_data$val_col]]
            ),
            breaks    = 1.0,
            colour    = "black",
            linewidth = 0.9
        )
    }

    p_ps | p_p
}

save_two_panel <- function (p_combined, out_path, title) {
    combined <- p_combined +
        plot_annotation (
            title = title,
            theme = theme (plot.title = element_text (size = 13, face = "bold"))
        )
    ggsave (out_path, combined, width = 12, height = 5, dpi = 300)
    cli_alert_info ("Saved {.file {out_path}}")
    invisible (out_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

cli_h1 (col_yellow ("Bivariate GP phase diagram plots"))

results_dir   <- "results"
phase_dir     <- file.path (results_dir, "gp_bivar_phase")
plots_dir     <- file.path (results_dir, "plots")
arch_phase_dir <- file.path (results_dir, "003-centrality-correlation", "gp_phase")

for (d in c (phase_dir, plots_dir)) {
    if (!dir.exists (d)) cli_abort ("Directory {.file {d}} not found")
}

theme_set (theme_minimal (base_size = 11))

pars    <- RcppTOML::parseTOML ("defaults.toml")
pars_a  <- pars$analysis
mid_lambda <- pars_a$mid_lambda
mid_alpha  <- pars_a$mid_alpha

axis_pairs <- list (
    list (
        p_a       = "mu_sigma",
        p_b       = "sigma_sigma",
        out_stem  = "gp_bivar_mu_sigma_sigma_sigma",
        try_arch  = FALSE
    ),
    list (
        p_a        = "mu_sigma",
        p_b        = "alpha",
        out_stem   = "gp_bivar_mu_sigma_alpha",
        try_arch   = TRUE,
        arch_axis  = "alpha",
        arch_other = "lambda",
        arch_mid   = mid_lambda
    ),
    list (
        p_a        = "mu_sigma",
        p_b        = "lambda",
        out_stem   = "gp_bivar_mu_sigma_lambda",
        try_arch   = TRUE,
        arch_axis  = "lambda",
        arch_other = "alpha",
        arch_mid   = mid_alpha
    )
)

for (ap in axis_pairs) {
    p_a <- ap$p_a
    p_b <- ap$p_b
    tag <- paste0 (p_a, "_", p_b)
    cli_alert_info ("Plotting {tag}")

    f_ps <- file.path (phase_dir, paste0 ("phase_psi_sigma_", tag, ".csv"))
    f_p  <- file.path (phase_dir, paste0 ("phase_psi_",       tag, ".csv"))
    if (!all (file.exists (c (f_ps, f_p)))) {
        cli_alert_warning ("Missing phase CSVs for {tag}, skipping")
        next
    }

    df_ps <- read.csv (f_ps)
    df_p  <- read.csv (f_p)

    ps_val_col <- setdiff (names (df_ps), c (p_a, p_b)) [1L]
    p_val_col  <- setdiff (names (df_p),  c (p_a, p_b)) [1L]

    psi1 <- NULL
    if (isTRUE (ap$try_arch) && dir.exists (arch_phase_dir)) {
        psi1 <- load_archived_psi1_contour (
            arch_phase_dir, ap$arch_axis, ap$arch_mid, ap$arch_other
        )
        if (is.null (psi1)) {
            cli_alert_warning (
                "No archived phase CSV with {ap$arch_axis} × {ap$arch_other} \\
                axes found in {.file {arch_phase_dir}}; skipping Psi=1 overlay"
            )
        }
    }

    p_combined <- two_panel_bivar (
        df_ps, df_p, p_a, p_b, ps_val_col, p_val_col, psi1
    )

    out <- file.path (plots_dir, paste0 (ap$out_stem, ".png"))
    save_two_panel (
        p_combined, out,
        title = paste ("Bivariate GP:", p_a, "×", p_b)
    )
}

cli_alert_success (col_green ("Bivariate phase plots complete."))
