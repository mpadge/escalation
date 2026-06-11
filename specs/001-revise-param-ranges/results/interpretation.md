# Stage 1 Interpretation: What the Revised Ranges Reveal

The first stage of the sensitivity analysis established which parameters matter
and how they interact. Stage 1 asks whether those findings are robust to the
choice of parameter ranges — specifically whether the dominance of the
observational learning channel was a genuine structural result or an artefact of
the ranges chosen for Stage 0.

The answer is nuanced. Some conclusions are stable across both stages. Others
change substantially, and the changes themselves are informative.

---

## What stayed the same

**Distance decay (alpha) is consistently the most important structural
parameter.** It ranked third in Stage 0's Morris screen, first in Stage 0's
Sobol analysis, and first again in both Morris and Sobol in Stage 1. In the
emulator-based analysis, it has the largest first-order index (0.28) of any
parameter — meaning it drives Ψ directly, not only through interactions.

The interpretation remains what it was in Stage 0: distance decay controls
*reach*. Whatever mechanism is generating sensitivity to initial conditions,
alpha determines how far that mechanism propagates through the network. Local
influence (high alpha) means early differences crystallise and persist in
pockets; diffuse influence (low alpha) means they average out. This is the one
finding that survives every methodological variant.

**First-order effects are small everywhere.** As in Stage 0, the direct Sobol
analysis finds that no parameter acts independently. The Sobol S₁ values are
statistically indistinguishable from zero for all six parameters. Individual
sweeps, holding everything else fixed, produce very little change in Ψ. The
model is fundamentally interactive.

**Beta and theta are consistently inert.** Status advantage (beta) ranks fifth
in Morris and fifth by S_T in every Sobol analysis run across both stages.
Audience radius (theta) is sixth or below throughout. Both could reasonably be
fixed at their midpoints without losing much information.

---

## What changed — and why it matters

### The observer edge boost was overestimated in Stage 0

The most striking change between the two stages is the fall of `dw_obs`. In
Stage 0 it ranked first in Morris screening (μ\* = 0.768). In Stage 1 it falls
to seventh (μ\* = 0.333). Its range is unchanged — [0, 0.2] in both stages.
Nothing about the observer edge boost mechanism was altered. What changed was
the range allowed for `gamma`, the network attachment exponent, which widened
from [2, 4] to [1, 5].

This tells a specific story about how the model works. When the network can take
a wide variety of structural forms — from a relatively flat, egalitarian
topology (low gamma) to a steeply hierarchical one dominated by a small number
of high-degree hubs (high gamma) — variation in network structure absorbs a
large share of the variance budget. The observer edge boost matters more when
the network is already structured to amplify transmission; it matters less when
the network itself is the primary variable. Stage 0 held gamma in a relatively
narrow band where it could not absorb that variance, so it all flowed to
`dw_obs`. Stage 1, with gamma free to range more widely, reveals that the
underlying driver of observational norm transmission is the topology through
which norms travel, not the strength of the signal at each encounter.

This does not mean the observer edge boost is unimportant in practice — it
means its importance is *conditional on network structure*. In a world with a
fixed, moderately hierarchical network, dw_obs dominates. In a world where
networks vary substantially in structure, topology dominates.

### Group size emerges as a suppressor

In Stage 0, group size (lambda) ranked eighth in Morris and was not selected for
the Sobol analysis. In Stage 1 it rises to third in Morris, with a strongly
negative directional effect (μ = −0.563), and enters the Sobol design at second
place by total-effect index (S_T = 0.737).

The interpretation is straightforward: large groups dilute the impact of early
aggressive encounters. In a small group, a few early contests can establish a
clear status hierarchy that then self-reinforces. In a large group, the same
encounters are proportionally less salient, the network is harder for any single
norm to saturate, and initial differences average out more readily. Lambda's
rise from obscurity in Stage 0 to second place in Stage 1 is partly because its
range was unchanged and it was always capable of this effect — it simply did not
have enough room to express that effect in Stage 0's parameter landscape, where
the observational learning parameters were already explaining most of the
variance.

The combination of alpha and lambda tells a coherent story: *reach* (alpha) and
*dilution* (lambda) are the two structural properties of the social environment
that most determine whether initial conditions persist. High alpha and low lambda
— local influence in small groups — maximises the lock-in of early aggressive
patterns. Low alpha and high lambda — diffuse influence in large groups — allows
them to dissolve.

---

## Two views of interaction structure

The direct Sobol analysis (14,000 model evaluations) produces a total-effect sum
of approximately 3.4, indicating high interaction. The emulator-based Sobol (one
million evaluations of the trained GP surrogate) produces a total-effect sum of
approximately 1.4, suggesting a substantially more additive surface.

Both analyses are correct, but they are measuring different things. The direct
Sobol is sampling from the full parameter space but with relatively few
evaluations, which makes the bootstrapped confidence intervals wide and the
estimates noisy. The emulator-based Sobol draws on a much larger sample but
filters the response surface through the GP — which, by virtue of its smooth
kernel, naturally suppresses the sharp local interactions that the direct Sobol
picks up.

The honest interpretation is that the truth lies between the two estimates. The
surface has genuine interaction structure — no single parameter drives Ψ alone —
but it is not as wildly non-additive as a total-effect sum of 3.4 would imply.
Alpha and gamma together account for S_T of roughly 0.9 in the emulator
analysis, which is already most of the explainable variance. The rest is divided
among lambda, eta_obs, and beta, with theta contributing almost nothing.

---

## A conflict worth noting

The GP's internal sensitivity ranking (derived from ARD length scales) assigns
lambda a long length scale (ell ≈ 5.1), implying low sensitivity — nearly the
opposite of its Sobol S_T of 0.737. This is not a contradiction but a
reflection of how the two analyses treat interactions. The ARD length scale
measures how rapidly the GP's predictions change as lambda alone varies, holding
other parameters fixed. This is small. Lambda's large Sobol S_T comes almost
entirely from interactions — primarily with alpha and gamma — not from its
direct effect. The GP absorbs those interaction effects into alpha's and gamma's
length scales, where they legitimately belong, since those parameters control the
context in which lambda's effect operates.

The practical implication: if you want to know what happens when you intervene
on lambda in isolation (change group sizes while holding everything else fixed),
the GP ARD is the right guide and the answer is "not much." If you want to know
how much of the model's output variance is attributable to variation in lambda
across realistic conditions, the Sobol S_T is the right guide and the answer is
"quite a lot."

---

## The overall picture, revised

Stage 0 suggested a model with two tiers: a propagation mechanism controlled
by observational learning (dw_obs, eta_obs, alpha) and a background tier of
structural parameters that set the scene. Stage 1 revises this picture.

The network structure tier — gamma (topology) and lambda (group size) — is not
background. It is co-equal with the propagation mechanism. The observational
learning channel is strong, but only in the context of a network that is
structured to amplify it (moderate-to-high gamma, small-to-moderate lambda).
Strip away the structural context and the learning signal is weak.

What this means for the model as a whole is that escalation persistence is a
joint product of social structure and social learning. Neither alone is
sufficient. A highly hierarchical network without active observational learning
may generate status differences but not lock them in. Active observational
learning in a large, flat network may not be able to propagate norms widely
enough to overcome dilution. The sensitive regime — where initial conditions
have lasting consequences — sits at the intersection of structured networks and
active observational transmission.

---

## What remains uncertain

The most important open question left by Stage 1 concerns the status of `dw_obs`
and `eta_obs`. Both are now ranked lower than in Stage 0, and `dw_obs` did not
enter the GP design at all. But the ranking reflects the ranges chosen — and
those ranges were chosen before the analysis, not derived from it. A targeted
follow-up that varies `dw_obs` parametrically within the GP phase diagrams (by
varying the fixed midpoint value rather than expanding the design) would test
whether the fall from first to seventh is a genuine demotion or an artefact of
the new interaction budget.

Similarly, the `eta_obs` range of [0.001, 0.1] may be too wide at the lower
end. Below some threshold, observational learning is effectively absent, and
the GP treats the transition as a local feature rather than a global one. If
the interesting dynamics all occur in [0.01, 0.1], the current range is
spending a large share of the design budget on a regime where nothing
interesting happens. Narrowing this range in a future stage would sharpen the
analysis at the cost of generality.
