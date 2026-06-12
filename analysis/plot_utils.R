library (ggplot2)
library (dplyr, warn.conflicts = FALSE)
library (patchwork)
library (cli)

build_e_limits <- function (phase_dir, prefix_lo, prefix_hi) {
    lo_files <- list.files (
        phase_dir,
        pattern    = paste0 ("^", prefix_lo, "_.*\\.csv$"),
        full.names = TRUE
    )
    hi_files <- list.files (
        phase_dir,
        pattern    = paste0 ("^", prefix_hi, "_.*\\.csv$"),
        full.names = TRUE
    )
    coord_cols <- c ("alpha", "gamma", "lambda", "eta_obs")
    all_vals   <- numeric (0)
    for (f in c (lo_files, hi_files)) {
        df      <- read.csv (f)
        val_col <- setdiff (names (df), coord_cols) [1L]
        if (!is.na (val_col)) all_vals <- c (all_vals, df [[val_col]])
    }
    range (all_vals, na.rm = TRUE)
}

panel_sequential <- function (df, xvar, yvar, val_col, limits,
                               legend_title, panel_title) {
    ggplot (df, aes (x = .data [[xvar]], y = .data [[yvar]])) +
        geom_tile (aes (fill = .data [[val_col]])) +
        scale_fill_viridis_c (
            option = "viridis",
            name   = legend_title,
            limits = limits
        ) +
        labs (title = panel_title, x = xvar, y = yvar)
}

panel_diverging <- function (df, xvar, yvar, val_col, midpoint = 0,
                              legend_title, panel_title,
                              contour_at = NULL, limits = NULL) {
    p <- ggplot (df, aes (x = .data [[xvar]], y = .data [[yvar]])) +
        geom_tile (aes (fill = .data [[val_col]])) +
        scale_fill_gradient2 (
            low      = "#2166ac",
            mid      = "white",
            high     = "#d6604d",
            midpoint = midpoint,
            limits   = limits,
            name     = legend_title
        ) +
        labs (title = panel_title, x = xvar, y = yvar)

    if (!is.null (contour_at)) {
        p <- p + geom_contour (
            aes (z = .data [[val_col]]),
            breaks    = contour_at,
            colour    = "black",
            linewidth = 0.9
        )
    }
    p
}

save_three_panel <- function (p_lo, p_hi, p_derived, out_path, title) {
    combined <- (p_lo | p_hi | p_derived) +
        plot_annotation (
            title = title,
            theme = theme (plot.title = element_text (size = 13, face = "bold"))
        )
    ggsave (out_path, combined, width = 18, height = 5.5, dpi = 300)
    cli_alert_info ("Saved {.file {out_path}}")
}
