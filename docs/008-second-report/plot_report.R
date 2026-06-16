#!/usr/bin/env Rscript
# Copy Stage 007 phase diagram PNGs into docs/008-second-report/figures/.
# Run from project root: Rscript docs/008-second-report/plot_report.R

src <- "results/plots"
dst <- "docs/008-second-report/figures"
dir.create (dst, recursive = TRUE, showWarnings = FALSE)

figs <- c (
    "gp_bivar_mu_sigma_alpha.png",
    "gp_bivar_mu_sigma_sigma_sigma.png"
)

for (f in figs) {
    ok <- file.copy (file.path (src, f), file.path (dst, f), overwrite = TRUE)
    cat (if (ok) "Copied" else "FAILED", file.path (dst, f), "\n")
}
