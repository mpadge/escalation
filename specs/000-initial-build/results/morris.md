# Morris Screening Results

**Date**: 2026-06-10  
**Design**: OAT, r = 15 trajectories, p = 12 parameters, 8 levels, grid jump 4  
**Binary settings**: N = 200, t_max = 2000, seed = 0 (paired μ₀ ∈ {0.4, 0.6})  
**Estimand**: Ψ = (ε̄(∞)|_{μ₀=0.6} − ε̄(∞)|_{μ₀=0.4}) / 0.2

## Bug fixed

`sensitivity` ≥ 1.30 stores raw elementary effects in `m$ee` and computes
μ\*/σ lazily in `print.morris`; they are not stored on the object.
Fixed `morris.R` to compute them directly via `apply(m$ee, 2, ...)`.

## Results (ranked by μ\*)

| Rank | Parameter    | μ\*    | σ      | μ       | Interpretation                          |
|------|-------------|--------|--------|---------|------------------------------------------|
| 1    | `w_win`     | 0.764  | 1.139  | +0.090  | Win payoff → r_win_cost dominant driver  |
| 2    | `delta`     | 0.674  | 0.942  | −0.110  | Edge decay rate: high δ suppresses Ψ     |
| 3    | `alpha`     | 0.617  | 0.915  | +0.175  | Locality: stronger locality raises Ψ     |
| 4    | `lambda`    | 0.597  | 0.686  | −0.305  | Group size: larger groups reduce Ψ       |
| 5    | `dw_obs`    | 0.554  | 0.648  | +0.532  | Observer edge boost: raises Ψ            |
| 6    | `gamma`     | 0.508  | 0.835  | +0.269  | Network exponent: steeper hierarchy → Ψ  |
| 7    | `dw_bridge` | 0.503  | 0.874  | −0.299  | Bridge increment (modest, high σ)        |
| 8    | `beta`      | 0.479  | 0.706  | +0.160  | Status advantage                         |
| 9    | `eta_obs`   | 0.455  | 0.619  | +0.060  | Observational learning rate              |
| 10   | `theta`     | 0.421  | 0.681  | +0.069  | Audience radius                          |
| 11   | `w_loss`    | 0.400  | 0.770  | −0.103  | Loss cost                                |
| 12   | `b`         | 0.081  | 0.179  | +0.048  | **Cooperation benefit — near-zero μ\***  |

## Key findings

**Top 6 by μ\*** (for Sobol): `w_win`, `delta`, `alpha`, `lambda`, `dw_obs`, `gamma`

All six have μ\* > 0.5; the gap to rank 7 (`dw_bridge`, 0.503) is small
so ranks 7–8 (`dw_bridge`, `beta`) are borderline candidates for inclusion.

**`b` is safely excluded**: μ\* = 0.081, well below the rest — cooperation
benefit has negligible first-order influence on Ψ at these parameter ranges.

**High σ / μ\* ratios** (σ/μ\* > 1) for `w_win`, `delta`, `alpha`, `dw_bridge`
indicate substantial nonlinearity or interaction effects — Sobol total-effect
indices will be important for these.

**Sign of μ**:
- Positive (raises Ψ): `dw_obs` > `alpha` > `gamma` > `beta` > `w_win`
- Negative (suppresses Ψ): `lambda` > `dw_bridge` > `delta` > `w_loss`

## Decision

Proceed to Sobol with the top 6 parameters:
`w_win`, `delta`, `alpha`, `lambda`, `dw_obs`, `gamma`

`dw_bridge` and `beta` are candidates for a sensitivity check but excluded
from the primary Sobol run to keep the Saltelli budget tractable.
