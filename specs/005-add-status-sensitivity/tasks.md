---
created: 2026-06-15T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 4df8f2074be07a80f4d5a46abc9bf729137d3e90
---

# Tasks: add-status-sensitivity

## T005-1: Add mu_sigma, sigma_sigma, eta_sigma to Params

- [x] T005-1: In `src/params.rs`, add three new fields: `mu_sigma: f64` (initial mean status
  sensitivity, default 1.0), `sigma_sigma: f64` (initial SD, default 0.2), and
  `eta_sigma: f64` (σ learning rate, default 0.05). Update `Params::default()` accordingly.
  Do NOT remove `eta_obs` or `dw_obs` — they are kept as global reference scales.
  Note: `mu_sigma` default of 1.0 ensures the model degenerates to original behaviour
  out of the box.

## T005-2: Add sigma field to SimState and initialise it

- [x] T005-2: In `src/sim.rs`, add `pub sigma: Vec<f64>` to `SimState`. In the simulation
  initialisation block (where `epsilon` is sampled), add an independent sample of `sigma`
  from `clip(Normal(params.mu_sigma, params.sigma_sigma), 0.0, 1.0)` using the same RNG.
  Update all `SimState` struct literals in the file (including `#[cfg(test)]` blocks) to
  include `sigma: vec![1.0; n]` — the value 1.0 preserves original behaviour in tests that
  do not exercise σ dynamics.

## T005-3: Scale prestige radiation by sigma_w * sigma_k

- [x] T005-3: In `src/sim.rs`, find all prestige radiation edge updates applied to observers
  of a winner `w`. These currently read `omega_w * params.dw_obs * ...` (two variants: one
  for in-group observers without the distance decay, one for non-group observers with
  `exp(-alpha * wd_kw)`). Multiply both by `state.sigma[w as usize] * state.sigma[k as usize]`
  so the full update becomes `omega_w * params.dw_obs * state.sigma[w] * state.sigma[k] * ...`.
  Apply the same substitution to the loser-devaluation observer update (the `decay_kl` line).
  `dw_obs` is retained as the global scale; the σ product is the per-interaction multiplier.

## T005-4: Scale observer propensity update by sigma_k

- [ ] T005-4: In `src/sim.rs`, find both locations where observer propensity updates use
  `params.eta_obs`:
  (a) Inside `update_propensities` for group members: `params.eta * r[idx] + params.eta_obs * o[idx]`
  — change to `params.eta * r[idx] + params.eta_obs * state.sigma[i as usize] * o[idx]`.
  (b) Inside the observer update loop for non-participants: `params.eta_obs * o_k * weight`
  — change to `params.eta_obs * state.sigma[k as usize] * o_k * weight`.
  `eta_obs` is retained as the global scale; σ_k multiplies it per-agent.

## T005-5: Implement sigma update rule for non-participant observers

- [ ] T005-5: In `src/sim.rs`, extend the observer update function (the loop over
  non-participant witnesses `k ∈ O \ G`) to also update σ_k. Before the timestep's payoff
  resolution begins, snapshot `payoff_before_k = state.payoff[k]` for each observer `k`
  (this requires either passing a pre-snapshot slice into the function, or capturing it
  before the regime handler runs). After all payoffs for the timestep are resolved, for each
  observer `k` compute:
  `delta_sigma = params.eta_sigma * (state.payoff[k] - payoff_before_k).signum()`
  and apply `state.sigma[k] = (state.sigma[k] + delta_sigma).clamp(0.0, 1.0)`.
  Group members (participants) do not receive σ updates — the signal is specifically about
  whether *observing* status interactions was profitable.

## T005-6: Add mean_sigma and epsilon_sigma_corr to MetricSeries

- [ ] T005-6: In `src/sim.rs`, add fields `mean_sigma: Vec<f64>` and
  `epsilon_sigma_corr: Vec<f64>` to `MetricSeries`, with matching initialisations in the
  `MetricSeries` constructor. In the metrics recording block (the `if t % RECORD_INTERVAL == 0`
  branch), compute `mean_sigma` as the arithmetic mean of `state.sigma`, and
  `epsilon_sigma_corr` as the Pearson correlation between `state.epsilon` and `state.sigma`
  using the existing `pearson_corr` helper. Push both into the series each recording step.

## T005-7: Add sigma summary fields to RunSummary, aggregate, and CSV output

- [ ] T005-7: In `src/aggregate.rs`, add four fields to `RunSummary`:
  `mean_sigma_final: f64`, `var_sigma_final: f64`, `epsilon_sigma_corr_final: f64`, and
  `psi_sigma: Option<f64>` (sensitivity of ε̄(∞) to μ_σ perturbation, populated by paired
  runs, analogous to `psi`). In `aggregate()`, compute the first three from the tail of the
  new `MetricSeries` fields using the existing `tail_mean` helper; set `psi_sigma: None`.
  In `src/output.rs`, add the four new fields to the CSV serialisation so they appear in
  output files.

## T005-8: Validation — exact degenerate-sigma recovery

- [ ] T005-8: In `src/sim.rs` `#[cfg(test)]` block, add a test
  `test_degenerate_sigma_matches_original`. Run two simulations with identical seeds and
  identical `Params`, differing only in that the first uses the default new params
  (`mu_sigma = 1.0, sigma_sigma = 0.0, eta_sigma = 0.0`) and the second is a reference run
  that never touches σ at all (achieved by confirming σ_i = 1.0 throughout). Assert that
  `mean_epsilon_final` from both runs is numerically identical (within f64 rounding tolerance,
  e.g. `approx::assert_abs_diff_eq!(..., epsilon = 1e-12)`). This is an exact equality test:
  `mu_sigma = 1.0` with no σ evolution must reproduce the original model bit-for-bit.

## T005-9: Validation — sigma distribution does not collapse

- [ ] T005-9: In `src/sim.rs` `#[cfg(test)]` block, add a test
  `test_sigma_distribution_stays_open`. Run a simulation with `mu_sigma = 0.5`,
  `sigma_sigma = 0.2`, `eta_sigma = 0.05`, N = 100, T = 5000 steps. After the run, assert:
  (a) the standard deviation of `state.sigma` exceeds 0.05 (distribution has not collapsed),
  (b) the mean of `state.sigma` is in (0.0, 1.0) exclusive,
  (c) at least one agent has σ > 0.1 and at least one has σ < 0.9 (not all at a boundary).

## T005-10: Validation — epsilon-sigma correlation emerges positive

- [ ] T005-10: In `src/sim.rs` `#[cfg(test)]` block, add a test
  `test_epsilon_sigma_corr_emerges`. Run a simulation with `mu0 = 0.5`, `mu_sigma = 0.5`,
  `sigma_sigma = 0.2`, `eta_sigma = 0.05`, N = 200, T = 10000 steps. Assert that the final
  value of `epsilon_sigma_corr` in the `MetricSeries` is positive (> 0.0). This checks that
  the endogenous positive correlation between escalation propensity and status sensitivity
  emerges even though the two traits are initialised independently.
