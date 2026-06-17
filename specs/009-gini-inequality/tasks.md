---
created: 2026-06-17T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 90f723eeebf5e742b328077edb8093d7e78a362f
---

# Tasks: 009-gini-inequality

## T009-1: Baseline model Gini GP and sensitivity analysis

- [ ] T009-1: Write `analysis/gp_gini_baseline.R`. Load
  `results/003-centrality-correlation/gp_train_raw.csv`. Reconstruct `pair_idx`
  with `mutate(pair_idx = ceiling(row_number() / (2L * n_rep)))` (n_rep from
  `defaults.toml`) and `eta_obs = kappa * eta_fixed` (eta_fixed from
  `defaults.toml$analysis$eta`), matching the logic in `gp_train_utils.R:8–29`.
  Aggregate mean `gini_k_final` per pair per mu0 condition (y_lo / y_hi), and
  separately aggregate mean `gini_dissipative = gini_peak - gini_k_final`.
  Fit four Matern-5/2 ARD GPs via DiceKriging using `TOP_PARAMS = c("alpha",
  "gamma", "lambda", "eta_obs")` (same reduced set as Ψ and ε–degree analyses):
  `gp_gini_lo`, `gp_gini_hi` (for `gini_k_final`) and `gp_diss_lo`,
  `gp_diss_hi` (for dissipative inequality). Use `fit_gp_surface` from
  `gp_train_utils.R` or replicate its pattern directly. Run GP-based Sobol
  sensitivity: generate a Saltelli design over the 4 TOP_PARAMS (ranges from
  `defaults.toml$ranges`), predict from each fitted GP using
  `predict(gp, newdata=design)$mean`, call `tell(s_obj, y)`, and extract S1/ST
  indices. Save: `results/003-centrality-correlation/gp_gini_data.csv` (aggregated
  lo/hi means per pair), `gp_gini_lo.rds`, `gp_gini_hi.rds`, `gp_diss_lo.rds`,
  `gp_diss_hi.rds` (GP objects), and
  `results/003-centrality-correlation/sobol_gini_baseline.csv` (ranked S1/ST for
  both `gini_k_final` and `gini_dissipative`, one table each).

## T009-2: Bivariate model Gini GP and sensitivity analysis

- [ ] T009-2: Write `analysis/gp_gini_bivar.R`. Load `results/gp_bivar_train.csv`.
  Reconstruct pair structure by joining to `results/design_gp_bivar.csv` on the
  six bivariate parameters (`mu_sigma`, `lambda`, `sigma_sigma`, `dw_obs`,
  `dw_bridge`, `alpha`) — each design row maps to a pair_idx. Aggregate mean
  `gini_k_final` per pair per mu0 condition (y_lo / y_hi) and mean
  `gini_dissipative = gini_peak - gini_k_final`. Fit four GPs (same pattern as
  T009-1) over the 6 bivariate parameters: `gp_gini_bivar_lo`,
  `gp_gini_bivar_hi`, `gp_diss_bivar_lo`, `gp_diss_bivar_hi`. Run GP-based
  Sobol over the 6 bivariate parameters (ranges from `defaults.toml$ranges`
  for each). Save: `results/gp_gini_bivar_data.csv` (aggregated per pair),
  `results/gp_gini_bivar_lo.rds`, `gp_gini_bivar_hi.rds`, `gp_diss_bivar_lo.rds`,
  `gp_diss_bivar_hi.rds`, and `results/sobol_gini_bivar.csv` (ranked S1/ST for
  both estimands).

## T009-3: Hypothesis test and cross-model comparison

- [ ] T009-3: Write `analysis/gini_compare.R`. (a) **Hypothesis test**: for each
  model, load the aggregated GP data (from T009-1 and T009-2), compute
  `delta_gini = y_hi - y_lo` per design point, and report: fraction of points
  where delta > 0, mean and SD of delta, and the distribution (histogram or
  density). (b) **Sobol ranking comparison**: load the Sobol results from T009-1
  and T009-2 alongside the existing rankings from
  `results/003-centrality-correlation/sobol_results.csv` (Ψ) and
  `results/sobol_bivar_results.csv` (psi_sigma), and print a combined rank-order
  table for each model showing the parameter ranks for all three estimands
  (Ψ / ε–degree / Gini in the baseline; Ψ / psi_sigma / Gini in the bivariate).
  (c) **Dissipative inequality pattern**: summarise mean `gini_dissipative` by
  quantile of alpha and lambda in each model, to check whether high-alpha
  (locally connected) configurations show more or less dissipation than
  low-alpha ones. Print all comparison tables to stdout and save a summary CSV
  `results/gini_comparison_summary.csv` containing: model, estimand, top-ranked
  parameter, delta_gini_frac_positive, delta_gini_mean.

## T009-4: Extend docs/final-report.md with Gini findings

- [ ] T009-4: Read `docs/final-report.md` in full. Add a new section "**Inequality
  of network centrality**" that resolves the current "Remaining questions" item
  on Gini. The section must cover: (a) which structural parameters govern
  `gini_k_final` in each model and whether they match the Ψ / ε–degree rankings
  (cite the rank comparison from T009-3 by name); (b) the dissipative inequality
  pattern — whether escalation produces transient concentration that cooperative
  reconstruction subsequently unwinds, and under which structural configurations;
  (c) the mu0 hypothesis result — state the fraction of configurations where the
  higher-escalation group produces higher equilibrium Gini and characterise the
  magnitude; (d) what the Gini findings add to the architectural claim (does the
  governing parameter axis for inequality align with that for amplification and
  power concentration, or reveal a new structural dimension?). Remove or fold the
  existing "Remaining questions" section once all three items are addressed by
  this stage's findings. Write in the same plain-language register as the rest of
  the report (no equations, structural parameter names introduced in parentheses
  on first use). Target ~400–600 words for the new section.
