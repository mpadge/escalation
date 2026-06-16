---
created: 2026-06-16T14:35:00Z
agent: claude-sonnet-4-6
git_hash: 378ec39318ef8f7f2bd6cbccfa66a02bbf4551a8
---

# Plan: bivar-report

## Overview

Produce two written outputs from the Stage 007 bivariate GP results:

1. **`docs/008-second-report/report.md`** — a ~2,500-word research memo
   reporting the Stage 007 findings: how σ heterogeneity (status sensitivity
   as a second evolving trait) modifies escalation dynamics. Structured like
   the Stage 004 report but addressed to the same broad social-science audience.
   No references section; no `.myst` or `.bib` files.

2. **`docs/final-report.md`** — a ~2,000-word synthesis document combining
   the Stage 004 and Stage 008 findings into a single integrated account of
   what determines escalation dynamics in the full bivariate model. This is
   the primary deliverable: a standalone document that supersedes both
   individual reports.

Both documents are plain `.md` files with no citations block.

## Context

Stage 004 produced `docs/004-first-report/report.md`, reporting Stages 002 and
003: (a) population-level amplification of escalation is structurally confined
to small-group / local-influence or small-group / steep-hierarchy configurations
(Ψ > 1 in roughly 10–15% of parameter space); (b) escalatory individuals gain
modestly in network centrality (mean ε–degree correlation ≈ 0.08, up to 0.63 in
local-influence configurations), governed by alpha (influence locality); (c) the
two effects dissociate — the amplification regime is the same regime where higher
μ₀ *reduces* individual centrality concentration.

Stage 007 added a second agent trait σ (status sensitivity) and trained two GPs
over the 6 bivariate Sobol parameters (mu_sigma, lambda, sigma_sigma, dw_obs,
dw_bridge, alpha). Key quantitative results:

**GP ARD sensitivity (1/ell; higher = more sensitive):**

psi_sigma (σ-perturbation sensitivity):
- dw_obs: 6315 (overwhelmingly dominant)
- dw_bridge: 74
- sigma_sigma: 1.56
- mu_sigma, alpha, lambda: 0.25–0.40

psi (μ₀-sensitivity with σ active):
- dw_obs: 9.70
- alpha: 5.30
- dw_bridge: 2.51
- sigma_sigma: 1.00
- lambda, mu_sigma: 0.33–0.35

**Phase surface ranges:**

psi:
- mu_sigma × alpha: [0.021, 0.714] — widest; alpha dominates as in Stage 002
- mu_sigma × lambda: [0.172, 0.394]
- mu_sigma × sigma_sigma: [0.207, 0.286] — very flat

psi_sigma:
- all three axis pairs: [0.035, 0.056] — extremely flat, nearly uniform positive

Ψ does not exceed 1 anywhere in the bivariate design space. σ heterogeneity does
not create a new amplification regime; it raises the floor without enabling Ψ > 1
at the midpoint parameter configuration used for phase slices.

## Design Goals

1. **Second report** (`docs/008-second-report/report.md`): answer *What does σ
   heterogeneity add to escalation dynamics?*
   - dw_obs (observational bandwidth) dominates both estimands — a new finding
     not present in Stages 002/003, which screened a different parameter set
   - psi_sigma is small and flat (0.035–0.056): σ sensitivity is a weak,
     interaction-driven phenomenon; the extreme dw_obs dominance is relative,
     not absolute
   - psi with σ active is qualitatively similar to Stage 002 (alpha second),
     but does not reach Ψ > 1 at midpoint configuration
   - σ-trait parameters (mu_sigma, sigma_sigma) rank last among the six inputs

2. **Final synthesis** (`docs/final-report.md`): unified account across both
   analyses. The unifying claim: escalation dynamics are governed by network
   architecture (alpha, lambda, dw_obs), not by intrinsic agent properties.
   σ heterogeneity makes the observational pathway first-order without changing
   the fundamental structural drivers or enabling new failure modes.

## Proposed Approach

### docs/008-second-report/report.md (~2,500 words)

1. **Opening** (~150 words): recap Stage 004 findings briefly; introduce the σ
   extension question.
2. **What σ heterogeneity adds to the model** (~400 words): plain-language
   description. σ scales each agent's responsiveness to observing others escalate.
   Heterogeneous σ means the population varies in social attunement.
3. **How σ affects the amplification surface** (~600 words): psi with σ active,
   dominated by alpha and dw_obs. Shape qualitatively similar to Stage 002; no
   new amplification regime found. σ-trait parameters rank last.
4. **The σ-perturbation sensitivity** (~600 words): psi_sigma tiny and flat.
   dw_obs extreme dominance (relative); the capacity for σ-mediated propagation
   is set by observational bandwidth. In absolute terms the signal is small.
5. **The observational bandwidth finding** (~400 words): dw_obs first-order for
   both estimands once σ is active. New finding specific to the bivariate model.
   High dw_obs: σ-mediated social learning propagates widely. Low dw_obs:
   insulation from observed escalation regardless of σ distribution.
6. **Discussion** (~350 words): limits of this analysis (midpoint slices; the
   Stage 002 amplification regime was not re-entered); connection to Stage 003
   dissociation. Deferred: targeted sweep at small-lambda/high-alpha with
   varying dw_obs to test whether the Ψ > 1 threshold changes with σ.

Figures: copy `gp_bivar_mu_sigma_alpha.png` and `gp_bivar_mu_sigma_sigma_sigma.png`
from `results/plots/` into `docs/008-second-report/figures/` via a `plot_report.R`
script (or direct copy; no re-rendering needed since PNGs already exist).

### docs/final-report.md (~2,000 words)

Standalone synthesis; does not assume prior reports have been read.

1. **The question**: do social environments amplify or absorb escalatory
   tendencies — at population and individual levels — and does introducing
   heterogeneous status sensitivity change this?
2. **Core findings** (three numbered): amplification is structurally confined
   (Stage 002); power concentration dissociates from amplification (Stage 003);
   σ heterogeneity makes observational bandwidth first-order without enabling
   new amplification (Stage 007).
3. **The architecture of escalation dynamics**: unified argument that all three
   findings reduce to network-architecture parameters. Agent-intrinsic properties
   (mean σ, σ dispersion, individual escalation propensity) rank last consistently.
4. **What σ changes — and what it does not**: σ introduces the observational
   pathway as a structural variable; the cooperative reconstruction mechanism
   and dissociation result are robust to the bivariate extension.
5. **Practical implications**: two failure modes (population-level amplification
   vs individual centrality accumulation), same structural antidote (open networks
   with broad interaction reach). The σ extension adds a third lever (observational
   bandwidth) without introducing new failure modes.

### Output files

```
docs/
  008-second-report/
    report.md
    plot_report.R
    figures/
      gp_bivar_mu_sigma_alpha.png
      gp_bivar_mu_sigma_sigma_sigma.png
  final-report.md
  figures/
    fig4_bivar_mu_sigma_alpha.png    (copy of results/plots/ file)
```

## Open Questions

1. **Non-amplification framing**: Ψ ≤ 0.714 everywhere in bivariate design
   could mean "σ suppresses amplification" or "midpoint slices don't reach
   small-lambda territory." The latter is more accurate; the report must note
   this distinction clearly.

2. **dw_obs framing**: Stage 002/003 screened a different parameter set; dw_obs
   being first-order here is not a contradiction of Stage 002/003 but a new
   finding specific to the σ-active analysis.

3. **Tone of final report**: more authoritative than the individual memos;
   should read as settling the main questions.
