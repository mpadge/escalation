---
created: 2026-06-12T12:00:00Z
agent: claude-sonnet-4-6
git_hash: c2bc665a7455f473c7f4fbe95777a3cdd8f65823
---

# Design Decisions: Escalation Model

## Current Architecture

A Rust simulation kernel generates triple-paired runs — (a) mu0=0.4 / nominal
mu_sigma, (b) mu0=0.6 / nominal mu_sigma, (c) mu0=0.4 / mu_sigma + 0.1 — sharing
the same seed, for a Barabási–Albert network of agents whose escalation propensities
and status sensitivities co-evolve with edge weights. Each agent carries two evolving
traits: ε_i (escalation propensity) and σ_i (status sensitivity). σ_i multiplies
the global prestige radiation weight (dw_obs) and observational learning rate
(eta_obs), making the observational cascade strength a per-agent property. An R
analysis pipeline wraps the binary: Morris OAT screening identifies the active
parameters for both the `psi` (μ₀ sensitivity) and `psi_sigma` (μ_σ sensitivity)
estimands, Sobol decomposition ranks their variance contributions, and a two-GP
emulator (DiceKriging, Matérn-5/2, ARD) maps the dominant parameters. Stage 006
completed Morris and Sobol for `psi_sigma`; GP emulation for the bivariate surface
is deferred to Stage 007.

---

## Key Decisions

### Rust simulation kernel
**Outcome:** All simulation code is in Rust; analysis in R.
**Rationale:** Rayon parallelism makes parameter sweeps trivial; memory safety
eliminates index-arithmetic bugs in the graph mutation code; CSV output keeps
downstream analysis language-agnostic.
**Roads not taken:** Python/NumPy (too slow for 60k+ paired runs); Julia
(acceptable performance, but Rust's type system catches more simulation-logic
errors at compile time).
**Stages:** 000

### Paired-run design (μ₀=0.4 vs μ₀=0.6, same seed)
**Outcome:** Every design point runs two simulations with the same seed and
differing only in μ₀. The derived quantity Ψ = (E_hi − E_lo) / 0.2 is the
sensitivity pipeline target. Extended in Stage 006 to triple-paired runs that
additionally compute psi_sigma from a third simulation per seed.
**Rationale:** Shared seed eliminates stochastic variance from the Ψ estimate;
the normalised ratio is independent of absolute escalation level. The same logic
extends cleanly to psi_sigma.
**Roads not taken:** Single-condition runs (cannot compute Ψ without pairing);
multiple μ₀ levels (two conditions sufficient for the first-order perturbation
question).
**Stages:** 000, 006

### Reparametrisation to ratio parameters
**Outcome:** Raw model parameters (w_win, b, e, delta_w_obs, eta_obs) are
replaced by dimensionless ratios (r_win_cost, r_coop_exploit, kappa, etc.)
before the sensitivity analysis.
**Rationale:** Ratios are scale-invariant and reduce the effective parameter
count; kappa = eta_obs / eta is theoretically motivated (relative learning rates).
**Roads not taken:** Raw parameters throughout (would require wider, less
interpretable ranges and reduce Sobol efficiency).
**Stages:** 000

### nugget.estim = TRUE instead of supplied noise.var
**Outcome:** DiceKriging fits the nugget by marginal likelihood rather than
receiving per-point noise variance as a fixed input.
**Rationale:** Stage 0 GP collapsed to the prior mean in several phase diagrams
because per-point psi_sd from 5 replicates was unstable (many tied at zero);
fixing noise.var forced zero process variance and caused the GP to interpolate
noise. nugget.estim absorbs observation noise stably.
**Roads not taken:** Heteroskedastic noise term (theoretically preferable but
practically destabilising given small replicate counts).
**Stages:** 001

### Replicate count increased from 5 to 20
**Outcome:** Each LHS design point runs 20 paired replicates for GP training.
**Rationale:** 5 replicates gave unstable per-point psi_sd (many zeros);
20 replicates produce reliable per-point averages and prevent nugget collapse.
**Roads not taken:** Adaptive refinement (add points in high-uncertainty
regions); not needed once the nugget instability was resolved.
**Stages:** 001

### Two-GP design (separate emulators per μ₀ condition)
**Outcome:** Each analysis stage fits two independent GPs — one for the μ₀=0.4
surface and one for μ₀=0.6 — and derives the difference post-hoc.
**Rationale:** A single GP trained on Ψ conflates absolute level and
sensitivity; two GPs allow independent characterisation of each surface and
make the derived quantity interpretable in context.
**Roads not taken:** Single Ψ-GP (Stage 0/1 approach, discarded Stage 2
onward); joint GP with μ₀ as a covariate (would require a 5D input; unnecessary
given only two conditions).
**Stages:** 002

### Shared utility R files without stage suffixes
**Outcome:** `gp_train_utils.R`, `gp_phase_utils.R`, `plot_utils.R` are
sourced by all stage scripts; Stage 2 and Stage 3 scripts share code rather
than duplicating it. Stage 006 analysis scripts use the `_bivar` suffix
convention for their own helper functions, remaining self-contained.
**Rationale:** Stage-suffixed utility files would proliferate with each stage;
a single shared file per utility class is maintainable and avoids divergence.
**Roads not taken:** Per-stage utility copies (safer against cross-stage
breakage but creates duplication).
**Stages:** 003, 006

### Generic column-name parameters in utilities
**Outcome:** `build_design_matrix(raw, response_col)` and
`write_phase_csvs(..., derived_col)` accept the response column as a string,
enabling the same utility to serve `mean_epsilon_final` (Stage 2) and
`epsilon_k_corr_final` (Stage 3). Stage 006 extends this further: the binary
now outputs both `psi` and `psi_sigma` columns, and the R scripts select the
appropriate column explicitly.
**Roads not taken:** Separate utility functions per response variable.
**Stages:** 003, 006

### Bivariate model: σ as second agent trait
**Outcome:** Each agent carries σ_i ∈ [0,1] (status sensitivity) in addition
to ε_i. σ_i multiplies the global prestige radiation weight and observational
learning rate, making cascade conductivity a per-agent property. Setting
mu_sigma=1.0 / sigma_sigma=0.0 / eta_sigma=0.0 recovers the original
univariate model exactly.
**Rationale:** σ directly gates the observational learning pathway — the
mechanism by which a μ₀ perturbation propagates beyond direct participants.
This makes it the strongest lever on the bivariate estimand Ψ(θ, μ_σ).
Alternative second dimensions (bond/bridge orientation β, reciprocity ρ)
act more indirectly on network topology and were rejected.
**Roads not taken:** Retiring eta_obs/dw_obs entirely (Option B) — rejected
because mu_sigma=0 would produce zero observational effects rather than
original-model behaviour; retiring globals as scales creates the clean
mu_sigma=1.0 degenerate baseline. Split σ_emit/σ_recv — deferred as
unnecessary complexity at this stage.
**Stages:** 005

### σ reinforcement via vicarious winner payoff + sigma_decay
**Outcome:** Non-participant observers update σ by sign(winner_payoff_delta) ·
eta_sigma. A global sigma_decay (default 0.002) prevents saturation at 1.0.
**Rationale:** Observer payoff does not change within a single timestep, so the
winner's payoff gain is the tractable vicarious reinforcement proxy. Without
decay, σ drifts monotonically to 1.0 (confirmed empirically). Decay creates the
equilibrium at which the ε–σ correlation can emerge.
**Roads not taken:** Observer's own payoff (always zero within a timestep);
propensity-prediction accuracy as the σ signal (requires counterfactual tracking).
**Stages:** 005

### eta_obs fixed in bivariate sensitivity analysis
**Outcome:** `eta_obs` is excluded from the bivariate Morris/Sobol candidate
set and fixed at its reference midpoint (0.05). The bivariate free-parameter
set is 14 parameters (original 11 − eta_obs + 4 σ-trait parameters).
**Rationale:** eta_obs and mu_sigma both scale the observational-learning
pathway; simultaneous variation creates near-collinear Morris elementary-effect
directions that cannot be resolved reliably.
**Roads not taken:** Including eta_obs at the cost of collinearity artefacts;
joint eta_obs × mu_sigma variation deferred to Stage 007.
**Stages:** 006

### Triple-paired run infrastructure
**Outcome:** `run_sigma_paired` in `src/experiment.rs` runs three simulations
per seed (mu0_lo, mu0_hi, mu0_lo + mu_sigma perturbation), computing both `psi`
and `psi_sigma` from a single binary call. `cmd_sensitivity` now calls
`run_sigma_paired` for all Morris and Sobol subcommands.
**Rationale:** One extra forward run per design point is the minimum cost for
the second estimand; shared seed cancels stochastic variance from both estimates.
**Tradeoffs:** 50% more expensive per design point; delta_mu_sigma = 0.1
validated by T006-3 (|psi_sigma| < 1e-3 under degenerate conditions).
**Stages:** 006

---

## Architectural Evolution

**Stage 000** established the full pipeline end-to-end: Rust kernel → Morris
screening → Sobol decomposition → GP emulation → phase diagrams → plots. The
GP training target was a single Ψ surface. A GP collapse artefact was
discovered in post-analysis: very short ARD length scales caused phase diagram
points to fall outside the training distribution, returning the prior mean.

**Stage 001** fixed the GP methodology (nugget estimation, more replicates) and
recalibrated parameter ranges so response surface peaks are interior to the
sampled region. The direct Sobol ranking (alpha first, then gamma, eta_obs,
lambda) was confirmed stable across the revised ranges.

**Stage 002** replaced the single Ψ-GP with a two-GP design on the absolute
escalation surfaces. The key finding — population-level amplification (Ψ > 1)
in the alpha×lambda and gamma×lambda regimes — was only recoverable with the
two-GP approach; the single Ψ-GP missed it. Lambda emerged as the structural
enabling variable for amplification despite having long ARD length scales in
both individual surfaces.

**Stage 003** extended the two-GP pipeline to a second response variable:
`epsilon_k_corr_final`. The central finding is a dissociation: the gamma×lambda
amplification regime (Stage 2) is exactly the regime where increased μ₀ reduces
individual-level centrality concentration. The two phenomena are driven by
different parameters — lambda for population-level dynamics, alpha for
individual-level network position.

**Stage 004** produced the final report (`docs/report.md`) synthesising Stages
000–003 into a coherent narrative around two findings: dampened amplification
except in small-group / local-influence configurations, and the dissociation
between population-level spread and individual power concentration.

**Stage 005** extended the Rust kernel to a bivariate (ε, σ) model. The
addition of status sensitivity σ as a second evolving trait makes the
observational cascade strength a per-agent property rather than a global
parameter. Three validation tests confirm: (1) exact degenerate recovery with
mu_sigma=1.0, (2) σ distribution does not collapse, (3) endogenous ε–σ
correlation emerges positive.

**Stage 006** ran Morris OAT screening and Sobol variance decomposition for the
bivariate model, simultaneously computing `psi_sigma` (μ_σ sensitivity) and
`psi` (μ₀ sensitivity with σ active) from a single binary call. Key findings:
(a) mu_sigma and sigma_sigma lead for psi_sigma by μ*, but network structure
parameters (lambda, dw_obs, dw_bridge, alpha) contribute substantially;
(b) psi_sigma Sobol shows S1 ≈ 0 / ST ≈ 0.86–1.03 for all parameters —
variance is interaction-dominated, contrasting with the univariate Ψ;
(c) alpha re-leads for psi with σ active (μ* = 0.636), consistent with Stage 003;
(d) recoverability Spearman ρ = 0.78 (below 0.95 threshold) attributed to
sigma_decay=0.002 in the degenerate run; fixing to sigma_decay=0.0 is the
identified remediation. GP emulation for psi_sigma deferred to Stage 007.

---

## Important Roads Not Taken

**Python/GPyTorch for GP emulation** (Stage 000 plan): the original plan
specified Python for the GP fitting stage. Switched to R/DiceKriging because
DiceKriging's Matérn-5/2 ARD with nugget estimation is a well-validated
emulator for stochastic simulations, and keeping the entire analysis in R
avoids a language boundary in the pipeline.

**Adaptive GP refinement** (Stage 000 plan): planned to add design points in
high-uncertainty regions. Not needed after the nugget-estimation fix resolved
the GP collapse; validation RMSEs were acceptable without refinement.

**High-resolution alpha×lambda boundary mapping** (deferred from Stage 002):
the phase diagrams identify the Ψ = 1 contour at 50×50 resolution; a targeted
100×100 grid would map the amplification boundary precisely. Deferred.

**Normalised difference surface for Stage 3**: raw C_hi − C_lo was used rather
than normalising by the μ₀ step, since both correlation surfaces are already
on the same [−1, 1] scale.

**Retiring eta_obs/dw_obs entirely** (Stage 005): proposed to simplify the
parameter space but rejected; mu_sigma=0 would suppress all observational
effects, preventing the original model from being recovered as a degenerate case.

**Split σ_emit/σ_recv** (Stage 005): a two-component status sensitivity
(how strongly a winner projects vs. how strongly an observer receives) was
considered but deferred as unnecessary complexity before the bivariate
sensitivity analysis establishes which aspects of σ matter most.

**eta_obs × mu_sigma joint variation** (Stage 006): excluded from the bivariate
Morris/Sobol to avoid collinearity. Joint variation deferred to Stage 007.

**sigma_decay=0.0 in degenerate recoverability run** (Stage 006): the task
specification used sigma_decay=0.002; this caused sigma to drift during the run
and reduced recoverability ρ to 0.78. Using sigma_decay=0.0 (as in T005-8)
would give exact degenerate recovery and is the recommended approach.
