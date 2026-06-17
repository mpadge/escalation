---
created: 2026-06-17T12:00:00Z
agent: claude-sonnet-4-6
git_hash: f1e95adc5b5f98dd917061c2bb9c5bc51f20f6bb
---

# Design Decisions: Stage 009 — Gini Inequality Analysis

## Summary

Stage 009 added GP-based Sobol sensitivity analysis for the `gini_k_final`
(equilibrium degree-centrality Gini) estimand to both the baseline and bivariate
σ models, using pre-existing training datasets with no new simulations required.
The central finding is that the structural parameter axes governing centrality
inequality are largely distinct from those governing population-level amplification
(Ψ) and individual power concentration (ε–degree correlation).

## New Design Decisions

### Decision 1: Absolute `gini_k_final` as primary estimand
**Chosen:** `gini_k_final` is analysed as an absolute level, with mu0 treated as
a covariate/condition and its effect tested separately.
**Rationale:** The governing-parameter question (which structural configurations
produce concentrated vs. distributed degree centrality?) requires the absolute
level. A paired Gini difference would merge two distinct questions: whether
escalation raises inequality and which parameters control the baseline level.
**Tradeoffs:** Requires a separate hypothesis-test step for the mu0 effect; cannot
be directly compared in scale to the normalised Ψ ratio.
**Proposed by:** agent

### Decision 2: Matched parameter sets for cross-estimand Sobol comparison
**Chosen:** Baseline Gini uses the four Stage 003 TOP_PARAMS (alpha, gamma, lambda,
eta_obs); bivariate Gini uses the six Stage 007 bivariate Sobol parameters
(mu_sigma, lambda, sigma_sigma, dw_obs, dw_bridge, alpha).
**Rationale:** Identical parameter sets are a precondition for the rank-order
comparison across Ψ / ε–degree / Gini that is the stage's primary analytical
output. Introducing additional parameters would make the comparison impossible.
**Tradeoffs:** Parameters outside the reduced sets may contribute to Gini variance
but cannot be detected.
**Proposed by:** agent

### Decision 3: Dissipative inequality (`gini_peak − gini_k_final`) as secondary estimand
**Chosen:** Four additional GPs fit the dissipative inequality surface (lo/hi ×
baseline/bivariate), and the structural pattern is characterised alongside Gini.
**Rationale:** The cooperative reconstruction mechanism already described in the
final report predicts that transient centrality concentration partially reverses
before equilibrium; dissipative inequality quantifies this directly. Globally
connected (low-alpha) configurations show larger dissipation, consistent with
faster cooperative rebuilding at distance.
**Tradeoffs:** Eight total GPs per model fit; dissipative inequality reported at
shorter length than the primary estimand.
**Proposed by:** agent

### Decision 4: "Remaining questions" section updated, not removed
**Chosen:** The Gini item is removed from "Remaining questions" in
`docs/final-report.md`; the two non-Gini items (Ψ=1 threshold under σ; bivariate
ε–degree correlation) are retained explicitly.
**Rationale:** Task T009-4 specified removing the section "once all three items are
addressed." Only one of three was addressed. The remaining two are substantive
empirical questions and should be explicitly preserved rather than silently dropped.
**Proposed by:** mpadge

## Key Empirical Findings

- **mu0 hypothesis**: 98.6% of 1,000 baseline configurations show higher
  `gini_k_final` at mu0 = 0.6, mean difference 0.19. In the bivariate model,
  100% of configurations show the same direction, mean difference 0.30.
- **Baseline Sobol**: eta_obs dominates (ARD sensitivity ≈ 5–6× the next
  parameter, alpha). Lambda — the dominant variable for Ψ — has almost no
  influence on Gini.
- **Bivariate Sobol**: dw_obs dominates (ARD sensitivity ≈ 9× the next
  parameter). sigma_sigma and mu_sigma rank last, below sensitivity 1.
- **Dissipative inequality**: modest on average (0.05–0.08 Gini units above
  equilibrium); largest in low-alpha (globally connected) configurations.

## Integration with Prior Work

The cross-estimand Sobol ranking comparison is the direct analytical payoff of
using the same parameter sets as Stages 003 and 007. The Stage 003 finding
(lambda governs Ψ; alpha governs ε–degree correlation) extends to a three-way
dissociation: lambda governs Ψ, alpha governs ε–degree correlation, and eta_obs
/ dw_obs govern Gini. The Stage 007 finding that sigma_sigma / mu_sigma govern
psi_sigma but not Ψ is mirrored here: sigma_sigma / mu_sigma also do not govern
Gini. Three structural mechanisms; three distinct governing parameters.

The dissipative inequality finding connects to the cooperative reconstruction
account in `docs/final-report.md`: globally connected configurations show larger
dissipation, consistent with faster cooperative rebuilding reaching distant
network positions.

## Issues Resolved

- **Gini "Remaining questions" item from Stage 008**: fully resolved. The
  `gini_k_final` estimand was characterised across both models; parameter rankings
  were compared to Ψ and ε–degree; the mu0 hypothesis was tested; the section
  extending the final report was written.

## Deferred Items

- **Ψ = 1 threshold under σ heterogeneity**: targeted sweep at small-lambda /
  high-alpha varying dw_obs remains to be done.
- **Bivariate ε–degree correlation**: whether the Stage 003 dissociation holds
  in the bivariate model was not empirically verified.

## Process Notes

- All four tasks were implemented sequentially without interruption.
- No new simulations were required; `gini_k_final`, `gini_peak`, and `t_gini_peak`
  were already present in both raw training datasets from Stage 000.
- `pair_idx` reconstruction in the baseline analysis required replicating the
  `ceiling(row_number() / (2L * n_rep))` logic from `gp_train_utils.R`.
