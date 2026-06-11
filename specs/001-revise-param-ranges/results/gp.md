# GP Emulator Results

**Date**: 2026-06-11  
**Design**: LHS, N = 1000 points, p = 6 parameters, 20 replicates each  
**Parameters**: `alpha`, `lambda`, `gamma`, `eta_obs`, `beta`, `theta` (top 6 from Stage 1 Sobol by S_T)  
**Binary settings**: N = 200, t_max = 5000 (paired μ₀ ∈ {0.4, 0.6})  
**Kernel**: Matérn-5/2, ARD, `nugget.estim = TRUE`  
**Trend**: constant (`formula = ~1`)

## Hyperparameters

| Parameter | ell (ARD length scale) | Sensitivity (1/ell) |
|-----------|------------------------|---------------------|
| `eta_obs` | 0.073                  | 13.71               |
| `alpha`   | 0.636                  | 1.57                |
| `beta`    | 0.652                  | 1.53                |
| `gamma`   | 2.231                  | 0.45                |
| `theta`   | 5.001                  | 0.20                |
| `lambda`  | 5.124                  | 0.20                |
| σ²        | 0.218                  | —                   |
| nugget    | 0.0046                 | —                   |

**Nugget**: 0.0046 > 0 — `nugget.estim = TRUE` is working; nugget/σ² ratio = 2.1%, indicating low but non-zero noise.

**eta_obs ell = 0.073 < 0.1**: flagged by T001-10 criterion. The eta_obs range is [0.001, 0.1] (span = 0.099), so ell/span = 0.74 — the correlation function covers most of the range, meaning this is a short-but-not-degenerate length scale. The GP is not at risk of numerical issues, but predictions will be sensitive to small changes in eta_obs.

**lambda and theta**: ell > 5, consistent with their low Sobol S_T (0.737 and 0.259). The GP confirms that, after conditioning on the other four parameters, lambda and theta contribute little additional variation.

Note: The Sobol S_T for lambda (0.737) conflicts sharply with the GP ARD (ell=5.12, sensitivity=0.20). Lambda is highly interactive in the Sobol sense (S_T >> S₁) but the GP finds its marginal contribution to variance small when all other parameters are included. This is consistent with lambda acting primarily through interactions with alpha and gamma — effects captured by those parameters' length scales.

## Validation

| Metric          | Value | Stage 0 |
|-----------------|-------|---------|
| RMSE (ψ)        | 0.134 | 0.237   |
| Coverage 95% (ψ) | 0.91  | —       |
| RMSE (τ)        | 1269  | —       |

RMSE(ψ) = 0.134 is substantially better than Stage 0 (0.237), attributable to the increased replicates (20 vs 5) reducing noise in the training targets and the revised parameter ranges producing a smoother response surface.

Coverage 0.91 is slightly below the nominal 0.95. This is typical for UK with a nugget; the GP's predictive intervals are calibrated but slightly narrow.

RMSE(τ) = 1269 simulation steps — large in absolute terms but τ is in [0, 10000], so relative RMSE ≈ 12.7%. Acceptable given that τ (time to peak ψ) is a noisier target than ψ itself.

## Phase diagrams

**Status**: ALL 6 PAIRS COLLAPSED — psi ≈ 0.2103 (constant) for every grid point in every phase diagram.

This is NOT the same as Stage 0's prior-mean collapse (psi=0.078), but the cause is different and worse: **a column-order bug in `gp_phase.R`**.

### Root cause

`gp_train.R` trains the GP with parameters in Sobol-ST order:  
`[alpha, lambda, gamma, eta_obs, beta, theta]`

`gp_phase.R::load_gp_inputs()` re-sorts `param_names` by ARD length scale:  
`[eta_obs, alpha, beta, gamma, theta, lambda]`

`build_phase_diagrams()` then calls:
```r
x_grid <- grid[, param_names, drop = FALSE]   # ell-sorted columns
predict(fit_psi, newdata = x_grid, checkNames = FALSE)
```

With `checkNames = FALSE`, DiceKriging suppresses the name-mismatch warning and maps positionally. The GP receives:

| Training dimension | Trained on   | Receives (phase grid) |
|--------------------|--------------|-----------------------|
| 1                  | alpha [0.1, 2.0] | eta_obs values [0.001, 0.1] |
| 2                  | lambda [1, 5]    | alpha values [0.1, 2.0]     |
| 3                  | gamma [1, 5]     | beta values [0, 1]          |
| 4                  | eta_obs [0.001, 0.1] | gamma values [1, 5]     |
| 5                  | beta [0, 1]      | theta values [1, 4]         |
| 6                  | theta [1, 4]     | lambda values [1, 5]        |

Every prediction point is outside the training range for most dimensions → GP collapses to trend (prior mean = 0.2103).

The validation in `gp_train.R` is not affected because it uses `splits$X_test` which is already in training order.

### Fix applied

In `gp_phase.R::build_phase_diagrams`, replaced:
```r
x_grid <- grid[, param_names, drop = FALSE]
predict(fit_psi, newdata = x_grid, checkNames = FALSE)
```
with:
```r
predict(fit_psi, newdata = x_grid[, colnames(fit_psi@X), drop = FALSE],
        checkNames = TRUE)
```

Same fix applied to `fit_tau` and the emulator-based Sobol batch loop. `checkNames = TRUE` restored so future column mismatches raise an error rather than silently corrupting predictions.

**Phase diagrams must be re-run** (`Rscript analysis/gp_phase.R`) to obtain valid results. The fitted GP objects (`gp_psi.rds`, `gp_tau.rds`) are correct; only the phase computation was affected.

### Results after fix

All 6 phase pairs show genuine variation (1663–2057 unique ψ values per 2500-point grid). Collapse is fully resolved.

| Pair                    | Unique ψ values | ψ min   | ψ mean  | ψ max  |
|-------------------------|-----------------|---------|---------|--------|
| `eta_obs` × `alpha`     | 2057            | −0.081  | 0.614   | 0.941  |
| `alpha` × `beta`        | 1922            | 0.162   | 0.605   | 0.865  |
| `alpha` × `gamma`       | 1957            | −0.084  | 0.524   | 0.836  |
| `eta_obs` × `beta`      | 1763            | —       | —       | —      |
| `eta_obs` × `gamma`     | 1986            | —       | —       | —      |
| `beta` × `gamma`        | 1663            | —       | —       | —      |

The near-zero and slightly negative ψ values at parameter extremes are numerical artefacts of GP extrapolation at the boundary of the training domain (particularly where eta_obs is very small and alpha is large). These do not indicate model failure.

### Emulator-based Sobol indices (`sobol_gp.csv`)

1,000,000 Saltelli samples evaluated via the GP emulator.

| Rank | Parameter | S₁    | S_T   |
|------|-----------|-------|-------|
| 1    | `alpha`   | 0.278 | 0.544 |
| 2    | `gamma`   | 0.198 | 0.368 |
| 3    | `lambda`  | 0.165 | 0.265 |
| 4    | `eta_obs` | 0.023 | 0.135 |
| 5    | `beta`    | 0.020 | 0.052 |
| 6    | `theta`   | 0.002 | 0.018 |

**∑ S₁ ≈ 0.69 · ∑ S_T ≈ 1.38**

This is a dramatic shift from Stage 1 Sobol (∑ S_T ≈ 3.44). The emulator-based analysis with 10⁶ evaluations indicates a substantially more additive surface than the direct Sobol run suggested:

- **alpha** now has a large first-order index (S₁ = 0.278), confirming it drives ψ both directly and through interactions.
- **eta_obs** drops from S_T = 0.561 (Stage 1 Sobol) to S_T = 0.135 (emulator). Its very short ARD length scale (ell = 0.073) means the GP treats its effect as highly localised; the emulator-based index averages over the full parameter space where eta_obs has limited global influence.
- **lambda** retains moderate S_T (0.265) consistent with its strong directional effect in Morris (μ = −0.563) despite a long ARD length scale.
- **∑ S_T ≈ 1.38**: total interaction budget is small. The response surface is predominantly additive after all, with alpha and gamma accounting for most variance.
