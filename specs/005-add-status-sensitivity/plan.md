---
created: 2026-06-15T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 058404e834a4c5c511310c4ed95b1b3f3e7d24d8
---

# Plan: add-status-sensitivity

## Overview

Add status sensitivity σ as a second evolving agent trait, making the model bivariate (ε, σ).
σ_i governs how strongly an agent projects status when winning and updates in response to
witnessed dominance. It replaces the global η_obs and Δw_obs parameters, which are retired.

## Context

The existing model is univariate: all interaction probabilities and network effects depend on
a single per-agent escalation propensity ε_i ∈ [0,1]. The primary estimand is
Ψ(θ) = (ε̄(∞)|_{μ₀=0.6} − ε̄(∞)|_{μ₀=0.4}) / 0.2 — sensitivity of equilibrium escalation
to initial mean propensity.

Stages 000–003 established that population-level amplification (Ψ > 1) is confined to small
encounter groups with either localised influence or steep hierarchy. The individual-level
centrality advantage of escalation (ε–degree correlation) is governed primarily by influence
locality (α). These two phenomena dissociate.

The extension motivation: σ gates the observational learning pathway — the cascade by which
a μ₀ perturbation propagates beyond direct participants. Currently this cascade strength is
uniform across agents (fixed η_obs, Δw_obs). Making it a per-agent evolving trait allows
the bivariate estimand Ψ(θ, μ_σ) to be characterised: does the Ψ = 1 phase boundary shift
or steepen as mean status sensitivity μ_σ increases?

## Design Goals

- Introduce σ_i ∈ [0,1] as a first-class per-agent trait initialised independently of ε_i
  from clip(Normal(μ_σ, σ_σ), 0, 1)
- Retire global parameters η_obs and Δw_obs; σ_i replaces both, governing:
  (a) how strongly a winning agent's victory radiates prestige to observers (emission)
  (b) how strongly an observing agent updates edge weights toward the winner (reception)
  σ is unified — no emit/receive split
- σ_i evolves via reinforcement, analogous to ε_i: for agents who were observers (not
  participants) in an encounter, update σ_i by the sign of their net payoff change
- Track the emergent ε–σ correlation as a new output metric; it is expected to become
  positive endogenously even though initialised at zero
- Validate that setting all σ_i to a constant and running the model recovers qualitatively
  equivalent dynamics to the original model (degenerate-σ sanity check)
- Scope: code changes and Phase 1–2 validation only; sensitivity analysis pipeline
  (Morris → Sobol → GP) is deferred to a subsequent stage

## Proposed Approach

### Parameter changes

Keep in `Params`: `eta_obs`, `dw_obs` (retained as global scales — see below)

Add to `Params`:
- `mu_sigma: f64` — initial mean status sensitivity (primary new control variable)
- `sigma_sigma: f64` — initial SD of status sensitivity distribution
- `eta_sigma: f64` — σ learning rate (analogous to η for ε)

`eta_obs` and `dw_obs` are kept as global reference scales. σ_i is a per-agent multiplier
on both. Setting `mu_sigma = 1.0, sigma_sigma = 0.0, eta_sigma = 0.0` recovers the original
model exactly, giving a clean degenerate baseline for validation.

### Agent state changes

Add to `SimState`:
- `sigma: Vec<f64>` — per-agent status sensitivity, same layout as `epsilon`

Initialise: `σ_i ~ clip(Normal(mu_sigma, sigma_sigma), 0, 1)`, independently of ε_i.

### Mechanical changes

**Prestige radiation** (winner w to observer k):

Old: `W_kw += Ω_w · dw_obs · exp(−α · w_kw)`

New: `W_kw += Ω_w · dw_obs · σ_w · σ_k · exp(−α · w_kw)`

`dw_obs` sets the population-level scale; σ_w · σ_k is the per-interaction multiplier.
Status effects require both a projecting winner (σ_w) and a receptive observer (σ_k).

**Observer propensity update** (non-participant witnesses):

Old: `ε_k += η_obs · O_k · exp(−α · w_kw)`

New: `ε_k += η_obs · σ_k · O_k · exp(−α · w_kw)`

`eta_obs` remains the global scale; σ_k multiplies it per-agent.

**σ update rule** (observers only — non-participants):

```
Δσ_k = η_sigma · sign(π_k(t+1) − π_k(t))
σ_k(t+1) = clip(σ_k + Δσ_k, 0, 1)
```

Applied after payoffs are resolved for the timestep. Participants (group members) do not
update σ — the signal is specifically about whether *observing* status interactions was
profitable. σ drift term (analogous to ε's σ_drift) is omitted for now; add if validation
shows σ distributions collapse to boundaries.

### Metrics additions

Add to `MetricSeries` and `RunSummary`:
- `mean_sigma_final: f64` — equilibrium mean status sensitivity
- `var_sigma_final: f64` — equilibrium variance
- `epsilon_sigma_corr_final: f64` — Corr(ε_i, σ_i) at equilibrium (expected to emerge positive)

Add to `RunSummary` for paired runs:
- `psi_sigma: Option<f64>` — (ε̄(∞)|_{μ_σ=hi} − ε̄(∞)|_{μ_σ=lo}) / Δμ_σ, analogous to psi

### Validation plan

**Phase 1 — degenerate-σ recovery**: set `mu_sigma = 1.0, sigma_sigma = 0.0, eta_sigma = 0.0`
(all σ_i fixed at 1); confirm ε dynamics are numerically identical to the original model
with the same seed and parameters. This is an exact equality test, not a qualitative check.

**Phase 2 — σ evolution check**: enable σ updates with small η_sigma; confirm σ
distributions do not collapse and that ε–σ correlation emerges as positive over time.

**Phase 3 — bivariate surface**: run paired ε simulations at several fixed μ_σ levels;
confirm the Ψ surface varies with μ_σ (i.e. μ_σ modulates amplification as hypothesised).

## Open Questions

- Should σ receive a drift term (σ_drift_sigma) to prevent distribution collapse at
  boundaries? Defer: check empirically in Phase 2 validation first.
- The product σ_w · σ_k for prestige radiation produces quadratically weak effects when
  both σ values are small — at mu_sigma = 0.1, radiation is only 1% of the dw_obs scale.
  Monitor whether this suppresses interesting dynamics at low mu_sigma values; if so,
  consider a sqrt or linear formulation instead.
- η_sigma relative to η (direct ε learning rate): should these be coupled (η_sigma = κ_σ · η)
  or treated as independent? Treating as independent for now; add to sensitivity analysis scope
  in the follow-on stage.
