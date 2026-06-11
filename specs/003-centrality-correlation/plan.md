---
created: 2026-06-11T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 82fafb29081854c16a1f6e9c4d5f628567de0edc
---

# Plan: centrality-correlation

## Overview
Analyse existing Stage 1 simulation data to build GP emulators of the
epsilon-degree correlation (`epsilon_k_corr_final`) for both μ₀ conditions,
map phase diagrams of the correlation surfaces and their difference across
the top-4 parameter space, and answer whether high-epsilon individuals
benefit more from increases in μ₀.

## Context

Stages 0–2 established the GP emulation pipeline and confirmed that:
- The model produces genuine amplification (Ψ > 1) in the alpha×lambda and
  gamma×lambda parameter regimes
- `mean_epsilon_final` is the primary population-level output; two GPs (E_lo,
  E_hi) map its absolute surfaces across the top-4 parameter space (alpha,
  gamma, lambda, eta_obs)
- The key structural result: lambda is the enabling variable for amplification;
  pairs without lambda stay well below Ψ = 1

`epsilon_k_corr_final` is already computed in the Rust simulation and written
to `gp_train_raw.csv`. It is the Pearson correlation between each agent's
current escalation propensity (ε) and their current weighted in-degree (k) at
quasi-equilibrium (tail-averaged over the last 20% of the run). A positive
value means escalatory agents are more network-central at equilibrium; a
higher value in the μ₀=0.6 condition than the μ₀=0.4 condition is evidence
that increases in μ₀ specifically benefit high-ε individuals — i.e. that the
social dynamics are not just raising the population average but also
concentrating network influence in the hands of the already-escalatory.

No new simulations or Rust changes are needed. This stage is a direct
parallel to Stage 2, substituting `epsilon_k_corr_final` for
`mean_epsilon_final` as the GP response variable.

## Design Goals

1. **Correlation surfaces**: build GP emulators of `epsilon_k_corr_final`
   for μ₀=0.4 (C_lo) and μ₀=0.6 (C_hi) separately across the 4-parameter
   space, using the same Matérn-5/2 ARD specification as Stage 2.

2. **Difference surface**: derive (C_hi − C_lo) post-hoc from the two
   emulators. Positive values indicate that increasing μ₀ amplifies the
   network advantage of high-ε individuals; negative values indicate it
   reduces it.

3. **Phase diagrams**: generate 6 pairwise phase diagrams (C(4,2) pairs)
   for each of the three surfaces (C_lo, C_hi, difference), for 18 diagrams
   total. Fix remaining parameters at Stage 1 midpoints.

4. **Answer the question**: identify whether C_hi > C_lo is consistent
   across parameter space or confined to specific structural regimes (e.g.
   the same alpha×lambda amplification regime found in Stage 2).

## Proposed Approach

**Data preparation**: read `results/gp_train_raw.csv`, split by `mu0`,
average `epsilon_k_corr_final` across seeds per design point per condition.
Reconstruct `eta_obs = kappa * eta_fixed` as in Stage 2. Identical pipeline
to Stage 2's treatment of `mean_epsilon_final`.

**GP training** (`analysis/gp_train3.R`): fit two GPs (`fit_corr_lo`,
`fit_corr_hi`) using the same 4-parameter design matrix as Stage 2 (alpha,
gamma, lambda, eta_obs; beta and theta fixed at midpoints). Same Matérn-5/2
ARD kernel, `nugget.estim=TRUE`, constant trend, and stratified 80/20
train-test split. Save `results/gp_corr_lo.rds` and `results/gp_corr_hi.rds`.
Also save `results/gp3_hyperparams.csv` with condition, param, ell, sigma2,
nugget, rmse, coverage columns.

**Phase diagrams** (`analysis/gp_phase3.R`): same 50×50 grid approach as
Stage 2 for each of 6 parameter pairs. Column ordering fix via
`colnames(fit@X)`. Compute difference = C_hi − C_lo (no normalisation;
both surfaces are on the same [−1, 1] correlation scale). Save to
`results/gp_phase3/`: `phase3_lo_*`, `phase3_hi_*`, `phase3_diff_*`
(three CSVs per pair, 18 total).

**Plots** (`analysis/plot3.R`): three-panel figures (C_lo | C_hi | difference)
for each of the 6 pairs using patchwork. Diverging colour scale for the
difference panel centred at 0; a contour at difference = 0 marks the boundary
between μ₀ helping vs hurting high-ε individuals. Sequential scale for C_lo
and C_hi panels with shared limits. Save to `results/plots/phase3_<tag>.png`.

**Makefile**: add `gp3`, `gp3_phase`, and `plots3` targets analogous to the
Stage 2 targets.

**Write-up**: `specs/003-centrality-correlation/results/gp.md` (hyperparams +
phase results), `results/summary.md`, and `results/interpretation.md`
addressing whether high-ε individuals benefit more from increases in μ₀ and
how that relates to the Stage 2 amplification regime.

## Open Questions

1. **Sign of the baseline correlation**: it is not yet known whether
   `epsilon_k_corr_final` is typically positive (escalatory agents end up
   more central) or negative (they end up more isolated). The direction of
   the baseline will determine how the difference surface should be
   interpreted.

2. **Relationship to Stage 2 amplification regime**: the hypothesis is that
   the alpha×lambda amplification regime identified in Stage 2 coincides with
   high (C_hi − C_lo). This will be visible in the phase diagrams but is not
   guaranteed.
