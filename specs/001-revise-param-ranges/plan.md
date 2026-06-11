---
created: 2026-06-11T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 0b12a019a66c1961762f1e04a27c63437f4b6d5a
---

# Plan: revise-param-ranges

## Overview
Second iteration sensitivity analysis with revised parameter ranges and improved GP fitting,
informed by boundary-slope and quintile analysis of the Stage 1 LHS output (1,000 design
points, 5 replicates each).

## Context
Stage 0 (`000-initial-build`) completed a full three-stage pipeline:

- **Morris OAT screening** (11 parameters) identified six parameters that matter and
  confirmed `delta` (edge decay) suppresses Ψ monotonically — fixed for all subsequent
  analyses.
- **Sobol variance decomposition** (26k runs) found no parameter acts independently;
  `alpha` (distance decay) leads total-effect indices, followed by `dw_obs` and `eta_obs`.
  All pairwise interactions are high — sum of total-effect indices ≈ 4×.
- **GP emulation** (DiceKriging Matérn-5/2, 1000 LHS points, 5 replicates) trained on
  `gp_data.csv`. The GP-based Sobol ranking diverged from the direct Sobol result because
  three of the six phase diagrams collapsed to the GP prior mean (psi=0.0783, sd=0.000):
  very short ARD length scales (`eta_obs` ℓ=0.074, `dw_obs` ℓ=0.089) mean phase grid
  points that fix non-focal parameters at medians are out-of-sample in 6D space. The
  GP-Sobol ranking is therefore an artefact; the direct Sobol result stands.

Post-hoc boundary-slope analysis of `gp_data.csv` revealed three parameters whose
current ranges are poorly calibrated (see **Proposed Approach**).

## Design Goals
- Recalibrate parameter ranges so that the response surface peaks and
  transitions are well-interior to the sampled region, not at or near boundaries.
- Eliminate the degenerate GP collapse by using `nugget.estim = TRUE` instead of
  supplying `noise.var`, so the nugget absorbs observation noise rather than
  forcing zero process variance.
- Increase replicates per design point from 5 to 20 to obtain reliable per-point
  noise variance estimates and prevent nugget collapse.
- Re-run the full pipeline (Morris → Sobol → GP) with the new ranges and confirm
  whether the direct Sobol ranking is stable across iterations.

## Proposed Approach

### Revised parameter ranges

| Parameter | Stage 0 range | Stage 1 range | Reason for change |
|-----------|--------------|--------------|-------------------|
| `gamma`   | [2.0, 4.0]   | [1.0, 5.0]   | Slope at lower boundary = +2.10; peak at 3.25; function still rising at γ=2. BA exponent γ=1 is standard and should be included. Extend both ends. |
| `beta`    | [0.0, 3.0]   | [0.0, 1.0]   | Response nearly flat across [0, 3] (peak Ψ=0.657, min=0.494; slope at lower boundary = 0.00). Upper half of range is uninformative dead weight. Narrow sharply. |
| `w_win`   | [0.1, 2.0]   | [0.0, 2.0]   | Peak at 0.34 with slope +0.50 at lower boundary. Function likely rises further near zero win payoff. Extend lower bound to 0. |
| `dw_obs`  | [0.0, 0.2]   | [0.0, 0.2]   | Peak at 0.165, slope −1.3 at upper boundary. Range captures full arc from zero to post-peak. **No change.** |
| `eta_obs` | [0.001, 0.1] | [0.001, 0.1] | Peak at 0.018; lower bound of 0.001 already near the physical zero. Slope at lower boundary is steep (+30.9) but the peak is within range. **No change.** |
| `alpha`   | [0.1, 2.0]   | [0.1, 2.0]   | Peak at ~0.7–1.0, well-centred; boundary slopes low (±2.2, ±0.2). **No change.** |

All other parameters (`lambda`, `theta`, `b`, `w_loss`, `dw_bridge`) remain fixed at
their Stage 0 values — Morris screening showed negligible influence, and Sobol confirmed
near-zero total-effect indices for these.

### GP fitting changes
- Replace `noise.var = noise_var_train` with `nugget.estim = TRUE` in the `km()` call
  for `fit_psi` in `analysis/gp_train.R`. The per-point `psi_sd` values from 5 replicates
  are noisy (many are 0 from tied replicates); supplying them as fixed noise variance
  destabilises the likelihood optimisation and causes the nugget to collapse to zero,
  making the GP overconfident and susceptible to collapsing to the prior mean in phase
  diagrams.
- Increase `n_rep` from 5 to 20 in `defaults.json` (key `n_rep_gp`). This gives reliable
  per-point `psi_sd` estimates; the 20-replicate noise variance can then also be supplied
  as `noise.var` as a cross-check once the nugget-estimation run confirms stability.
- Keep `N_LHS = 1000` — the training set size is adequate; the GP degeneracy was caused
  by the fitting strategy, not insufficient data.

### Pipeline execution order (unchanged)
1. `analysis/morris.R` — screening with revised ranges
2. `analysis/sobol.R` — variance decomposition
3. `analysis/gp_train.R` — GP fitting with `nugget.estim = TRUE`, 20 replicates
4. `analysis/gp_phase.R` — phase diagrams and emulator-based Sobol
5. `analysis/plot.R` — all plots

## Open Questions
- Whether `eta_obs` lower bound should be extended further below 0.001. The steep slope
  (+30.9) at the lower boundary implies a sharp transition just above zero; it is not
  clear whether this is a near-zero singularity or a genuine interior peak. A targeted
  one-dimensional sweep of `eta_obs` over [0.0001, 0.005] would clarify this before
  committing to a wider range for the full LHS.
- Whether `nugget.estim = TRUE` alone is sufficient to prevent GP collapse, or whether
  the LHS design itself should be augmented with space-filling criteria that improve
  coverage in the corners where `eta_obs` and `dw_obs` interact.
- Whether the direct Sobol ranking (`alpha` first) is robust to the range changes —
  narrowing `beta` and shifting `gamma` downward could redistribute total-effect indices.
