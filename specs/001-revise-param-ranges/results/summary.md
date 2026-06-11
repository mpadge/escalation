# Stage 1 Results Summary: Revise Parameter Ranges

**Stage**: 001-revise-param-ranges  
**Date**: 2026-06-11  
**Status**: GP training and phase diagrams complete; plots pending (T001-12)

## What changed from Stage 0

Three parameter ranges were revised:

| Parameter | Stage 0       | Stage 1       | Rationale                              |
|-----------|---------------|---------------|----------------------------------------|
| `gamma`   | [2.0, 4.0]    | [1.0, 5.0]    | Wider: prior literature allows 1–5     |
| `beta`    | [0.0, 3.0]    | [0.0, 1.0]    | Narrower: values > 1 are unrealistic   |
| `w_win`   | [0.1, 2.0]    | [0.0, 2.0]    | Allow zero payoff as boundary case     |

All other ranges, fixed structural parameters, and analysis settings were inherited from Stage 0, except:
- `n_rep_gp` increased from 5 → 20 replicates per GP design point
- GP kernel: `noise.var` replaced with `nugget.estim = TRUE` (Stage 0 had fixed noise)
- `t_max_gp` = 5000 (vs Stage 0 value)

---

## Morris screening

Full results in `specs/001-revise-param-ranges/results/morris.md`.

The ranking shifted substantially compared to Stage 0:

| Rank | Stage 0   | μ\* (S0) | Stage 1   | μ\* (S1) |
|------|-----------|----------|-----------|----------|
| 1    | `dw_obs`  | 0.768    | `alpha`   | 0.736    |
| 2    | `eta_obs` | 0.742    | `gamma`   | 0.657    |
| 3    | `alpha`   | 0.605    | `lambda`  | 0.596    |
| 4    | `gamma`   | 0.576    | `eta_obs` | 0.450    |
| 5    | `beta`    | 0.540    | `beta`    | 0.434    |
| 6    | `w_win`   | 0.505    | `theta`   | 0.344    |
| 7    | `dw_bridge` | 0.448  | `dw_obs`  | 0.333    |

**`dw_obs` falls from rank 1 → 7.** This is the largest qualitative change: the observer edge boost, which dominated Stage 0, is substantially displaced when `gamma`'s range is widened. The effect is not from `dw_obs`'s own range (unchanged at [0, 0.2]) but from interaction structure — with `gamma` now exploring [1, 5], network topology absorbs more of the variance budget.

**`lambda` rises from rank 8 → 3**, with strong negative directional effect (μ = −0.563). Large groups suppress escalation sensitivity.

Top 6 for Sobol: `alpha`, `gamma`, `lambda`, `eta_obs`, `beta`, `theta`.

---

## Sobol decomposition

Full results in `specs/001-revise-param-ranges/results/sobol.md`.

| Rank | Parameter | S₁    | S_T   |
|------|-----------|-------|-------|
| 1    | `alpha`   | 0.043 | 0.778 |
| 2    | `lambda`  | 0.098 | 0.737 |
| 3    | `gamma`   | 0.068 | 0.691 |
| 4    | `eta_obs` | 0.040 | 0.561 |
| 5    | `beta`    | −0.002 | 0.419 |
| 6    | `theta`   | 0.027 | 0.259 |

∑ S_T ≈ 3.44 — still strongly interactive, but `dw_obs` is absent (Morris rank 7; not selected for Sobol). `alpha` retains the top position by S_T (consistent with Stage 0). Every S₁ remains negligible, confirming the surface cannot be characterised parameter-by-parameter.

**Sobol vs Stage 0**: the ranking of `alpha`, `gamma`, `eta_obs`, `beta` is stable. `lambda` is new at rank 2; `dw_obs` and `w_win` drop out of the Sobol design entirely.

---

## GP emulation

Full results in `specs/001-revise-param-ranges/results/gp.md`.

### Hyperparameters

| Parameter | ell   | Sensitivity |
|-----------|-------|-------------|
| `eta_obs` | 0.073 | 13.7        |
| `alpha`   | 0.636 | 1.57        |
| `beta`    | 0.652 | 1.53        |
| `gamma`   | 2.231 | 0.45        |
| `theta`   | 5.001 | 0.20        |
| `lambda`  | 5.124 | 0.20        |
| σ²        | 0.218 | —           |
| nugget    | 0.005 | —           |

`nugget.estim = TRUE` is confirmed working (nugget > 0). RMSE(ψ) = 0.134 vs Stage 0's 0.237 — a 43% improvement, driven by 4× more replicates and a better-conditioned response surface.

The GP ARD conflicts with Sobol for `lambda` (S_T=0.737 but ell=5.12): lambda acts through interactions with alpha/gamma that the GP absorbs into those parameters' length scales rather than lambda's own.

### Phase diagram collapse — bug found and fixed

The first run of `gp_phase.R` produced constant ψ ≈ 0.210 across all 6 phase pairs. Root cause: `gp_phase.R` re-sorted `param_names` by ARD length scale before calling `predict()`, but DiceKriging maps `newdata` columns positionally. With `checkNames = FALSE`, the mismatch was silent — every prediction point landed outside the training range in all six dimensions.

Fix: use `colnames(fit_psi@X)` to restore training column order before prediction; switched to `checkNames = TRUE` to catch this class of error in future.

### Phase diagram results (after fix)

All 6 pairs show genuine variation (1663–2057 unique ψ values per 2500-point 50×50 grid). The collapse seen in Stage 0 (psi=0.078) is fully resolved. Small negative ψ values appear at parameter extremes (eta_obs near zero, alpha near 2.0) and are GP extrapolation artefacts, not model failures.

### Emulator-based Sobol (10⁶ samples)

| Rank | Parameter | S₁    | S_T   |
|------|-----------|-------|-------|
| 1    | `alpha`   | 0.278 | 0.544 |
| 2    | `gamma`   | 0.198 | 0.368 |
| 3    | `lambda`  | 0.165 | 0.265 |
| 4    | `eta_obs` | 0.023 | 0.135 |
| 5    | `beta`    | 0.020 | 0.052 |
| 6    | `theta`   | 0.002 | 0.018 |

∑ S_T ≈ 1.38 — the emulator reveals a **substantially more additive surface** than Stage 1 Sobol (∑ S_T ≈ 3.44). `alpha` now has a large first-order index (S₁ = 0.278). `eta_obs` drops sharply (S_T 0.561 → 0.135) because its very short ARD length scale means its effect is highly localised and averages out over the full Sobol sample.

---

## Qualitative conclusions

**Unchanged from Stage 0:**
- `alpha` (locality) is the dominant driver of ψ sensitivity
- S₁ values are negligible in the direct Sobol run; the surface is strongly non-additive at the intermediate scale
- `beta` and `theta` are consistently low-ranked and could be fixed in future stages

**Changed:**
- `dw_obs` (observer edge boost), Stage 0's top Morris parameter, falls to rank 7 after the range revision — its marginal influence is substantially mediated by `gamma`
- `lambda` (group size) emerges as a high-influence parameter with a strong negative directional effect; it was underestimated in Stage 0
- The emulator-based Sobol at 10⁶ samples indicates a more additive surface (∑ S_T ≈ 1.38) than direct Sobol at 14k evaluations

## Open questions

1. **`eta_obs` lower boundary**: the range [0.001, 0.1] may still be too wide at the lower end; at eta_obs ≈ 0.001 the observational learning mechanism is essentially inactive. A follow-up stage could truncate to [0.01, 0.1] to clarify whether eta_obs has a genuine threshold effect.

2. **`dw_obs` exclusion**: Stage 1 drops `dw_obs` from Sobol and GP because Morris ranks it 7th. But Stage 0 ranked it first; the drop is driven by range interactions, not a confirmed finding that `dw_obs` is unimportant. A sensitivity check fixing `dw_obs` at different values in the GP phase diagrams would test whether its exclusion masks important structure.

3. **`lambda` and `gamma` interaction**: both are structural network parameters with opposing and interacting effects. The emulator-based Sobol assigns them S_T 0.37 and 0.27 respectively. A targeted phase diagram at higher resolution for the `lambda × gamma` pair would clarify whether there is a critical group-size / attachment-exponent boundary.

4. **Third stage needed?**: the revised ranges shifted the ranking qualitatively (dw_obs out, lambda in). If the goal is a definitive phase diagram for the escalation mechanism, a third stage with the revised top-4 set (`alpha`, `gamma`, `lambda`, `eta_obs`) and tighter parameter ranges based on the GP posterior would strengthen the conclusions.
