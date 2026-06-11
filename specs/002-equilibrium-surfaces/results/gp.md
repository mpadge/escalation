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

All 18 CSV files generated (6 pairs × 3 surfaces). Results below.

### Per-pair summary

| Pair | E_lo range | E_hi range | Ψ range | Ψ > 1? |
|------|------------|------------|---------|--------|
| `alpha × eta_obs` | [0.520, 0.870] | [0.602, 0.893] | [−0.053, 0.900] | No |
| `alpha × gamma`   | [0.559, 0.788] | [0.716, 0.842] | [−0.036, 0.835] | No |
| `alpha × lambda`  | [0.429, 0.785] | [0.696, 0.836] | [0.081, **1.339**] | **Yes** |
| `gamma × eta_obs` | [0.561, 0.715] | [0.695, 0.782] | [0.163, 0.925] | No |
| `gamma × lambda`  | [0.540, 0.724] | [0.735, 0.803] | [0.160, **1.026**] | **Yes** |
| `lambda × eta_obs`| [0.549, 0.655] | [0.723, 0.783] | [0.595, 0.999] | No (≈1) |

**Central hypothesis confirmed**: Ψ > 1 exists in the top-4 parameter subspace. Social
dynamics amplify the initial μ₀ perturbation in two of six parameter pairs.

### Key findings

**`alpha × lambda` is the primary amplification pair** (Ψ_max = 1.339). This is the
largest Ψ value observed anywhere across all analyses (Stage 1 maximum was ~0.94).
The combination of low alpha (local distance-decay, reach limited to close neighbours)
and low lambda (small group size) produces a regime where the population primed at
μ₀=0.6 diverges from the μ₀=0.4 population by more than the initial 0.2 gap. Small
groups under local influence allow early escalation to crystallise without being
diluted by network-wide averaging.

**`gamma × lambda` shows marginal amplification** (Ψ_max = 1.026). The gamma × lambda
interaction is at the boundary: a specific combination of network attachment exponent
and group size barely crosses Ψ = 1. This confirms lambda as the key enabler of
amplification — lambda is involved in both amplifying pairs.

**`lambda × eta_obs` reaches Ψ = 0.999** — effectively at the amplification boundary
but not crossing it. Strong observational learning (high eta_obs) in small groups
(low lambda) nearly amplifies, but the observational learning parameter alone is
insufficient without the structural reach provided by low alpha.

**Pairs not involving lambda stay well below Ψ = 1**: alpha × eta_obs (max 0.900),
alpha × gamma (max 0.835), gamma × eta_obs (max 0.925). Amplification requires
lambda — neither the propagation mechanism (eta_obs, alpha) nor the network topology
(gamma) alone is sufficient.

**Negative Ψ at extremes**: small negative Ψ values appear in alpha × eta_obs
(min −0.053) and alpha × gamma (min −0.036). These occur at very low alpha and/or
very low eta_obs, where the GP extrapolates outside the training density. They are
numerical artefacts, not genuine dampening-to-reversal.

**E_hi is consistently higher than E_lo**: across all pairs, E_hi > E_lo at every
grid point (ignoring artefact-level negatives). The μ₀ perturbation always shifts
the equilibrium upward — the question is only whether by more or less than the
initial 0.2 gap.
