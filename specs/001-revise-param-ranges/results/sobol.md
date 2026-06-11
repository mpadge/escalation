# Sobol Sensitivity Analysis Results

**Date**: 2026-06-11  
**Design**: Saltelli sampling via `sobol2007()`, n = 1000, p = 6 → 14,000 model evaluations  
**Parameters varied**: `alpha`, `lambda`, `gamma`, `eta_obs`, `beta`, `theta` (top 6 from Stage 1 Morris)  
**Binary settings**: N = 150, t_max = 3000, seed = 0 (paired μ₀ ∈ {0.4, 0.6})  
**Estimand**: Ψ = (ε̄(∞)|_{μ₀=0.6} − ε̄(∞)|_{μ₀=0.4}) / 0.2  
**Fixed**: `delta = 0.01`, plus all structural params in `defaults.toml`

## Results (ranked by S_T)

| Rank | Parameter | S₁      | S₁ CI   | S_T     | S_T CI  | S_T − S₁ | Interpretation                                   |
|------|-----------|---------|---------|---------|---------|-----------|--------------------------------------------------|
| 1    | `alpha`   | 0.043   | 0.263   | 0.778   | 0.307   | 0.735     | Locality: dominant, almost entirely interactive  |
| 2    | `lambda`  | 0.098   | 0.253   | 0.737   | 0.266   | 0.639     | Group size: high S_T despite negative μ in Morris |
| 3    | `gamma`   | 0.068   | 0.279   | 0.691   | 0.269   | 0.623     | Network exponent: almost purely interactive      |
| 4    | `eta_obs` | 0.040   | 0.221   | 0.561   | 0.226   | 0.521     | Observational learning rate: negligible S₁       |
| 5    | `beta`    | −0.002  | 0.203   | 0.419   | 0.276   | 0.421     | Status advantage: S₁ ≈ 0 (noise)                |
| 6    | `theta`   | 0.027   | 0.182   | 0.259   | 0.168   | 0.232     | Audience radius: weakest total effect            |

**∑ S₁ ≈ 0.28 · ∑ S_T ≈ 3.44**

## Key findings

### First-order indices remain negligible

Every S₁ is well within its bootstrap CI. As in Stage 0, no parameter drives Ψ
additively. Individual sweeps cannot characterise the surface.

### Interaction structure persists but is weaker

∑ S_T ≈ 3.44 (Stage 0: 4.12). The reduction reflects the narrower parameter set and
revised ranges, but the model remains strongly interactive — the excess over 1.0 (≈ 2.44)
is attributable to pairwise and higher-order interactions.

### Ranking comparison versus Stage 0

| Rank | Stage 0   | S_T (S0) | Stage 1   | S_T (S1) |
|------|-----------|----------|-----------|----------|
| 1    | `alpha`   | 0.823    | `alpha`   | 0.778    |
| 2    | `dw_obs`  | 0.785    | `lambda`  | 0.737    |
| 3    | `gamma`   | 0.722    | `gamma`   | 0.691    |
| 4    | `eta_obs` | 0.694    | `eta_obs` | 0.561    |
| 5    | `beta`    | 0.616    | `beta`    | 0.419    |
| 6    | `w_win`   | 0.482    | `theta`   | 0.259    |

`alpha` retains rank 1 with nearly identical S_T. `dw_obs` and `w_win` are absent from
Stage 1 Sobol (screened out by Morris to ranks 7 and 9). `lambda` enters at rank 2 —
consistent with its strong negative effect on Ψ (μ = −0.563 in Morris); it suppresses
escalation sensitivity as group sizes grow.

### `theta` as the safest fixed point

`theta` (S_T = 0.259, lowest) is the best candidate for fixing if dimensionality
reduction is needed for GP. Its discrete nature (integer 1–4) also makes it awkward
as a continuous GP input.

### Absence of `dw_obs`

`dw_obs` was the Stage 0 S_T rank-2 parameter (S_T = 0.785) but does not appear in
Stage 1 Sobol (screened to Morris rank 7). Its influence on Ψ appears to be mediated
by interaction with `alpha`; when `alpha` and `gamma` occupy more of the variance budget
under their revised ranges, `dw_obs`'s marginal effect shrinks below the top-6 cut.
This should be monitored in GP phase diagrams — fixing `dw_obs` at its midpoint (0.1)
may hide meaningful structure.

## Decisions for GP emulation

**Parameters retained**: `alpha`, `lambda`, `gamma`, `eta_obs`, `beta`, `theta` (all 6)

**Parameters to watch**: `dw_obs` is not in the GP design but was prominent in Stage 0;
the GP phase diagrams should be checked for sensitivity to the `dw_obs` fixing assumption.

**Phase diagram priority** (50×50 grids, remaining 4 params at median):
1. `alpha` × `gamma` — highest combined S_T (1.47), network structure × locality
2. `alpha` × `lambda` — combined S_T (1.52), locality × group-size suppression
3. `alpha` × `eta_obs` — combined S_T (1.34), locality gates observational learning
4. `lambda` × `gamma` — both structural network parameters (1.43)

**Expected GP behaviour**: ridge-like features along the `alpha` × `lambda` diagonal
(opposing directional effects), with Matérn-5/2 ARD likely assigning short length scales
to `alpha` and `lambda`, and the longest scale to `theta`.
