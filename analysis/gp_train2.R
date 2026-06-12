#!/usr/bin/env Rscript
# Stage 2: Two-GP emulator training on absolute equilibrium escalation surfaces.
# Reads Stage 1 simulation data (gp_train_raw.csv), splits by mu0 condition,
# and fits separate Matern-5/2 ARD GPs for E_lo (mu0=0.4) and E_hi (mu0=0.6).
#
# Prerequisites: install.packages(c("DiceKriging", "dplyr", "RcppTOML", "cli"))
# Run from project root: Rscript analysis/gp_train2.R
# Requires: results/gp_train_raw.csv (from Stage 1 make gp)

source ("analysis/gp_train_utils.R")

set.seed (42)
cli_h1 (col_yellow ("Stage 2: Two-GP training on absolute escalation surfaces"))

results_dir <- "results"
pars        <- RcppTOML::parseTOML ("defaults.toml")
n_rep       <- as.integer (pars$gp$n_rep_gp)

cli_h2 (col_yellow ("Load and aggregate Stage 1 data"))
raw      <- load_raw_data (results_dir, n_rep)
gp2_data <- build_design_matrix (raw, "mean_epsilon_final")
write.csv (gp2_data, file.path (results_dir, "gp2_data.csv"), row.names = FALSE)
cli_alert_info ("Wrote {.file gp2_data.csv}")

cli_h2 (col_yellow ("Train-test split"))
splits <- split_train_test (gp2_data)

cli_h2 (col_yellow ("Fit GP on E_lo (mu0 = 0.4)"))
fit_lo <- fit_gp_surface (splits$X_train, splits$y_lo_train, "E_lo")
saveRDS (fit_lo, file.path (results_dir, "gp_lo.rds"))
cli_alert_info ("Saved {.file gp_lo.rds}")

cli_h2 (col_yellow ("Fit GP on E_hi (mu0 = 0.6)"))
fit_hi <- fit_gp_surface (splits$X_train, splits$y_hi_train, "E_hi")
saveRDS (fit_hi, file.path (results_dir, "gp_hi.rds"))
cli_alert_info ("Saved {.file gp_hi.rds}")

cli_h2 (col_yellow ("Validation"))
val_lo <- validate_gp_surface (fit_lo, splits$X_test, splits$y_lo_test, "E_lo")
val_hi <- validate_gp_surface (fit_hi, splits$X_test, splits$y_hi_test, "E_hi")

cli_h2 (col_yellow ("Hyperparameters"))
hp_lo <- print_hyperparams (fit_lo, "E_lo")
hp_hi <- print_hyperparams (fit_hi, "E_hi")
save_hyperparams_csv (hp_lo, hp_hi, val_lo, val_hi,
                      file.path (results_dir, "gp2_hyperparams.csv"))

cli_alert_success (col_green ("Done. Run {.code make gp2_phase} next."))
