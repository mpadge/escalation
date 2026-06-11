---
created: 2026-06-11T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 54bf6f4b9ca33dcb727c260d7ad6d3dd4b864188
---

# Plan: equilibrium-surfaces

## Overview
Analyse existing Stage 1 simulation data to build GP emulators of absolute equilibrium
escalation for both μ₀ conditions, map phase diagrams of the absolute surfaces and their
step response across the top-4 parameter space.

## Context

Stages 0 and 1 established the full sensitivity pipeline (Morris → Sobol → GP → phase
diagrams) using Ψ = (mean_epsilon_final_hi − mean_epsilon_final_lo) / 0.2 as the single
GP training target. Ψ is a normalised step response that conflates the absolute escalation
level of each condition with the sensitivity to the μ₀ perturbation. It is the right
measure for parameter screening, but not for characterising population-level outcomes.

Stage 1 identified the top-4 drivers of Ψ: **alpha**, **gamma**, **lambda**, **eta_obs**.
Beta and theta are consistently low-ranked and will be fixed at their Stage 1 midpoints
for all Stage 2 analysis. Parameter ranges are fixed from Stage 1 and no new simulations
are needed.

The Stage 1 results CSV already contains `mean_epsilon_final` for both μ₀=0.4 (lo) and
μ₀=0.6 (hi) rows — this is the population-mean probability of escalation at
pseudo-equilibrium (tail average over the last 20% of each run, computed in Rust by
`aggregate.rs`). This is exactly the output needed for Stage 2. The "blunder" in previous
stages was not using these absolute values directly; instead Ψ was derived and the
per-condition values were discarded in R.

The cooperative reward system in the model is asymmetric by design: observing an escalation
victory directly updates observers' propensities (via `update_observer_propensities()` in
`sim.rs`), while cooperative success propagates only through structural edge changes. This
asymmetry is intentional and no new parameters are introduced in Stage 2.

## Design Goals

1. **Absolute equilibrium surfaces**: build GP emulators of `mean_epsilon_final` for
   μ₀=0.4 and μ₀=0.6 separately across the 4-parameter space (alpha, gamma, lambda,
   eta_obs). These are the primary scientific outputs — they describe what population-level
   escalation looks like at pseudo-equilibrium under two distinct starting conditions.

2. **Step response surface**: derive (hi_surface − lo_surface) post-hoc from the two
   emulators. This is the absolute (unnormalised) step response — where in parameter space
   does a population primed with higher initial escalation end up substantially more
   escalatory at equilibrium? Non-linear amplification here indicates proximity to a phase
   boundary.

3. **Phase diagrams**: generate 6 pairwise phase diagrams (C(4,2) pairs) for each of the
   three surfaces (lo, hi, step response), for 18 diagrams total. Fix the remaining
   two parameters at their Stage 1 midpoints for each diagram.

4. **Amplification boundary**: the primary hypothesis is that Ψ > 1 exists somewhere in
   the 4-parameter space — i.e. there are structural conditions under which social dynamics
   amplify the initial μ₀ perturbation rather than dampen it. The Ψ = 1 contour in each
   phase diagram is the key feature: above it, the model predicts self-reinforcing
   escalation; below it, regression toward baseline.

## Proposed Approach

**Data preparation**: load Stage 1 results CSV, filter to design-point rows (exclude any
diagnostic runs), split by `mu0` column into lo (0.4) and hi (0.6) subsets. Average
`mean_epsilon_final` across seeds per design point within each subset. Verify that the
design points match between lo and hi (same LHS grid).

**GP training**: fit two GPs using the same specification as Stage 1 — Matérn-5/2 kernel,
ARD length scales, `nugget.estim = TRUE`, constant trend — one per condition. Input
columns: alpha, gamma, lambda, eta_obs. Validate each GP against a held-out split and
report RMSE and 95% coverage.

**Phase diagrams**: use the same 50×50 grid approach as Stage 1. For each of the 6
parameter pairs, hold the remaining two at their midpoints and generate predictions from
both GPs. Plot lo surface, hi surface, and derived step response (hi − lo) side-by-side
for each pair.

**Step response analysis**: the derived surface is Ψ = (E_hi − E_lo) / 0.2 — the same
quantity as Stage 1, but now interpreted as an *amplification ratio* rather than a
sensitivity measure. Ψ > 1 means the social dynamics amplify the initial μ₀ perturbation
(equilibrium escalation diverges more than the starting conditions); Ψ < 1 means they
dampen it. Stage 1 showed Ψ_max ≈ 0.94 across the full 6-parameter space — Stage 2 asks
whether restricting to the top-4 (beta and theta fixed at midpoints) reveals any regime
where Ψ > 1. Phase diagrams will include the Ψ = 1 contour as the primary feature of
interest.

**Write-up**: produce `results/gp.md` (hyperparameters, validation, surface summaries) and
`results/interpretation.md` (narrative: where does higher initial escalation lock in, where
does it wash out, and what structural conditions determine which regime a population is in).

## Open Questions

1. **Whether Ψ > 1 exists**: Stage 1 showed Ψ_max ≈ 0.94 with all 6 parameters free.
   Fixing beta and theta may expose higher Ψ values in the top-4 subspace, or may confirm
   that the system does not amplify under any realistic parameter combination. Either
   outcome is informative.

2. **GP training data sufficiency**: Stage 1 used N=1000 LHS points with 20 replicates.
   With only 4 active parameters (down from 6), the same design is more than adequate —
   but the averaging across seeds will produce cleaner targets than Stage 1 because the
   effective dimensionality is lower.
