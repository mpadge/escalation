---
created: 2026-06-12T12:00:00Z
agent: claude-sonnet-4-6
git_hash: 62e5417c3c237b354a05ea95dbab9c941f65edb5
---

# Design Decisions: Escalation Model

## Current Architecture

A Rust simulation kernel generates paired (μ₀=0.4 / μ₀=0.6) runs for a
Barabási–Albert network of agents whose escalation propensities co-evolve with
edge weights. An R analysis pipeline wraps the binary: Morris OAT screening
identifies the active parameters, Sobol decomposition ranks them, and a
two-GP emulator (DiceKriging, Matérn-5/2, ARD) maps the four dominant
parameters (alpha, gamma, lambda, eta_obs) across two output surfaces per
stage. Phase diagrams visualise pairwise slices; each stage adds a new
response variable. Stage 3 (current) uses `epsilon_k_corr_final` — the
Pearson correlation between escalation propensity and weighted in-degree at
quasi-equilibrium — as the GP response, alongside the Stage 2 absolute
escalation surfaces.

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
sensitivity pipeline target.
**Rationale:** Shared seed eliminates stochastic variance from the Ψ estimate;
the normalised ratio is independent of absolute escalation level.
**Roads not taken:** Single-condition runs (cannot compute Ψ without pairing);
multiple μ₀ levels (two conditions sufficient for the first-order perturbation
question).
**Stages:** 000

### Reparametrisation to ratio parameters
**Outcome:** Raw model parameters (w_win, b, e, delta_w_obs, eta_obs) are
replaced by dimensionless ratios (r_win_cost, r_coop_exploit, kappa, etc.)
before the sensitivity analysis.
**Rationale:** Ratios are scale-invariant and reduce the effective parameter
count; kappa = eta_obs / eta is theoretically motivated (relative learning
rates).
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
than duplicating it.
**Rationale:** Stage-suffixed utility files would proliferate with each stage;
a single shared file per utility class is maintainable and avoids divergence.
**Roads not taken:** Per-stage utility copies (safer against cross-stage
breakage but creates duplication).
**Stages:** 003

### Generic column-name parameters in utilities
**Outcome:** `build_design_matrix(raw, response_col)` and
`write_phase_csvs(..., derived_col)` accept the response column as a string,
enabling the same utility to serve `mean_epsilon_final` (Stage 2) and
`epsilon_k_corr_final` (Stage 3).
**Roads not taken:** Separate utility functions per response variable.
**Stages:** 003

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
`epsilon_k_corr_final`. The shared utilities extracted from Stage 2 scripts
were parameterised by response column name and sourced by both stages. The
central finding is a dissociation: the gamma×lambda amplification regime
(Stage 2) is exactly the regime where increased μ₀ reduces individual-level
centrality concentration (Stage 3). The two phenomena are driven by different
parameters — lambda for population-level dynamics, alpha for individual-level
network position.

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
the phase diagrams identify the Ψ = 1 contour at 50×50 resolution; a
targeted 100×100 grid over this pair would map the amplification boundary
precisely. Deferred to a future stage.

**Normalised difference surface for Stage 3**: the Stage 2 Ψ is normalised by
the μ₀ step (0.2). For Stage 3, the raw difference C_hi − C_lo was used
instead, since both correlation surfaces are on the same [−1, 1] scale and
normalisation would reduce interpretability.
