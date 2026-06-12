#!/usr/bin/env Rscript
# Stage 3: Two-GP emulator training on epsilon-degree correlation surfaces.
# Reads Stage 1 simulation data (gp_train_raw.csv), splits by mu0 condition,
# and fits separate Matern-5/2 ARD GPs for C_lo (mu0=0.4) and C_hi (mu0=0.6)
# using epsilon_k_corr_final as the response variable.
#
# Prerequisites: install.packages(c("DiceKriging", "dplyr", "RcppTOML", "cli"))
# Run from project root: Rscript analysis/gp_train3.R
# Requires: results/gp_train_raw.csv (from Stage 1 make gp)

source ("analysis/gp_train_utils.R")

set.seed (42)
cli_h1 (col_yellow ("Stage 3: Two-GP training on epsilon-degree correlation surfaces"))

results_dir <- "results"
pars        <- RcppTOML::parseTOML ("defaults.toml")
n_rep       <- as.integer (pars$gp$n_rep_gp)

cli_h2 (col_yellow ("Load and aggregate Stage 1 data"))
raw      <- load_raw_data (results_dir, n_rep)
gp3_data <- build_design_matrix (raw, "epsilon_k_corr_final")
write.csv (gp3_data, file.path (results_dir, "gp3_data.csv"), row.names = FALSE)
cli_alert_info ("Wrote {.file gp3_data.csv}")

cli_h2 (col_yellow ("Train-test split"))
splits <- split_train_test (gp3_data)

cli_h2 (col_yellow ("Fit GP on C_lo (mu0 = 0.4)"))
fit_corr_lo <- fit_gp_surface (splits$X_train, splits$y_lo_train, "C_lo")
saveRDS (fit_corr_lo, file.path (results_dir, "gp_corr_lo.rds"))
cli_alert_info ("Saved {.file gp_corr_lo.rds}")

cli_h2 (col_yellow ("Fit GP on C_hi (mu0 = 0.6)"))
fit_corr_hi <- fit_gp_surface (splits$X_train, splits$y_hi_train, "C_hi")
saveRDS (fit_corr_hi, file.path (results_dir, "gp_corr_hi.rds"))
cli_alert_info ("Saved {.file gp_corr_hi.rds}")

cli_h2 (col_yellow ("Validation"))
val_lo <- validate_gp_surface (fit_corr_lo, splits$X_test, splits$y_lo_test, "C_lo")
val_hi <- validate_gp_surface (fit_corr_hi, splits$X_test, splits$y_hi_test, "C_hi")

cli_h2 (col_yellow ("Hyperparameters"))
hp_lo <- print_hyperparams (fit_corr_lo, "C_lo")
hp_hi <- print_hyperparams (fit_corr_hi, "C_hi")
save_hyperparams_csv (hp_lo, hp_hi, val_lo, val_hi,
                      file.path (results_dir, "gp3_hyperparams.csv"))

cli_alert_success (col_green ("Done. Run {.code make gp3_phase} next."))
