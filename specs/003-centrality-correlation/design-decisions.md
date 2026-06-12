---
created: 2026-06-12T12:00:00Z
agent: claude-sonnet-4-6
git_hash: 62e5417c3c237b354a05ea95dbab9c941f65edb5
---

# Design Decisions: Stage 3 — Centrality–Escalation Correlation

## Summary

Stage 3 asks whether high-ε individuals gain disproportionate network
centrality when μ₀ increases. It re-uses the Stage 1 simulation data and
extends the Stage 2 two-GP pipeline to a new response variable
(`epsilon_k_corr_final`), adding shared utility extraction so both stages
share code. The key empirical finding is a dissociation: population-level
amplification (Stage 2) and individual-level centrality concentration
(Stage 3) are driven by different parameters and point in opposite directions
in the gamma × lambda regime.

## New Design Decisions

### Decision 1: Shared utility files without stage suffixes
**Chosen:** Three utility files (`gp_train_utils.R`, `gp_phase_utils.R`,
`plot_utils.R`) shared across all stage scripts, rather than per-stage copies.
**Rationale:** Avoids divergence between stage implementations as the pipeline
grows. Stage 2 scripts source the same utilities as Stage 3 scripts.
**Tradeoffs:** Any signature change requires updating all callers; coordinated
but manageable.
**Proposed by:** mpadge

### Decision 2: Generic function signatures via column-name parameters
**Chosen:** `build_design_matrix(raw, response_col)` and
`write_phase_csvs(..., derived_col)` accept the column name as a string
argument.
**Rationale:** Enables the same utility functions to serve both
`mean_epsilon_final` (Stage 2) and `epsilon_k_corr_final` (Stage 3).
**Tradeoffs:** Column name errors are runtime rather than load-time.
**Proposed by:** agent

### Decision 3: Column auto-detection in plot utilities for backward compatibility
**Chosen:** `build_e_limits` reads the first non-coordinate column; `plot2.R`
detects the value column from the first available CSV file.
**Rationale:** DiceKriging was unavailable in the development environment,
so old `phase2_*.csv` files on disk used the legacy `"psi"` column name.
Auto-detection allowed `make plots2` verification without re-running
`gp_phase2.R`.
**Tradeoffs:** Minor fragility if CSV schema changes; acceptable for the
controlled output format.
**Proposed by:** agent

### Decision 4: Difference surface on raw correlation scale
**Chosen:** `diff = C_hi − C_lo` with no normalisation by the μ₀ step.
**Rationale:** Unlike Stage 2's Ψ (normalised by 0.2 to express a ratio),
both correlation surfaces are already on the same [−1, 1] scale; raw
difference is directly interpretable.
**Tradeoffs:** Not directly comparable to Ψ numerically.
**Proposed by:** agent

### Decision 5: T003-3 reads output CSV instead of console capture
**Chosen:** Task updated to read `results/gp3_hyperparams.csv` and
`results/gp3_data.csv` for all quantitative verification.
**Rationale:** `save_hyperparams_csv` already persists all needed numbers;
referencing the file is reproducible and independent of terminal output.
**Proposed by:** mpadge

## Integration with Prior Work

Stage 3 is a direct analogue of Stage 2 with a different response variable.
The two-GP training, stratified split, ARD Matérn-5/2 kernel, and three-panel
phase diagram structure are all inherited from Stage 2. The shared utility
extraction in T003-0 was retroactively applied to the Stage 2 scripts, which
now source the same files as Stage 3.

The empirical results stand in deliberate contrast to Stage 2: where Stage 2
found lambda as the enabling variable for amplification, Stage 3 finds lambda
nearly inert and alpha dominant. Where Stage 2 found gamma × lambda as an
amplification pair, Stage 3 finds gamma × lambda as the one pair where
increased μ₀ *suppresses* individual-level centrality concentration.

## Issues Resolved

- **Plan open question 1 (sign of baseline correlation)**: Confirmed positive
  on average (mean ≈ 0.08), reaching up to 0.63; negative regions are a
  minority of parameter space.
- **Plan open question 2 (relationship to Stage 2 amplification regime)**:
  Resolved as a dissociation — the gamma × lambda amplification pair shows
  uniformly negative diff; the positive diff regions involve eta_obs pairs
  not implicated in Stage 2.

## Deferred Items

- High-resolution mapping of the alpha × gamma centrality concentration
  boundary (the surface peaks around low alpha, low gamma but the boundary
  is not precisely mapped at 50 × 50).
- Robustness check: whether the eta_obs range [0.001, 0.1] is narrow enough
  to suppress its apparent sensitivity in C_lo.

## Process Notes

- DiceKriging was absent from the environment during T003-0 verification.
  `make gp2` and `make gp2_phase` could not be re-run; `make plots2` was
  verified against stale CSVs using auto-detection.
- The `gp3_phase` Makefile target was omitted from the initial T003-2 commit
  and added in a follow-up before the phase script was run.
- T003-5 (Makefile `gp3_phase` target) was completed ahead of its natural
  sequence when the omission was noticed.
