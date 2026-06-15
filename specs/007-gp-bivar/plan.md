---
created: 2026-06-15T21:30:00Z
agent: claude-sonnet-4-6
git_hash: 4833b2d012b588bfa3bffe8ec8c3f4e46983b87e
---

# Plan: gp-bivar

## Overview

Train Gaussian process emulators for both bivariate estimands — `psi_sigma`
(sensitivity of ε̄(∞) to μ_σ perturbation) and `psi` (μ₀ sensitivity with σ
active) — and generate 2D phase diagrams across three axis pairs that connect
the σ-trait space to the Stage 002/003 network-structure findings. This is the
final emulation stage for the bivariate (ε, σ) model introduced in Stage 005.

## Context

Stage 006 completed Morris OAT screening and Sobol variance decomposition for
the bivariate model. The Sobol result for `psi_sigma` is qualitatively
distinctive: S1 ≈ 0 and ST ≈ 0.86–1.03 for all six screened parameters, meaning
psi_sigma variance is almost entirely interaction-driven with no dominant main
effect. The Morris μ* ranking does show separation (mu_sigma 0.490, lambda 0.382,
sigma_sigma 0.359, dw_obs 0.354, dw_bridge 0.289, alpha 0.257), but the flat
Sobol ST structure means these six cannot be meaningfully ranked for
dimensionality reduction. All six are therefore used as GP inputs.

For `psi` (with σ active), Morris also ranked alpha first (μ* = 0.636), and the
Ψ surface with σ active should connect directly to Stage 002/003 phase diagrams
(where alpha and lambda were the dominant axes). Stage 007 enables that
comparison by emulating psi on the same 6D bivariate design.

The GP infrastructure (DiceKriging, Matérn-5/2, ARD, nugget.estim=TRUE,
n_lhs=1000 design points, n_rep_gp=20 replicates) was validated in Stage 001
and has been used unchanged through Stages 002 and 003. The `cmd_gp_train`
Rust subcommand handles LHS training runs with streaming output and resumability.
It currently computes `psi` only; Stage 007 must extend it to also compute
`psi_sigma` via a third simulation per seed.

The recoverability Spearman ρ = 0.78 (Stage 006) has been accepted as sufficient
given the 0.95 threshold was arbitrary. No re-run is planned.

## Design Goals

1. **Extend cmd_gp_train for psi_sigma**: add the sigma-perturbed third simulation
   per seed per design row so that GP training runs emit `psi_sigma` alongside
   `psi` and all other RunSummary fields.

2. **Train GPs for both estimands**: fit one DiceKriging GP per estimand
   (`psi_sigma`, `psi`) on the 6D bivariate LHS design. Single-GP approach
   (train directly on the derived quantity) rather than the two-GP approach used
   for absolute surfaces in Stages 002/003 — the derived quantities are already
   normalised and do not require per-condition decomposition.

3. **Generate phase diagrams for three axis pairs**:
   - **mu_sigma × sigma_sigma** — primary σ-trait space; characterises how the
     mean and dispersion of status sensitivity jointly govern escalation
     amplification
   - **mu_sigma × alpha** — connects σ to Stage 003's finding that influence
     locality (alpha) is the dominant driver of individual concentration; tests
     whether high σ amplifies or suppresses the alpha effect
   - **mu_sigma × lambda** — connects σ to Stage 002's finding that small groups
     (lambda) enable population-level amplification; tests whether σ and group
     size interact

4. **Plot both estimands per axis pair**: each axis pair produces two phase
   panels (psi_sigma and psi), enabling direct visual comparison of how the
   σ-control variable changes the μ₀ sensitivity surface.

## Proposed Approach

### Rust: extend cmd_gp_train (src/main.rs)

Call `run_sigma_paired` with a single-element design slice and the full seeds
slice for each design row, replacing the current inline lo/hi sim loop. This
gives psi_sigma for free from the existing experiment infrastructure, and the
streaming/resumability logic is otherwise unchanged (one progress file per
(design_row, seed) triple, same `.done` counting logic in `make progress`).

### R: gp_train_bivar.R (analysis/)

LHS design over the 6 bivariate Sobol params (sigma_sigma, mu_sigma, lambda,
dw_bridge, alpha, dw_obs) using defaults.toml ranges. Fixed params include
eta_obs at mid_eta_obs (same as Morris/Sobol-bivar). Output:
`results/design_gp_bivar.csv` (LHS design) and `results/gp_bivar_train.csv`
(aggregated training data, 1000 × 20 replicates = 20,000 RunSummary rows).
Makefile target: `gp-train-bivar` (depends on `release`).

Stop after this task and ask the user to run `make gp-train-bivar`.

### R: gp_phase_bivar.R (analysis/)

Reads `results/gp_bivar_train.csv`. For each estimand (psi_sigma, psi):
1. Aggregate replicates per design point to mean response
2. Train a DiceKriging GP (Matérn-5/2 kernel, ARD length scales, nugget.estim=TRUE)
3. For each of the three axis pairs, predict on a 50×50 grid with non-focal
   params fixed at their midpoints from defaults.toml
4. Write phase CSVs to `results/gp_bivar_phase/`

Uses the `_bivar` suffix convention for internal helpers. Sources
`analysis/gp_train_utils.R` and `analysis/gp_phase_utils.R` where applicable.
Makefile target: `gp-phase-bivar` (depends on `release`).

Stop after this task and ask the user to run `make gp-phase-bivar`.

### R: plot_bivar.R (analysis/)

Reads `results/gp_bivar_phase/` CSVs. For each axis pair, produces a two-panel
plot (psi_sigma | psi) using `analysis/plot_utils.R` diverging palette (positive
= amplification, zero = no sensitivity, negative = suppression). For the
mu_sigma × alpha and mu_sigma × lambda panels, overlays a reference contour from
the archived Stage 002/003 psi surface (read from
`results/003-centrality-correlation/`) to show how activating σ shifts the Ψ=1
amplification boundary. Outputs: `results/plots/gp_bivar_{axis_pair}.png`.
Makefile target: `plots-bivar`.

### Output files

```
results/
  design_gp_bivar.csv            # 1000-point LHS over 6 bivariate params
  gp_bivar_train.csv             # GP training data (psi_sigma + psi per row)
  gp_bivar_phase/
    phase_psi_sigma_mu_sigma_sigma_sigma.csv
    phase_psi_sigma_mu_sigma_alpha.csv
    phase_psi_sigma_mu_sigma_lambda.csv
    phase_psi_mu_sigma_sigma_sigma.csv
    phase_psi_mu_sigma_alpha.csv
    phase_psi_mu_sigma_lambda.csv
results/plots/
  gp_bivar_mu_sigma_sigma_sigma.png   # psi_sigma | psi panels
  gp_bivar_mu_sigma_alpha.png
  gp_bivar_mu_sigma_lambda.png
```

## Open Questions

1. **GP convergence with interaction-dominated surface**: with S1 ≈ 0 and strong
   interaction structure, the psi_sigma GP surface may not be well-approximated
   by a stationary Matérn kernel. If training RMSE or leave-one-out CV is poor,
   a non-stationary kernel or increased n_lhs may be needed.

2. **Non-focal param choice for phase slices**: all non-focal params are fixed at
   defaults.toml midpoints. The psi_sigma surface may be sensitive to which
   midpoints are chosen (given the interaction dominance). A robustness check
   (vary one non-focal param while holding the axis pair fixed) is a possible
   Stage 008 item if the phase diagrams show unexpected structure.

3. **Comparison with Stage 002/003**: the archived stage psi surfaces were trained
   on the 11-param univariate model. The Stage 007 psi surface uses 6 params
   (different screening result). The mu_sigma × alpha and mu_sigma × lambda
   overlays compare across different GP input spaces; the comparison is
   informative but not apples-to-apples.
