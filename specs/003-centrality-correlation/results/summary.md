# Stage 3 Results Summary: Centrality–Escalation Correlation

**Stage**: 003-centrality-correlation  
**Date**: 2026-06-12  
**Status**: Complete

## What this stage adds

Stage 3 re-analyses the Stage 1 simulation data using the same two-GP pipeline
as Stage 2, but with `epsilon_k_corr_final` (the Pearson correlation between
each agent's escalation propensity ε and their weighted in-degree) as the
response variable, rather than `mean_epsilon_final`. The two emulators are
C_lo (μ₀=0.4) and C_hi (μ₀=0.6). The derived quantity is the raw difference
C_hi − C_lo: positive values indicate that raising μ₀ amplifies the network
advantage of escalatory individuals.

---

## GP hyperparameters

Sensitivity = range / ell (larger = more sensitive to that parameter).
Parameter ranges: alpha [0.1, 2.0] (width 1.9), gamma [1.0, 5.0] (4.0),
lambda [1.0, 5.0] (4.0), eta_obs [0.001, 0.1] (0.099).

| Parameter | ell (C_lo) | ell (C_hi) | Sensitivity (C_lo) | Sensitivity (C_hi) |
|-----------|-----------|-----------|--------------------|--------------------|
| `alpha`   | 0.297     | 0.211     | 6.40               | 9.02               |
| `gamma`   | 1.924     | 1.702     | 2.08               | 2.35               |
| `eta_obs` | 0.165     | 0.087     | 0.60               | 1.13               |
| `lambda`  | 7.101     | 7.988     | 0.56               | 0.50               |

| Metric       | C_lo   | C_hi   |
|--------------|--------|--------|
| σ²           | 0.0118 | 0.0047 |
| nugget       | 6.9×10⁻⁴ | 8.3×10⁻⁴ |
| RMSE         | 0.0335 | 0.0292 |
| Coverage 95% | 0.93   | 0.95   |

Both GPs fit well. C_hi is smoother (lower σ², lower RMSE, nominal 95%
coverage). Alpha is the dominant parameter in both conditions, with sensitivity
increasing by 41% from C_lo to C_hi. Lambda is nearly inert (rel_ell > 1.7 in
both), and eta_obs is also weak in C_lo but gains moderate relevance in C_hi.

---

## Phase diagram results

| Pair              | C_lo range       | C_hi range       | diff range        | diff > 0? |
|-------------------|------------------|------------------|-------------------|-----------|
| `alpha × gamma`   | [0.036, 0.314]   | [0.030, 0.241]   | [−0.090, +0.024]  | yes       |
| `alpha × lambda`  | [0.036, 0.308]   | [0.029, 0.272]   | [−0.042, +0.023]  | yes       |
| `alpha × eta_obs` | [0.017, 0.231]   | [0.022, 0.248]   | [−0.021, +0.028]  | yes       |
| `gamma × lambda`  | [0.055, 0.184]   | [0.049, 0.105]   | [−0.080, −0.002]  | **no**    |
| `gamma × eta_obs` | [0.033, 0.172]   | [0.050, 0.162]   | [−0.045, +0.029]  | yes       |
| `lambda × eta_obs`| [0.030, 0.079]   | [0.049, 0.066]   | [−0.019, +0.025]  | yes       |

---

## Central question: Do high-ε individuals benefit more from increases in μ₀?

**Answer: weakly and selectively yes, but not in the amplification regime.**

The baseline correlation is positive but modest (mean ≈ 0.08, range up to 0.63):
escalatory agents tend to be more central at equilibrium, but the effect is
strongly parameter-dependent. Raising μ₀ produces a positive difference (C_hi
> C_lo) in five of six pairs, but the magnitude is small (max +0.029 on the
correlation scale).

The critical exception is **gamma × lambda**, the only pair where diff ≤ 0
throughout. This is also the region where Stage 2 found modest population-level
amplification (Ψ_max = 1.026). In this regime, higher μ₀ raises the
population mean but simultaneously reduces the correlation between ε and
degree — the network advantage of high-ε individuals is eroded, not amplified.

The largest positive differences occur in pairs involving `eta_obs`
(gamma×eta_obs +0.029, alpha×eta_obs +0.028, lambda×eta_obs +0.025), a
parameter that was not implicated in Stage 2 amplification.

---

## Comparison with Stage 2

| Feature                  | Stage 2 (E_lo / E_hi)      | Stage 3 (C_lo / C_hi)         |
|--------------------------|----------------------------|-------------------------------|
| Most sensitive parameter | `eta_obs` (sens 12–14)     | `alpha` (sens 6–9)            |
| Least sensitive          | `lambda` (sens 0.13–0.16)  | `lambda` (sens 0.50–0.56)     |
| Key enabling variable    | `lambda` (needed for Ψ>1)  | none — surface is alpha-dominated |
| gamma × lambda regime    | Ψ_max = 1.026 (amplifies)  | diff uniformly ≤ 0 (suppresses individual advantage) |
| alpha × lambda regime    | Ψ_max = 1.339 (amplifies)  | diff > 0 in part of space, max +0.023 |

Lambda is the population-level amplification enabler (Stage 2) but is
irrelevant to the individual-level correlation surface (Stage 3). Alpha
governs the correlation but is not the amplification enabler. The two phenomena
are driven by different parameters.
