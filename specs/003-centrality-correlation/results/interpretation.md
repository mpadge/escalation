# Stage 3 Interpretation: Does Escalation Concentrate Network Power?

Stage 2 established that social dynamics can amplify an initial difference in
escalation tendency — that a society starting with slightly more escalatory
agents can end up, at equilibrium, with a disproportionately larger gap between
the two starting conditions. Stage 3 asks a different question: who, within a
given equilibrium, holds the network power? Do high-ε individuals — those who
escalate more readily — end up more central in the interaction network, and does
increasing the population's initial tendency to escalate make that concentration
worse?

The question matters because the aggregate result (Stage 2) and the distributional
result (Stage 3) can point in opposite directions. A social environment could raise
everyone's escalation level without concentrating influence in the most escalatory
individuals; or it could concentrate influence without raising the aggregate. Stage
3 tests whether the two phenomena co-occur.

---

## What the baseline correlation surfaces reveal

The `epsilon_k_corr_final` variable measures whether an agent's escalation
propensity predicts its in-degree at quasi-equilibrium — whether the more
escalatory agents have more connections, on average, once the social dynamics have
run their course. A positive value means that, at equilibrium, network centrality
and escalatory tendency are aligned: those who escalate more readily are also
more connected, more influential, more embedded in the network.

Across most of the parameter space, the correlation is positive. The mean is
approximately 0.08 in both conditions — modest, but consistent with a tendency
for escalatory agents to attract more interaction ties. The surface reaches as
high as 0.63 in some parameter regimes, indicating that under the right structural
conditions the alignment between ε and centrality can be quite strong. Negative
values — regimes where escalatory agents are more *isolated* — do occur but are a
small minority of the design space; both surfaces dip slightly below zero at their
minima.

The parameter governing this surface is `alpha`. Not eta_obs, which dominates
the absolute escalation level in Stage 2. Not lambda, which enables population-
level amplification. The encounter-weight decay parameter — how sharply an
agent's social influence falls off with network distance — is the primary
determinant of whether escalatory individuals end up central or peripheral. Low
alpha means influence stays local and spreads slowly; high alpha means the network
homogenises quickly. In the low-alpha regime, the early encounters between
escalatory agents establish local dominance relationships that crystallise before
the broader network can dissolve them. These agents accumulate ties specifically
because their local influence is high and their early behavioral signals are
strong. In the high-alpha regime, influence is more global, encounters are less
sticky, and the correlation between ε and centrality is attenuated.

Gamma (the reward scaling exponent) is second in importance. Lambda and eta_obs
are both essentially inert — their ARD length scales exceed 1.7 times the
parameter range, meaning the correlation surface is nearly flat across the entire
lambda and eta_obs dimensions. This is the sharpest contrast with Stage 2, where
lambda was the amplification enabler and eta_obs dominated the absolute escalation
level. The same parameters that determine who becomes escalatory (eta_obs) and
whether escalation amplifies at the population level (lambda) are not the
parameters that determine whether escalatory agents end up central in the network.
Those are different parameters entirely.

---

## Whether and where increased μ₀ amplifies the individual-level advantage

Five of six parameter pairs show at least some region where C_hi > C_lo — where
raising μ₀ increases the correlation between ε and centrality. But the positive
differences are consistently small (maximum +0.029 on the correlation scale), and
in most of these pairs the dominant signal is negative: C_hi < C_lo across the
bulk of the space, with only a corner of the grid producing a positive difference.

The one pair that shows no positive difference at all is **gamma × lambda** — the
same pair that produces modest population-level amplification (Ψ_max = 1.026) in
Stage 2. Across the entire gamma × lambda plane, increasing μ₀ reduces the
correlation between ε and centrality. The direction of the effect is uniformly
negative, with a maximum magnitude of −0.080. In this regime, raising the initial
escalation tendency raises the population mean (Stage 2 result) while
*simultaneously* flattening the relationship between individual ε values and
individual network position. The social dynamics become more uniformly escalatory
— the whole distribution shifts — but they do not specifically concentrate
influence in the already-escalatory agents.

The positive diff regions are concentrated in pairs involving `eta_obs`. When
eta_obs co-varies with alpha, gamma, or lambda, there are sub-regions where
higher μ₀ slightly increases the centrality advantage of escalatory agents. The
mechanism is plausible: higher eta_obs means faster observational learning, and
in the C_hi condition there are more escalatory agents for others to observe. If
observational learning is fast enough, the early high-ε agents accumulate ties
before the broader population catches up. But the effect is weak, and it is not
the regime that drives population-level amplification.

---

## How structural parameters shape the individual-level benefit

The structural parameter picture for Stage 3 is cleaner than for Stage 2, because
a single parameter — alpha — accounts for most of the variation. The correlation
surface is steep in the alpha direction and shallow in all others. Low alpha
produces strong ε-centrality correlation; high alpha dissolves it. This is
structurally coherent: local influence networks (low alpha) allow escalatory
agents to accumulate local dominance relationships that persist and compound,
while global influence networks (high alpha) expose every agent to the full
distribution of behaviors, so early escalatory signals are diluted.

Gamma's secondary role refines this picture. High gamma (steep hierarchical
rewards) in combination with low alpha concentrates the very highest correlations
in the surface. When network hierarchy is steep and influence is local, not only
do escalatory agents become more central — they become *increasingly* central,
because every tie they gain amplifies their ability to attract further ties. This
is a mild rich-get-richer dynamic in the network centrality space.

The irrelevance of lambda here is informative. Lambda does not determine whether
escalatory agents become central; it determines whether the gap between populations
widens at equilibrium. These are different questions about different aspects of
the social dynamics. Lambda controls the granularity of encounters and thereby the
speed at which group-level norms form and propagate. This matters for whether two
populations diverge (Stage 2), but not for whether, within a single population,
the within-group distribution of centrality tracks the within-group distribution
of ε. The latter is an intra-population structural question; lambda is an
inter-encounter resolution question.

---

## Relationship to the Stage 2 amplification result

The juxtaposition of Stage 2 and Stage 3 results reveals a dissociation that is
central to interpreting this model.

In Stage 2, the gamma × lambda regime is where population-level amplification
is observed: higher μ₀ leads to a disproportionately larger gap at equilibrium
in steep-hierarchy, small-group environments. In Stage 3, the same gamma × lambda
regime is where the individual-level centrality advantage of escalatory agents is
most reliably *reduced* by increasing μ₀. The two results co-occur in the same
structural regime: social dynamics that amplify the population-level escalation
signal simultaneously suppress the concentration of network influence in
escalatory individuals.

This dissociation makes mechanistic sense. In the gamma × lambda amplification
regime, small groups and steep hierarchical rewards mean that whichever agents
happen to escalate early gain outsized local influence quickly. But precisely
because the rewards are steep and groups are small, the dynamics resolve fast:
the local hierarchy crystallises early, and from that point, even moderately
escalatory agents can maintain high centrality by occupying an established
hierarchical position. The correlation between ε and centrality at equilibrium
is therefore not particularly high — the network position is determined by early
dynamics and maintained by structural inertia, not continuously by ε level.
Raising μ₀ shifts who those early escalators are (there are more of them), and
the rapid crystallisation means that more agents reach moderate centrality sooner,
flattening the correlation. The population average rises (Stage 2 result); the
individual advantage of high-ε agents does not (Stage 3 result).

Contrast this with the alpha-dominated correlation regime. Here, influence is
local and slow to diffuse. Agents accumulate ties gradually, and whether an
agent ends up central is a running function of its behavior over the whole
trajectory, not just the first few encounters. In this regime, ε tracks
centrality persistently: high-ε agents keep accumulating relative to low-ε
agents over the full run. But this regime does not produce population-level
amplification, because the slow diffusion also means the two populations (hi
and lo μ₀) do not diverge quickly — they both settle toward roughly the same
structural outcome, just with the hi population shifted slightly upward.

The implication is that the two phenomena — population-level amplification and
individual-level centrality concentration — are not two aspects of the same
underlying dynamic. They are driven by different mechanisms, in different
structural regimes, and to some extent they trade off against each other. A
structural environment optimised to amplify population-level escalation is not
optimised to concentrate network influence in escalatory individuals, and vice
versa.
