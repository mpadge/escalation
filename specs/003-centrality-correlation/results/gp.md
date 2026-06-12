# Stage 3 GP results: epsilon-degree correlation surfaces

Source files: `results/gp3_hyperparams.csv`, `results/gp3_data.csv`,
`results/gp_corr_lo.rds`, `results/gp_corr_hi.rds`.

## Verification

- Both RDS fits exist and loaded without error.
- Nugget > 0 for both conditions (lo: 6.9×10⁻⁴, hi: 8.3×10⁻⁴).
- No degenerate ARD length scale: minimum relative ell = 0.111 (alpha, C_hi),
  well above the 0.05 threshold.

## Baseline correlation

`epsilon_k_corr_final` measures the Pearson correlation between each agent's
escalation propensity (ε) and their weighted in-degree at quasi-equilibrium.

| Condition | Min     | Mean   | Max    |
|-----------|---------|--------|--------|
| C_lo (μ₀=0.4) | −0.052 | 0.081 | 0.632 |
| C_hi (μ₀=0.6) | −0.114 | 0.072 | 0.618 |

The correlation is predominantly positive: across most of the parameter space,
escalatory agents end up more central at equilibrium. The mean is modest (~0.08)
but the surface spans a wide range (up to 0.63), indicating strong parameter
dependence. A small fraction of design points show negative correlation —
regimes where escalatory agents become more isolated.

## ARD length scales and sensitivity

Sensitivity here is `range / ell` (larger = more sensitive). Parameter ranges:
alpha [0.1, 2.0] (width 1.9), gamma [1.0, 5.0] (4.0), lambda [1.0, 5.0]
(4.0), eta_obs [0.001, 0.1] (0.099).

| param   | ell C_lo | ell C_hi | norm_sens C_lo | norm_sens C_hi |
|---------|----------|----------|----------------|----------------|
| alpha   | 0.297    | 0.211    | 6.40           | 9.02           |
| gamma   | 1.924    | 1.702    | 2.08           | 2.35           |
| eta_obs | 0.165    | 0.087    | 0.60           | 1.13           |
| lambda  | 7.101    | 7.988    | 0.56           | 0.50           |

Ranking (both conditions agree): **alpha > gamma ≫ eta_obs ≈ lambda**.

`alpha` dominates in both conditions, with sensitivity increasing markedly in
C_hi (9.02 vs 6.40). `gamma` is second but much weaker. `lambda` and `eta_obs`
are both low-sensitivity in C_lo; in C_hi, `eta_obs` gains moderate importance
(1.13) while `lambda` remains flat (0.50).

## Fit quality

| Metric       | C_lo   | C_hi   |
|--------------|--------|--------|
| σ²           | 0.0118 | 0.0047 |
| nugget       | 6.9×10⁻⁴ | 8.3×10⁻⁴ |
| RMSE (test)  | 0.0335 | 0.0292 |
| Coverage 95% | 0.93   | 0.95   |

Both fits are good. C_hi is tighter (lower σ², lower RMSE, exact nominal
coverage at 0.95).

## Notable differences between C_lo and C_hi

- **Alpha sensitivity doubles in C_hi**: the correlation surface becomes
  substantially more alpha-dependent at higher μ₀, suggesting that the
  interaction structure (alpha controls encounter-weight decay) matters more
  when the social signal is stronger.
- **eta_obs gains relevance in C_hi**: nearly inert in C_lo (norm_sens 0.60),
  it reaches moderate importance in C_hi (1.13), implying that the observation
  noise floor starts shaping who becomes central only when μ₀ is high enough.
- **lambda is irrelevant in both**: relative ell > 1.7 means the correlation
  surface is essentially flat in the lambda direction — in stark contrast to
  Stage 2, where lambda was the key enabling variable for population-level
  amplification (Ψ > 1).
- **C_hi is smoother overall** (lower σ²): the mu₀=0.6 correlation surface
  has less variance, concentrated in the alpha direction.

## Contrast with Stage 2

Stage 2 found that lambda × alpha and lambda × gamma were the amplification
regimes (Ψ > 1). Here, lambda is the least sensitive parameter. The
individual-level network advantage of escalatory agents is shaped primarily by
alpha (encounter-weight structure) and gamma (reward scaling), not by the
feedback gain that drives population-level amplification.

---

## Phase diagrams

Source: `results/gp_phase3/` (18 CSV files: 6 pairs × 3 surfaces).

### Per-pair summary

| Pair              | C_lo range       | C_hi range       | diff range        | diff > 0? |
|-------------------|------------------|------------------|-------------------|-----------|
| alpha × gamma     | [0.036, 0.314]   | [0.030, 0.241]   | [−0.090, +0.024]  | yes       |
| alpha × lambda    | [0.036, 0.308]   | [0.029, 0.272]   | [−0.042, +0.023]  | yes       |
| alpha × eta_obs   | [0.017, 0.231]   | [0.022, 0.248]   | [−0.021, +0.028]  | yes       |
| gamma × lambda    | [0.055, 0.184]   | [0.049, 0.105]   | [−0.080, −0.002]  | **no**    |
| gamma × eta_obs   | [0.033, 0.172]   | [0.050, 0.162]   | [−0.045, +0.029]  | yes       |
| lambda × eta_obs  | [0.030, 0.079]   | [0.049, 0.066]   | [−0.019, +0.025]  | yes       |

### Pairs with largest positive difference

The three pairs involving `eta_obs` produce the largest positive differences:
gamma×eta_obs (+0.029), alpha×eta_obs (+0.028), lambda×eta_obs (+0.025). These
are the regimes where increasing μ₀ most benefits the centrality of high-ε
individuals. The effect is modest in absolute terms (< 0.03 on the correlation
scale) but consistent across the eta_obs dimension.

### Consistently negative pair

**gamma × lambda** is the only pair where diff ≤ 0 throughout (range
[−0.080, −0.002]). In this region of parameter space, increasing μ₀ uniformly
reduces the correlation between ε and degree — high-ε agents become *less*
central relative to low-ε agents when μ₀ rises, across all gamma × lambda
combinations. The effect is also the largest in magnitude of any pair
(max |diff| = 0.090).

### Relationship to Stage 2 amplification pairs

Stage 2 identified alpha×lambda and gamma×lambda as the population-level
amplification regimes (Ψ > 1). The individual-level picture diverges:

- **gamma × lambda**: Stage 2's strongest amplification pair shows *uniformly
  negative* diff here — higher μ₀ reduces the correlation advantage of
  high-ε agents even as it raises the population mean.
- **alpha × lambda**: Shows small positive diff (+0.023) in part of its space,
  but is not among the leading pairs.
- The strongest positive diff comes from eta_obs pairs, which were not
  implicated in Stage 2 amplification.

The regimes that amplify the population average (Stage 2) do not overlap with
the regimes that concentrate network influence in escalatory individuals
(Stage 3). In the gamma × lambda regime, the two effects point in opposite
directions.
