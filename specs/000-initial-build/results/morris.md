# Morris Screening Results

**Date**: 2026-06-10  
**Design**: OAT, r = 15 trajectories, p = 11 parameters, 8 levels, grid jump 4  
**Binary settings**: N = 200, t_max = 2000, seed = 0 (paired μ₀ ∈ {0.4, 0.6})  
**Estimand**: Ψ = (ε̄(∞)|_{μ₀=0.6} − ε̄(∞)|_{μ₀=0.4}) / 0.2  
**Fixed**: `delta = 0.01` (see decision below), plus all structural params in `defaults.json`

## Notes

- `sensitivity` ≥ 1.30 stores raw elementary effects in `m$ee`; μ\*/σ computed
  via `apply(m$ee, 2, ...)` directly, not via `m$mu.star`.
- `delta` was excluded from the free-parameter set before this run (fixed at
  0.01 in `defaults.json`); see the Decision section for rationale.

## Results (ranked by μ\*)

| Rank | Parameter    | μ\*    | σ      | μ       | Interpretation                            |
|------|-------------|--------|--------|---------|-------------------------------------------|
| 1    | `dw_obs`    | 0.768  | 1.278  | +0.623  | Observer edge boost: primary Ψ driver     |
| 2    | `eta_obs`   | 0.742  | 1.033  | +0.352  | Observational learning rate               |
| 3    | `alpha`     | 0.605  | 0.683  | +0.319  | Locality: stronger locality raises Ψ      |
| 4    | `gamma`     | 0.576  | 0.724  | +0.108  | Network exponent: steeper hierarchy → Ψ   |
| 5    | `beta`      | 0.540  | 0.671  | +0.145  | Status advantage                          |
| 6    | `w_win`     | 0.505  | 0.837  | −0.086  | Win payoff (r_win_cost); near-neutral μ   |
| 7    | `dw_bridge` | 0.448  | 0.750  | +0.258  | Bridge edge increment                     |
| 8    | `lambda`    | 0.447  | 0.449  | −0.393  | Group size: larger groups suppress Ψ      |
| 9    | `theta`     | 0.249  | 0.340  | +0.007  | Audience radius (discrete)                |
| 10   | `w_loss`    | 0.127  | 0.209  | +0.050  | Loss cost                                 |
| 11   | `b`         | 0.035  | 0.076  | +0.027  | **Cooperation benefit — near-zero μ\***   |

## Key findings

**Top 6 by μ\*** (for Sobol): `dw_obs`, `eta_obs`, `alpha`, `gamma`, `beta`, `w_win`

Clear tier break after rank 6 (μ\* drops from 0.505 to 0.448). Ranks 7–8
(`dw_bridge`, `lambda`) are borderline; `lambda` has the most negative μ
(−0.393) so it warrants inclusion in any cooperative-regime analysis.

**`b` and `w_loss` safely excluded**: μ\* = 0.035 and 0.127 respectively —
well below the tier-1 group. `theta` is marginal (0.249) but discrete-valued
and cheap to sweep separately if needed.

**High σ / μ\* ratios** (σ/μ\* > 1): `dw_obs` (1.66), `eta_obs` (1.39),
`w_win` (1.66) — strong nonlinearity or interactions on these three.
Sobol total-effect indices will be essential.

**Sign of μ** (direction of effect on Ψ):
- Positive (raises Ψ): `dw_obs` >> `eta_obs` > `alpha` > `dw_bridge` > `beta` > `gamma`
- Negative (suppresses Ψ): `lambda` > `w_win` (weakly)

The observational learning channel (`dw_obs`, `eta_obs`) dominates —
together they account for the two highest μ\* values, suggesting that
audience effects are the primary mechanism driving μ₀ sensitivity.

## Decision: delta fixed, not varied in analyses

`delta` (edge-decay rate) suppresses Ψ monotonically (confirmed by
`analysis/delta_monotone.R`). Conceptually necessary for active-reinforcement
network semantics but uninteresting to vary for phase-diagram purposes.
Fixed at `delta = 0.01` in `defaults.json` (~10% cumulative weight loss
per run at SLOW_INTERVAL = 1,000 steps).

## Decision: parameters for Sobol

Proceed to Sobol with the top 6:
`dw_obs`, `eta_obs`, `alpha`, `gamma`, `beta`, `w_win`

`lambda` (rank 8, μ = −0.393) is a candidate for inclusion given its strong
directional effect; add if Saltelli budget permits (increases design by 2n rows).
