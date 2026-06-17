---
created: 2026-06-17T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 90f723eeebf5e742b328077edb8093d7e78a362f
---

# Plan: gini-inequality

## Overview
Characterise the Gini coefficient of degree centrality at equilibrium (`gini_k_final`)
across the parameter space of both the baseline model and the bivariate σ model.
The primary question is which structural parameters govern the *level* of centrality
inequality, and whether that ordering matches or diverges from the parameters that
govern Ψ (population-level amplification) and ε–degree correlation (individual
power concentration).

## Context

This stage addresses the third item listed as deferred in Stage 008
(`design-decisions.md`, Deferred Items): "network centrality inequality (not just
the ε–degree correlation) was not measured in either analysis." The final report
(`docs/final-report.md`) explicitly names this gap in its "Remaining questions"
section, noting that a Gini-type measure would "complement the correlation measures
reported here and might further differentiate the structural conditions under which
escalation produces dispersed versus concentrated network outcomes."

Crucially, `gini_k_final` was recorded from the initial build (Stage 000) and is
present in both raw training datasets — no new simulations are required:

- **Baseline model**: `results/003-centrality-correlation/gp_train_raw.csv`
  (40,000 rows; `gini_k_final` range [0.015, 0.925])
- **Bivariate σ model**: `results/gp_bivar_train.csv`
  (40,000 rows; `gini_k_final` range [0.011, 0.935])

Both datasets use paired mu0 = 0.4 / 0.6 conditions (20,000 rows each) across
their respective parameter spaces.

Prior stages established that the dominant structural variables for Ψ are group
size (lambda) and influence locality (alpha) in the baseline model, with
observational bandwidth (dw_obs) entering as first-order in the bivariate model.
The question here is whether those same variables govern inequality, or whether
a different structural axis is primary for Gini.

## Design Goals

1. Determine which parameters govern `gini_k_final` in the baseline model via
   GP emulation and Sobol sensitivity analysis, and compare the ranking to the
   existing Ψ and ε–degree correlation rankings from Stage 003.
2. Repeat for the bivariate σ model, comparing the Gini parameter ranking to the
   Ψ and psi_sigma rankings from Stage 007.
3. Test whether higher baseline escalation propensity (mu0 = 0.6 vs 0.4) is
   associated with higher `gini_k_final` across the parameter space — the core
   hypothesis — and characterise the magnitude and structural conditions of that
   effect.
4. Determine whether the structural conditions that produce high Gini overlap with,
   diverge from, or are orthogonal to those that produce Ψ > 1 (amplification) and
   high ε–degree correlation (power concentration).
5. Produce a short written section extending `docs/final-report.md` with the Gini
   findings, closing the "Remaining questions" item explicitly.

## Proposed Approach

### Estimand
The primary estimand is `gini_k_final` — the Gini coefficient of the degree
centrality distribution at simulation end — as an absolute level, not a paired
difference or ratio. The reasoning: a paired quantity (Gini_hi − Gini_lo) would
ask whether *more* escalation produces *more* inequality relative to a baseline,
but the scale of such a difference is hard to interpret without knowing the
baseline level. The absolute level across the full parameter space is the
informative quantity: it shows which structural configurations produce high or low
inequality regardless of the group's initial escalation propensity.

The mu0 dimension is treated as a covariate (or separate condition), not folded
into a ratio. The hypothesis — that higher mu0 raises `gini_k_final` — is tested
by comparing mean Gini across conditions at the same parameter configurations.

### Baseline model analysis
Aggregate `gp_train_raw.csv` by parameter combination to get mean `gini_k_final`
per parameter point (averaging across seeds, separately for mu0 = 0.4 and mu0 = 0.6).
Fit a GP emulator to the aggregated Gini surface using the same structural
parameters used in Stage 003 for Ψ (alpha, lambda, gamma, eta_obs as the primary
axes). Run Sobol sensitivity analysis via the GP. Compare first-order and total
indices to the existing Stage 003 Sobol rankings.

### Bivariate model analysis
Aggregate `gp_bivar_train.csv` by the six bivariate parameters (mu_sigma, lambda,
sigma_sigma, dw_obs, dw_bridge, alpha) to get mean `gini_k_final` per parameter
point. Fit a GP emulator and run Sobol sensitivity. Compare rankings to the Stage
007 rankings for Ψ and psi_sigma.

### Hypothesis test
For each parameter configuration, compare mean `gini_k_final` at mu0 = 0.6 versus
mu0 = 0.4. Report the fraction of configurations where Gini is higher at mu0 = 0.6,
and the distribution of the difference. This directly tests whether higher baseline
escalation systematically elevates inequality.

### Secondary estimand: dissipative inequality
The datasets also contain `gini_peak` (maximum Gini reached during the run) and
`t_gini_peak`. The gap between `gini_peak` and `gini_k_final` measures how much
transient inequality cooperative reconstruction dissipates: a large gap indicates
a structural configuration where escalation briefly concentrates degree centrality
but the cooperative payoff mechanism rebuilds distributed connectivity before
equilibrium. This dissipative inequality (`gini_peak - gini_k_final`) is a
secondary estimand and will be characterised alongside `gini_k_final`. High
dissipative inequality is substantively interesting — it would reveal structural
configurations where escalation's power-concentrating effect is real but
self-limiting, which complements the cooperative reconstruction mechanism already
described in the final report.

### Parameter set
Both the baseline and bivariate GP analyses use the same reduced parameter sets
as their corresponding existing analyses (Stage 003 for the baseline, Stage 007
for the bivariate). This ensures Gini sensitivity rankings are directly comparable
to the existing Ψ and ε–degree correlation rankings without introducing
incomparable parameter axes.

### Output
An extension and potential rewriting of `docs/final-report.md` incorporating the
Gini findings. Specifically: (a) which structural parameters govern `gini_k_final`
in each model and how they compare to the Ψ / ε–degree parameter rankings, (b)
the dissipative inequality pattern and what it adds to the cooperative
reconstruction account, (c) the result of the mu0 hypothesis test, and (d) how
this resolves the "Remaining questions" item from the current final report. The
existing "Remaining questions" section will be removed or replaced once the
findings are incorporated.

## Open Questions

None.
