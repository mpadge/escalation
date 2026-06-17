---
created: 2026-06-17T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 00c5122fd6e483a2bc9b6ce28ac89ae394489dfb
---

# Tasks: consolidate-workflow

## Commit points
Commit after: T010-2 (utils), T010-3 (screen.R), T010-4 (sobol.R), T010-5 (gp_explore.R), T010-6 (gp_train.R), T010-7 (gini.R), T010-9 (Makefile complete), T010-11 (report written).

## T010-1: Delete obsolete analysis/ files and create new file skeleton
- [x] T010-1: Delete the following files from `analysis/`: `gp_train2.R`, `gp_train3.R`,
  `gp_phase2.R`, `gp_phase3.R`, `plot2.R`, `plot3.R`, `morris-bivar.R`, `sobol-bivar.R`,
  `gp_train_bivar.R`, `gp_phase_bivar.R`, `plot_bivar.R`, `gp_gini_baseline.R`,
  `gp_gini_bivar.R`, `gini_compare.R`, `recover-bivar.R`, `gp_phase_utils.R`,
  `gp_train_utils.R`, `plot_utils.R`, `delta_monotone.R`. Rename `morris.R` → `screen.R`
  and `gp_phase.R` → `gp_explore.R` (both will be fully rewritten). Create empty stubs
  for `gini.R`. The surviving files are: `utils.R`, `screen.R`, `sobol.R`, `gp_train.R`,
  `gp_explore.R`, `gini.R`, `plot.R` — no others.

## T010-2: Consolidate shared utilities into utils.R
- [x] T010-2: Rewrite `analysis/utils.R` to consolidate all shared helpers needed by the
  remaining scripts. Absorb the `delta_monotone()` function (previously in
  `delta_monotone.R`). Remove any helper functions that existed only to support deleted
  scripts (stage-numbered GP train/phase utilities). Ensure `utils.R` is source-able
  standalone with no dependencies on other analysis scripts.

## T010-3: Write screen.R — unified bivariate Morris screening
- [x] T010-3: Rewrite `analysis/screen.R` (formerly `morris.R`) as a single script running
  Morris elementary-effects screening on the bivariate (ε, σ) model. The script must
  run the Rust binary, generate Morris trajectories across all parameters (including
  mu_sigma, sigma_sigma), and write results to `results/morris_results.csv`. Remove all
  univariate-specific branches and stage-numbered references. The σ-degenerate case
  (mu_sigma=1, sigma_sigma=0) is not a separate run — it is recovered by inspection of
  the Morris output, not by re-running.

## T010-4: Write sobol.R — unified bivariate Sobol analysis
- [x] T010-4: Rewrite `analysis/sobol.R` as a single bivariate script computing first-order
  and total-order Sobol indices for Ψ (and psi_sigma where applicable) across the full
  bivariate parameter set. Write results to `results/sobol_results.csv`. Remove all
  stage-numbered references and the separate `sobol-bivar.R` logic (already deleted in
  T010-1); the bivariate Sobol is the only Sobol run.

## T010-5: Write gp_explore.R — adaptive phase exploration
- [x] T010-5: Write `analysis/gp_explore.R` implementing the adaptive sampling algorithm:
  (1) Generate a coarse LHS design of N=200 points over the full bivariate parameter
  space and simulate Ψ. (2) Fit an initial DiceKriging GP on Ψ. (3) Evaluate the GP
  posterior mean on a 30×30 grid; identify the grid point with maximum predicted Ψ.
  (4) Sample N=300 new points within a hypercube centred on that maximum, with side
  length = 40% of each parameter's range, shrinking by 20% each iteration. (5) Retrain
  the GP on the combined design. (6) Repeat steps 3–5, stopping when the peak-Ψ
  location moves less than 1% of parameter range between iterations, with a hard cap
  of K=5 iterations. Use numerical finite differences on the GP posterior mean for
  gradient estimation (no DiceOptim dependency). Save the final adaptive design to
  `results/adaptive_design.csv` and the fitted GP object to `results/gp_psi.rds`.
  Generate and save phase diagram CSVs (50×50 grids across the λ×α axes with other
  parameters fixed at high-Ψ-corner values: λ at lower-range boundary, α at
  upper-range boundary) to `results/gp_phase/`.

## T010-6: Write gp_train.R — GP training on all estimands
- [x] T010-6: Rewrite `analysis/gp_train.R` to load the adaptive design from
  `results/adaptive_design.csv`, simulate the remaining estimands (ε–degree correlation,
  psi_sigma), and fit DiceKriging GPs for each. Save GP objects to `results/gp_edeg.rds`
  and `results/gp_psi_sigma.rds`. Include a σ-degenerate slice block: predict Ψ from
  `gp_psi.rds` at (mu_sigma=1, sigma_sigma=0) across the high-resolution λ×α grid from
  the adaptive design and write predictions to `results/gp_phase/psi_degenerate.csv`.
  This is a new result on the adaptive design — not a reproduction of Stage 002.
  No separate univariate GP is trained.

## T010-7: Write gini.R — consolidated Gini estimand analysis
- [ ] T010-7: Write `analysis/gini.R` to fit DiceKriging GPs for `gini_k_final` and
  dissipative inequality (`gini_peak − gini_k_final`) using the adaptive design from
  `results/adaptive_design.csv`. Compute ARD sensitivity rankings and compare to the
  Ψ and ε–degree rankings from the same design (reproducing the three-way dissociation:
  λ→Ψ, α→ε–degree, η_obs/dw_obs→Gini). Save GP objects to `results/gp_gini.rds` and
  `results/gp_gini_dissip.rds`; write phase CSVs to `results/gp_phase/gini_*.csv`.

## T010-8: Write plot.R — consolidated plotting
- [ ] T010-8: Rewrite `analysis/plot.R` to produce all figures from the CSV outputs in
  `results/gp_phase/`: (a) Ψ phase diagram (λ×α, high-Ψ corner) with Ψ=1 contour;
  (b) σ-degenerate Ψ slice for comparison; (c) ε–degree correlation phase diagram;
  (d) Gini phase diagram; (e) ARD sensitivity bar chart comparing all three estimands
  side by side. Write PNGs to `results/figures/`. Remove all stage-numbered plot
  variants and bivariate-specific branches — one script, one call per figure type.

## T010-9: Collapse Makefile to ≤8 targets
- [ ] T010-9: Rewrite the `Makefile` so that it contains exactly the following analysis
  targets (each invoking one script): `screen`, `sobol`, `explore`, `train`, `gini`,
  `plots`, plus `doc` (for report rendering) and `all` (runs explore → train → gini →
  plots in order). Remove all stage-numbered targets (`gp2`, `gp2_phase`, `plots2`,
  `gp3`, `gp3_phase`, `plots3`, `morris-bivar`, `sobol-bivar`, `recover-bivar`,
  `gp-train-bivar`, `gp-phase-bivar`, `plots-bivar`). Retain the Rust targets (`build`,
  `release`, `test`, `validate`) unchanged.

## T010-10: Run full pipeline and verify outputs
- [ ] T010-10: Execute the full pipeline in order via `make explore`, `make train`,
  `make gini`, `make plots`. Verify that all expected output files appear in
  `results/`: `adaptive_design.csv`, `gp_psi.rds`, `gp_edeg.rds`, `gp_psi_sigma.rds`,
  `gp_gini.rds`, `gp_gini_dissip.rds`, phase CSVs in `results/gp_phase/`, and PNGs in
  `results/figures/`. Fix any runtime errors. Confirm the adaptive sampling converged
  (peak-Ψ location stable across iterations) and that the high-Ψ corner is visible in
  the phase diagrams. Archive results to `results/010-consolidate-workflow.tar.gz`.

## T010-11: Write docs/report.md
- [ ] T010-11: Write `docs/report.md` as an entirely new, self-contained research
  document (~3,000 words) synthesising the findings from this stage. The report must
  be written fresh from the numerical results; it must not reference, paraphrase, or
  be structured around any prior report. Cover: (1) Ψ amplification in the high-Ψ
  corner — boundary shape under σ heterogeneity, effect of dw_obs on the Ψ=1
  threshold; (2) ε–degree correlation in the amplification regime; (3) Gini inequality
  — parameter dissociation and dissipative inequality; (4) σ-degenerate slice as an
  interpretive reference within the bivariate results, not as a separate analysis.
  Write figures to `docs/figures/`. The previous report lives at
  `docs/009-gini-inequality/report.md` and is not modified.
