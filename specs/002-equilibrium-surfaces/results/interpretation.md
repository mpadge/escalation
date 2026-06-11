# Stage 2 Interpretation: When Does Society Amplify Its Own Escalation?

The central question driving Stage 2 is not which parameters make the model sensitive —
that was established across the first two stages — but whether the social dynamics
themselves can amplify a perturbation. If a population starts with a slightly higher
baseline tendency to escalate, does it end up proportionally more escalatory at
equilibrium, or does the social environment act as a dampener, pulling divergent initial
conditions back toward a common outcome? Stage 2 asks that question directly, using the
absolute equilibrium escalation level as the output rather than a derived sensitivity
measure.

The answer is that it depends — and the conditions under which amplification occurs are
structurally specific.

---

## What the absolute surfaces reveal

The two GP emulators trained on E_lo (μ₀=0.4) and E_hi (μ₀=0.6) each describe a
population's mean escalation probability at quasi-equilibrium as a function of the four
structural parameters. Both surfaces are dominated by the same ranking — eta_obs first,
then alpha, then gamma, then lambda — and both validate well.

The most striking feature of the two surfaces compared is how little room there is
between them. E_lo ranges from roughly 0.43 to 0.87 across the parameter space; E_hi
ranges from 0.55 to 0.89. The two surfaces are close together in absolute terms, and
both are substantially elevated above their respective μ₀ starting points. A population
that begins at μ₀=0.4 does not settle near 0.4 — it settles between 0.43 and 0.87
depending on structural conditions. The social dynamics push both populations upward. The
question Ψ answers is whether they push the hi population *further* than they push the
lo population.

Across most of the parameter space, they do not. Ψ < 1 in four of six parameter pairs,
meaning the model characteristically dampens the initial difference: the gap between the
two populations at equilibrium is smaller than the gap they started with. This is the
modal behaviour of the model — a robustness result in itself. The initial 20-percentage-
point difference in starting escalation tendency does not, in general, translate into a
20-percentage-point difference at equilibrium. Most structural environments absorb the
perturbation rather than amplifying it.

---

## Where amplification occurs

Two parameter pairs push past Ψ = 1. In both, lambda — group size — is one of the two
axes. This is not a coincidence.

The `alpha × lambda` pair produces the strongest amplification, with Ψ reaching 1.34 in
one region of the parameter space. The mechanism is coherent with everything established
in Stages 0 and 1: alpha controls how far social influence propagates through the network,
and lambda controls how many agents participate in each encounter. In the amplifying
region — low alpha, low lambda — social influence is local and groups are small. Early
encounters between a handful of agents in a small group, where each agent's behaviour
carries outsized weight, establish a local norm that then propagates only within the
immediate neighbourhood. The hi-μ₀ population enters this regime with enough initial
escalators to seed local dominance hierarchies before cooperative coalitions can form.
The lo-μ₀ population, starting just below the tipping density, does not. The same
structural environment that amplifies for one starting condition dampens for the other.

The `gamma × lambda` pair shows marginal amplification (Ψ_max just above 1.026).
Hierarchical networks — high gamma, hubs with many connections — combined with small
groups produce a condition where the tournament dynamics within groups compound quickly.
High-degree hub agents, when they escalate, radiate prestige signals to large audiences;
this is the mechanism that drives escalation norms outward through the network. In small
groups, each encounter is weighted heavily; hub agents dominate quickly. The hi-μ₀
population seeds these hubs as escalators; the lo-μ₀ population does not quite reach
the threshold density needed.

---

## The role of lambda

Lambda's behaviour across this analysis is worth dwelling on. In Stage 1, lambda had a
long ARD length scale (low GP sensitivity) in the Ψ-based emulator, yet ranked second
by Sobol total-effect index — a tension attributed to lambda acting through interactions
rather than directly. Stage 2 resolves this picture more clearly.

Lambda is inert in the absolute surfaces individually: in both E_lo and E_hi, ell_lambda
is the longest of the four parameters (6.4 and 8.0 respectively). The absolute level of
population escalation at equilibrium is not strongly sensitive to group size, holding
other parameters fixed. But lambda is crucial for *whether the gap between the two
populations closes or widens*. It shapes the dynamics of convergence — how quickly and
completely the social environment homogenises a population's escalation tendency —
without strongly controlling the final level that population settles at.

This is a subtle distinction: lambda does not determine whether a society is high- or
low-escalation at equilibrium. It determines whether an external perturbation to that
society (a shift in the starting distribution) gets absorbed or amplified. In practical
terms: you cannot easily change a society's equilibrium escalation level by changing
group size alone. But whether a sudden increase in escalatory behaviour (a new cohort,
a period of conflict) persists and compounds, or reverts to the prior norm, depends
critically on group size.

---

## The dampening regime is the norm

It is worth being explicit about what the non-amplifying pairs show. In `alpha × eta_obs`,
`alpha × gamma`, and `gamma × eta_obs`, Ψ stays below 1 everywhere. The strongest
observational learning, the most hierarchical networks, and the sharpest distance decay
— when considered without lambda — produce dampening rather than amplification. The
initial perturbation is absorbed.

This has a specific implication for the model's narrative: observational learning of
escalation (eta_obs) does not, on its own, amplify initial differences. It raises the
absolute escalation level — both populations end up more escalatory than they started
— but it does so roughly equally for both starting conditions. The hi-μ₀ population
benefits from high eta_obs, but so does the lo-μ₀ population, and the gap does not
widen. The same logic applies to network topology (gamma): a more hierarchical network
elevates the equilibrium for everyone, without specifically advantaging the already-
escalatory population.

The amplification result requires a structural *bottleneck* — a constraint that forces
the dynamics to operate locally rather than globally. Lambda provides this bottleneck
directly (small encounter groups mean outcomes are decided in a handful of agents).
Alpha provides it indirectly (local distance decay means influence stays local even in
a large population). The two mechanisms are related but distinct: alpha controls spatial
locality in the network, lambda controls the density of encounters. Both concentrate the
social dynamics into small enough units that starting composition — who is in the room
at the beginning — matters more than the global average.

---

## What this means for the original question

The question motivating Stage 2 was whether increases in population-level escalation
tendency produce non-linear responses at equilibrium — whether societies can tip into
self-reinforcing escalation. The answer from this analysis is: yes, but only under
specific structural conditions that are neither universal nor trivial to achieve.

The amplifying regime requires small groups and local influence. A large, well-mixed
population with broad network reach is robustly dampening — perturbations average out.
The danger zone is a population fragmented into small, locally-coupled groups whose
escalation dynamics resolve quickly within each group before the larger social network
can intervene. This is a recognisable description of contexts where escalation norms
are known to be particularly persistent: tightly-knit subgroups, insular communities,
cohorts that interact primarily within themselves.

The practical implication is that interventions aimed at altering escalation equilibria
may need to target structural parameters rather than — or in addition to — the
escalation propensity directly. Increasing group size (lambda) or broadening social
reach (alpha) shifts the population from the amplifying regime to the dampening regime,
making it more resilient to perturbations in either direction. Within the amplifying
regime, even a small initial difference in escalation tendency compounds at equilibrium;
outside it, the same difference is absorbed.
