---
created: 2026-06-11T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 82fafb29081854c16a1f6e9c4d5f628567de0edc
---

# Tasks: centrality-correlation

## T003-0: Extract shared utilities from existing analysis scripts
- [x] T003-0: Read `analysis/gp_train2.R`, `analysis/gp_phase2.R`, and
  `analysis/plot2.R`. Extract all reusable functions into three new utility
  files so that Stage 2 and Stage 3 scripts share code rather than duplicate
  it. Then update the Stage 2 scripts to source the utilities. Specific
  requirements:

  **`analysis/gp_train_utils.R`** — extract from `gp_train2.R`:
  - `load_raw_data(results_dir, n_rep)` — reads `gp_train_raw.csv`,
    reconstructs `eta_obs = kappa * eta_fixed` (eta_fixed from `defaults.toml`
    `$analysis$eta`), adds `pair_idx = ceiling(row_number() / (2L * n_rep))`,
    prints row/pair counts.
  - `build_design_matrix(raw, response_col)` — takes the raw data frame and
    a column name string; extracts design points from the lo subset and
    averages `response_col` per `pair_idx` for both lo and hi subsets;
    returns a data frame with columns `pair_idx`, `alpha`, `gamma`, `lambda`,
    `eta_obs`, `y_lo`, `y_hi`.
  - `split_train_test(gp_data)` — stratified 80/20 split on the mean of
    `y_lo` and `y_hi` (5-quantile strata, seed 42); returns a list with
    `X_train`, `X_test`, `y_lo_train`, `y_lo_test`, `y_hi_train`, `y_hi_test`.
  - `fit_gp_surface(X_train, y_train, label)` — fits `DiceKriging::km()`
    with Matérn-5/2, ARD, `nugget.estim=TRUE`, `formula=~1`; prints timing
    warning; returns the fitted km object.
  - `validate_gp_surface(fit, X_test, y_test, label)` — predicts on test
    set with `type="UK"`, `checkNames=TRUE`, column order from
    `colnames(fit@X)`; prints RMSE and 95% coverage; returns
    `list(rmse, coverage)`.
  - `print_hyperparams(fit, label)` — extracts `ell`, `sigma2`, `nugget`
    from the fitted km object, prints them sorted by ell; returns
    `list(ell=named_vector, sigma2, nugget)`.
  - `save_hyperparams_csv(hp_lo, hp_hi, val_lo, val_hi, path)` — writes a
    CSV with columns `condition`, `param`, `ell`, `sigma2`, `nugget`,
    `rmse`, `coverage` to `path`.

  **`analysis/gp_phase_utils.R`** — extract from `gp_phase2.R`:
  - `load_phase_params(toml_path, top_params)` — reads `defaults.toml`,
    returns `list(all_binf, all_bsup, mid_vals)` using `ranges` and
    `analysis` sections.
  - `build_phase_grid(p_a, p_b, all_binf, all_bsup, mid_vals, top_params,
    n_grid=50)` — builds the expand.grid, fills non-focal params at
    midpoints; returns the grid data frame.
  - `predict_gp_pair(fit, grid)` — calls `predict()` with column reordering
    via `colnames(fit@X)`, `type="UK"`, `checkNames=TRUE`; returns the
    DiceKriging predict list.
  - `write_phase_csvs(grid, p_a, p_b, pred_lo, pred_hi, derived,
    out_dir, prefix, derived_col="val")` — writes three CSVs:
    `<prefix>_lo_<p_a>_vs_<p_b>.csv`, `<prefix>_hi_<p_a>_vs_<p_b>.csv`,
    `<prefix>_<derived_col>_<p_a>_vs_<p_b>.csv`; each has columns
    `p_a`, `p_b`, and the value column; returns the file paths invisibly.

  **`analysis/plot_utils.R`** — extract from `plot2.R`:
  - `build_e_limits(phase_dir, prefix_lo, prefix_hi)` — globs all lo and
    hi surface CSVs from `phase_dir` matching the given prefixes, reads the
    value column from each, returns `c(global_min, global_max)`.
  - `panel_sequential(df, xvar, yvar, val_col, limits, legend_title,
    panel_title)` — returns a `ggplot` geom_tile with `scale_fill_viridis_c`
    at the given limits.
  - `panel_diverging(df, xvar, yvar, val_col, midpoint=0, legend_title,
    panel_title, contour_at=NULL)` — returns a `ggplot` geom_tile with
    `scale_fill_gradient2` (blue/white/red), optional black contour line at
    `contour_at`.
  - `save_three_panel(p_lo, p_hi, p_derived, out_path, title)` — combines
    with patchwork and calls `ggsave(..., width=18, height=5.5, dpi=300)`.

  **Update Stage 2 scripts to source utils:**
  - Replace the inline function definitions in `gp_train2.R` with
    `source("analysis/gp_train_utils.R")` and update calls to use the
    generalised function signatures (pass `"mean_epsilon_final"` as
    `response_col` to `build_design_matrix()`; pass the correct output paths
    to `save_hyperparams_csv()`).
  - Replace inline functions in `gp_phase2.R` with
    `source("analysis/gp_phase_utils.R")` and update accordingly.
  - Replace inline helpers in `plot2.R` with
    `source("analysis/plot_utils.R")` and update accordingly.
  - Verify that `make gp2`, `make gp2_phase`, and `make plots2` still
    produce identical outputs after the refactor (check that the same RDS
    files and CSVs are written without error).

## T003-1: Write analysis/gp_train3.R
- [x] T003-1: Write `analysis/gp_train3.R` that trains two GP emulators on
  the epsilon-degree correlation surfaces from Stage 1 data. The script must
  source `analysis/gp_train_utils.R` and use its functions throughout. Steps:
  1. `source("analysis/gp_train_utils.R")`.
  2. Read `n_rep` from `defaults.toml` (`$gp$n_rep_gp`).
  3. Call `load_raw_data(results_dir, n_rep)` to get the raw data frame.
  4. Call `build_design_matrix(raw, "epsilon_k_corr_final")` to produce
     `gp3_data` with columns `pair_idx`, `alpha`, `gamma`, `lambda`,
     `eta_obs`, `y_lo`, `y_hi`. Write to `results/gp3_data.csv`.
  5. Call `split_train_test(gp3_data)` to get `splits`.
  6. Call `fit_gp_surface(splits$X_train, splits$y_lo_train, "C_lo")` and
     save to `results/gp_corr_lo.rds`.
  7. Call `fit_gp_surface(splits$X_train, splits$y_hi_train, "C_hi")` and
     save to `results/gp_corr_hi.rds`.
  8. Call `validate_gp_surface()` for both fits.
  9. Call `print_hyperparams()` for both fits.
  10. Call `save_hyperparams_csv(hp_lo, hp_hi, val_lo, val_hi,
      file.path(results_dir, "gp3_hyperparams.csv"))`.

## T003-2: Add Makefile gp3 target
- [x] T003-2: Add a `gp3` target to the `Makefile` that runs
  `Rscript analysis/gp_train3.R`. Add to `.PHONY` with `##` comment:
  `## Train two-GP emulators on epsilon-degree correlation surfaces (Stage 3)`.
  Do not modify existing targets.

## T003-3: Run gp3 and write results/gp.md
- [ ] T003-3: Run `make gp3` and capture the console output including ARD
  length scales, RMSE, and coverage for both GPs. Verify: (a) both
  `results/gp_corr_lo.rds` and `results/gp_corr_hi.rds` exist; (b) nugget > 0
  for both; (c) no ARD length scale is degenerate (< 0.05 relative to the
  parameter range). Then write `specs/003-centrality-correlation/results/gp.md`
  documenting:
  - ARD length scales and sensitivity (1/ell) for both GPs side-by-side
  - Nugget and σ² for each
  - RMSE and coverage for each
  - Whether the two GPs agree on which parameters are most important
  - The sign and typical magnitude of the baseline correlation (positive =
    escalatory agents more central; negative = more isolated)
  - Notable differences in parameter sensitivity between C_lo and C_hi

## T003-4: Write analysis/gp_phase3.R
- [ ] T003-4: Write `analysis/gp_phase3.R` that generates phase diagrams for
  three surfaces: C_lo, C_hi, and difference = C_hi − C_lo. The script must
  source `analysis/gp_phase_utils.R` and use its functions throughout. Steps:
  1. `source("analysis/gp_phase_utils.R")`.
  2. Load `results/gp_corr_lo.rds` and `results/gp_corr_hi.rds` (abort with
     informative message if missing).
  3. Call `load_phase_params("defaults.toml", TOP_PARAMS)` for bounds and
     midpoints.
  4. For each of the 6 pairs from {alpha, gamma, lambda, eta_obs}:
     a. Call `build_phase_grid(p_a, p_b, ...)` to get the grid.
     b. Call `predict_gp_pair(fit_corr_lo, grid)` and
        `predict_gp_pair(fit_corr_hi, grid)` to get predictions.
     c. Compute `derived = pred_hi$mean - pred_lo$mean`.
     d. Call `write_phase_csvs(grid, p_a, p_b, pred_lo, pred_hi, derived,
        phase3_dir, prefix="phase3", derived_col="diff")`.
     e. Print min/mean/max for each surface and whether `derived > 0`
        anywhere.
  5. After all pairs, print an overall summary: which pairs show positive
     difference anywhere, and the maximum difference across all pairs.

## T003-5: Add Makefile gp3_phase target
- [ ] T003-5: Add a `gp3_phase` target to the `Makefile` that runs
  `Rscript analysis/gp_phase3.R`. Add to `.PHONY` with comment:
  `## Generate two-GP phase diagrams for C_lo, C_hi, and difference surfaces (Stage 3)`.
  Do not modify existing targets.

## T003-6: Run gp3_phase and append to gp.md
- [ ] T003-6: Run `make gp3_phase` and capture the console output. Verify that
  18 CSV files exist in `results/gp_phase3/` (6 pairs × 3 surfaces). Append a
  **Phase diagrams** section to `specs/003-centrality-correlation/results/gp.md`
  documenting:
  - Per-pair summary table: C_lo range, C_hi range, difference range,
    whether difference > 0 anywhere in the pair's grid
  - Which parameter pairs show the largest positive difference (most benefit
    for high-ε individuals from increased μ₀)
  - Whether any pair shows consistently negative difference (increased μ₀
    uniformly disadvantages high-ε individuals in network centrality)
  - Whether the pairs where difference > 0 overlap with the Stage 2
    amplification pairs (alpha×lambda and gamma×lambda)

## T003-7: Write analysis/plot3.R
- [ ] T003-7: Write `analysis/plot3.R` that reads from `results/gp_phase3/`
  and generates phase diagram plots for all 18 surfaces. Source
  `analysis/plot_utils.R` and use its functions throughout. Steps:
  1. `source("analysis/plot_utils.R")`.  # shared with plot2.R
  2. Call `build_e_limits(phase3_dir, "phase3_lo", "phase3_hi")` for the
     shared sequential scale limits across C_lo and C_hi panels.
  3. For each of the 6 pairs (detected from `phase3_hi_*.csv` filenames):
     a. Read the three CSVs (lo, hi, diff).
     b. Call `panel_sequential()` twice (C_lo and C_hi) with the shared
        limits and appropriate `legend_title` / `panel_title`.
     c. Call `panel_diverging()` with `midpoint=0`, `contour_at=0`, and a
        per-pair symmetric limit sized to the max absolute diff value.
     d. Call `save_three_panel(p_lo, p_hi, p_diff, out_path, title)` where
        `out_path = results/plots/phase3_<tag>.png`.

## T003-8: Add Makefile plots3 target
- [ ] T003-8: Add a `plots3` target to the `Makefile` that runs
  `Rscript analysis/plot3.R`. Add to `.PHONY` with comment:
  `## Generate Stage 3 phase diagram plots`. Do not modify existing targets.

## T003-9: Run plots3 and confirm outputs
- [ ] T003-9: Run `make plots3` and confirm that 6 PNG files exist in
  `results/plots/` matching `phase3_*.png`. If any plot fails, fix the error
  before proceeding. Confirm the difference = 0 contour is rendered in all
  difference panels.

## T003-10: Write stage results summary
- [ ] T003-10: Write `specs/003-centrality-correlation/results/summary.md`
  documenting the full quantitative results: GP hyperparameter tables for both
  conditions, per-pair phase diagram summary table, and a direct answer to
  the central question: "Do high-epsilon individuals benefit more from
  increases in μ₀?" Structure analogous to
  `specs/002-equilibrium-surfaces/results/summary.md`. Include any overlap
  or contrast with the Stage 2 amplification findings.

## T003-11: Write stage interpretation
- [ ] T003-11: Write `specs/003-centrality-correlation/results/interpretation.md`
  as a prose narrative in the style of
  `specs/002-equilibrium-surfaces/results/interpretation.md`. Address:
  (1) what the baseline correlation surfaces (C_lo, C_hi) reveal about the
  typical relationship between escalation propensity and network centrality
  at equilibrium; (2) whether and where increased μ₀ amplifies the network
  advantage of high-ε individuals (positive difference); (3) how the
  structural parameters shape this individual-level benefit; (4) how the
  findings relate to the Stage 2 population-level amplification result —
  i.e., whether the same regimes that amplify the population average also
  concentrate network influence in escalatory individuals.
