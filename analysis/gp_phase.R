#!/usr/bin/env Rscript
# GP-based phase diagrams and emulator-based Sobol analysis.
# Loads fitted GP objects from gp_train.R, identifies the most sensitive
# parameters via ARD length scales, builds 50x50 phase grids for each pair
# of top-ranked parameters, and runs a cheap emulator-based Sobol analysis
# using 10^6 Saltelli samples.
#
# Prerequisites: install.packages(c("DiceKriging", "sensitivity", "dplyr"))
# Run from project root: Rscript analysis/gp_phase.R
# Requires: gp_psi.rds, gp_tau.rds, gp_hyperparams.csv (from gp_train.R)

library(DiceKriging)
library(sensitivity)
library(dplyr)

set.seed(42)

# ---------------------------------------------------------------------------
# Load fitted GPs and identify top parameters
# ---------------------------------------------------------------------------
for (f in c("gp_psi.rds", "gp_hyperparams.csv")) {
  if (!file.exists(f)) stop(f, " not found — run gp_train.R first")
}

fit_psi <- readRDS("gp_psi.rds")
fit_tau <- readRDS("gp_tau.rds")

hyperparams <- read.csv("gp_hyperparams.csv")
param_rows  <- hyperparams[!is.na(hyperparams$sensitivity), ]
param_rows  <- param_rows[order(param_rows$ell), ]   # short ell first = sensitive
param_names <- as.character(param_rows$param)
p <- length(param_names)

cat("Parameters ranked by GP ARD length scale (most sensitive first):\n")
print(param_rows[, c("param", "ell", "sensitivity")], digits = 3)

# Medians from training data (for fixing non-focal parameters)
gp_data    <- read.csv("gp_data.csv")
param_medians <- sapply(param_names, function(nm) median(gp_data[[nm]], na.rm = TRUE))
cat("Parameter medians:\n"); print(round(param_medians, 3))

# Top parameters for phase diagrams
TOP_PHASE  <- min(4, p)  # build diagrams for all pairs of the top-4
top_params <- param_names[seq_len(TOP_PHASE)]
cat("Building phase diagrams for:", paste(top_params, collapse = ", "), "\n")

# ---------------------------------------------------------------------------
# Phase diagram helper: 50x50 grid for two focal parameters
# ---------------------------------------------------------------------------
all_binf <- c(gamma=2.0, lambda=1.0, alpha=0.1, theta=1.0, beta=0.0,
              w_win=0.1, b=0.0, w_loss=0.1, dw_obs=0.0, dw_bridge=0.0,
              eta_obs=0.001, delta=0.001)
all_bsup <- c(gamma=4.0, lambda=5.0, alpha=2.0, theta=4.0, beta=3.0,
              w_win=2.0, b=2.0, w_loss=2.0, dw_obs=0.2, dw_bridge=0.2,
              eta_obs=0.1, delta=0.05)

make_phase_grid <- function(pA, pB, n_grid = 50) {
  seqA <- seq(all_binf[pA], all_bsup[pA], length.out = n_grid)
  seqB <- seq(all_binf[pB], all_bsup[pB], length.out = n_grid)
  grid <- expand.grid(A = seqA, B = seqB)
  colnames(grid) <- c(pA, pB)
  # Fill remaining parameters at their median
  for (nm in param_names) {
    if (!(nm %in% c(pA, pB))) grid[[nm]] <- param_medians[nm]
  }
  grid
}

# Build phases for all pairs of top parameters
pairs <- combn(top_params, 2, simplify = FALSE)
cat("Building", length(pairs), "phase diagrams...\n")

for (pair in pairs) {
  pA <- pair[1]; pB <- pair[2]
  tag <- paste0(pA, "_vs_", pB)
  cat("  Phase:", tag, "\n")

  grid <- make_phase_grid(pA, pB)
  X_grid <- grid[, param_names, drop = FALSE]

  pred_psi <- predict(fit_psi, newdata = X_grid, type = "UK", checkNames = FALSE)
  pred_tau <- predict(fit_tau, newdata = X_grid, type = "UK", checkNames = FALSE)

  phase_df <- grid[, c(pA, pB)]
  phase_df$psi_mean <- pred_psi$mean
  phase_df$psi_sd   <- pred_psi$sd
  phase_df$tau_mean <- pred_tau$mean
  phase_df$tau_sd   <- pred_tau$sd

  write.csv(phase_df, paste0("phase_", tag, ".csv"),     row.names = FALSE)
  write.csv(phase_df[, c(pA, pB, "tau_mean", "tau_sd")],
            paste0("phase_", tag, "_tau.csv"),            row.names = FALSE)
  cat("    Wrote phase_", tag, ".csv\n", sep = "")
}

# ---------------------------------------------------------------------------
# Emulator-based Sobol via 10^6 Saltelli samples (cheap: only GP evaluations)
# ---------------------------------------------------------------------------
cat("Running emulator-based Sobol (n=10^6)...\n")
n_sobol <- 1e6

make_sobol_sample <- function(n) {
  df <- as.data.frame(matrix(NA_real_, n, p))
  colnames(df) <- param_names
  for (nm in param_names) {
    df[[nm]] <- all_binf[nm] + (all_bsup[nm] - all_binf[nm]) * runif(n)
  }
  df
}

X1_gp <- make_sobol_sample(n_sobol)
X2_gp <- make_sobol_sample(n_sobol)
s_gp  <- sobol2007(model = NULL, X1 = X1_gp, X2 = X2_gp, nboot = 0)

# Evaluate GP mean on full Saltelli design (SK = Simple Kriging, no variance,
# much faster than UK for large n)
psi_gp <- predict(fit_psi, newdata = s_gp$X[, param_names, drop = FALSE],
                  type = "SK", checkNames = FALSE)$mean
tell(s_gp, psi_gp)

sobol_gp <- data.frame(
  param = param_names,
  S1    = s_gp$S$original,
  ST    = s_gp$T$original
)
sobol_gp <- sobol_gp[order(-sobol_gp$ST), ]
write.csv(sobol_gp, "sobol_gp.csv", row.names = FALSE)

cat("\nEmulator-based Sobol indices (ranked by ST):\n")
print(sobol_gp, digits = 3)
cat("Wrote sobol_gp.csv\n")
