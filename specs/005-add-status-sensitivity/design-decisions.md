---
created: 2026-06-15T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 68110d5a1877cb909c5e6d8ba59fa7b681649936
---

# Design Decisions: Stage 005 — Add Status Sensitivity

## Summary

Stage 005 extends the simulation kernel from a univariate (ε) to a bivariate (ε, σ)
agent model, where σ is a per-agent status sensitivity trait that multiplies the
existing prestige radiation and observational learning pathways. Three validation tests
confirm degenerate recovery, distribution stability, and endogenous ε–σ correlation.

## New Design Decisions

### Decision 1: σ as the second agent trait
**Chosen:** Status sensitivity σ_i ∈ [0,1], rather than bond/bridge orientation (β)
or reciprocity orientation (ρ), as the second evolving trait.
**Rationale:** σ directly gates the observational cascade — the mechanism by which a
μ₀ perturbation propagates. β and ρ affect network topology but do not control cascade
conductivity. This makes σ the most direct lever on the bivariate estimand Ψ(θ, μ_σ).
**Tradeoffs:** σ and ε will correlate endogenously; treated as a feature, not a flaw.
**Proposed by:** joint
**Relates to:** Stage 003 finding that alpha (influence locality) governs individual
centrality concentration; σ is expected to interact with alpha through the same pathway.

### Decision 2: Global scales retained; σ as per-agent multiplier
**Chosen:** eta_obs and dw_obs are kept as global reference parameters. σ_i multiplies
both: prestige radiation = `Ω_w · dw_obs · σ_w · σ_k · exp(...)` and observer propensity
update = `eta_obs · σ_k · O_k · exp(...)`. Setting mu_sigma=1.0, sigma_sigma=0.0,
eta_sigma=0.0 recovers the original model with numerical exactness (verified by T005-8).
**Rationale:** Retiring globals entirely (Option B) was initially proposed for cleanliness,
but rejected after identifying that mu_sigma=0 under that scheme gives zero observational
effects — not original-model behaviour. Retaining globals as scales gives a clean
degenerate baseline and avoids reparametrisation collinearity.
**Tradeoffs:** mu_sigma and eta_obs cannot be independently varied in sensitivity analysis
without care; flagged for the follow-on sensitivity stage.
**Proposed by:** mpadge (identified gap); agent (proposed fix)

### Decision 3: Unified σ with product formulation
**Chosen:** Single σ_i applies to both emission and reception. Prestige radiation uses
σ_w · σ_k (product), meaning status effects require both a projecting winner and a
receptive observer.
**Tradeoffs:** Effect scales quadratically with σ at low values; a sqrt or linear
formulation may be needed if low-μ_σ runs show insufficient sensitivity. Noted as an
open question.
**Proposed by:** mpadge

### Decision 4: Vicarious σ reinforcement + sigma_decay
**Chosen:** Non-participant observers update σ by sign(winner_payoff_delta) · eta_sigma.
A global sigma_decay parameter (default 0.002) applied each timestep prevents saturation.
**Rationale:** Observer payoff does not change within a single timestep (non-participants
receive no direct payoff), so winner payoff gain is used as a vicarious reinforcement
proxy. Without decay, σ drifts monotonically to 1.0 for all agents (confirmed empirically
by T005-9 failure before sigma_decay was added).
**Tradeoffs:** sigma_decay is an additional free parameter; its sensitivity is deferred
to stage 006. The plan prescribed decay as a contingency if validation showed collapse.
**Proposed by:** agent

### Decision 5: Stage scope — code and validation only
**Chosen:** Stage 005 covers Rust code changes and three validation tests only. The
sensitivity analysis pipeline (Morris → Sobol → GP) for the bivariate model is deferred.
**Rationale:** σ update rule complexity warranted isolated validation before scaling.
**Proposed by:** mpadge

## Integration with Prior Work

The bivariate extension sits entirely within the Rust simulation kernel (Stage 000
architecture). The existing MetricSeries / RunSummary / CSV pipeline is extended with
four new fields (mean_sigma_final, var_sigma_final, epsilon_sigma_corr_final, psi_sigma)
following the same patterns established in Stages 000–003. The R analysis pipeline is
unaffected by this stage.

The key motivating context is Stage 003's dissociation finding: population-level
amplification and individual-level centrality concentration are governed by different
parameters. σ is expected to interact with the alpha (influence locality) pathway
identified in Stage 003 as the dominant driver of individual concentration.

## Issues Resolved

- **Backward compatibility**: Resolved by retaining eta_obs/dw_obs as global scales with
  mu_sigma=1.0 as the degenerate recovery point.
- **σ saturation at 1.0**: Resolved by adding sigma_decay, identified empirically during
  validation test T005-9.

## Deferred Items

- Sensitivity analysis (Morris → Sobol → GP) for the bivariate (ε, σ) model — stage 006.
- Whether sigma_decay warrants coupling to eta (kappa-style ratio) or independent treatment.
- Whether σ_w · σ_k product is appropriate at low μ_σ, or whether a sqrt/linear
  formulation is needed.
- psi_sigma (sensitivity of ε̄(∞) to μ_σ perturbation) is populated as None in RunSummary;
  the paired-run infrastructure is ready but not yet exercised.

## Process Notes

- The σ update rule was the hardest design question: "sign of net payoff change for
  observers" is ambiguous when observers receive no direct payoff within a timestep.
  Vicarious reinforcement (winner's payoff as proxy) was adopted as the tractable
  interpretation.
- sigma_decay was not in the original task list but was added after T005-9 revealed
  monotonic σ drift. The plan explicitly anticipated this contingency.
