---
created: 2026-06-15T00:00:00Z
agent: claude-sonnet-4-6
git_hash: 5251fe6aefd0aa2ef380a90ec79c8a95ff7f1d37
---

# Plan: bivariate-sensitivity

## Overview

Run Morris elementary-effects screening and Sobol variance decomposition for the
bivariate (ε, σ) model introduced in stage 005. The primary estimand is psi_sigma —
the sensitivity of equilibrium mean escalation ε̄(∞) to a perturbation in mean
status sensitivity μ_σ — a direct analog of the Ψ estimand used in stages 000–003
for μ₀. A secondary goal is to show how the Ψ surface (μ₀ amplification) changes
when σ is active (non-degenerate). A recoverability section confirms that fixing σ
at its degenerate values reproduces the stage 002/003 results. No GP emulation in
this stage — that is deferred to stage 007.

## Context

Stage 000/001 established the full sensitivity pipeline: Morris screening to rank
parameters by elementary effects on Ψ, followed by Sobol variance decomposition for
the top-ranked subset, followed by GP emulation. Stages 002 and 003 used GP surfaces
to produce the equilibrium-surface and centrality-correlation results that underpin
the stage 004 report.

Stage 005 extended the simulation kernel to a bivariate (ε, σ) agent model. Four new
Rust parameters were introduced: `mu_sigma` (initial mean σ), `sigma_sigma` (initial
SD of σ), `eta_sigma` (σ update rate), and `sigma_decay` (per-timestep σ drift toward
0). Degenerate recovery is exact: setting mu_sigma=1.0, sigma_sigma=0.0, eta_sigma=0.0
recovers the original univariate model (verified by T005-8).

The `psi_sigma` field in `RunSummary` / `aggregate.rs` is populated as `None` — the
paired-run infrastructure for μ_σ perturbation is not yet wired into `experiment.rs`.

A collinearity risk was flagged in stage 005 design-decisions.md: mu_sigma and eta_obs
share the same observational-learning scale; they cannot be varied simultaneously in
sensitivity analysis without care.

Parameter ranges for the four new σ parameters are drawn from the stage 005 defaults
and from the empirical behaviour observed during T005-9 (monotonic drift without decay):

| Parameter   | Range       | Rationale |
|-------------|-------------|-----------|
| mu_sigma    | [0.5, 2.0]  | 1.0 is the degenerate point; > 2.0 saturates the product σ_w · σ_k |
| sigma_sigma | [0.0, 0.5]  | 0.0 = all agents identical; 0.5 = wide heterogeneity |
| eta_sigma   | [0.0, 0.2]  | 0.0 = no σ learning; default 0.05; 0.2 = rapid adaptation |
| sigma_decay | [0.001, 0.01] | Default 0.002; upper bound chosen to prevent over-damping |

Stage 003's key finding: the ε–degree centrality correlation is governed by `alpha`
(locality) rather than the amplification parameters (gamma × lambda). Stage 006
does not reopen that question; it targets the σ pathway only.

## Design Goals

1. **Activate psi_sigma computation**: implement μ_σ-paired runs in `experiment.rs`
   so that the `psi_sigma` field in `RunSummary` is populated with
   (ε̄(∞, μ_σ + δ) − ε̄(∞, μ_σ)) / δ for each design point, analogous to how Ψ
   is computed for μ₀ perturbation.

2. **Morris screening (psi_sigma)**: extend the Morris parameter space to include
   mu_sigma, sigma_sigma, eta_sigma, and sigma_decay (adding to the existing 11
   free parameters). Screen using psi_sigma as the output metric to identify which
   parameters govern the new σ-driven amplification pathway. Hold `eta_obs` fixed
   during Morris to isolate the mu_sigma / eta_obs collinearity.

3. **Sobol decomposition (psi_sigma)**: run Sobol variance decomposition on the
   top-ranked parameters from the Morris run, using psi_sigma as the output metric.
   Report first-order and total-order indices.

4. **Ψ comparison with σ active**: using the same Morris design points, compare the
   Ψ (μ₀ sensitivity) values from the bivariate run (σ evolving at default non-zero
   values) against the degenerate-case Ψ values. This answers: does activating σ
   change which parameters drive μ₀ amplification, and by how much?

5. **Recoverability section**: run the full pipeline with mu_sigma=1.0,
   sigma_sigma=0.0, eta_sigma=0.0 (the degenerate σ-fixed case) and confirm that
   the resulting Ψ Morris rankings and Sobol indices match the stage 002/003 results.
   Presented as a results section, not a hard numerical assertion.

## Proposed Approach

### Rust: Activate psi_sigma (experiment.rs)

Extend `run_paired` (or add `run_sigma_paired`) to accept a `delta_mu_sigma`
argument. For each seed: run once with nominal `mu_sigma` and once with
`mu_sigma + delta_mu_sigma` (e.g. 0.1). Compute
`psi_sigma = (mean_epsilon_final_hi − mean_epsilon_final_lo) / delta_mu_sigma`
and store in `RunSummary`. Wire this into the Morris and Sobol subcommands so that
both `psi` (μ₀ pairing) and `psi_sigma` (μ_σ pairing) are emitted per design point.

The degenerate case must be handled: when sigma_sigma=0.0 and eta_sigma=0.0,
psi_sigma should be 0.0 (no σ dynamics, no σ amplification) and the regular Ψ
values must be identical to those from the original model.

### R: New analysis scripts

Create `analysis/morris-bivar.R` and `analysis/sobol-bivar.R` following the same
structure as `morris.R` / `sobol.R` but targeting the bivariate model:

- `param_names` extended with: `mu_sigma`, `sigma_sigma`, `eta_sigma`, `sigma_decay`
- `fixed` includes `eta_obs` at its reference value (not varied) to avoid
  collinearity with mu_sigma; this is documented explicitly in the script header
- Primary output metric: `psi_sigma` (reads from the `psi_sigma` column in the
  binary output)
- Secondary output metric: `psi` (μ₀ Ψ, now with σ active) — extracted from the
  same run, compared to stage 000/001 Morris μ* values as a within-script check

Run via `make morris-bivar` and `make sobol-bivar` (see Makefile).

### R: Recoverability section

Add a short `analysis/recover-bivar.R` that:
1. Runs the Morris binary with the full parameter set but mu_sigma=1.0,
   sigma_sigma=0.0, eta_sigma=0.0 fixed
2. Computes Morris indices using psi (Ψ) as output
3. Loads the stage 000/001 Morris results from `results/morris_results.csv`
   and overlays the μ* rankings in a side-by-side table
4. Reports rank correlation between stage 000/001 and degenerate-σ stage 006 rankings

Run via `make recover-bivar`.

### Output files

All results go into the project-level `results/` directory (same location as all
prior stages). Plots go into `results/plots/`. Stage 006 files use a `_bivar` suffix
to avoid overwriting existing results from prior stages.

```
results/
  design_morris_bivar.csv          # Morris trajectory design (15 params)
  morris_bivar_raw.csv             # Raw Morris binary output (psi + psi_sigma columns)
  morris_bivar_results_psi_sigma.csv  # Morris μ*, σ ranked by psi_sigma metric
  morris_bivar_results_psi.csv        # Morris μ*, σ ranked by Ψ metric (σ active)
  design_morris_bivar_degen.csv    # Morris design for degenerate σ-fixed run
  morris_bivar_raw_degen.csv       # Raw binary output for degenerate run
  recover_bivar_comparison.csv     # Rank comparison: stage 000/001 vs degenerate stage 006
  design_sobol_bivar.csv           # Saltelli design for psi_sigma Sobol
  sobol_bivar_raw.csv              # Raw Sobol binary output
  sobol_bivar_results.csv          # Sobol S1 and ST for psi_sigma
results/plots/
  morris_bivar_plot.png            # μ* vs σ scatter for both metrics (psi_sigma, Ψ)
  sobol_bivar_plot.png             # S1 / ST bar chart for psi_sigma
```

## Open Questions

1. **delta_mu_sigma value**: 0.1 is proposed for the μ_σ perturbation (10% of the
   [0.5, 2.0] range). If mu_sigma is at the lower end of its range (0.5), the
   perturbed value is 0.6 — well within range. Confirm this is sufficient for
   numerical stability of psi_sigma estimates.

2. **eta_obs treatment**: holding eta_obs fixed at its reference value during
   bivariate Morris is conservative but clean. Whether eta_obs should be included
   as a joint-varying parameter in a follow-on stage (once the mu_sigma / eta_obs
   interaction is characterised) is deferred to stage 007.

3. **psi_sigma sign convention**: psi_sigma = (ε̄_hi − ε̄_lo) / δ will be positive
   when higher mean status sensitivity amplifies escalation, and negative when it
   dampens. The quadratic σ_w · σ_k product (stage 005, Decision 3) predicts
   positive psi_sigma across most of parameter space; this is a testable prediction.

4. **Whether to run GP emulation for psi_sigma**: deferred to stage 007. If Morris
   + Sobol in stage 006 identify ≤4 dominant parameters for psi_sigma, stage 007
   can reuse the existing GP infrastructure (`gp_train.R` / `gp_phase.R`) with
   minimal extension.
</content>
</invoke>