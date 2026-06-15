---
created: 2026-06-15T21:30:00Z
agent: claude-sonnet-4-6
git_hash: 098e58efda64444ac9bafac5f0c763406661090d
---

# Tasks: gp-bivar

## T007-1: Extend cmd_gp_train to emit psi_sigma

- [x] T007-1: In `src/main.rs`, replace the inline lo/hi simulation loop inside
  `cmd_gp_train` with a call to `run_sigma_paired` (from `src/experiment.rs`),
  passing a single-element slice `&[design_row]` and the full seeds slice. This
  runs three simulations per seed — (a) mu0=0.4 / nominal mu_sigma, (b) mu0=0.6
  / nominal mu_sigma, (c) mu0=0.4 / mu_sigma + 0.1 — and populates both `psi`
  and `psi_sigma` in every output row. The streaming/resumability logic (one
  `.done` file per (design_row, seed), per-row flush to CSV) must be preserved
  exactly as before. Update the import in `main.rs` to include `run_sigma_paired`
  if not already present. Add a `cargo test` to verify the existing
  `integration_10_pairs_csv_20_rows` test still passes after the change.

---

## T007-2: Create analysis/gp_train_bivar.R

- [x] T007-2: Create `analysis/gp_train_bivar.R` based on `analysis/gp_train.R`
  with the following changes:
  - `param_names`: the 6 bivariate Sobol parameters in Morris μ* order:
    `mu_sigma`, `lambda`, `sigma_sigma`, `dw_obs`, `dw_bridge`, `alpha`.
  - Ranges from `defaults.toml` `[ranges]` (all six have entries after the Stage
    006 update); fall back to hardcoded values if absent.
  - `fixed` list: same structural constants as `gp_train.R` plus
    `eta_obs = pars_a$mid_eta_obs` (fixed to avoid mu_sigma collinearity).
    Sigma-trait params not in `param_names` default to `Params::default()` via
    `#[serde(default)]` and do not need explicit fixed entries.
  - Binary call uses `gp-train` subcommand with `--design results/design_gp_bivar.csv`
    and `--output results/gp_bivar_train.csv`. Use `n_lhs`, `n_rep_gp`, and
    `log_dir` from `defaults.toml` `[gp]` and `[structural]` sections.
  - Internal helper functions follow `_bivar` suffix convention
    (e.g. `make_lhs_design_bivar`, `run_gp_train_binary_bivar`).
  - Add `gp-train-bivar: release` Makefile target (analogous to existing `gp`
    target) that runs `Rscript analysis/gp_train_bivar.R`. Add it to `.PHONY`.

  **After implementing this task, stop and ask the user to run
  `make gp-train-bivar` before continuing to T007-3.**

---

## T007-3: Create analysis/gp_phase_bivar.R

- [ ] T007-3: Create `analysis/gp_phase_bivar.R` based on `analysis/gp_phase.R`
  with the following changes:
  - Read `results/gp_bivar_train.csv`. Aggregate replicates per design point
    (group by all `param_names` columns, take mean of `psi_sigma` and `psi`).
  - Train two DiceKriging GPs — one for `psi_sigma`, one for `psi` — using the
    same kernel specification as the existing pipeline: Matérn-5/2, ARD length
    scales, `nugget.estim = TRUE`, `optim.method = "BFGS"`.
  - For each of the three axis pairs and each estimand (6 prediction grids total),
    predict on a 50×50 grid with non-focal params fixed at their `defaults.toml`
    midpoints (`mid_mu_sigma`, `mid_sigma_sigma`, `mid_lambda`, `mid_dw_obs`,
    `mid_dw_bridge`, `mid_alpha`):
      - `mu_sigma × sigma_sigma` (sigma-trait space)
      - `mu_sigma × alpha` (sigma vs influence locality)
      - `mu_sigma × lambda` (sigma vs group size)
  - Write phase CSVs to `results/gp_bivar_phase/` (create if absent), one file
    per (estimand, axis_pair):
      `phase_psi_sigma_mu_sigma_sigma_sigma.csv`,
      `phase_psi_sigma_mu_sigma_alpha.csv`,
      `phase_psi_sigma_mu_sigma_lambda.csv`,
      `phase_psi_mu_sigma_sigma_sigma.csv`,
      `phase_psi_mu_sigma_alpha.csv`,
      `phase_psi_mu_sigma_lambda.csv`.
    Each CSV has three columns: the two axis parameter values and the GP mean
    prediction.
  - Print GP fit diagnostics (nugget estimate, ARD length scales) for both GPs
    to stdout before generating phase grids.
  - Internal helper functions follow `_bivar` suffix convention. Sources
    `analysis/gp_train_utils.R` and `analysis/gp_phase_utils.R` where the
    existing shared utilities apply without modification.
  - Add `gp-phase-bivar: release` Makefile target running
    `Rscript analysis/gp_phase_bivar.R`. Add to `.PHONY`.

  **After implementing this task, stop and ask the user to run
  `make gp-phase-bivar` before continuing to T007-4.**

---

## T007-4: Create analysis/plot_bivar.R

- [ ] T007-4: Create `analysis/plot_bivar.R` that reads the six phase CSVs from
  `results/gp_bivar_phase/` and produces three output PNGs in `results/plots/`:

  - `gp_bivar_mu_sigma_sigma_sigma.png` — two-panel plot (psi_sigma | psi) for
    the mu_sigma × sigma_sigma axis pair.
  - `gp_bivar_mu_sigma_alpha.png` — two-panel plot (psi_sigma | psi) for
    mu_sigma × alpha. On the **psi panel only**, overlay the Ψ=1 amplification
    contour from the archived Stage 002/003 psi surface. Load the archived
    contour from `results/003-centrality-correlation/` — specifically, find the
    alpha×lambda phase CSV that contains alpha on one axis and read the Ψ=1
    iso-line at the mid_lambda midpoint. If the archived phase CSV format does
    not support this directly, skip the overlay and note it in a CLI warning
    rather than erroring.
  - `gp_bivar_mu_sigma_lambda.png` — two-panel plot (psi_sigma | psi) for
    mu_sigma × lambda. Apply the same Ψ=1 overlay logic on the psi panel using
    the archived lambda axis.

  Use `analysis/plot_utils.R` diverging palette (`panel_diverging`) for all
  panels, with midpoint = 0. Use `patchwork` for the two-panel layout. The
  colour axis label should read `psi_sigma` or `Ψ` as appropriate. Add
  `plots-bivar` Makefile target running `Rscript analysis/plot_bivar.R`. Add to
  `.PHONY`.

  After implementing, read the written PNG files to verify they exist and report
  their file sizes to confirm non-empty output.
