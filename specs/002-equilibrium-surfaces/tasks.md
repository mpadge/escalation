---
created: 2026-06-11T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 54bf6f4b9ca33dcb727c260d7ad6d3dd4b864188
---

# Tasks: equilibrium-surfaces

## T002-1: Write analysis/gp_train2.R
- [ ] T002-1: Write a new script `analysis/gp_train2.R` that trains two GP emulators on the
  absolute equilibrium escalation surfaces from Stage 1 data. The script must:
  1. Read `results/gp_train_raw.csv` (which contains paired rows: mu0=0.4 and mu0=0.6 for
     each seed × design point, with `mean_epsilon_final` as the key column).
  2. Split by `mu0`: lo subset (mu0=0.4), hi subset (mu0=0.6).
  3. Average `mean_epsilon_final` across seeds per design point within each subset to
     produce one scalar per design point per condition.
  4. Use only the top-4 parameters as GP inputs: `alpha`, `gamma`, `lambda`, `eta_obs`.
     Fix `beta = mid_beta` and `theta = mid_theta` from `defaults.toml` (these are only
     used for documentation; the design points already have varied beta and theta, so
     subsetting or marginalising over them is not needed — just drop those columns and use
     the 4-column design matrix).
  5. Fit two GPs using `DiceKriging::km()` with Matérn-5/2 kernel, ARD length scales,
     `nugget.estim = TRUE`, constant trend (`formula = ~1`), one per condition. Name them
     `fit_lo` and `fit_hi`.
  6. Validate each GP on a held-out 20% split: report RMSE and 95% coverage for each.
  7. Print ARD length scales, nugget, and σ² for each fitted GP.
  8. Save `results/gp_lo.rds` and `results/gp_hi.rds`.
  9. Save a hyperparameter summary to `results/gp2_hyperparams.csv` with columns:
     `condition` (lo/hi), `param`, `ell`, `sigma2`, `nugget`, `rmse`, `coverage`.

## T002-2: Add Makefile gp2 target
- [ ] T002-2: Add a `gp2` target to the `Makefile` that runs `Rscript analysis/gp_train2.R`.
  Add it to `.PHONY` and give it a `##` comment: `## Train two-GP emulators on absolute
  escalation surfaces (Stage 2)`. Do not modify the existing `gp` target.

## T002-3: Run gp2 and write results/gp.md
- [ ] T002-3: Instruct the user to run `make gp2` and report back the console output including
  ARD length scales, RMSE, and coverage for both GPs. Do not run this yourself. Verify:
  (a) both `results/gp_lo.rds` and `results/gp_hi.rds` exist; (b) nugget > 0 for both;
  (c) no ARD length scale is degenerate (< 0.05 relative to its parameter range). Once
  confirmed, write `specs/002-equilibrium-surfaces/results/gp.md` documenting:
  - ARD length scales and sensitivity (1/ell) for both GPs side-by-side
  - Nugget and σ² for each
  - RMSE and coverage for each
  - Whether the two GPs agree on which parameters are most important
  - Any notable differences between the lo and hi surfaces implied by the hyperparameters

## T002-4: Write analysis/gp_phase2.R
- [ ] T002-4: Write a new script `analysis/gp_phase2.R` that generates phase diagrams for
  three surfaces: E_lo, E_hi, and Ψ = (E_hi − E_lo) / 0.2. The script must:
  1. Load `results/gp_lo.rds` and `results/gp_hi.rds`.
  2. Read parameter bounds from `defaults.toml` (`ranges` section) for alpha, gamma,
     lambda, eta_obs. Read midpoints (`mid_beta`, `mid_theta`) for the fixed parameters.
  3. For each of the 6 pairs from the top-4 parameters {alpha, gamma, lambda, eta_obs}:
     a. Build a 50×50 grid over the pair's ranges.
     b. Fill the remaining two parameters at their Stage 1 midpoints (`mid_alpha`,
        `mid_gamma`, `mid_lambda`, `mid_eta_obs` from defaults.toml, each used when not
        the focal pair).
     c. Reorder columns to match `colnames(fit_lo@X)` before calling `predict()` on
        both GPs (same column-order fix as Stage 1 to avoid silent mismatches).
        Use `checkNames = TRUE` for both predict calls.
     d. Compute E_lo predictions (type = "UK"), E_hi predictions (type = "UK"), and
        Ψ = (E_hi_mean − E_lo_mean) / 0.2.
     e. Write three CSV files to `results/gp_phase2/`:
        - `phase2_lo_<param1>_<param2>.csv` with columns: param1, param2, psi (E_lo)
        - `phase2_hi_<param1>_<param2>.csv` with columns: param1, param2, psi (E_hi)
        - `phase2_psi_<param1>_<param2>.csv` with columns: param1, param2, psi (Ψ)
     f. Print summary stats (min, mean, max) for each surface and whether Ψ > 1 is
        observed anywhere in this pair's grid.
  4. After all pairs, print an overall summary: which pairs (if any) contain regions where
     Ψ > 1, and the maximum Ψ observed across all pairs.

## T002-5: Add Makefile gp2_phase target
- [ ] T002-5: Add a `gp2_phase` target to the `Makefile` that runs
  `Rscript analysis/gp_phase2.R`. Add to `.PHONY` with comment: `## Generate two-GP
  phase diagrams for E_lo, E_hi, and Psi surfaces (Stage 2)`. Do not modify existing
  targets.

## T002-6: Run gp2_phase and append to gp.md
- [ ] T002-6: Instruct the user to run `make gp2_phase` and report back the console output.
  Do not run this yourself. Verify that 18 CSV files exist in `results/gp_phase2/` (6
  pairs × 3 surfaces). Report whether Ψ > 1 is observed in any pair's grid, and the
  maximum Ψ value found. Append a **Phase diagrams** section to
  `specs/002-equilibrium-surfaces/results/gp.md` documenting:
  - Per-pair summary table: E_lo range, E_hi range, Ψ range, whether Ψ > 1 observed
  - Which parameter pairs show the largest amplification
  - Whether E_hi or E_lo shows any near-zero or near-1 saturation in any region

## T002-7: Update plot.R for two-GP phase outputs
- [ ] T002-7: Add a new section to `analysis/plot.R` that reads from `results/gp_phase2/`
  and generates phase diagram plots for all 18 surfaces. For each of the 6 parameter
  pairs, produce a single multi-panel figure with three panels side-by-side: E_lo, E_hi,
  and Ψ. Requirements:
  - Use a diverging colour scale for Ψ centred at Ψ = 1 (the amplification boundary):
    values below 1 in one colour family, above 1 in another.
  - If Ψ = 1 is reached anywhere in a pair's grid, draw a contour line at Ψ = 1 on the
    Ψ panel.
  - Use a sequential colour scale (e.g. viridis) for E_lo and E_hi panels, with a shared
    scale across both so differences are visually comparable.
  - Save each three-panel figure as `results/plots/phase2_<param1>_<param2>.png`.
  - Do not modify the existing plot functions for Stage 1 outputs.

## T002-8: Add Makefile plots2 target
- [ ] T002-8: Add a `plots2` target to the `Makefile` that runs `Rscript analysis/plot.R
  --stage2`. Alternatively, if a command-line flag is awkward, add a separate
  `analysis/plot2.R` script and call that. Add to `.PHONY` with comment: `## Generate
  Stage 2 phase diagram plots`. Do not modify the existing `plots` target.

## T002-9: Run plots2 and confirm outputs
- [ ] T002-9: Instruct the user to run `make plots2` and report back that 6 PNG files
  exist in `results/plots/` matching `phase2_*.png`. Do not run this yourself. If any
  plot fails, report the error. Confirm that the Ψ = 1 contour is visible in any panel
  where Ψ > 1 was reported in T002-6.

## T002-10: Write stage results summary
- [ ] T002-10: Write `specs/002-equilibrium-surfaces/results/summary.md` documenting the
  full quantitative results: GP hyperparameter tables for both conditions, per-pair phase
  diagram summary table, the maximum Ψ observed, and whether the central hypothesis
  (Ψ > 1 exists in the top-4 parameter space) was confirmed or not. Structure analogous
  to `specs/001-revise-param-ranges/results/summary.md`.

## T002-11: Write stage interpretation
- [ ] T002-11: Write `specs/002-equilibrium-surfaces/results/interpretation.md` as a
  prose narrative in the style of `specs/001-revise-param-ranges/results/interpretation.md`.
  Address: (1) what the absolute E_lo and E_hi surfaces reveal about which parameter
  combinations produce high versus low equilibrium escalation; (2) whether and where the
  social dynamics amplify the initial μ₀ perturbation (Ψ > 1) or dampen it; (3) how the
  structural parameters (alpha, gamma, lambda) shape the amplification landscape; (4) what
  the results imply for the original question about the societal consequences of increased
  initial escalation tendency.
