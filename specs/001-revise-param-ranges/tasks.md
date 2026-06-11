---
created: 2026-06-11T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 0b12a019a66c1961742f1e04a27c63437f4b6d5a
---

# Tasks: revise-param-ranges

## T001-1: Convert defaults.json to defaults.toml
- [x] T001-1: Convert `defaults.json` to `defaults.toml` using proper TOML structure with
  inline comments. Group parameters into labelled sections (e.g. `[structural]`,
  `[analysis]`, `[sobol]`, `[gp]`). Delete `defaults.json` once the TOML file is
  written. Then find every `jsonlite::fromJSON` call that reads `defaults.json` across
  all `analysis/*.R` scripts and replace it with `RcppTOML::parseTOML("defaults.toml")`.
  Add `library(RcppTOML)` where needed (or use `RcppTOML::parseTOML` without loading).
  After all edits, instruct the user to run a quick smoke-test in R:
  `pars <- RcppTOML::parseTOML("defaults.toml"); print(pars$analysis$n); print(pars$gp$n_rep_gp)` and
  report back that both values are read correctly as integers (200 and 20 respectively —
  noting that n_rep_gp will be updated in T001-6).

## T001-2: Audit analysis/*.R scripts and move hardcoded parameters to defaults.toml
- [x] T001-2: Read through all files in `analysis/` and identify any numeric constants
  that represent model parameters or analysis settings that are currently hardcoded
  rather than read from `defaults.toml`. Candidates to look for: `t_max`, `N_LHS`,
  `TOP_N`, `TOP_PHASE`, `n_sobol`, batch sizes, mu0 initial condition, fixed
  mid-point values in the `fixed` list in `gp_train.R`, tolerance values in
  `delta_monotone.R`, and any similar magic numbers. For each candidate, decide
  whether it belongs in `defaults.toml` (i.e. it is a setting a user might legitimately
  want to tune without editing R code). Move confirmed candidates to an appropriate
  section in `defaults.toml` and update the R scripts to read them via `pars$<section>$<key>`.
  Do not move constants that are genuinely internal to the analysis logic (e.g.
  quantile cut points, ggplot aesthetics).

## T001-3: Update parameter ranges in gp_train.R
- [x] T001-3: In `analysis/gp_train.R`, update `all_binf` and `all_bsup` vectors:
  - `gamma`: binf 2.0 → 1.0, bsup 4.0 → 5.0
  - `beta`: bsup 3.0 → 1.0 (binf stays 0.0)
  - `w_win`: binf 0.1 → 0.0 (bsup stays 2.0)
  All other parameters unchanged.

## T001-4: Update parameter ranges in gp_phase.R
- [x] T001-4: In `analysis/gp_phase.R`, update `all_binf` and `all_bsup` vectors to match
  the same changes as T001-3 (gamma, beta, w_win). These two vectors appear near line 71.

## T001-5: Switch GP fitting from noise.var to nugget.estim
- [x] T001-5: In `analysis/gp_train.R`, in the `km()` call for `fit_psi` (around line 251),
  replace the `noise.var = noise_var_train` argument with `nugget.estim = TRUE`. Remove
  the `noise_var_train` construction lines above it (the `psi_sd^2` computation and
  the zero-guard `noise_var_train[...] <- 1e-6`) since they are no longer needed for
  the psi fit. The `fit_tau` km() call already uses `nugget.estim = TRUE` — leave it
  unchanged.

## T001-6: Increase replicates per design point to 20
- [x] T001-6: In `defaults.toml`, change `n_rep_gp` from 5 to 20. This controls the number
  of simulation replicates run per LHS design point in `gp_train.R`.

## T001-7: Delete stale results to force full re-run
- [x] T001-7: Remove stale outputs from `results/` so that all scripts regenerate from
  scratch with the new ranges and replicate count. Confirm with the user before deleting.
  Remove only the following:
  - All files directly in `results/` (CSV, RDS, etc.)
  - The subdirectory `results/gp_phase/` and all its contents
  - The subdirectory `results/plots/` and all its contents
  Any other subdirectories in `results/` (e.g. `results/000-initial-build/`) must NOT
  be touched — they hold archived results from prior stages.

## T001-8: Run Morris screening and report output
- [x] T001-8: Instruct the user to run `make morris` from the project root
  (i.e., `Rscript analysis/morris.R`) and report the console output back. Do not run
  this script yourself. Verify that the script completes without error, that
  `results/morris_results.csv` exists, and that the top-ranked parameters match
  expectations (observational learning parameters and alpha should still dominate; beta
  should rank lower given its narrowed range). Once results are confirmed, write a
  `specs/001-revise-param-ranges/results/morris.md` file documenting the full ranked
  table, key findings, ranking shifts versus Stage 0, and the decision on which
  parameters to carry forward to Sobol.

## T001-9: Run Sobol decomposition and report output
- [x] T001-9: Instruct the user to run `make sobol` (i.e., `Rscript analysis/sobol.R`)
  and report back the console output and the contents of `results/sobol_results.csv`. Do
  not run this script yourself. Check whether the total-effect ranking is consistent with
  Stage 0 (alpha leading, dw_obs and eta_obs prominent). Note any substantial changes in
  ranking or magnitude caused by the revised ranges. Once results are confirmed, write a
  `specs/001-revise-param-ranges/results/sobol.md` file documenting the full S₁/S_T
  table, comparison against Stage 0, key findings on interaction structure, and decisions
  for GP emulation (which parameters to carry forward and phase diagram priority).

## T001-10: Run GP training and report hyperparameters
- [x] T001-10: Instruct the user to run `make gp` (i.e., `Rscript analysis/gp_train.R`
  followed by `Rscript analysis/gp_phase.R`) and report back the console output including
  the ARD length scales, validation RMSE, and coverage. Do not run this script yourself.
  Verify that the nugget is non-zero (confirming that `nugget.estim = TRUE` is working),
  that no ARD length scale is shorter than ~0.1 (which would indicate the GP is still at
  risk of collapsing to its prior mean in phase diagrams), and that validation RMSE is
  comparable to or better than Stage 0 (0.237). Once results are confirmed, write a
  `specs/001-revise-param-ranges/results/gp.md` file documenting the ARD length scales,
  nugget estimates, RMSE, coverage, and any notable differences versus Stage 0.

## T001-11: Run GP phase diagrams and report results
- [x] T001-11: If `make gp` was not run as a unit in T001-10, instruct the user to run
  `Rscript analysis/gp_phase.R` directly. Report back the console output and a sample of
  the phase CSV files in `results/gp_phase/`. Do not run this script yourself. Verify
  that phase CSV files no longer show constant `psi=0.078` (the prior-mean collapse seen
  in Stage 0). If any phase diagram is still constant, investigate whether the affected
  parameter pair has short ARD length scales and document the finding. Append phase
  diagram findings (collapse resolved or not, any remaining constant pairs) to the
  `specs/001-revise-param-ranges/results/gp.md` written in T001-10.

## T001-12: Run plots and report final outputs
- [ ] T001-12: Instruct the user to run `make plots` (i.e., `Rscript analysis/plot.R`)
  and report back that plots have been generated in `results/plots/`. Do not run this
  script yourself. Confirm the expected files exist: one PNG per phase pair plus summary
  comparison plots. If any plot fails, report the error.

## T001-13: Write up Stage 1 results
- [ ] T001-13: Once all scripts have run successfully, write a results summary analogous
  to `specs/000-initial-build/results/summary.md` at
  `specs/001-revise-param-ranges/results/summary.md`. The write-up should: (1) compare
  the Sobol total-effect ranking against Stage 0, (2) confirm whether the GP collapse
  was resolved, (3) state whether the revised ranges changed any qualitative conclusions,
  and (4) note any remaining open questions from the plan (particularly the eta_obs
  lower-boundary question and whether a third iteration is needed).
