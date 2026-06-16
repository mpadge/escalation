# Escalation Dynamics in Social Networks: Structure, Sensitivity, and the Limits of Individual Agency

---

## The question

When a social group starts with a higher average tendency to escalate — to
respond to conflict with competitive force rather than accommodation — does the
social environment amplify that tendency, dampen it, or leave it unchanged? And
do the individuals within that group who escalate most readily end up more
powerful, more central in the network of social relationships that distributes
influence and resources?

These are not the same question. A group could become uniformly more escalatory
without power concentrating in the hands of its most escalatory members.
Conversely, a few highly connected escalators could dominate a network without
triggering a population-level escalation norm. The analysis reported here
addresses both questions across two models — a baseline model and an extended
model that adds heterogeneous status sensitivity as a second evolving trait —
and finds that the answers are interestingly asymmetric, and governed almost
entirely by the architecture of the social environment rather than by the
properties of individuals within it.

---

## Three findings

**Finding 1: Population-level amplification is structurally confined.**
Social feedback mostly dampens an initial difference in escalatory disposition.
The amplification ratio — the ratio of the equilibrium escalation gap between
two groups to the gap they started with — exceeds 1 in only two structural
configurations: small encounter groups with strongly localised influence, and
small encounter groups with steep hierarchical rewards. Together these cover
roughly ten to fifteen per cent of the parameter space explored. In all other
configurations, the higher-tendency group ends up more escalatory at
equilibrium, but not proportionally more so. The social environment is a
compressor, not an amplifier.

**Finding 2: Individual power concentration dissociates from population-level
amplification.**
Escalatory agents do gain modestly in network centrality at equilibrium: the
correlation between an agent's escalation propensity and their degree centrality
is positive on average (≈ 0.08) and reaches 0.63 in some structural
configurations. But this advantage is governed by influence locality, not group
size, and the configurations that produce the strongest amplification of
population-level escalation are the same configurations where raising baseline
escalatory disposition most *suppresses* the individual centrality advantage.
When escalation spreads at the population level, it spreads to everyone — it
does not preferentially concentrate power in the hands of the most escalatory.

**Finding 3: Heterogeneous status sensitivity does not create new failure
modes, but it makes the observational environment first-order.**
Adding σ — a second evolving trait that captures how strongly each agent
responds to observed escalatory outcomes — does not introduce a new amplification
regime or alter the dissociation result. Ψ remains below 1 across the bivariate
parameter space at the configurations examined. The σ-perturbation sensitivity
(the effect of marginally increasing mean σ) is positive everywhere but tiny
(0.035–0.056). The key finding from the bivariate analysis is structural: once
agents vary in status sensitivity, the dominant determinant of both Ψ and
σ-sensitivity is observational bandwidth — how broadly escalatory outcomes are
visible across the network — not the distribution of σ itself.

---

## The architecture of escalation dynamics

The three findings share a structural logic. In every analysis, the parameters
that govern escalation outcomes are properties of the social environment —
specifically of how interactions are structured, how influence is distributed,
and how social signals propagate — rather than intrinsic properties of the
agents themselves.

In the baseline model, the two critical structural parameters are group size
(lambda) and influence locality (alpha). Lambda governs whether amplification
is possible at all: across every parameter pair that does not include group
size, the amplification ratio stays below 1. Alpha governs the individual
centrality advantage: influence that stays local enables escalatory agents to
accumulate persistent positional benefits, while globally diffuse influence
continuously rebalances and attenuates those gains. The intrinsic parameters
— individual reward rates, learning rates, direct payoff magnitudes — matter
less than these two architectural facts.

In the extended model with σ heterogeneity, a third structural parameter
becomes prominent: observational bandwidth (dw_obs). This parameter controls
how broadly the visible consequences of escalatory encounters propagate across
the network — how many observers are exposed to a winner's status signal, and
with what intensity. When observational bandwidth is high, σ-mediated social
learning propagates widely and the full range of σ variation matters; when it
is low, agents are insulated from observed outcomes regardless of how responsive
their σ would make them.

The ordering is consistent: sigma_sigma (the dispersion of σ) and mu_sigma
(the mean of σ) rank last among the six parameters for both estimands. Whether
the population is highly dispersed or concentrated in its status sensitivity
matters less than whether the social architecture allows those sensitivities to
be expressed.

This is a strong structural claim: escalation dynamics are architectural, not
individual. The conditions that produce population-level amplification, individual
power concentration, or σ-mediated escalation spread are all determined by how
the social environment is structured — by group composition, interaction reach,
the visibility of outcomes, and the distribution of network influence — not by
the dispositions or sensitivities of the people within it.

![Figure 1: Amplification ratio (Ψ) across group size and influence locality in
the baseline model. The amplification regime (Ψ > 1, upper left) covers roughly
10–15% of the surface. The dominant structural variable is group size
(lambda).](figures/fig1_amplification_alpha_lambda.png)

---

## What σ changes — and what it does not

The extended model activates a new mechanism: observational social learning
mediated by individual status sensitivity. An agent with high σ updates their
escalation propensity strongly from watching others; an agent with low σ is
relatively insulated from social signals, adjusting primarily through direct
experience. When σ varies across the population, the aggregate social learning
rate is a function of both the distribution of σ and the bandwidth of the
observational channel through which σ operates.

What changes when σ is activated: observational bandwidth (dw_obs) enters as
a first-order structural parameter for both Ψ and the σ-sensitivity estimand.
The mechanism is gating: dw_obs controls whether the observational channel is
open at all. High dw_obs with high or variable σ produces a population that
responds strongly to observed outcomes; low dw_obs insulates the population
from observed escalation regardless of how responsive individual agents would
be. This finding — that the observational *architecture* matters more than the
observational *distribution* — is consistent with the broader structural logic
of both models.

What does not change: the qualitative shape of the Ψ surface (alpha remains
second in importance, influence locality remains the dominant driver within the
bivariate parameter range), the absence of a new amplification regime at the
parameter configurations examined, and the cooperative reconstruction mechanism
that prevents winner-takes-all convergence. This last point deserves emphasis.

The reason no analysis produces a fully dominant escalatory hierarchy is that
cooperation generates diffuse network benefits — stronger ties, bridging
connections, group solidarity — that escalation cannot replicate. A cooperative
network position is self-sustaining: both parties have an ongoing incentive to
maintain cooperative ties, and the ties strengthen through interaction. An
escalatory position is extractive: each win comes partly at the expense of the
defeated party's network connections, and the escalator must continuously win
to maintain their positional advantage. The cooperative infrastructure rebuilds
itself around escalatory bottlenecks. This payoff asymmetry is a structural
property of the interaction rules, and σ heterogeneity does not alter it —
adding status sensitivity to the social learning pathway does not change the
fundamental payoff structure that constrains escalation dynamics.

![Figure 2: Ψ (left) and σ-perturbation sensitivity (right) across the
mu_sigma × alpha axis pair in the extended model. The Ψ surface rises with
alpha (influence locality), consistent with the baseline model. The
σ-perturbation sensitivity is nearly flat everywhere, indicating that σ's
effect on escalation dynamics is small and structurally insensitive to both
the σ distribution and the influence structure.](figures/fig4_bivar_mu_sigma_alpha.png)

---

## Practical implications

Two structural failure modes emerge from this analysis, and they do not coincide.

**The amplification failure mode** — where an initially higher escalatory
disposition is amplified into a self-reinforcing norm — requires small encounter
groups combined with either strongly localised influence or steep hierarchical
rewards. The social forms that fit this description are recognisable: tightly
insular subgroups, hierarchical cohorts with high internal density and low
external connectivity, organisations where a small number of individuals control
the conditions for advancement. These are not unusual, but they are specific.
Open networks with diverse group composition, broad interaction reach, and
moderate hierarchy are firmly in the dampening regime.

**The power concentration failure mode** — where escalatory individuals
accumulate disproportionate centrality and network influence — requires
fragmented, locally-connected structures where early wins compound and social
signals travel slowly. This configuration does not coincide with the
amplification regime. In the environments where escalation is most likely to
become a self-reinforcing norm, the advantage it confers on the most escalatory
individuals is smallest, because the norm spreads uniformly rather than
preferentially.

**The observational bandwidth lever** — identified in the extended model —
adds a third structural parameter. High observational bandwidth makes the
population highly responsive to visible escalatory outcomes; when combined with
high mean or variable σ, this propagates both escalatory tendencies and their
social consequences rapidly across the network. Low bandwidth insulates most
agents from observed outcomes, making the population's escalation dynamics
primarily a function of direct experience rather than social learning. Whether
this translates into practical intervention depends on the mechanism of
observational bandwidth in the context at hand — it might be addressed through
transparency of outcomes, norms about public discussion of conflict, or the
architecture of reporting and information flow within an organisation.

The consistent practical implication across all three findings is that the
relevant lever is structural, not individual. The conditions for amplification
(group composition, interaction reach), for power concentration (locality of
influence), and for σ-mediated social learning (observational bandwidth) are all
properties of the social environment that can, in principle, be addressed without
targeting the dispositions or tendencies of individual participants. Escalation
and its consequences are architectural problems, and they call for architectural
interventions.

---

## Remaining questions

Several questions are left open by this analysis.

Whether the Ψ = 1 amplification threshold shifts in the presence of σ
heterogeneity remains unverified. The bivariate analysis did not sample into
the small-lambda / high-alpha configurations where the first analysis found
amplification; a targeted parameter sweep varying dw_obs at those configurations
would determine whether activating σ makes amplification easier or harder to
achieve, and whether observational bandwidth is the critical variable.

The individual centrality advantage under σ heterogeneity was not directly
measured in the bivariate analysis. The structural argument predicts that the
dissociation result from the baseline model should hold — σ does not alter the
payoff mechanism that ties individual power accumulation to influence locality —
but this has not been verified empirically.

Finally, neither analysis characterised the inequality of network centrality at
equilibrium — how concentrated the distribution of connections becomes, not
just whether it correlates with escalatory disposition. A Gini-type measure of
centrality inequality across the parameter space would complement the correlation
measures reported here and might further differentiate the structural conditions
under which escalation produces dispersed versus concentrated network outcomes.
