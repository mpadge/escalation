# Status Sensitivity and the Observational Channel: What Heterogeneous σ Adds to Escalation Dynamics

---

## Background: what the first analysis established

An earlier analysis of this model established two findings about the consequences
of increasing a population's baseline tendency to escalate. At the population
level, social feedback is mostly a dampener: a group that starts with a higher
escalatory disposition does not end up proportionally more escalatory at
equilibrium. The amplification ratio — the ratio of the equilibrium gap to the
starting gap between a higher- and lower-tendency group — exceeds 1 in only two
structural configurations, both requiring small encounter groups combined with
either strongly localised influence or steep hierarchical rewards. This accounts
for roughly ten to fifteen per cent of the parameter space explored.

At the individual level, escalatory agents do accumulate slightly more network
centrality at equilibrium, but the advantage is modest on average (mean
correlation ≈ 0.08) and is governed primarily by how locally influence is
distributed in the network. The two effects dissociate: the structural regime
that most amplifies escalation as a population-level norm actively suppresses
the individual centrality advantage, because the norm spreads to everyone rather
than preferentially elevating the most escalatory agents.

The question addressed here is whether adding heterogeneous status sensitivity
to the model changes any of this. Status sensitivity σ captures the degree to
which each agent responds to the observable consequences of escalatory encounters
— how readily they update their own escalatory tendency from watching others win
or lose. When σ varies across agents, some are highly attuned social learners
while others barely register the outcomes of encounters they observe. The
analysis extends the model to incorporate σ as a second evolving trait and asks
how this changes the sensitivity of escalation dynamics to the population's
baseline escalatory disposition.

---

## What σ heterogeneity adds to the model

In the extended model, each agent carries two evolving traits: an escalation
propensity ε (the probability of choosing to escalate in any given encounter)
and a status sensitivity σ (how strongly observational experience shapes that
propensity). σ modulates two mechanisms through which agents learn from others:
direct prestige radiation, in which a winner's status boost ripples outward to
connected observers, and observational learning, in which observers update their
own tendencies based on the payoffs they witness. An agent with high σ is a
highly receptive social learner; one with low σ is largely insulated from social
signals and adjusts their escalatory tendency primarily through direct experience.

The key structural parameters governing this observational channel are not σ
itself but the bandwidth of observation: how broadly escalatory outcomes are
visible across the network, and how strongly bridging connections carry these
signals between different parts of the social structure. In this analysis, these
are captured by `dw_obs` (the weight adjustment applied to the observer's
connection to a winner, scaling the prestige radiation reach) and `dw_bridge`
(the weight applied to indirect bridging ties that form or strengthen when two
agents interact cooperatively). Together these parameters determine whether σ
heterogeneity can amplify the social learning channel across the network or
whether it remains localised within tightly-connected clusters.

The six parameters varied in this analysis are: mean σ (`mu_sigma`), σ
dispersion (`sigma_sigma`), observational bandwidth (`dw_obs`), bridging weight
(`dw_bridge`), influence locality (`alpha`), and group size (`lambda`). The
question is which of these governs the sensitivity of escalation outcomes to a
marginal increase in the population's baseline escalatory disposition — and which
governs the sensitivity to a marginal increase in mean σ itself.

---

## How σ affects the amplification surface

The primary outcome measure — Ψ, the ratio of the equilibrium escalation gap
between two groups differing only in their starting μ₀ — shows a surface that
is qualitatively similar to the first analysis, with alpha (influence locality)
and `dw_obs` (observational bandwidth) as the dominant structural determinants.

Across the mu_sigma × alpha phase diagram, Ψ ranges from 0.021 to 0.714. High
values occur at high alpha — consistent with the first analysis, where influence
locality was the primary driver of the individual centrality advantage and a
necessary ingredient for the amplification regime. Low alpha (globally diffuse
influence) suppresses Ψ across the full range of mu_sigma; even a population
with high mean σ and high σ dispersion does not sustain elevated Ψ when social
influence spreads broadly. The mu_sigma × lambda surface shows a narrower range
(0.172 to 0.394), and the mu_sigma × sigma_sigma surface is nearly flat (0.207
to 0.286): the σ-trait parameters themselves have very little effect on Ψ.

The ordering of parameter importance for Ψ with σ active: `dw_obs` (sensitivity
index 9.7), alpha (5.3), `dw_bridge` (2.5), `sigma_sigma` (1.0), followed by
lambda and mu_sigma at 0.33–0.35. The σ-trait parameters mu_sigma and
sigma_sigma rank last.

Ψ does not exceed 1 anywhere in this analysis. This does not mean that σ
heterogeneity suppresses the amplification regime established in the first
analysis. The phase diagrams here fix non-focal parameters at midpoint values —
including group size (lambda) at a moderate setting and influence structure at
default values that correspond to neither extreme. The first analysis found that
Ψ > 1 requires small encounter groups combined with highly localised influence
or steep hierarchy. Those configurations were not sampled in the bivariate phase
slices reported here. The correct reading is that activating σ heterogeneity
does not *add* a new amplification regime at the parameter ranges explored;
whether it shifts the Ψ > 1 threshold in the small-lambda / high-alpha corner
remains an open question.

What the surface does show is that μ₀ sensitivity remains real throughout the
bivariate parameter space — Ψ is positive everywhere, meaning the higher-tendency
group always ends up more escalatory at equilibrium — and that the structural
determinants of how large this effect is (alpha and `dw_obs`) are consistent
with the first analysis.

![Figure 1: Ψ (left panel) and psi_sigma (right panel) across the mu_sigma ×
alpha axis pair. The Ψ surface rises steeply with alpha (influence locality)
and is nearly flat across mu_sigma. The psi_sigma surface is nearly flat
everywhere.](figures/gp_bivar_mu_sigma_alpha.png)

---

## The σ-perturbation sensitivity

A marginal increase in mean σ always raises Ψ slightly: the σ-perturbation
sensitivity (psi_sigma) is positive across the entire parameter space. But the
effect is small and nearly uniform. Across all three axis pairs examined —
mu_sigma × alpha, mu_sigma × lambda, and mu_sigma × sigma_sigma — psi_sigma
ranges from 0.035 to 0.056. This is a narrow absolute range with no strong
gradient in any direction.

The Gaussian process emulator for psi_sigma assigns `dw_obs` an extreme
dominance: its ARD sensitivity index is 6315, compared to 74 for `dw_bridge`
and 1.56 for `sigma_sigma`. This appears to imply that observational bandwidth
is overwhelmingly the most important parameter for σ-mediated effects. But the
dominance should be read carefully. The total variation in psi_sigma across the
entire design space is 0.035–0.056 — less than two percentage points. The ARD
sensitivity captures relative variation within that range, not the absolute
magnitude of the effect. `dw_obs` is the strongest driver of a small signal,
not a small driver of a large one.

The mechanism is consistent with the model structure. `dw_obs` controls how
broadly observers are exposed to the outcomes of escalatory encounters; when
`dw_obs` is high, a winning escalator's prestige signal reaches many observers,
and σ-mediated social learning propagates widely across the network. When
`dw_obs` is low, most agents are insulated from observed outcomes regardless
of their σ level, so the σ distribution becomes irrelevant to aggregate
dynamics. This explains the dominance: the capacity for σ to matter at all is
gated by how visible escalatory outcomes are to potential observers.

The near-zero Sobol first-order indices (S1 ≈ 0 for all six parameters) are
consistent with this picture. The variance of psi_sigma is driven by interactions
between parameters, not by any single parameter in isolation. But this
interaction structure operates over a very small signal: even in the most
favourable conditions (high `dw_obs`, moderate sigma_sigma), a marginal increase
in mean σ raises Ψ by at most 0.056 — a modest increment on top of a Ψ surface
that already ranges up to 0.7.

![Figure 2: Ψ (left panel) and psi_sigma (right panel) across the mu_sigma ×
sigma_sigma axis pair. Both surfaces are nearly flat, confirming that σ-trait
parameters have little structural effect on either estimand.](figures/gp_bivar_mu_sigma_sigma_sigma.png)

---

## The observational bandwidth finding

The most important result from the bivariate analysis is the prominence of
`dw_obs` as a structural parameter. In the first analysis (Stages 002 and 003),
observational bandwidth was not a top-ranked parameter; the dominant structural
determinants of Ψ were group size (lambda) and influence locality (alpha), and
of individual centrality concentration was influence locality (alpha). The
bivariate analysis changes this: once σ heterogeneity is active, `dw_obs`
becomes the single most important parameter for both Ψ and psi_sigma.

This finding is not a contradiction of the first analysis — the first analysis
screened a different parameter set, and `dw_obs` was screened alongside many
other parameters that had stronger main effects in the univariate model. The
bivariate result is a new finding specific to the σ-active context: when agents
vary in their status sensitivity, the structural factor that governs how much
that variation matters is not the distribution of σ itself but the bandwidth of
the observational channel through which σ is expressed.

The implication is practical. A population where agents vary widely in their
responsiveness to observed social outcomes — some highly attuned, others
indifferent — will not exhibit strong σ-mediated escalation dynamics if the
observational bandwidth is low, regardless of how high or dispersed σ is.
Conversely, a high-bandwidth observational environment (encounters that are
widely visible, whose outcomes are clearly legible and consistently signalled)
enables σ heterogeneity to have its full structural effect. The lever is not
the distribution of individual sensitivities but the architecture of the
observational environment.

---

## Discussion

Three limits of this analysis deserve note.

First, the amplification regime was not re-entered in the bivariate phase
diagrams, because the phase slices fix non-focal parameters at midpoint values
that do not sample into the small-lambda / high-alpha corner where the first
analysis found Ψ > 1. Whether activating σ shifts the Ψ = 1 threshold — and
whether `dw_obs` is the critical variable in that shift — would require a
targeted parameter sweep at small lambda, high alpha, and varying `dw_obs`.
This is a natural follow-on analysis.

Second, the individual-level centrality advantage (the ε–degree correlation that
the first analysis found to be governed by alpha, and dissociated from the
amplification regime) was not re-measured in the bivariate analysis. The
structural argument predicts that the dissociation should hold: the mechanism —
cooperative reconstruction of network ties around escalatory bottlenecks —
operates through the same payoff structure in both the univariate and bivariate
models, and σ heterogeneity adds to the social learning pathway rather than
replacing the tie-formation dynamics. But this was not directly verified.

Third, the psi_sigma signal is small throughout. A marginal increase in mean σ
raises Ψ by at most five or six percentage points under the most favourable
conditions. At the scale of realistic social variation in σ — a substantial
shift in the population's average status sensitivity — the structural effect on
escalation dynamics is present but modest. The practical significance of σ
heterogeneity as a lever for intervention is likely to be smaller than that of
the structural parameters (alpha, lambda, `dw_obs`) that the emulator identifies
as dominant.
