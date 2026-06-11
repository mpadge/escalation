#!/usr/bin/env Rscript
# GP-based phase diagrams and emulator-based Sobol analysis.
# Loads fitted GP objects from gp_train.R, identifies the most sensitive
# parameters via ARD length scales, builds 50x50 phase grids for each pair
# of top-ranked parameters, and runs a cheap emulator-based Sobol analysis
# using 10^6 Saltelli samples.
#
# Prerequisites: install.packages(c("DiceKriging", "sensitivity", "dplyr", "cli"))
# Run from project root: Rscript analysis/gp_phase.R
# Requires: gp_psi.rds, gp_tau.rds, gp_hyperparams.csv (from gp_train.R)

library (DiceKriging)
library (sensitivity)
library (dplyr)
library (cli)

set.seed (42)

# ---------------------------------------------------------------------------
# Load fitted GPs and identify top parameters
# ---------------------------------------------------------------------------
for (f in c ("gp_psi.rds", "gp_hyperparams.csv")) {
    if (!file.exists (f)) stop (f, " not found — run gp_train.R first")
}

fit_psi <- readRDS ("gp_psi.rds")
fit_tau <- readRDS ("gp_tau.rds")

hyperparams <- read.csv ("gp_hyperparams.csv")
param_rows <- hyperparams [!is.na (hyperparams$sensitivity), ]
# short ell first = sensitive
param_rows <- param_rows [order (param_rows$ell), ]
param_names <- as.character (param_rows$param)
p <- length (param_names)

cli_alert_info (col_yellow (
    "Parameters ranked by GP ARD length scale (most sensitive first):"
))
print (param_rows [, c ("param", "ell", "sensitivity")], digits = 3)

# Medians from training data (for fixing non-focal parameters)
gp_data <- read.csv ("gp_data.csv")
param_medians <- sapply (
    param_names,
    function (nm) median (gp_data [[nm]], na.rm = TRUE)
)
cli_alert_info ("Parameter medians:")
print (round (param_medians, 3))

# Top parameters for phase diagrams
# build diagrams for all pairs of the top-4
TOP_PHASE <- min (4, p) # nolint
top_params <- param_names [seq_len (TOP_PHASE)]
cli_alert_info (
    "Building phase diagrams for: {.field {top_params}}"
)

# ---------------------------------------------------------------------------
# Phase diagram helper: 50x50 grid for two focal parameters
# ---------------------------------------------------------------------------
all_binf <- c (
    gamma = 2.0, lambda = 1.0, alpha = 0.1, theta = 1.0, beta = 0.0,
    w_win = 0.1, b = 0.0, w_loss = 0.1, dw_obs = 0.0, dw_bridge = 0.0,
    eta_obs = 0.001
)
all_bsup <- c (
    gamma = 4.0, lambda = 5.0, alpha = 2.0, theta = 4.0, beta = 3.0,
    w_win = 2.0, b = 2.0, w_loss = 2.0, dw_obs = 0.2, dw_bridge = 0.2,
    eta_obs = 0.1
)

make_phase_grid <- function (p_a, p_b, n_grid = 50) {
    seq_a <- seq (all_binf [p_a], all_bsup [p_a], length.out = n_grid)
    seq_b <- seq (all_binf [p_b], all_bsup [p_b], length.out = n_grid)
    grid <- expand.grid (A = seq_a, B = seq_b)
    colnames (grid) <- c (p_a, p_b)
    # Fill remaining parameters at their median
    for (nm in param_names) {
        if (!(nm %in% c (p_a, p_b))) grid [[nm]] <- param_medians [nm]
    }
    grid
}

# Build phases for all pairs of top parameters
pairs <- combn (top_params, 2, simplify = FALSE)
cli_alert_info ("Building {.value {length(pairs)}} phase diagrams...")

for (pair in pairs) {
    p_a <- pair [1]
    p_b <- pair [2]
    tag <- paste0 (p_a, "_vs_", p_b)
    cli_alert_info ("Phase: {tag}")

    grid <- make_phase_grid (p_a, p_b)
    x_grid <- grid [, param_names, drop = FALSE]

    pred_psi <- predict (
        fit_psi, newdata = x_grid, type = "UK", checkNames = FALSE
    )
    pred_tau <- predict (
        fit_tau, newdata = x_grid, type = "UK", checkNames = FALSE
    )

    phase_df <- grid [, c (p_a, p_b)]
    phase_df$psi_mean <- pred_psi$mean
    phase_df$psi_sd <- pred_psi$sd
    phase_df$tau_mean <- pred_tau$mean
    phase_df$tau_sd <- pred_tau$sd

    write.csv (phase_df, paste0 ("phase_", tag, ".csv"), row.names = FALSE)
    write.csv (phase_df [, c (p_a, p_b, "tau_mean", "tau_sd")],
        paste0 ("phase_", tag, "_tau.csv"),
        row.names = FALSE
    )
    cli_alert_info ("Wrote {.file {phase_{tag}.csv}")
}

# ---------------------------------------------------------------------------
# Emulator-based Sobol via 10^6 Saltelli samples (cheap: only GP evaluations)
# ---------------------------------------------------------------------------
cli_alert_info ("Running emulator-based Sobol (n=10^6)...")
n_sobol <- 1e6

make_sobol_sample <- function (n) {
    df <- as.data.frame (matrix (NA_real_, n, p))
    colnames (df) <- param_names
    for (nm in param_names) {
        df [[nm]] <- all_binf [nm] + (all_bsup [nm] - all_binf [nm]) * runif (n)
    }
    df
}

x1_gp <- make_sobol_sample (n_sobol)
x2_gp <- make_sobol_sample (n_sobol)
s_gp <- sobol2007 (model = NULL, X1 = x1_gp, X2 = x2_gp, nboot = 0)

# Evaluate GP mean on full Saltelli design in batches: the n_test × n_train
# covariance matrix overflows a 32-bit integer when n_test > ~14M rows.
n_pred <- nrow (s_gp$X)
batch_size <- 1e4L
psi_gp <- numeric (n_pred)
for (start in seq (1L, n_pred, by = batch_size)) {
    end <- min (start + batch_size - 1L, n_pred)
    psi_gp [start:end] <- predict (
        fit_psi,
        newdata = s_gp$X [start:end, param_names, drop = FALSE],
        type = "SK", checkNames = FALSE
    )$mean
}
s_gp <- tell (s_gp, psi_gp)

sobol_gp <- data.frame (
    param = param_names,
    S1    = s_gp$S$original,
    ST    = s_gp$T$original
)
sobol_gp <- sobol_gp [order (-sobol_gp$ST), ]
write.csv (sobol_gp, "sobol_gp.csv", row.names = FALSE)

cli_alert_info ("Emulator-based Sobol indices (ranked by ST):")
print (sobol_gp, digits = 3)
cli_alert_info ("Wrote {.file sobol_gp.csv}")
