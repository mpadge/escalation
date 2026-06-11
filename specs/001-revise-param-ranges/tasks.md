---
created: 2026-06-11T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 0b12a019a66c1961742f1e04a27c63437f4b6d5a
---

# Tasks: revise-param-ranges

## T001-1: Convert defaults.json to defaults.toml
- [ ] T001-1: Convert `defaults.json` to `defaults.toml` using proper TOML structure with
  inline comments. Group parameters into labelled sections (e.g. `[structural]`,
  `[analysis]`, `[sobol]`, `[gp]`). Delete `defaults.json` once the TOML file is
  written. Then find every `jsonlite::fromJSON` call that reads `defaults.json` across
  all `analysis/*.R` scripts and replace it with `RcppTOML::parseTOML("defaults.toml")`.
  Add `library(RcppTOML)` where needed (or use `RcppTOML::parseTOML` without loading).
  After all edits, instruct the user to run a quick smoke-test in R:
  `d <- RcppTOML::parseTOML("defaults.toml"); print(d$n); print(d$n_rep_gp)` and
  report back that both values are read correctly as integers (200 and 20 respectively —
  noting that n_rep_gp will be updated in T001-6).

## T001-2: Audit analysis/*.R scripts and move hardcoded parameters to defaults.toml
- [ ] T001-2: Read through all files in `analysis/` and identify any numeric constants
  that represent model parameters or analysis settings that are currently hardcoded
  rather than read from `defaults.toml`. Candidates to look for: `t_max`, `N_LHS`,
  `TOP_N`, `TOP_PHASE`, `n_sobol`, batch sizes, mu0 initial condition, fixed
  mid-point values in the `fixed` list in `gp_train.R`, tolerance values in
  `delta_monotone.R`, and any similar magic numbers. For each candidate, decide
  whether it belongs in `defaults.toml` (i.e. it is a setting a user might legitimately
  want to tune without editing R code). Move confirmed candidates to an appropriate
  section in `defaults.toml` and update the R scripts to read them via `d$<key>`.
  Do not move constants that are genuinely internal to the analysis logic (e.g.
  quantile cut points, ggplot aesthetics).

## T001-3: Update parameter ranges in gp_train.R
- [ ] T001-3: In `analysis/gp_train.R`, update `all_binf` and `all_bsup` vectors:
  - `gamma`: binf 2.0 → 1.0, bsup 4.0 → 5.0
  - `beta`: bsup 3.0 → 1.0 (binf stays 0.0)
  - `w_win`: binf 0.1 → 0.0 (bsup stays 2.0)
  All other parameters unchanged.

## T001-4: Update parameter ranges in gp_phase.R
- [ ] T001-4: In `analysis/gp_phase.R`, update `all_binf` and `all_bsup` vectors to match
  the same changes as T001-3 (gamma, beta, w_win). These two vectors appear near line 71.

## T001-5: Switch GP fitting from noise.var to nugget.estim
- [ ] T001-5: In `analysis/gp_train.R`, in the `km()` call for `fit_psi` (around line 251),
  replace the `noise.var = noise_var_train` argument with `nugget.estim = TRUE`. Remove
  the `noise_var_train` construction lines above it (the `psi_sd^2` computation and
  the zero-guard `noise_var_train[...] <- 1e-6`) since they are no longer needed for
  the psi fit. The `fit_tau` km() call already uses `nugget.estim = TRUE` — leave it
  unchanged.

## T001-6: Increase replicates per design point to 20
- [ ] T001-6: In `defaults.toml`, change `n_rep_gp` from 5 to 20. This controls the number
  of simulation replicates run per LHS design point in `gp_train.R`.

## T001-7: Delete stale results to force full re-run
- [ ] T001-7: Delete the `results/` directory at the project root so that all scripts
  regenerate their outputs from scratch with the new ranges and replicate count.
  Confirm with the user before deleting. The files in `specs/000-initial-build/results/`
  must NOT be touched — those are the archived Stage 0 results.

## T001-8: Run Morris screening and report output
- [ ] T001-8: Instruct the user to run `Rscript analysis/morris.R` from the project root
  and report the console output back. Do not run this script yourself. Verify that the
  script completes without error, that `results/morris_results.csv` exists, and that
  the top-ranked parameters match expectations (observational learning parameters and
  alpha should still dominate; beta should rank lower given its narrowed range).

## T001-9: Run Sobol decomposition and report output
- [ ] T001-9: Instruct the user to run `Rscript analysis/sobol.R` and report back the
  console output and the contents of `results/sobol_results.csv`. Do not run this script
  yourself. Check whether the total-effect ranking is consistent with Stage 0 (alpha
  leading, dw_obs and eta_obs prominent). Note any substantial changes in ranking or
  magnitude caused by the revised ranges.

## T001-10: Run GP training and report hyperparameters
- [ ] T001-10: Instruct the user to run `Rscript analysis/gp_train.R` and report back the
  console output including the ARD length scales, validation RMSE, and coverage. Do not
  run this script yourself. Verify that the nugget is non-zero (confirming that
  `nugget.estim = TRUE` is working), that no ARD length scale is shorter than ~0.1
  (which would indicate the GP is still at risk of collapsing to its prior mean in phase
  diagrams), and that validation RMSE is comparable to or better than Stage 0 (0.237).

## T001-11: Run GP phase diagrams and report results
- [ ] T001-11: Instruct the user to run `Rscript analysis/gp_phase.R` and report back the
  console output and a sample of the phase CSV files in `results/gp_phase/`. Do not run
  this script yourself. Verify that phase CSV files no longer show constant `psi=0.078`
  (the prior-mean collapse seen in Stage 0). If any phase diagram is still constant,
  investigate whether the affected parameter pair has short ARD length scales and document
  the finding.

## T001-12: Run plots and report final outputs
- [ ] T001-12: Instruct the user to run `Rscript analysis/plot.R` and report back that
  plots have been generated in `results/plots/`. Do not run this script yourself. Confirm
  the expected files exist: one PNG per phase pair plus summary comparison plots. If any
  plot fails, report the error.

## T001-13: Write up Stage 1 results
- [ ] T001-13: Once all scripts have run successfully, write a results summary analogous
  to `specs/000-initial-build/results/summary.md` at
  `specs/001-revise-param-ranges/results/summary.md`. The write-up should: (1) compare
  the Sobol total-effect ranking against Stage 0, (2) confirm whether the GP collapse
  was resolved, (3) state whether the revised ranges changed any qualitative conclusions,
  and (4) note any remaining open questions from the plan (particularly the eta_obs
  lower-boundary question and whether a third iteration is needed).
