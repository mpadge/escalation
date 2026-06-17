---
created: 2026-06-17T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 00c5122fd6e483a2bc9b6ce28ac89ae394489dfb
---

# Plan: consolidate-workflow

## Overview

Collapse the 24-file analysis directory and 20+ Makefile targets accumulated across
Stages 000–009 into a single coherent bivariate pipeline. All analysis is bivariate
(ε, σ model) from the outset; σ-degenerate runs (mu_sigma=1, sigma_sigma=0) serve as
the interpretive baseline rather than a separate univariate pipeline. Phase exploration
replaces the brute-force LHS grid with an adaptive approach: coarse initial grid,
gradient ascent on the GP posterior mean to locate Ψ maxima, dense resample around
that region, retrain, and repeat to convergence. The entire workflow is re-run from
scratch. All results go to `results/`, final documentation to `docs/`.

## Context

Stages 000–009 developed the analysis incrementally:
- Stage 002 identified the high-Ψ amplification corner: small λ (group size), high α
  (influence locality). This is the region of primary interest.
- Stage 004 produced the first report from a generic midpoint that missed this corner;
  Stage 008 repeated the mistake — its bivariate phase slices fixed non-focal parameters
  at midpoints that do not include small-λ / high-α.
- Stage 005 introduced the bivariate (ε, σ) model. Stage 006–007 ran sensitivity and GP
  emulation. Stage 009 added Gini analysis, establishing a three-way parameter
  dissociation: λ governs Ψ, α governs ε–degree correlation, η_obs/dw_obs governs Gini.
- The script proliferation reflects development history: numbered variants
  (gp_train2.R, gp_train3.R, plot2.R, plot3.R, …) and parallel bivariate copies
  (morris-bivar.R, sobol-bivar.R, gp_train_bivar.R, …) should be eliminated.
- Stage 009 deferred two empirical questions: Ψ=1 threshold under σ heterogeneity at
  small-λ / high-α; bivariate ε–degree correlation behaviour in that corner.

## Design Goals

1. Reduce `analysis/` to ≤8 scripts with no stage numbers in filenames; each script
   named after what it does (e.g. `screen.R`, `sobol.R`, `gp_train.R`).
2. Replace brute-force LHS with adaptive sampling: coarse grid → GP fit → gradient ascent
   → dense resample in high-Ψ region → iterate to convergence.
3. Unify the pipeline: no distinction between "baseline" and "bivariate" scripts.
   σ-degenerate runs are a special case of the bivariate model, not a separate path.
4. Focus all phase analysis on the high-Ψ corner (small λ, high α); non-focal
   parameters fixed at values consistent with that corner, not at generic midpoints.
5. Collapse Makefile to ≤8 targets, each mapping 1-to-1 onto a script.
6. Deliver an updated `docs/report.md` covering all three estimands (Ψ, ε–degree
   correlation, Gini) in the high-Ψ region, plus the two deferred empirical questions
   from Stage 009.

## Proposed Approach

**Analysis scripts (target set, tentative names):**

| Script | Replaces | Purpose |
|---|---|---|
| `screen.R` | morris.R, morris-bivar.R | Morris sensitivity screening, bivariate model |
| `sobol.R` | sobol.R, sobol-bivar.R | Sobol first/total-order indices |
| `gp_train.R` | gp_train.R–3, gp_train_bivar.R, gp_train_utils.R | GP training on adaptive design |
| `gp_explore.R` | gp_phase.R–3, gp_phase_bivar.R, gp_phase_utils.R | Adaptive sampling + phase diagrams |
| `gini.R` | gp_gini_baseline.R, gp_gini_bivar.R, gini_compare.R | Gini estimand analysis |
| `plot.R` | plot.R–3, plot_bivar.R, plot_utils.R | All plotting |
| `utils.R` | utils.R, delta_monotone.R | Shared utilities |

`recover-bivar.R` (degenerate-σ recoverability validation) is either absorbed into
`gp_train.R` as a validation block or dropped if the degenerate baseline is now
handled inline.

**Adaptive exploration algorithm (`gp_explore.R`):**
1. Generate a coarse LHS design (e.g. N=200) over the full parameter space.
2. Simulate and train an initial GP on Ψ.
3. Evaluate the GP posterior mean on a fine grid; identify the Ψ maximum.
4. Sample densely in the neighbourhood of the maximum (e.g. N=300 within a shrinking
   hypercube around the peak).
5. Retrain GP on the combined design; check convergence (change in peak Ψ estimate
   and its location < threshold).
6. Repeat steps 3–5 for up to K iterations (K≈3–5 expected sufficient).
7. Use DiceKriging's analytic gradient (`predict` with `se.compute=TRUE` + finite
   differences, or the `DiceOptim` `max_EI` / `max_qEI` interface) for step 3.

**σ-degenerate interpretation:** All analyses run with the full bivariate design.
The degenerate comparison (mu_sigma=1, sigma_sigma=0) is a 1D slice through the
fitted GP surface, not a separately trained model. This gives the qualitative
baseline without doubling the script count.

**High-Ψ corner focus:** Non-focal parameters in phase diagrams are fixed at values
that sit inside the amplification regime: λ at its lower range, α at its upper range.
The Stage 002/004 finding pinpoints this corner; stage 008's generic-midpoint error is
not repeated.

**Deferred empirical questions (from Stage 009):**
- Ψ=1 threshold under σ heterogeneity: the adaptive design naturally targets this
  because Ψ=1 is the boundary of the amplification region — gradient ascent will
  characterise the boundary shape.
- Bivariate ε–degree correlation: addressed by running the ε–degree GP on the same
  adaptive design used for Ψ.

## Open Questions

None — all resolved during planning:

1. **Gradient implementation:** Numerical finite differences on the GP posterior mean.
   `DiceOptim::max_EI` risks oversampling the boundary rather than the interior of the
   high-Ψ region and is not used.

2. **Convergence criterion:** Threshold-based: stop when peak-Ψ location moves less
   than δ (1% of parameter range) between iterations. A maximum-iterations cap
   (K=5) prevents runaway in pathological cases.

3. **σ-degenerate slice:** Produces a new phase diagram on the high-resolution adaptive
   design. Approximate reproduction of Stage 002 is not a goal; the adaptive design
   is the primary result.

4. **Report scope:** Entirely new document at `docs/report.md`. The previous report
   was archived to `docs/009-gini-inequality/report.md`. The new report is a fresh
   synthesis of findings from this stage only; it is not influenced by, and does not
   reference, the prior documents.
