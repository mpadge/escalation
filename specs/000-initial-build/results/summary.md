# Sensitivity Analysis: Summary of Conclusions

The three-stage sensitivity analysis asks a single question: **which parameters
determine whether the model's long-run escalation levels are sensitive to where
agents start?** The outcome variable throughout is Ψ — roughly, how much the
final average escalation rate differs between a group that begins slightly more
aggressive and one that begins slightly more cooperative. A large Ψ signals that
initial conditions have lasting consequences; a small Ψ means the system
converges to the same outcome regardless of where it starts.

---

## What we learned from each stage

### Stage 1 — Screening: which parameters matter at all?

The Morris screening tested eleven parameters with a relatively modest number of
model evaluations. Its main purpose was to eliminate parameters that have
negligible influence so that the more expensive analyses can focus on those
that do.

The clearest result from screening is that **how observers respond to conflict
is the dominant channel**. Two parameters that both describe this process came
top: the degree to which social ties strengthen between a bystander and a
tournament winner (the observer edge boost), and the speed at which those
bystanders update their own propensity to escalate in future. Together these
two parameters, both describing the transmission of aggressive norms through
witnessing conflict, produced the largest average effects on Ψ by a noticeable
margin.

Third was **how sharply social influence decays with network distance** —
whether an agent's behaviour is shaped mainly by immediate neighbours or by
contacts further away. Steeper decay (more local influence) raised Ψ, which
makes sense: if influence is local, initial differences persist in pockets
rather than averaging out.

Below these three, a second tier of parameters also showed clear but smaller
effects: the steepness of the social hierarchy (how extreme the most-connected
hubs are), the advantage that higher-status agents have in tournaments, and
the size of the reward for winning a fight. Group size had a notably
*negative* directional effect — larger groups suppress Ψ, presumably because
mixing dilutes whatever initial imbalance exists.

Two parameters were essentially inert: the benefit of cooperative behaviour
and the cost of losing a fight. Both showed near-zero average effects across
the screened range. The audience radius — how far away bystanders can be and
still respond to a conflict — was also marginal.

Edge decay (the rate at which social ties weaken passively over time) was
confirmed separately to suppress Ψ monotonically and smoothly. Because it is
uninteresting to vary — more decay always means less sensitivity to initial
conditions — it was fixed at a moderate value for all remaining analyses.

---

### Stage 2 — Variance decomposition: how do parameters interact?

The Sobol analysis uses far more model evaluations to partition the total
variance in Ψ among parameters and their interactions. Its headline finding is
stark: **no parameter acts independently**.

Every parameter's direct contribution to variance — measured when all other
parameters are held fixed — is statistically indistinguishable from zero.
When you change any single parameter while holding everything else constant,
Ψ barely moves. What drives Ψ instead is the *combination* of multiple
parameters changing together. The total-effect indices (which capture a
parameter's contribution *including* all its interactions) sum to over four
times what they would for an additive model. This is an unusually high degree
of interaction.

**Distance decay (alpha) has the highest total-effect index** — not because it
acts alone, but because it gates everything else. Whether observational
learning spreads widely through the network or stays confined to immediate
neighbours depends on how sharply influence decays with distance. The
mechanism is intuitive: a high observer edge boost and a fast observational
learning rate are only consequential if those observations actually reach
many agents. Distance decay controls that reach. The three pairwise
interactions most likely to carry large effects are:

- **Distance decay × observer edge boost**: locality controls how far the
  structural reinforcement of "winning" radiates
- **Distance decay × observational learning rate**: locality controls how
  many observers update their propensity after witnessing a conflict
- **Observer edge boost × observational learning rate**: these two parameters
  describe the same phenomenon (norm transmission through witnessing) from
  complementary angles and multiply each other's effect

The win payoff turns out to be the most separable of the six parameters —
relatively more of its total effect comes from direct influence rather than
interactions — but it is still predominantly interactive.

The implication is that no single-parameter sweep can characterise the
model's behaviour. The response surface must be explored jointly.

---

### Stage 3 — GP emulation: mapping the full response surface

A Gaussian process surrogate model was trained on 1,000 design points covering
the six-parameter space. The surrogate is accurate enough for ranking and
identifying broad features of the response surface (prediction error is roughly
60% of the outcome's standard deviation across the training set), though its
uncertainty estimates are overconfident. Phase diagrams were produced for all
six pairwise combinations of the four most influential parameters (by the GP's
internal sensitivity estimates), showing the predicted Ψ surface as each pair
varies jointly with the other four held at their midpoint values.

The GP-based sensitivity analysis, which is able to draw on a million notional
evaluations via the trained surrogate, produces a different ranking than the
direct Sobol analysis. **Win payoff and status advantage emerge as the dominant
drivers of total variance** — accounting, by total-effect, for roughly 95% and
69% of the output variance respectively. This appears to contradict the Sobol
ranking (where distance decay was first), but the explanation is
straightforward: the win payoff and status advantage both have wide ranges in
the design (payoff varies across nearly a twenty-fold range; status advantage
varies across an essentially unlimited scale from absent to very strong), while
the observational learning parameters have narrow ranges. When the analysis
integrates over the full parameter space — including the extremes — the payoff
and status parameters sweep through multiple qualitatively different regimes.
At low win payoff the tournament system is nearly neutral; at high win payoff
dominant escalation becomes self-reinforcing and initial conditions become
locked in. This threshold behaviour, spread across a wide range, dominates
the global variance budget.

The observational learning parameters show **sharp local transitions** — a
small change in either can shift Ψ dramatically — but those sharp transitions
are confined to a relatively narrow band of the input space. Most of the
parameter space lies outside that band, so their contribution to global
variance is smaller.

The network hierarchy steepness and the distance decay parameter drop to near
zero in the GP-based ranking. This does not mean they are irrelevant in
practice — it means that *averaged across all possible combinations* of the
other parameters, varying them does not change Ψ much. In specific corners of
the parameter space (particularly when observational learning is active and
influential), network structure matters considerably.

---

## The overall picture

The model has a roughly two-level structure of influence:

**Regime selection** — Win payoff and status advantage jointly determine the
broad dynamical regime. When tournament rewards are high and high-status
agents win consistently, the network reinforces escalation in a self-amplifying
way and initial conditions become locked in. When rewards are modest and status
advantage is limited, conflicts do not concentrate social capital enough to
produce persistent sensitivity. These two parameters determine *whether*
initial conditions matter at all.

**Propagation and diffusion** — Conditional on being in a regime where Ψ is
appreciable, how large it becomes depends primarily on the observational
learning channel. If witnesses to conflict both update their own behaviour and
form stronger social ties with the winner, and if network distance does not
decay too sharply, then the effects of early aggressive encounters spread
broadly and persist. Distance decay acts as a gate on this entire propagation
process.

**What does not matter** — Cooperation benefit and loss cost have negligible
influence on the sensitivity of the system to initial conditions across the
ranges studied. This is perhaps the most striking negative finding: the
cooperative game is essentially irrelevant to whether initial escalation levels
persist. Audience radius is marginal and could be fixed without much loss.

---

## Caveats

The main uncertainty in these conclusions comes from the parameter ranges
chosen for the analysis. The win payoff and status advantage ranges are broad
— arguably broader than realistic — and part of their dominance in the GP
emulation reflects that their ranges include genuinely different dynamical
regimes. If the ranges were tightened to a plausible empirical band, the
observational learning parameters would likely reassert more influence.
Conversely, if those ranges were widened, even more dramatic regime
transitions might emerge.

The GP emulator itself is moderately accurate for point predictions but
systematically overconfident in its uncertainty. The phase diagrams and
emulator-based sensitivity rankings are reliable as qualitative guides but
should not be taken as precise quantitative statements. Validation on a fresh
set of 200 held-out design points gave a prediction error of about 0.63
standard deviations of Ψ — useful for understanding the landscape, not for
precise calibration.
