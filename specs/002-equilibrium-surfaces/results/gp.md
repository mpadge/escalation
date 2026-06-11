# Stage 2 GP Results: Absolute Escalation Surfaces

**Date**: 2026-06-11  
**Design**: Stage 1 LHS data re-used, N=1000 points, p=4 parameters, 20 replicates  
**Parameters**: `alpha`, `gamma`, `lambda`, `eta_obs` (top-4 from Stage 1; beta and theta fixed)  
**Conditions**: E_lo (μ₀=0.4) and E_hi (μ₀=0.6) trained as separate GPs  
**Kernel**: Matérn-5/2, ARD, `nugget.estim = TRUE`, constant trend

## Hyperparameters

### E_lo (μ₀ = 0.4)

| Parameter | ell    | Sensitivity (1/ell) |
|-----------|--------|---------------------|
| `eta_obs` | 0.079  | 12.71               |
| `alpha`   | 0.628  | 1.59                |
| `gamma`   | 2.229  | 0.45                |
| `lambda`  | 6.361  | 0.16                |
| σ²        | 0.0150 | —                   |
| nugget    | 0.0012 | —                   |

### E_hi (μ₀ = 0.6)

| Parameter | ell    | Sensitivity (1/ell) |
|-----------|--------|---------------------|
| `eta_obs` | 0.071  | 14.01               |
| `alpha`   | 1.153  | 0.87                |
| `gamma`   | 2.288  | 0.44                |
| `lambda`  | 7.985  | 0.13                |
| σ²        | 0.0084 | —                   |
| nugget    | 0.0006 | —                   |

## Validation

| Metric          | E_lo   | E_hi   |
|-----------------|--------|--------|
| RMSE            | 0.0338 | 0.0224 |
| Coverage 95%    | 0.98   | 0.96   |

Both GPs validate substantially better than Stage 1 (RMSE 0.134) — a consequence of working with
absolute surfaces rather than the noisier difference quantity Ψ, and of fewer active dimensions (4
vs 6). Coverage slightly exceeds the nominal 0.95, consistent with a well-conditioned nugget.

## Notable observations

**Ranking agreement**: both GPs agree on the ordering eta_obs >> alpha > gamma >> lambda.
This differs from the Stage 1 Ψ-based GP, where alpha ranked first. The reordering makes
sense: the absolute escalation level is primarily set by how strongly agents respond to
what they observe (eta_obs), while Ψ — the difference between conditions — was more
sensitive to alpha because alpha controls how widely observational effects propagate, which
determines whether the two initial conditions diverge.

**alpha is less influential for E_hi than E_lo**: ell_alpha = 0.628 (lo) vs 1.153 (hi).
The hi surface is flatter with respect to alpha — once the population is primed at μ₀=0.6,
the equilibrium escalation level is relatively insensitive to the distance-decay parameter.
The lo surface is more structured.

**lambda is effectively inert in both GPs**: ell_lambda ≈ 6.4–8.0 across both conditions,
sensitivity ≈ 0.13–0.16. Consistent with Stage 1 emulator-based Sobol (S_T=0.265) — lambda's
influence in the direct Sobol (S_T=0.737) was predominantly through interactions with alpha/gamma
that the GP does not attribute to lambda's own length scale.

**E_hi is a smoother, lower-variance surface**: σ² = 0.0084 vs 0.0150 for E_lo. The high-μ₀
population converges to a narrower range of equilibrium outcomes — high initial escalation
dominates, leaving less room for parameter variation to matter.

## Phase diagrams

*(To be appended after `make gp2_phase` — see T002-6)*
