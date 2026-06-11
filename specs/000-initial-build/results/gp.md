# GP Emulation Results

**Date**: 2026-06-11  
**Design**: LHS via `lhs::maximinLHS(n=1000, k=6)`, R=5 replicates per point  
**Parameters varied**: `alpha`, `dw_obs`, `gamma`, `eta_obs`, `beta`, `w_win` (top 6 from Sobol)  
**Binary settings**: N = 200, t_max = 2000 (paired μ₀ ∈ {0.4, 0.6})  
**Estimand**: Ψ = (ε̄(∞)|_{μ₀=0.6} − ε̄(∞)|_{μ₀=0.4}) / 0.2  
**Fixed**: `delta = 0.01`, plus all structural params in `defaults.json`  
**Kernel**: Matérn-5/2 ARD, heteroscedastic noise (`noise.var = psi_sd²`), fitted via `DiceKriging::km()`  
**Split**: 800 train / 200 test (stratified by `psi_mean` quintile)

## Response surface summary

Ψ range across 1000 LHS points: [−0.211, 2.075], mean = 0.565, SD = 0.378.  
τ_Ψ (convergence time) range: [800, 10000], mean = 7364 — heavily right-skewed.

## Validation on hold-out (n=200)

| Metric             | Value  | Notes                                      |
|--------------------|--------|--------------------------------------------|
| RMSE(Ψ)            | 0.237  | ≈ 0.63 SD of Ψ — moderate fit             |
| RMSE(τ_Ψ)         | 1608   | ≈ 22% of τ range; τ surface is rough       |
| 95% PI coverage(Ψ) | 0.595  | Below nominal 0.95 — GP is overconfident   |

**Coverage note**: The 0.595 empirical coverage against a nominal 0.95 indicates
the predictive intervals are too narrow. The most likely cause is that the
heteroscedastic `noise.var` (estimated from R=5 replicates) underestimates the true
run-to-run variance at many design points — a small replicate sample can produce
spuriously tight clustering. The GP then over-trusts those points and shrinks its
posterior uncertainty. The τ_Ψ GP is similarly affected. Point predictions
(RMSE) are usable; interval-based inference should be treated with caution.

## ARD length scales (Matérn-5/2 fit on Ψ)

| Rank | Parameter | ℓ_d    | 1/ℓ_d  | Interpretation                                |
|------|-----------|--------|--------|-----------------------------------------------|
| 1    | `eta_obs` | 0.0742 | 13.47  | Shortest: Ψ varies sharply along this axis    |
| 2    | `dw_obs`  | 0.0891 | 11.23  | Almost as sharp                               |
| 3    | `alpha`   | 0.769  | 1.30   | Moderate — locality still influential         |
| 4    | `w_win`   | 1.637  | 0.611  | Smooth variation across range                 |
| 5    | `gamma`   | 3.999  | 0.250  | Near-flat in GP metric                        |
| 6    | `beta`    | 5.994  | 0.167  | Longest: slowest-varying dimension            |

GP output variance σ² = 0.0866; nugget = 0.0866 (equal to σ² — suggests the
optimizer partitioned variance equally between signal and nugget, consistent with
moderate RMSE and the noisy replicate estimates feeding `noise.var`).

## Emulator-based Sobol indices (n=10⁶ Saltelli samples, SK prediction)

| Rank | Parameter | S₁      | S_T     | S_T − S₁ | Interpretation                              |
|------|-----------|---------|---------|-----------|---------------------------------------------|
| 1    | `w_win`   | 0.0867  | 0.9494  | 0.863     | Regime gatekeeper: mostly through interactions |
| 2    | `beta`    | 0.0345  | 0.6899  | 0.655     | Status advantage: almost entirely interactive |
| 3    | `dw_obs`  | 0.0064  | 0.2103  | 0.204     | Observer edge boost: small S₁, wider reach  |
| 4    | `alpha`   | 0.0030  | 0.1075  | 0.105     | Locality: consistent with Sobol ST rank #1  |
| 5    | `eta_obs` | 0.0011  | 0.0114  | 0.010     | Observational rate: negligible global effect |
| 6    | `gamma`   | 0.0006  | 0.0092  | 0.009     | Network exponent: negligible at GP scale    |

∑ S₁ ≈ 0.13 · ∑ S_T ≈ 1.97

## Key findings

### ARD ranking ≠ GP-Sobol ranking — and why that is expected

ARD length scales measure the local rate of change of Ψ in each input dimension.
`eta_obs` (ℓ=0.074) and `dw_obs` (ℓ=0.089) have the sharpest local gradients.
But the GP-Sobol places `w_win` (ℓ=1.637) and `beta` (ℓ=5.994) at the top of
the global variance decomposition.

The reconciliation: `w_win` and `beta` have large parameter ranges ([0.1,2.0]
and [0.0,3.0]) relative to `eta_obs` ([0.001,0.1]) and `dw_obs` ([0.0,0.2]).
Even with smooth variation (long ℓ), a parameter that sweeps through multiple
behavioural regimes over a wide range can dominate the global variance.
`eta_obs` and `dw_obs` produce sharp transitions locally but those transitions
are confined to a narrow part of the input hypercube; most Saltelli samples land
away from their sensitive region.

Concretely: `w_win` sets the tournament reward magnitude — at low values the
model is near-neutral, at high values dominant escalation is self-reinforcing.
This threshold behaviour accounts for its S_T ≈ 0.95 despite a smooth GP fit.

### Interaction structure

∑ S_T ≈ 1.97 implies pairwise interactions carry roughly 0.97 units of variance
(for p=6 this is moderate — the Sobol run showed ∑ S_T ≈ 4.12, so the GP
emulator has compressed some higher-order structure). The highest-interaction
parameters are `w_win` (S_T − S₁ = 0.863) and `beta` (0.655). The most likely
interacting pairs, given the mechanism:

| Pair                  | Rationale                                                     |
|-----------------------|---------------------------------------------------------------|
| (`w_win`, `beta`)     | Payoff magnitude × status-bias: jointly set tournament stakes |
| (`w_win`, `dw_obs`)   | Win reward × observer edge update: prestige diffusion channel |
| (`beta`, `alpha`)     | Status advantage × locality: hierarchy steepness × reach     |

`eta_obs` and `gamma` are negligible at this scale (S_T < 0.012); they can be
safely fixed for phase diagram purposes.

### Consistency with prior stages

| Parameter | Morris μ\* rank | Sobol S_T rank | GP-ARD rank | GP-Sobol S_T rank |
|-----------|-----------------|----------------|-------------|-------------------|
| `dw_obs`  | 1               | 2              | 2           | 3                 |
| `eta_obs` | 2               | 4              | 1           | 5                 |
| `alpha`   | 3               | 1              | 3           | 4                 |
| `gamma`   | 4               | 3              | 5           | 6                 |
| `beta`    | 5               | 5              | 6           | 2                 |
| `w_win`   | 6               | 6              | 4           | 1                 |

`w_win` rises from rank 6 (Morris, Sobol) to rank 1 (GP-Sobol). This is
plausible: Morris uses ±Δ perturbations around a base point (rank 6 there means
it is not influential near the Morris base), while the GP-Sobol integrates over
the full hypercube including the regime transition. `beta` shows a similar rise.

## Phase diagrams produced

All grids are 50×50 with the remaining 4 parameters held at their training
medians (`eta_obs`=0.051, `dw_obs`=0.100, `alpha`=1.05, `w_win`=1.05,
`gamma`=3.00, `beta`=1.50).

| File                            | Axes                    |
|---------------------------------|-------------------------|
| `phase_eta_obs_vs_dw_obs.csv`   | `eta_obs` × `dw_obs`    |
| `phase_eta_obs_vs_alpha.csv`    | `eta_obs` × `alpha`     |
| `phase_eta_obs_vs_w_win.csv`    | `eta_obs` × `w_win`     |
| `phase_dw_obs_vs_alpha.csv`     | `dw_obs` × `alpha`      |
| `phase_dw_obs_vs_w_win.csv`     | `dw_obs` × `w_win`      |
| `phase_alpha_vs_w_win.csv`      | `alpha` × `w_win`       |

Each file contains columns `{p_a}`, `{p_b}`, `psi_mean`, `psi_sd`,
`tau_mean`, `tau_sd`. Corresponding `_tau.csv` files contain the τ_Ψ surface.

## Decisions and caveats

**Coverage is inadequate for calibrated UQ**: the 59.5% empirical PI coverage
means the GP cannot be used for reliable uncertainty quantification. Point
predictions are reasonable (RMSE ≈ 0.63 SD); use the GP for ranking and phase
boundary identification, not for credible intervals.

**Refit recommendation**: if higher-fidelity emulation is needed, increase
replicates per LHS point from R=5 to R=20 to get stable `noise.var` estimates,
or switch to `nugget.estim = TRUE` with no `noise.var` to let the model learn
homoscedastic observation error.

**Parameters that can be fixed for targeted sweeps**:
`eta_obs` (S_T=0.011) and `gamma` (S_T=0.009) are negligible in GP-Sobol;
fixing them at medians introduces negligible variance in Ψ.

**Priority pair for follow-up**: (`w_win`, `beta`) — highest combined S_T
(1.64) and the clearest mechanistic interpretation (payoff magnitude × status
advantage jointly determine tournament outcome distribution).
