# Sobol Sensitivity Analysis Results

**Date**: 2026-06-10  
**Design**: Saltelli sampling via `sobol2007()`, n = 2000, p = 6 → 26,000 model evaluations  
**Parameters varied**: `alpha`, `dw_obs`, `gamma`, `eta_obs`, `beta`, `w_win` (top 6 from Morris)  
**Binary settings**: N = 200, t_max = 2000, seed = 0 (paired μ₀ ∈ {0.4, 0.6})  
**Estimand**: Ψ = (ε̄(∞)|_{μ₀=0.6} − ε̄(∞)|_{μ₀=0.4}) / 0.2  
**Fixed**: `delta = 0.01`, plus all structural params in `defaults.json`

## Results (ranked by S_T)

| Rank | Parameter | S₁      | S₁ CI   | S_T     | S_T CI  | S_T − S₁ | Interpretation                              |
|------|-----------|---------|---------|---------|---------|-----------|---------------------------------------------|
| 1    | `alpha`   | 0.046   | 0.212   | 0.823   | 0.268   | 0.777     | Locality: dominant via interactions         |
| 2    | `dw_obs`  | 0.123   | 0.218   | 0.785   | 0.258   | 0.661     | Observer edge boost: largest S₁, still low  |
| 3    | `gamma`   | 0.074   | 0.212   | 0.722   | 0.296   | 0.648     | Network exponent: almost purely interactive |
| 4    | `eta_obs` | 0.045   | 0.226   | 0.694   | 0.237   | 0.649     | Observational learning: negligible S₁       |
| 5    | `beta`    | −0.024  | 0.204   | 0.616   | 0.307   | 0.640     | Status advantage: S₁ ≈ 0 (noise)           |
| 6    | `w_win`   | 0.088   | 0.239   | 0.482   | 0.246   | 0.394     | Win payoff: weakest total effect            |

**∑ S₁ ≈ 0.35 · ∑ S_T ≈ 4.12**

## Key findings

### All first-order indices are negligible

Every S₁ value is well within its bootstrap CI (95% CIs span ±0.21–0.31 around estimates of 0.05–0.12). `beta` has a negative point estimate (−0.024), a clear sampling artefact. No parameter drives Ψ additively and independently; individual sweeps cannot characterise the surface.

### Massive interaction structure

∑ S_T ≈ 4.12 ≫ 1. For an additive model ∑ S_T = 1 exactly; the excess (≈ 3.1) is attributable to pairwise and higher-order interactions. The interaction fraction for each parameter (S_T − S₁) exceeds 0.39 for all six, and exceeds 0.64 for the top five.

### Ranking shift versus Morris

Morris ranked `dw_obs` #1 (μ\* = 0.768); Sobol ranks `alpha` #1 by S_T (0.823 vs 0.785). The crossover is consistent with Morris's σ/μ\* ratios (both above 1.0), which already signalled strong nonlinearity. `alpha` is almost entirely an interaction driver (S₁ = 0.046, S_T = 0.823), meaning its effect on Ψ depends critically on the values of the other parameters — especially `dw_obs` and `eta_obs`, which share the same network-diffusion logic.

### Implied interaction structure

The three pairs most likely to carry large S_ij:

| Pair                    | Rationale                                                   |
|-------------------------|-------------------------------------------------------------|
| (`alpha`, `dw_obs`)     | Locality controls reach of observer edge updates            |
| (`alpha`, `eta_obs`)    | Locality gates how many observers update propensity         |
| (`dw_obs`, `eta_obs`)   | Both observational-learning parameters — multiplicative channel |

`w_win` is the most separable parameter (lowest S_T, highest S₁/S_T ratio ≈ 0.18), making it the best candidate for a one-at-a-time sweep independent of the others.

## Decisions for GP emulation (Stage 3)

**All 6 parameters retained** in the GP design. The negligible S₁ values rule out dimension reduction via additive screening; the full interaction surface must be emulated.

**GP input space**: 6-dimensional hypercube, parameter ranges as in Morris design.

**Phase diagram priority** (50×50 grids with remaining 4 parameters at median):
1. `alpha` × `dw_obs` — highest combined S_T (1.61), strong interaction hypothesis
2. `alpha` × `eta_obs` — second-highest combined (1.52)
3. `dw_obs` × `eta_obs` — both observational-learning arms (1.48)
4. `gamma` × `alpha` — network structure × locality (1.55)

**Expected GP behaviour**: the response surface will be non-additive with ridge-like features along the (`alpha`, `dw_obs`) and (`alpha`, `eta_obs`) diagonals. A Matérn-5/2 ARD kernel should capture this; ARD length scales for `w_win` are expected to be longest (least sensitive dimension), confirming it as the safest fixed point if further reduction is needed.
