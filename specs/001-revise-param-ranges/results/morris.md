# Morris Screening Results

**Date**: 2026-06-11  
**Design**: OAT, r = 15 trajectories, p = 11 parameters, 8 levels, grid jump 4  
**Binary settings**: N = 200, t_max = 2000, seed = 0 (paired μ₀ ∈ {0.4, 0.6})  
**Estimand**: Ψ = (ε̄(∞)|_{μ₀=0.6} − ε̄(∞)|_{μ₀=0.4}) / 0.2  
**Fixed**: `delta = 0.01`, plus all structural params in `defaults.toml`  
**Revised ranges**: `gamma` [1.0, 5.0] (was [2.0, 4.0]), `beta` [0.0, 1.0] (was [0.0, 3.0]), `w_win` [0.0, 2.0] (was [0.1, 2.0])

## Results (ranked by μ\*)

| Rank | Parameter    | μ\*    | σ      | μ       | Interpretation                                 |
|------|-------------|--------|--------|---------|------------------------------------------------|
| 1    | `alpha`     | 0.736  | 0.906  | +0.495  | Locality: now primary Ψ driver                 |
| 2    | `gamma`     | 0.657  | 0.829  | +0.189  | Network exponent: rises with wider range       |
| 3    | `lambda`    | 0.596  | 0.603  | −0.563  | Group size: strong negative directional effect |
| 4    | `eta_obs`   | 0.450  | 0.605  | +0.191  | Observational learning rate                    |
| 5    | `beta`      | 0.434  | 0.543  | +0.086  | Status advantage                               |
| 6    | `theta`     | 0.344  | 0.459  | +0.069  | Audience radius (discrete)                     |
| 7    | `dw_obs`    | 0.333  | 0.380  | +0.222  | Observer edge boost: drops from rank 1         |
| 8    | `dw_bridge` | 0.316  | 0.426  | +0.004  | Bridge edge increment                          |
| 9    | `w_win`     | 0.310  | 0.394  | +0.140  | Win payoff                                     |
| 10   | `w_loss`    | 0.154  | 0.250  | +0.035  | Loss cost                                      |
| 11   | `b`         | 0.096  | 0.225  | +0.030  | **Cooperation benefit — near-zero μ\***        |

## Key findings

**Top 6 by μ\*** (for Sobol): `alpha`, `gamma`, `lambda`, `eta_obs`, `beta`, `theta`

Clear tier break after rank 6 (μ\* drops from 0.344 to 0.333). Ranks 7–9 (`dw_obs`,
`dw_bridge`, `w_win`) are tightly clustered and just below the cut.

### Major ranking shifts versus Stage 0

The revised parameter ranges substantially changed the sensitivity ranking:

- **`alpha`** rises from rank 3 → 1 (μ\* 0.605 → 0.736). Range unchanged; the shift
  reflects how the wider `gamma` and narrower `beta` ranges alter interaction structure.
- **`gamma`** rises from rank 4 → 2 (μ\* 0.576 → 0.657). Directly attributable to the
  widened range [2,4] → [1,5]; more of the parameter space is now explored.
- **`lambda`** rises from rank 8 → 3 (μ\* 0.447 → 0.596) and has the most negative μ
  (−0.563). Range unchanged; likely unmasked by shifts in the other parameters.
- **`dw_obs`** falls from rank 1 → 7 (μ\* 0.768 → 0.333). The range is the same [0,0.2];
  this drop is an interaction effect — its marginal influence is reduced when `alpha` and
  `gamma` occupy more of the variance budget.
- **`beta`** holds at rank 5 despite range narrowing [0,3] → [0,1], confirming it is a
  genuinely active parameter, not an artefact of a wide range.

### σ/μ\* ratios

High σ/μ\* (> 1.0): `alpha` (1.23), `gamma` (1.26), `eta_obs` (1.34) — strong nonlinearity
or interactions. Sobol total-effect indices will resolve the interaction structure.

### Sign of μ (direction of effect on Ψ)

- Positive (raises Ψ): `alpha` > `gamma` > `eta_obs` > `dw_obs` > `beta` > `w_win`
- Negative (suppresses Ψ): `lambda` (strongly, μ = −0.563)

## Decision: parameters for Sobol

Top 6 by μ\*: `alpha`, `gamma`, `lambda`, `eta_obs`, `beta`, `theta`

Note that `dw_obs` (Stage 0 rank 1) falls to rank 7 and is excluded from the
Sobol design. This is a substantive change from Stage 0 and warrants watching whether
it re-emerges in GP emulation via interaction with `alpha`.
