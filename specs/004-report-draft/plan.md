---
created: 2026-06-12T12:30:00Z
agent: claude-sonnet-4-6
git_hash: a938c4a2320aa587b04a674f98da674ac5819e70
---

# Plan: report-draft

## Overview

Write a ~3,000-word research memo addressed to a broad social-science audience,
synthesising the Stage 2 and Stage 3 findings into a coherent answer to the
question: *What are the effects of increases in the average probability of
escalation?* The report treats the modelling results as finished endpoints —
no developmental history, no technical GP details — and foregrounds the
qualitative interpretation, particularly the payoff asymmetry between escalation
and cooperation and its role in preventing runaway hierarchical convergence.

## Context

Stage 2 established that social dynamics can amplify an initial increase in
escalation propensity (Ψ > 1), but only in a structurally specific regime:
small encounter groups combined with either strongly local network influence
(alpha × lambda) or steep hierarchical reward structure (gamma × lambda). Across
most of the parameter space, the system dampens perturbations. Lambda (group
size) is the enabling variable for amplification; the effect disappears in all
pairs that do not include lambda.

Stage 3 established that escalatory individuals tend to become more central in
the interaction network at equilibrium (positive ε–degree correlation), but this
advantage is governed by alpha (encounter-weight decay) rather than lambda, and
is weak on average (mean correlation ≈ 0.08). Crucially, the regime where the
population-level amplification is strongest (gamma × lambda) is the same regime
where increasing μ₀ *reduces* individual-level centrality concentration — the
two effects are dissociated.

Neither analysis has examined regime distributions (CC / X / CK fractions) or
Gini trajectories; the report works from what is available.

## Design Goals

1. Answer the central question in plain language: under what conditions does
   more escalation beget more escalation, and does escalatory behaviour
   concentrate power in the individuals who exhibit it?

2. Frame the findings as condition-dependent rather than as a blanket
   confirmation or refutation of the hypothesis. Assess qualitatively how
   restrictive the amplification conditions are — i.e. whether the Ψ > 1 regime
   is likely to be encountered in practice or represents a narrow edge case.

3. Build the narrative around the payoff asymmetry: escalation offers
   individual-encounter advantages but generates systemic costs; cooperation
   provides diffuse stabilisation that prevents winner-takes-all convergence
   to a single dominant hierarchy. Ground this in the model mechanics only
   where unavoidable for the argument.

4. Make the dissociation between population-level amplification and individual
   centrality concentration the conceptual centrepiece — this is the finding that
   most directly addresses the original hypothesis and is most likely to be
   surprising to a social-science audience.

5. Leave the door open for future expansion (Gini trajectories, regime
   distributions, longer time horizons) without promising it.

## Proposed Approach

**Structure** (approximate word allocations):

1. **Opening** (~200 words): frame the question. Escalation is socially costly
   but individually tempting; the puzzle is whether social feedback amplifies or
   absorbs individual-level escalatory tendencies at the population level.

2. **The model in brief** (~300 words): describe what the simulation captures
   without technical detail — agents in a social network, repeated interactions,
   reputation and edge weights as the memory of past behaviour, two regimes of
   interaction outcome (escalation vs cooperation/conciliation). Emphasise the
   payoff asymmetry: escalation wins locally but degrades the cooperative
   infrastructure; cooperation is slower but builds durable network ties.

3. **Does more escalation beget more escalation?** (~700 words): Stage 2
   findings. The amplification question. Present the Ψ surface result: most
   of parameter space is dampening; amplification exists but is structurally
   confined. Describe the two amplifying pairs (alpha × lambda, gamma × lambda)
   in plain language. Assess practical likelihood: small isolated groups with
   local influence or steep hierarchy are recognisable social forms, but they
   are not the default — they represent specific institutional conditions
   (tightly-knit subgroups, insular organisations, hierarchical cohorts).

4. **Does escalation concentrate power?** (~700 words): Stage 3 findings.
   The centrality question. Present the ε–degree correlation result: positive
   on average but modest; governed by alpha (structural locality), not by the
   same parameters that drive amplification. Deliver the dissociation finding:
   the regime that amplifies the population-level signal actively suppresses
   the individual-level centrality advantage. Interpret: in the conditions where
   escalation spreads most effectively as a norm, it spreads to everyone — it
   does not preferentially elevate the most escalatory individuals.

5. **Why cooperation prevents runaway convergence** (~600 words): the payoff
   asymmetry narrative. Cooperation produces diffuse network benefits (edge
   strengthening, bridging ties, group solidarity) that are not available to
   escalators. Even when escalation is individually profitable in specific
   encounters, the cooperative infrastructure rebuilds after each confrontation.
   The model does not converge to a single dominant escalatory hierarchy because
   conciliators continuously reconstitute their own network ties; the escalatory
   network advantage is real but bounded. Connect this to the empirical finding
   that the ε–degree correlation rarely exceeds 0.3 across most of parameter
   space.

6. **Discussion and caveats** (~500 words): what was not examined (Gini
   trajectories, regime distributions, longer time horizons). Qualitative
   limits of the amplification regime. Implications for understanding escalation
   dynamics in real organisational or social contexts.

**Tone**: accessible research memo. No equations, no model acronyms on first
use without definition, no references to GP emulators or ARD length scales.
Model jargon (μ₀, Ψ, alpha) to be rendered in plain-language descriptions on
first use, with parenthetical technical labels only where needed for precision.

**Source material**: `specs/002-equilibrium-surfaces/results/` and
`specs/003-centrality-correlation/results/` — specifically `summary.md`,
`interpretation.md`, and `gp.md` from each stage.

**Outputs**:
- `docs/report.md` — the memo itself
- `docs/plot_report.R` — standalone figure-rendering script; sources
  `analysis/plot_utils.R`; reads phase CSV files from `results/gp_phase2/`
  and `results/gp_phase3/`; writes final figures to `docs/figures/`
- `docs/figures/*.png` — only the figures cited in the report

## Open Questions

1. **Practical likelihood of the Ψ > 1 regime**: the report needs a qualitative
   argument for whether small-group / local-influence conditions are common or
   rare in the kinds of social contexts this model is meant to represent. This
   will be written as a judgment call from the model structure, not from
   empirical data.

2. **Payoff asymmetry framing**: the claim that cooperation "stabilises" the
   system rests on the model mechanics (cooperative payoffs, bridging ties,
   solidarity bonuses). Whether to cite specific payoff parameters or keep this
   entirely qualitative is to be decided during drafting; lean toward qualitative
   unless a specific number is needed for the argument.

3. **Which figures to include**: figures should be included wherever they
   materially strengthen the narrative. Candidates: the alpha × lambda Ψ surface
   (amplification regime), the gamma × lambda Ψ surface (marginal amplification),
   and the gamma × lambda diff surface (the dissociation result — the centrepiece
   finding). A `docs/` subdirectory will hold both the report and a standalone
   `docs/plot_report.R` script that sources `analysis/plot_utils.R` and renders
   only the figures actually cited in `docs/report.md`, writing them to
   `docs/figures/`. This keeps the report self-contained and reproducible without
   re-running the full pipeline.
