# Stage 2 Results Summary: Equilibrium Surfaces

**Stage**: 002-equilibrium-surfaces  
**Date**: 2026-06-11  
**Status**: Complete

## What changed from Stage 1

Stage 2 does not introduce new simulations. It re-analyses the Stage 1 data
(`gp_train_raw.csv`) using a two-GP design: one emulator trained on `mean_epsilon_final`
at μ₀=0.4 (E_lo) and one at μ₀=0.6 (E_hi), replacing the single Ψ-normalised emulator
used in Stages 0 and 1. Beta and theta are fixed at their Stage 1 midpoints; only the
top-4 parameters (alpha, gamma, lambda, eta_obs) are active inputs.

The derived quantity Ψ = (E_hi − E_lo) / 0.2 is now interpreted as an **amplification
ratio**: Ψ > 1 means social dynamics amplify the initial μ₀ perturbation.

---

## GP hyperparameters

| Parameter | ell (E_lo) | ell (E_hi) | Sensitivity (E_lo) | Sensitivity (E_hi) |
|-----------|-----------|-----------|--------------------|--------------------|
| `eta_obs` | 0.079     | 0.071     | 12.71              | 14.01              |
| `alpha`   | 0.628     | 1.153     | 1.59               | 0.87               |
| `gamma`   | 2.229     | 2.288     | 0.45               | 0.44               |
| `lambda`  | 6.361     | 7.985     | 0.16               | 0.13               |

| Metric       | E_lo   | E_hi   |
|--------------|--------|--------|
| σ²           | 0.0150 | 0.0084 |
| nugget       | 0.0012 | 0.0006 |
| RMSE         | 0.0338 | 0.0224 |
| Coverage 95% | 0.98   | 0.96   |

Both GPs validate substantially better than Stage 1 (RMSE 0.134). The hi surface is
smoother and lower-variance: once primed at μ₀=0.6, parameter variation matters less.
Alpha is notably less influential for E_hi (ell 1.15) than E_lo (ell 0.63) — the
high-μ₀ population is less sensitive to distance-decay.

---

## Phase diagram results

| Pair | E_lo range | E_hi range | Ψ range | Ψ > 1? |
|------|------------|------------|---------|--------|
| `alpha × eta_obs` | [0.520, 0.870] | [0.602, 0.893] | [−0.053, 0.900] | No |
| `alpha × gamma`   | [0.559, 0.788] | [0.716, 0.842] | [−0.036, 0.835] | No |
| `alpha × lambda`  | [0.429, 0.785] | [0.696, 0.836] | [0.081, **1.339**] | **Yes** |
| `gamma × eta_obs` | [0.561, 0.715] | [0.695, 0.782] | [0.163, 0.925] | No |
| `gamma × lambda`  | [0.540, 0.724] | [0.735, 0.803] | [0.160, **1.026**] | **Yes** |
| `lambda × eta_obs`| [0.549, 0.655] | [0.723, 0.783] | [0.595, 0.999] | No (≈1) |

---

## Central hypothesis

**Confirmed**: Ψ > 1 exists in the top-4 parameter subspace. Social dynamics amplify
the initial μ₀ perturbation in two of six parameter pairs:

1. **`alpha × lambda`**: Ψ_max = 1.339 — the strongest amplification. Low alpha (local
   influence) combined with low lambda (small groups) allows early escalation to
   crystallise before network-wide averaging can dilute it.

2. **`gamma × lambda`**: Ψ_max = 1.026 — marginal amplification. A specific network
   topology (high gamma, strongly hierarchical) combined with small groups is sufficient
   to push past the amplification boundary.

Lambda is the enabling variable: it appears in both amplifying pairs and drives
`lambda × eta_obs` to Ψ ≈ 1. Pairs without lambda stay comfortably below 1.

---

## Qualitative conclusions

**Unchanged from prior stages:**
- eta_obs is the most GP-sensitive parameter for absolute escalation level
- alpha and gamma are the next most influential
- lambda has long ARD length scales (low GP sensitivity) in both conditions

**New findings:**
- Ψ > 1 is confirmed — the central Stage 2 hypothesis holds in a specific structural
  regime (small groups + local influence or hierarchical topology)
- The amplification regime is defined by lambda, not by the learning parameters
- E_hi has lower variance and lower alpha-sensitivity than E_lo — the hi-μ₀ population
  converges to a narrower, higher outcome range regardless of structural parameters

## Open questions

1. **Where exactly in the alpha×lambda plane does Ψ cross 1?** The phase diagram
   identifies the boundary region but at 50×50 resolution. A targeted high-resolution
   grid (100×100 or finer) over this pair would map the amplification boundary precisely.

2. **Does the gamma×lambda amplification persist at other alpha values?** The
   gamma×lambda phase diagram fixes alpha at its midpoint (1.0). If the amplification
   there depends on a specific alpha regime, the boundary may be a surface in 3D
   parameter space rather than a line in 2D.

3. **Why does lambda×eta_obs not cross Ψ = 1?** Given lambda's role in the other two
   amplifying pairs, the fact that lambda × eta_obs stops at 0.999 suggests that
   observational learning rate cannot substitute for distance-decay (alpha) or network
   topology (gamma) as the co-enabler of amplification.
