#!/usr/bin/env Rscript
# Gini hypothesis test and cross-model comparison.
# (a) Tests whether higher baseline escalation (mu0=0.6) produces higher
#     gini_k_final across design points in both models.
# (b) Builds rank-order tables comparing Gini Sobol results to existing Ψ and
#     ε-degree sensitivity rankings.
# (c) Summarises dissipative inequality (gini_peak - gini_k_final) by alpha
#     and lambda quantile.
# Saves: results/gini_comparison_summary.csv
#
# Prerequisites: install.packages(c("dplyr", "cli", "ggplot2"))
# Run from project root: Rscript analysis/gini_compare.R
# Requires: gp_gini_baseline.R and gp_gini_bivar.R to have been run first.

library (dplyr, warn.conflicts = FALSE)
library (tidyr, warn.conflicts = FALSE)
library (cli)
library (ggplot2)

results_dir      <- "results"
results_base_dir <- "results/003-centrality-correlation"

# ---------------------------------------------------------------------------
# (a) Hypothesis test: does higher mu0 produce higher gini_k_final?
# ---------------------------------------------------------------------------

cli_h1 (col_yellow ("(a) Hypothesis test: mu0=0.6 > mu0=0.4 for gini_k_final"))

hypo_test <- function (gp_data, label) {
    delta <- gp_data$y_hi - gp_data$y_lo
    frac  <- mean (delta > 0, na.rm = TRUE)
    cli_h2 (col_yellow (label))
    cli_alert_info (
        "Fraction of design points where Gini(hi) > Gini(lo): {.val {round(frac, 3)}} \\
        ({.val {sum(delta>0,na.rm=T)}} / {.val {sum(!is.na(delta))}})"
    )
    cli_alert_info (
        "Mean delta: {.val {round(mean(delta,na.rm=T),4)}}  \\
        SD: {.val {round(sd(delta,na.rm=T),4)}}  \\
        Median: {.val {round(median(delta,na.rm=T),4)}}"
    )
    cli_alert_info (
        "Range: [{.val {round(min(delta,na.rm=T),4)}}, {.val {round(max(delta,na.rm=T),4)}}]"
    )
    list (label = label, frac_positive = frac, mean_delta = mean (delta, na.rm = TRUE),
          sd_delta = sd (delta, na.rm = TRUE), median_delta = median (delta, na.rm = TRUE))
}

gp_gini_base  <- read.csv (file.path (results_base_dir, "gp_gini_data.csv"))
gp_gini_bivar <- read.csv (file.path (results_dir, "gp_gini_bivar_data.csv"))

hypo_base  <- hypo_test (gp_gini_base,  "Baseline model")
hypo_bivar <- hypo_test (gp_gini_bivar, "Bivariate model")

# ---------------------------------------------------------------------------
# (b) Sobol ranking comparison
# ---------------------------------------------------------------------------

cli_h1 (col_yellow ("(b) Sobol ranking comparison"))

make_rank_table <- function (sobol_df, label) {
    sobol_df |>
        filter (condition == "hi") |>
        arrange (desc (ST)) |>
        mutate (rank = row_number (), source = label) |>
        select (source, rank, param, S1, ST)
}

# Baseline: compare Gini vs Ψ (GP-based sobol_gp.csv) vs ε-degree (ARD from gp3_hyperparams.csv)
sobol_gini_base <- read.csv (file.path (results_base_dir, "sobol_gini_baseline.csv"))
sobol_psi_base  <- read.csv (file.path (results_base_dir, "sobol_gp.csv"))  # GP-based Sobol for Ψ
gp3_hp          <- read.csv (file.path (results_base_dir, "gp3_hyperparams.csv"))

# ε-degree ranking from ARD (hi condition, sorted by ell ascending = sensitivity descending)
edeg_rank <- gp3_hp |>
    filter (condition == "hi") |>
    arrange (ell) |>
    mutate (rank = row_number (), source = "epsilon_degree (ARD)", S1 = NA_real_, ST = 1 / ell) |>
    select (source, rank, param, S1, ST)

gini_k_rank_base <- sobol_gini_base |>
    filter (estimand == "gini_k_final") |>
    make_rank_table ("gini_k_final")

gini_d_rank_base <- sobol_gini_base |>
    filter (estimand == "gini_dissipative") |>
    make_rank_table ("gini_dissipative")

psi_rank_base <- sobol_psi_base |>
    mutate (condition = "hi") |>
    make_rank_table ("psi (GP-based)")

cli_h2 (col_yellow ("Baseline model: parameter rank comparison"))
cli_alert_info ("Ψ ranks (GP-based Sobol):")
print (psi_rank_base [, c ("rank", "param", "ST")], digits = 3, row.names = FALSE)
cli_alert_info ("Gini_k_final ranks:")
print (gini_k_rank_base [, c ("rank", "param", "ST")], digits = 3, row.names = FALSE)
cli_alert_info ("Gini_dissipative ranks:")
print (gini_d_rank_base [, c ("rank", "param", "ST")], digits = 3, row.names = FALSE)
cli_alert_info ("ε-degree ranks (ARD 1/ell):")
print (edeg_rank [, c ("rank", "param", "ST")], digits = 3, row.names = FALSE)

# Combined baseline rank table
combined_base <- bind_rows (psi_rank_base, edeg_rank, gini_k_rank_base, gini_d_rank_base) |>
    select (source, param, rank)
rank_wide_base <- tidyr::pivot_wider (combined_base, names_from = source, values_from = rank)
cli_alert_info ("Baseline: combined rank table")
print (rank_wide_base, row.names = FALSE)

# Bivariate: compare Gini vs psi_sigma (sobol_bivar_results.csv, binary-based)
sobol_gini_bivar <- read.csv (file.path (results_dir, "sobol_gini_bivar.csv"))
sobol_psi_sigma  <- read.csv (file.path (results_dir, "sobol_bivar_results.csv"))

gini_k_rank_bivar <- sobol_gini_bivar |>
    filter (estimand == "gini_k_final") |>
    make_rank_table ("gini_k_final")

gini_d_rank_bivar <- sobol_gini_bivar |>
    filter (estimand == "gini_dissipative") |>
    make_rank_table ("gini_dissipative")

psi_sigma_rank <- sobol_psi_sigma |>
    mutate (condition = "hi") |>
    make_rank_table ("psi_sigma (binary)")

cli_h2 (col_yellow ("Bivariate model: parameter rank comparison"))
cli_alert_info ("psi_sigma ranks:")
print (psi_sigma_rank [, c ("rank", "param", "ST")], digits = 3, row.names = FALSE)
cli_alert_info ("Gini_k_final ranks:")
print (gini_k_rank_bivar [, c ("rank", "param", "ST")], digits = 3, row.names = FALSE)
cli_alert_info ("Gini_dissipative ranks:")
print (gini_d_rank_bivar [, c ("rank", "param", "ST")], digits = 3, row.names = FALSE)

combined_bivar <- bind_rows (psi_sigma_rank, gini_k_rank_bivar, gini_d_rank_bivar) |>
    select (source, param, rank)
rank_wide_bivar <- tidyr::pivot_wider (combined_bivar, names_from = source, values_from = rank)
cli_alert_info ("Bivariate: combined rank table")
print (rank_wide_bivar, row.names = FALSE)

# ---------------------------------------------------------------------------
# (c) Dissipative inequality by alpha and lambda quantile
# ---------------------------------------------------------------------------

cli_h1 (col_yellow ("(c) Dissipative inequality by structural parameter quantile"))

dissipative_summary <- function (gp_data, param, label, n_q = 4) {
    gp_data$q <- ntile (gp_data [[param]], n_q)
    out <- gp_data |>
        group_by (q) |>
        summarise (
            param_mid       = round (mean (.data [[param]], na.rm = TRUE), 3),
            mean_gini_lo    = round (mean (y_lo, na.rm = TRUE), 3),
            mean_gini_hi    = round (mean (y_hi, na.rm = TRUE), 3),
            .groups = "drop"
        ) |>
        mutate (param_name = param, model = label)
    print (out, row.names = FALSE)
    out
}

gp_gini_base_diss <- gp_gini_base  # y_lo/y_hi are gini_k_final; we need dissipative data
gp_diss_base  <- read.csv (file.path (results_base_dir, "gp_gini_data.csv"))

# For dissipative, re-load from the raw aggregated data would be ideal, but
# gp_gini_data.csv only has gini_k_final. We aggregate gini_dissipative from
# the train data directly here for the cross-tabulation.
raw_base <- tryCatch ({
    r <- read.csv (file.path (results_base_dir, "gp_train_raw.csv"))
    pars <- RcppTOML::parseTOML ("defaults.toml")
    r |>
        mutate (
            pair_idx         = ceiling (row_number () / (2L * as.integer (pars$gp$n_rep_gp))),
            eta_obs          = kappa * pars$analysis$eta,
            gini_dissipative = gini_peak - gini_k_final
        )
}, error = function (e) NULL)

if (!is.null (raw_base)) {
    TOP_PARAMS <- c ("alpha", "gamma", "lambda", "eta_obs")

    agg_diss_base <- raw_base |>
        group_by (pair_idx) |>
        summarise (
            alpha           = first (alpha),
            lambda          = first (lambda),
            gini_diss_mean  = mean (gini_dissipative, na.rm = TRUE),
            .groups = "drop"
        )

    cli_h2 (col_yellow ("Baseline: mean gini_dissipative by alpha quartile"))
    dissipative_summary (
        agg_diss_base |> rename (y_lo = gini_diss_mean, y_hi = gini_diss_mean),
        "alpha", "baseline"
    )
    cli_h2 (col_yellow ("Baseline: mean gini_dissipative by lambda quartile"))
    dissipative_summary (
        agg_diss_base |> rename (y_lo = gini_diss_mean, y_hi = gini_diss_mean),
        "lambda", "baseline"
    )
} else {
    cli_alert_warning ("Could not load baseline raw data for dissipative summary")
}

raw_bivar <- tryCatch (
    read.csv (file.path (results_dir, "gp_bivar_train.csv")),
    error = function (e) NULL
)

if (!is.null (raw_bivar)) {
    design_bivar <- read.csv (file.path (results_dir, "design_gp_bivar.csv")) |>
        select (mu_sigma, lambda, sigma_sigma, dw_obs, dw_bridge, alpha) |>
        distinct ()

    agg_diss_bivar <- raw_bivar |>
        left_join (design_bivar, by = c ("lambda", "alpha")) |>
        mutate (gini_dissipative = gini_peak - gini_k_final) |>
        group_by (lambda, alpha) |>
        summarise (
            gini_diss_mean = mean (gini_dissipative, na.rm = TRUE),
            .groups = "drop"
        )

    cli_h2 (col_yellow ("Bivariate: mean gini_dissipative by alpha quartile"))
    dissipative_summary (
        agg_diss_bivar |> rename (y_lo = gini_diss_mean, y_hi = gini_diss_mean),
        "alpha", "bivariate"
    )
    cli_h2 (col_yellow ("Bivariate: mean gini_dissipative by lambda quartile"))
    dissipative_summary (
        agg_diss_bivar |> rename (y_lo = gini_diss_mean, y_hi = gini_diss_mean),
        "lambda", "bivariate"
    )
} else {
    cli_alert_warning ("Could not load bivariate raw data for dissipative summary")
}

# ---------------------------------------------------------------------------
# Save summary CSV
# ---------------------------------------------------------------------------

summary_df <- data.frame (
    model               = c ("baseline", "bivariate"),
    estimand            = "gini_k_final",
    top_ranked_param    = c (
        gini_k_rank_base$param [1],
        gini_k_rank_bivar$param [1]
    ),
    delta_gini_frac_pos = c (hypo_base$frac_positive, hypo_bivar$frac_positive),
    delta_gini_mean     = c (hypo_base$mean_delta,     hypo_bivar$mean_delta)
)

write.csv (summary_df, file.path (results_dir, "gini_comparison_summary.csv"), row.names = FALSE)
cli_alert_success (col_green ("Wrote gini_comparison_summary.csv"))
print (summary_df, digits = 3, row.names = FALSE)
