---
created: 2026-06-16T14:45:00Z
agent: claude-sonnet-4-6
git_hash: cd4b21a03a6fd509139dbfbb91e256449e97efaf
---

# Design Decisions: Stage 008 — Bivariate Report and Combined Synthesis

## Summary

Stage 008 produced two documents: a research memo reporting the Stage 007
bivariate GP findings (`docs/008-second-report/report.md`, ~2,500 words) and a
standalone synthesis document combining both analyses (`docs/final-report.md`,
~2,000 words). The principal framing decision was how to characterise the
observational bandwidth (dw_obs) finding and the non-amplification result from
the bivariate phase analysis.

## New Design Decisions

### Decision 1: dw_obs framing as a new finding, not a correction
**Chosen:** dw_obs is described as a finding specific to the σ-active bivariate
analysis rather than as a parameter previously overlooked in Stages 002/003.
**Rationale:** Stages 002/003 screened a different 11-parameter set; dw_obs was
present but not among the top-four parameters under the univariate model. With
σ active, dw_obs gates the observational channel and naturally becomes
first-order. Framing it as a new finding avoids implying a gap in the earlier
work.
**Tradeoffs:** Requires a brief caveat in the text explaining the different
parameter sets; without it a reader might wonder why dw_obs was missed before.
**Proposed by:** agent

### Decision 2: Non-amplification framed as midpoint-configuration result
**Chosen:** The fact that Ψ ≤ 0.714 everywhere in the bivariate phase diagrams
is described as "the amplification regime was not re-entered at the midpoint
configuration," not as "σ heterogeneity suppresses amplification."
**Rationale:** The bivariate phase slices fix non-focal parameters at midpoints
that do not include the small-lambda / high-alpha configurations where Stage 002
found Ψ > 1. Claiming suppression would overstate the finding; the analysis
simply did not sweep into the corner where amplification occurs.
**Tradeoffs:** This framing requires the reader to hold two ideas simultaneously
(Ψ is always below 1 here; but this doesn't mean amplification is impossible
with σ active). The discussion section carries this distinction explicitly.
**Proposed by:** agent

### Decision 3: No references section in either document
**Chosen:** Both `docs/008-second-report/report.md` and `docs/final-report.md`
are plain `.md` with no citations block. The Stage 004 report included a full
references section; Stage 008 documents do not.
**Rationale:** Per user instruction. Removes the `.myst`/`.bib` workflow
entirely for these documents.
**Proposed by:** mpadge

### Decision 4: Final report as standalone synthesis, not addendum
**Chosen:** `docs/final-report.md` is written as a self-contained document that
does not assume the reader has read either prior report. It states all three
findings from scratch, with only brief cross-references to stage numbers.
**Rationale:** A synthesis that presupposes the prior reports would be useful
only to readers who have already read them; a standalone synthesis is the
primary deliverable and needs to work independently.
**Tradeoffs:** Some content from the Stage 004 report is restated at shorter
length, creating minor duplication with `docs/004-first-report/report.md`.
**Proposed by:** joint

### Decision 5: docs/figures/ as shared figure directory for final report
**Chosen:** The final report's figures live in `docs/figures/` — a directory
shared between Stage 004 and Stage 008 figures. Stage 004 used
`docs/004-first-report/figures/` (since renamed); the final report copies
`fig1_amplification_alpha_lambda.png` and `fig4_bivar_mu_sigma_alpha.png` there.
**Rationale:** The final report is in `docs/` directly, so a sibling `figures/`
directory is the natural convention. Consistent relative paths for figure
references.
**Proposed by:** agent

## Integration with Prior Work

The second report (`docs/008-second-report/report.md`) directly continues the
Stage 004 narrative, opening with a recap of the two Stage 004 findings and
then asking what σ heterogeneity adds. The final report (`docs/final-report.md`)
subsumes both reports: it restates the Stage 004 findings at shorter length,
presents the Stage 007 findings as a third block, and develops the unified
architectural claim across all three.

Both documents preserve the Stage 004 tone: accessible research memo without
equations or GP technical detail, with structural parameters described in plain
language (influence locality rather than alpha, observational bandwidth rather
than dw_obs) on first use.

## Issues Resolved

- **dw_obs dominance interpretability**: the extreme ARD sensitivity (6315×)
  for psi_sigma was potentially misleading since psi_sigma varies by only 0.021
  absolute units. Resolved by explicitly separating relative dominance from
  absolute magnitude in the text.
- **Missing fig1 in docs/figures/**: the Stage 004 figures were in
  `docs/004-first-report/` rather than `docs/figures/`; copied on demand for
  the final report.

## Deferred Items

- **Bivariate centrality analysis**: whether the Stage 003 ε–degree correlation
  and dissociation result hold in the bivariate model was not verified; flagged
  as a remaining question in both documents.
- **Amplification threshold under σ**: targeted sweep at small-lambda /
  high-alpha with varying dw_obs to test whether the Ψ = 1 boundary shifts.
- **Gini / inequality characterisation**: network centrality inequality (not
  just the ε–degree correlation) was not measured in either analysis.

## Process Notes

- The four tasks were implemented sequentially without interruption.
- figure reference verification used Python regex rather than grep due to
  multi-line figure captions in the markdown source.
