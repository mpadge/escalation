---
created: 2026-06-16T14:20:00Z
agent: claude-sonnet-4-6
git_hash: 72d5c37b720e6a5bacabd16745d99bca264bf2a0
---

# Design Decisions: Stage 007 — GP Bivariate Emulation

## Summary

Stage 007 trained two Gaussian process emulators (psi_sigma and psi) on a 1000-point
LHS design over the 6 bivariate Sobol parameters identified in Stage 006, generated
six 50×50 phase grids across three axis pairs, and produced two-panel diverging-scale
phase plots. A train/test stratification bug (non-unique quantile breakpoints from
tied psi_sigma values) was fixed before the GP fitting step.

## New Design Decisions

### Decision 1: ntile() for rank-based train/test stratification
**Chosen:** `dplyr::ntile(psi_sigma_mean, 5L)` replaces `cut(quantile(...))` for
quintile-stratified train/test splitting in `gp_train_bivar.R`.
**Rationale:** The psi_sigma_mean distribution contains exact zeros (design points
where sigma perturbation produces no observable effect), causing `quantile()` to
return duplicate breakpoints that `cut.default` rejects with a fatal error. `ntile()`
partitions ranks into equal-count bins and is immune to ties.
**Tradeoffs:** Strata boundaries are rank-based rather than value-based; immaterial
for a balance heuristic. The change is localised to a single line.
**Proposed by:** agent

### Decision 2: Phase script loads pre-trained GP objects
**Chosen:** `gp_phase_bivar.R` reads `.rds` files saved by `gp_train_bivar.R` rather
than re-fitting DiceKriging GPs from scratch.
**Rationale:** Follows the established pipeline pattern (`gp_phase.R` reads `gp_psi.rds`).
Avoids paying the O(n³) Cholesky cost twice; train and phase stages are independently
rerunnable with the serialised model as the interface.
**Tradeoffs:** File-name coupling between the two scripts.
**Proposed by:** agent

### Decision 3: Archived Ψ=1 overlay deferred — warn, not error
**Chosen:** `plot_bivar.R` attempts to load an archived alpha×lambda phase CSV from
`results/003-centrality-correlation/gp_phase/` for the Ψ=1 contour overlay on the
psi panels of the alpha and lambda axis-pair plots. When no matching CSV is found
(Stage 003 used alpha/gamma/beta/eta_obs — lambda was not a top parameter), a
`cli_alert_warning` is emitted and the overlay is skipped.
**Rationale:** Failing silently would hide the gap; erroring would prevent the three
output PNGs from being written. The warn-and-skip pattern matches the plan's
specification: "skip the overlay and note it in a CLI warning rather than erroring."
**Tradeoffs:** The cross-stage Ψ=1 boundary comparison stated in the design goals is
not realised. A follow-on stage could produce a dedicated univariate alpha×lambda
phase CSV at the Stage 007 6D midpoints to enable this overlay.
**Proposed by:** joint

### Decision 4: Shared symmetric diverging colour scale per plot
**Chosen:** Both panels within each two-panel plot share a single `[-abs_max, abs_max]`
diverging scale, where `abs_max` is the maximum absolute value across both estimands.
**Rationale:** Shared scale makes the psi_sigma and psi panels directly comparable
without rescaling; zero (no sensitivity) maps to the same white midpoint in both panels.
**Tradeoffs:** If one estimand has much wider range the other panel's colour variation
is compressed. Given both are normalised sensitivity ratios this is acceptable.
**Proposed by:** agent

## Integration with Prior Work

Stage 007 closes the emulation loop opened in Stage 005 (introduction of psi_sigma
estimand). The GP infrastructure — DiceKriging, Matérn-5/2, ARD, nugget.estim=TRUE,
n_lhs=1000, n_rep=20 — is unchanged from Stages 001–003. The Rust `cmd_gp_train`
extended in Stage 007-T1 builds on Stage 006's `run_sigma_paired`, adding no new
binary interface beyond what Stage 006 required for Morris/Sobol.

The GP validation metrics (RMSE psi_sigma=0.072, coverage=92.5%; RMSE psi=0.057,
coverage=96.5%) are consistent with the Stage 001/002 GP accuracy levels, suggesting
the stationary Matérn-5/2 kernel is adequate despite S1 ≈ 0 in the Sobol result.
The open question from the plan (non-stationary kernel for interaction-dominated
surface) is provisionally resolved in favour of the stationary kernel.

## Issues Resolved

- **cut.default breaks not unique**: fixed by switching to rank-based `ntile()`.
  Root cause: exact zero values in psi_sigma_mean from design points where σ
  perturbation has no effect.
- **Archived Ψ=1 contour overlay**: resolved as not feasible with Stage 003 archival
  data (lambda not a Stage 003 top parameter); deferred with warning.

## Deferred Items

- **Archived Ψ=1 overlay**: requires a dedicated univariate alpha×lambda (or
  mu_sigma×lambda) phase CSV at fixed Stage 003 midpoints. Possible Stage 008 item.
- **Non-focal midpoint robustness check**: vary one non-focal param while holding
  axis pair fixed to assess sensitivity of psi_sigma phase surface to midpoint choice.
  Flagged in Stage 007 plan as possible Stage 008 item.
- **sigma_decay=0.0 recoverability re-run**: carried forward from Stage 006.

## Process Notes

- The `psi_sigma_mean` exact-zero issue reflects a genuine feature of the model:
  at many design points, the sigma perturbation (Δmu_sigma = 0.1) produces no change
  in the escalation outcome, particularly when sigma_sigma is near zero (symmetric
  sigma traits collapse to the homogeneous case).
- All four tasks in tasks.md completed; `make gp-train-bivar` and `make gp-phase-bivar`
  were run by the user between tasks as specified, confirming pipeline correctness
  before the next script was implemented.
