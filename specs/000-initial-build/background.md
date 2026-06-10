# Background: Social Dynamics of Escalation vs. Compromise

## Overview

This project simulates the co-evolution of behavioural propensities and social network structure
in a population of agents who repeatedly choose between escalatory and conciliatory strategies.
The central question is: **which structural and dynamic parameters determine how strongly a
population's long-run behaviour is shaped by its initial disposition toward escalation versus
cooperation?** Formally, the quantity of interest is Ψ(θ) = ∂ε̄(∞)/∂μ₀ — the sensitivity of
long-run mean escalation propensity to initial mean propensity — across the full space of model
parameters θ.

---

## State Space

### Agent state

Each agent i ∈ {1, …, N} carries:

- **ε_i(t) ∈ [0,1]** — escalation propensity; the primary evolving trait. Initialised from
  clip(Normal(μ₀, σ₀), 0, 1).
- **π_i(t) ∈ ℝ** — cumulative payoff (experience ledger). Initialised to 0.

### Network state

- **W(t)** — an N×N matrix of directed, weighted edges. W_ij is the strength of agent i's
  attention/deference toward agent j. Self-edges undefined. Edge weights evolve; graph topology
  (which edges exist) is fixed after initialisation.

### Derived quantities (recomputed each timestep)

- **k_i(t) = Σ_j W_ji(t)** — weighted in-degree; serves as status proxy.
- **d_ij** — shortest topological (hop-count) path from i to j. Fixed at initialisation.
- **w_ij(t)** — weighted distance from i to j; sum of 1/W along the shortest topological path.
  Evolves as W changes.
- **A_i(θ, t) = |{k : d_ik ≤ θ}|** — audience size within hop radius θ of i.

---

## Initialisation

- **Network**: preferential-attachment (Barabási–Albert) with exponent γ. Initial edge weights
  W_ij ~ Uniform(w_min, w_max).
- **Propensities**: ε_i(0) ~ clip(Normal(μ₀, σ₀), 0, 1).
- **Payoffs**: π_i(0) = 0.

---

## Interaction Protocol (each timestep)

1. Select focal agent i* uniformly at random.
2. Draw group size m ~ Poisson(λ) + 1; redraw if m = 1 (minimum group size 2).
3. Sample m−1 partners without replacement with probability:

   > P(j | i*) ∝ exp(−α · w_{i*j}) / Σ_{k≠i*} exp(−α · w_{i*k})

   where w_{i*j} is the current weighted distance and α is the locality parameter. High α
   concentrates interactions among close neighbours; low α approaches uniform selection.

4. Assemble group G = {i*, j₁, …, j_{m-1}}.

---

## Strategy Realisation

Each agent i ∈ G independently draws s_i ~ Bernoulli(ε_i(t)), where s_i = 1 means Escalate (E)
and s_i = 0 means Conciliate (C).

Group profile: n_E = Σ s_i, n_C = m − n_E, φ = n_E / m.

---

## Audience Multiplier

Symbolic capital effects scale with the visible audience. For each focal agent i ∈ G:

> Ω_i = 1 + log(1 + A_i(θ,t) + m − 1) / log(N)

The (m−1) term counts fellow group members as witnesses. The log/log(N) normalisation keeps Ω
dimensionally comparable across population sizes.

---

## Regime Classification

| Regime | Condition | Social analogue |
|---|---|---|
| Consensus Conflict (CC) | φ > 0.75 | Tournament / dominance contest |
| Contested (X) | 0.25 ≤ φ ≤ 0.75 | Negotiation under threat |
| Consensus Cooperation (CK) | φ < 0.25 | Collective action / alliance |

---

## Payoff and Network Update Rules

### Consensus Conflict (φ > 0.75)

**Conciliator pile-on**: each conciliator q absorbs cost from all escalators:

> π_q ← π_q − n_E · e

For each escalator p, conciliator q pair:

> W_qp ← W_qp + Δw_sub &nbsp;&nbsp;&nbsp;&nbsp; (subordination)  
> W_pq ← W_pq − δ_exploit &nbsp;&nbsp;&nbsp; (exploiter devalues)

**Dominance tournament** among escalators E_G:

Iterate until one winner w remains:
1. Sort E_G by k_i descending.
2. Pair sequentially: (1st vs 2nd), (3rd vs 4th), …
3. For each pair (p, q) with k_p ≥ k_q: P(p beats q) = σ(β · (k_p − k_q)) where σ is logistic.
   - Winner p: π_p ← π_p + w_win − c; loser q: π_q ← π_q − w_loss − c
   - W_qp ← W_qp + Δw_sub (loser defers); W_pq ← W_pq − δ_direct (winner devalues)
4. Repeat with survivors.

**Winner prestige radiation** to all observers O = {k : d_kw ≤ θ} ∪ G \ {w}:

> W_kw ← W_kw + Ω_w · Δw_obs · exp(−α · w_kw) · I(k ∉ G) + Ω_w · Δw_obs · I(k ∈ G)  
> W_kl ← W_kl − Ω_l · Δw_obs · exp(−α · w_kl) · (1 − ε_k) &nbsp;&nbsp;&nbsp; [for each loser l]

**Victory bridging**: winner w acquires weak edges into losers' neighbourhoods. For each loser l,
for each neighbour n of l (n ≠ w, n ∉ G):

> W_wn ← W_wn + Δw_bridge · exp(−α · w_wn) &nbsp;&nbsp;&nbsp; if W_wn < w_max

---

### Contested Regime (0.25 ≤ φ ≤ 0.75)

1. **E→C exploitation** (sorted by ε_i descending, greedy pairing to nearest conciliator):
   - π_p ← π_p + e; π_q ← π_q − e
   - W_qp ← W_qp + Δw_sub; W_pq ← W_pq − δ_exploit
   - Observer updates with reduced multiplier Ω' = Ω · ρ_contested

2. **Residual E→E tournament** among unpaired escalators, same logic as CC but with Ω' throughout.

3. **C solidarity** among unexploited conciliators C_free:
   - For each pair (q_a, q_b) ∈ C_free:
     π_{q_a,b} ← π_{q_a,b} + b · (n_{C,free} / m)
   - W_{q_a q_b} ← W_{q_a q_b} + Δw_coop (symmetric)
   - Bridging: for each (q_a, q_b), add weak edges to q_b's neighbours not yet connected to q_a

4. **Lone hawk penalty** (if n_E = 1):
   W_pq ← W_pq − Δw_excl; W_qp ← W_qp − Δw_excl &nbsp;&nbsp;&nbsp; for all q ∈ C_free

---

### Consensus Cooperation (φ < 0.25)

- **Cooperative payoff**: π_i ← π_i + b · log(1 + n_C) for all cooperators i.
- **Mutual edge strengthening**: W_ij ← W_ij + Δw_coop for all pairs (i,j) ∈ C_G (symmetric).
- **Full group bridging**: all pairwise bridges form among C_G to outside neighbours.
- **Escalator exclusion**: W_pq ← W_pq − Δw_excl; W_qp ← W_qp − Δw_excl for each p ∈ G with
  s_p=1.

---

## Propensity Update

After all payoffs are resolved, for each i ∈ G:

> Δε_i = η · R_i + η_obs · O_i + ξ_i  
> ε_i(t+1) = clip(ε_i(t) + Δε_i, 0, 1)

where:
- η — direct learning rate
- R_i — direct reinforcement: +1 if played E and π gained; −1 if played E and π lost; signs
  reversed for C
- η_obs — observational learning rate (η_obs < η)
- O_i — mean reinforcement sign of same-strategy agents observed in G
- ξ_i ~ Normal(0, σ_drift) — stochastic drift

**Observer propensity updates** for k ∈ O \ G (non-participant witnesses):

> ε_k ← clip(ε_k + η_obs · O_k, 0, 1)

where O_k = +sign(admiration signal) for escalatory observers, −sign(solidarity signal) for
conciliatory observers, weighted by exp(−α · w_kw).

---

## Network Decay

Applied globally after each timestep:

> W_ij(t+1) ← max(W_ij(t) · (1 − δ), w_min) &nbsp;&nbsp;&nbsp; ∀i,j

---

## Full Parameter Table

| Parameter | Symbol | Suggested range | Role |
|---|---|---|---|
| Population size | N | 100–1000 | Scale |
| Network exponent | γ | 2–4 | Initial hierarchy steepness |
| Initial propensity mean | μ₀ | 0–1 | **Primary sensitivity variable** |
| Initial propensity SD | σ₀ | 0.1–0.4 | Behavioural diversity |
| Mean group size | λ | 1–5 | Interaction scope |
| Locality | α | 0–2 | Interaction reach |
| Audience radius | θ | 1–4 | Prestige propagation distance (hops) |
| Status advantage | β | 0–3 | Winner-takes-all strength |
| Conflict cost | c | 0–1 | Escalation self-limiting pressure |
| Win payoff | w_win | 0–2 | Escalation reward |
| Loss payoff | w_loss | 0–2 | Escalation risk |
| Exploitation payoff | e | 0–1 | E–C asymmetry |
| Cooperation benefit | b | 0–2 | Conciliation reward |
| Subordination weight | Δw_sub | 0–0.3 | Follower link strength |
| Cooperation weight | Δw_coop | 0–0.3 | Bond strengthening |
| Bridging weight | Δw_bridge | 0–0.2 | Reach expansion rate |
| Observer weight | Δw_obs | 0–0.2 | Prestige radiation strength |
| Exclusion weight | Δw_excl | 0–0.2 | Isolation penalty |
| Direct decay | δ_direct | 0–0.1 | Winner devalues loser |
| Exploit decay | δ_exploit | 0–0.1 | Exploiter devalues victim |
| Edge decay | δ | 0–0.05 | Network forgetting rate |
| Edge floor | w_min | 0–0.1 | Latent social memory |
| Edge ceiling | w_max | 1–5 | Maximum bond strength |
| Direct learning rate | η | 0–0.2 | Propensity update speed |
| Observational learning rate | η_obs | 0–0.1 | Vicarious learning speed |
| Drift SD | σ_drift | 0–0.05 | Stochastic exploration |
| Contested discount | ρ_contested | 0.3–0.8 | Distraction in mixed groups |
| Trauma sensitivity | η_trauma | 0–0.2 | Exploitation-driven ε shift |

Total: 28 parameters including μ₀.

---

## Measurement Schedule

Compute at each timestep t:

| Metric | Formula |
|---|---|
| Mean escalation | ε̄(t) = N⁻¹ Σ_i ε_i(t) |
| Propensity variance | Var(ε)(t) |
| Status Gini | G(t) = Gini({k_i(t)}) |
| ε–status correlation | ρ(ε, k)(t) = Corr(ε_i, k_i) |
| Network modularity | Q(t) — partitioned by ε_i > 0.5 |
| Mean edge weight | W̄(t) = (N(N−1))⁻¹ Σ_{i≠j} W_ij(t) |
| Rich-club coefficient | Φ(k)(t) — standard weighted rich-club |
| Cooperative cluster size | max clique size among {i : ε_i < 0.5} |
| Encounter regime distribution | (f_CC, f_X, f_CK)(t) |

---

## Sensitivity Analysis Strategy

### Estimand

The primary estimand is:

> Ψ(θ) = (ε̄(∞)|_{μ₀=0.6} − ε̄(∞)|_{μ₀=0.4}) / 0.2

estimated via **paired simulation runs** sharing identical θ and random seed, differing only in
μ₀. Taking the contrast cancels much of the run-to-run noise, yielding a lower-variance estimator
than ε̄(∞) itself.

A secondary metric is:

> τ_Ψ — timestep at which |ε̄(t)|_{μ₀=0.6} − ε̄(t)|_{μ₀=0.4}| drops below threshold ζ

capturing the *persistence* of μ₀ influence rather than just its asymptotic magnitude.

### Parameter classes with respect to Ψ

- **Amplifiers**: parameters that increase Ψ, meaning dynamics are weak and initial conditions
  persist. Candidates: high δ, low β, low b/e, high σ_drift.
- **Attractor-dominators**: parameters that decrease Ψ by creating strong basins. Candidates:
  high β, high b, strong Δw_obs, low δ.
- **Moderators**: parameters that increase Var(Ψ) — creating path-dependence or bistability.
  Candidates: α (echo chambers), γ (hub presence), ρ_contested.

### Staged analysis

| Stage | Method | Runs | Purpose |
|---|---|---|---|
| 0 | Analytical reduction | 0 | 28 → ~12 effective parameters via ratio reparametrisation |
| 1 | Morris screening on Ψ | ~150 | Identify the ~6 parameters that most control μ₀ sensitivity |
| 2 | Sobol indices (S_i, S_Ti, S_ij) | ~30,000 | Quantify main effects, interactions, and second-order terms |
| 3 | GP emulation of Ψ(θ) | ~500–1000 (training) | Cheap phase diagram; locate parameter regimes where μ₀ matters |

### Parameter reduction (Stage 0)

Several parameters enter the model only as ratios:
- Payoffs: reparametrise to w_win/c (escalation return-to-cost), b/e (cooperation vs exploitation
  advantage), w_loss/w_win (risk-reward asymmetry). Saves 1 degree of freedom.
- Edge update weights: collapse Δw_obs/Δw_coop and Δw_bridge/Δw_sub to contrast ratios. Saves
  2–3 degrees of freedom.
- Observational learning: fix η_obs = κ·η, making κ the free parameter.
- Decay parameters: collapse δ_direct, δ_exploit, δ to a shared scale plus two relative ratios.

After reduction: ~12 free parameters. Fix w_min, w_max, σ_drift, ρ_contested at central values
after a quick one-at-a-time screen; this leaves ~8 parameters for Sobol.

---

## Theoretical Predictions

1. **Phase transition**: a critical β/c ratio likely separates escalation-cascade regimes from
   cooperative-cluster regimes, analogous to the hawk-dove ESS.
2. **Rich-club trap**: hubs formed through E–E wins gain higher k_i, increasing future win
   probability — lock-in unless cooperative bridging routes around them.
3. **Locality paradox**: high α may protect cooperative clusters or reinforce local dominance
   hierarchies depending on initial conditions.
4. **Inequality-aggression feedback**: as Gini(k) rises, low-degree agents face worse E–C odds
   and may shift strategy in either direction.
5. **Contested regime as evolutionary engine**: mixed-φ encounters generate the most varied
   propensity updates, maintaining ε diversity and driving adaptation.
