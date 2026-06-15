---
created: 2026-06-15T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 5251fe6aefd0aa2ef380a90ec79c8a95ff7f1d37
---

# Tasks: bivariate-sensitivity

## T006-1: Implement run_sigma_paired in experiment.rs

- [x] T006-1: Add `run_sigma_paired(params, delta_mu_sigma, seeds, zeta, log_dir)` to
  `src/experiment.rs`. For each seed, run three simulations sharing the same seed:
  (a) nominal mu_sigma at mu0=mu0_lo, (b) nominal mu_sigma at mu0=mu0_hi,
  (c) mu_sigma + delta_mu_sigma at mu0=mu0_lo. Compute
  `psi = (ε̄_b − ε̄_a) / (mu0_hi − mu0_lo)` and
  `psi_sigma = (ε̄_c − ε̄_a) / delta_mu_sigma`, and populate both fields in the
  returned lo and hi RunSummary records (both records receive the same psi and
  psi_sigma values, matching the pattern for `psi` in the existing `run_paired`).
  Use delta_mu_sigma = 0.1 as the default. Reuse `run_pairs_parallel` structure for
  parallelism; the sigma run can be a sequential post-pass over each lo result
  (cheapest: only one extra sim per seed, reusing the already-computed lo result).

---

## T006-2: Extend cmd_sensitivity to emit psi_sigma in output CSV

- [x] T006-2: In `src/main.rs`, replace the `run_pairs_parallel` call inside
  `cmd_sensitivity` with a call to `run_sigma_paired` (T006-1), which produces the
  same paired output plus the populated `psi_sigma` field. Verify that
  `src/output.rs` `write_summaries` already writes the `psi_sigma` column (it should,
  since RunSummary includes the field); if not, add it following the same pattern as
  the other Option<f64> fields. After this change, `results/morris_bivar_raw.csv`
  and `results/sobol_bivar_raw.csv` will contain a `psi_sigma` column alongside the
  existing `psi` column.

---

## T006-3: Validation test T006-1 — psi_sigma = 0 in degenerate case

- [x] T006-3: Add a `#[test]` in `src/experiment.rs` (alongside the existing
  `integration_10_pairs_csv_20_rows` test) that runs `run_sigma_paired` with
  `eta_sigma = 0.0` and `sigma_sigma = 0.0` (degenerate σ case: agents have fixed
  σ = mu_sigma = 1.0, no learning). Assert that `|psi_sigma| < 1e-3` for each seed
  in the result. Use n = 30 agents, 5 seeds, t_max = 500 for speed. This verifies
  that a mu_sigma perturbation has no effect on ε̄(∞) when the σ pathway is inactive.

---

## T006-4: Create analysis/morris-bivar.R

- [x] T006-4: Create `analysis/morris-bivar.R` based on `analysis/morris.R` with the
  following changes:
  - Set `results_dir <- "results"`. Use stage-specific filenames: design file
    `design_morris_bivar.csv`, raw output `morris_bivar_raw.csv`.
  - Extend `param_names` to add `mu_sigma`, `sigma_sigma`, `eta_sigma`,
    `sigma_decay` (15 free parameters total). Add a header comment explaining that
    `eta_obs` is moved from `param_names` into `fixed` to avoid collinearity with
    `mu_sigma` (both scale the observational-learning pathway).
  - In `fixed`, add `eta_obs = pars_a$eta_obs` (at its reference value) and remove
    it from `param_names`.
  - Add ranges for the four new parameters to `binf`/`bsup` (read from
    `defaults.toml` if entries exist; otherwise hardcode mu_sigma=[0.5,2.0],
    sigma_sigma=[0.0,0.5], eta_sigma=[0.0,0.2], sigma_decay=[0.001,0.01]).
  - Call `compute_morris_indices` twice: once using the `psi_sigma` column as output
    metric and once using the `psi` column (Ψ with σ active). Internal helper
    functions follow the `_bivar` suffix convention (e.g. `make_morris_design_bivar`,
    `compute_morris_indices_bivar`). Write results to:
    - `results/morris_bivar_results_psi_sigma.csv`
    - `results/morris_bivar_results_psi.csv`
  - Produce `results/plots/morris_bivar_plot.png`: a μ* vs σ scatter with both
    metrics as separate coloured series (psi_sigma and psi), parameter names as
    point labels, using `analysis/plot_utils.R` styling.

  **After implementing this task, stop and ask the user to run `make morris-bivar`
  and report back with the console output before continuing to T006-5.**

---

## T006-5: Create analysis/sobol-bivar.R

- [ ] T006-5: Create `analysis/sobol-bivar.R` based on `analysis/sobol.R` with the
  following changes:
  - Set `results_dir <- "results"`. Use stage-specific filenames: design file
    `design_sobol_bivar.csv`, raw output `sobol_bivar_raw.csv`.
  - Read top parameters from `results/morris_bivar_results_psi_sigma.csv` (written
    by the `make morris-bivar` run) instead of the archived `morris_results.csv`. Use the same
    `select_sobol_params` logic (top_n from the μ* ranking; eta_obs excluded from
    the candidate set since it was not screened). Internal helper functions follow
    the `_bivar` suffix convention (e.g. `select_sobol_params_bivar`,
    `make_saltelli_design_bivar`).
  - Include `mu_sigma`, `sigma_sigma`, `eta_sigma`, `sigma_decay` in the candidate
    set with the same ranges as T006-4.
  - Use the `psi_sigma` column from `sobol_bivar_raw.csv` as the output metric for
    `sobol2007 / tell`.
  - Write results to:
    - `results/sobol_bivar_results.csv` (parameter, S1, S1_lower, S1_upper, ST,
      ST_lower, ST_upper)
    - `results/plots/sobol_bivar_plot.png` (S1 / ST bar chart, same style as
      existing Sobol plots)

  **After implementing this task, stop and ask the user to run `make sobol-bivar`
  and report back with the console output before continuing to T006-6.**

---

## T006-6: Create analysis/recover-bivar.R

- [ ] T006-6: Create `analysis/recover-bivar.R`. This script runs the Morris binary
  with σ fixed at degenerate values and compares the resulting Ψ rankings to the
  stage 000/001 Morris results in `results/morris_results.csv`, showing that stage 004
  report results are fully recoverable from the bivariate binary.
  - Set `results_dir <- "results"`. Use filenames `design_morris_bivar_degen.csv`
    and `morris_bivar_raw_degen.csv` to avoid overwriting the main bivar outputs.
  - Set `fixed` to include `mu_sigma = 1.0`, `sigma_sigma = 0.0`, `eta_sigma = 0.0`,
    `sigma_decay = 0.002` (degenerate σ: agents behave exactly as in the original
    model).
  - Use the original 11 `param_names` from `morris.R` (no σ params varied).
  - Run the Morris binary (r = 15 trajectories) and compute Morris indices using the
    `psi` column (Ψ) as output.
  - Load stage 000/001 Morris results from
    `results/003-centrality-correlation/morris_results.csv` (the archived location
    after the most recent `make archive` run). Compute Spearman rank correlation
    between the μ* vectors.
  - Write `results/recover_bivar_comparison.csv` with columns: parameter,
    mu_star_000, mu_star_006_degen, rank_000, rank_006_degen.
  - Print the Spearman ρ to stdout. A value ≥ 0.95 confirms recoverability.

  **After implementing this task, stop and ask the user to run `make recover-bivar`
  and report back with the console output and the printed Spearman ρ.**
</content>
</invoke>