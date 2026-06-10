#!/usr/bin/env Rscript
# Morris elementary-effects screening for the escalation model.
# Generates an OAT trajectory design, runs the Rust binary for each point (paired
# mu0=0.4 vs mu0=0.6), and computes mu* and sigma per parameter.
#
# Prerequisites: install.packages(c("sensitivity", "processx", "dplyr", "cli"))
# Run from project root: Rscript analysis/morris.R
# Requires a release build: cargo build --release

library(sensitivity)
library(processx)
library(dplyr)
library(jsonlite)
library(cli)

set.seed(42)

# ---------------------------------------------------------------------------
# Parameter space (11 free parameters after ratio reparametrisation)
# ---------------------------------------------------------------------------
param_names <- c(
  "gamma",    # network attachment exponent
  "lambda",   # mean group size (Poisson)
  "alpha",    # locality / distance decay
  "theta",    # audience radius (integer 1-4)
  "beta",     # status-advantage multiplier
  "w_win",    # win payoff (with c=0.5 fixed: r_win_cost = w_win/c)
  "b",        # cooperation benefit (with e=0.5: r_coop_exploit = b/e)
  "w_loss",   # loss cost (ratio r_loss_win = w_loss/w_win)
  "dw_obs",   # observer edge increment (with dw_coop=0.15: r_obs_coop)
  "dw_bridge",# bridge edge increment (with dw_sub=0.15: r_bridge_sub)
  "eta_obs"   # observational learning rate (with eta=0.1: kappa = eta_obs/eta)
  # delta fixed at d$delta — suppresses Psi monotonically; held out of analyses
)
p <- length(param_names)

binf <- c(gamma=2.0, lambda=1.0, alpha=0.1, theta=1.0, beta=0.0,
          w_win=0.1, b=0.0, w_loss=0.1, dw_obs=0.0, dw_bridge=0.0,
          eta_obs=0.001)
bsup <- c(gamma=4.0, lambda=5.0, alpha=2.0, theta=4.0, beta=3.0,
          w_win=2.0, b=2.0, w_loss=2.0, dw_obs=0.2, dw_bridge=0.2,
          eta_obs=0.1)

# Fixed parameters (not varied in this stage)
# Structural constants from defaults.json; t_max reduced for screening speed.
d <- jsonlite::fromJSON("defaults.json")
fixed <- list(
  n = as.integer(d$n), mu0 = 0.5, sigma0 = d$sigma0,
  c = d$c, e = d$e,
  dw_coop = d$dw_coop, dw_sub = d$dw_sub, dw_excl = d$dw_excl,
  eta = d$eta,
  delta_direct = d$delta_direct, delta_exploit = d$delta_exploit,
  w_min = d$w_min, w_max = d$w_max,
  sigma_drift = d$sigma_drift, rho_contested = d$rho_contested,
  eta_trauma = d$eta_trauma,
  delta = d$delta,
  t_max = 2000L
)

# ---------------------------------------------------------------------------
# Generate Morris OAT design
# ---------------------------------------------------------------------------
cli_alert_info("Generating Morris design (r=15 trajectories, p={p} parameters)...")
m <- morris(
  model  = NULL,
  factors = param_names,
  r      = 15,
  design = list(type = "oat", levels = 8, grid.jump = 4),
  binf   = binf[param_names],
  bsup   = bsup[param_names]
)
cli_alert_info("Design has {nrow(m$X)} rows")

# Expand to full Params CSV (all 29 fields required by the Rust binary)
design_full <- as.data.frame(m$X)
colnames(design_full) <- param_names
for (nm in names(fixed)) design_full[[nm]] <- fixed[[nm]]
design_full$theta <- pmax(1L, pmin(4L, as.integer(round(design_full$theta))))
design_full$n     <- as.integer(design_full$n)
design_full$t_max <- as.integer(design_full$t_max)

write.csv(design_full, "design_morris.csv", row.names = FALSE)
cli_alert_info("Wrote design_morris.csv ({nrow(design_full)} rows x {ncol(design_full)} cols)")

# ---------------------------------------------------------------------------
# Run the Rust binary
# ---------------------------------------------------------------------------
binary <- "./target/release/escalation"
if (!file.exists(binary)) {
  stop("Binary not found at ", binary, " — run 'cargo build --release' first")
}

cli_alert_info("Running binary...")
result <- processx::run(
  binary,
  c("morris", "--design", "design_morris.csv", "--output", "morris_raw.csv"),
  echo = TRUE,
  error_on_status = FALSE
)
if (result$status != 0) {
  stop("Binary exited with status ", result$status, "\nstderr: ", result$stderr)
}

# ---------------------------------------------------------------------------
# Collect psi values (binary outputs 2 rows per design point: lo then hi)
# Both rows carry the same psi; take the odd-indexed rows (lo runs).
# ---------------------------------------------------------------------------
raw <- read.csv("morris_raw.csv")
if (nrow(raw) != 2 * nrow(design_full)) {
  cli_alert_warning("Expected {2 * nrow(design_full)} rows, got {nrow(raw)}")
}
psi_vals <- raw$psi[seq(1, nrow(raw), by = 2)]
if (any(is.na(psi_vals))) {
  cli_alert_warning("{sum(is.na(psi_vals))} NA psi values replaced with 0")
  psi_vals[is.na(psi_vals)] <- 0
}

# ---------------------------------------------------------------------------
# Compute Morris sensitivity indices
# ---------------------------------------------------------------------------
m <- tell(m, psi_vals)

# sensitivity 1.30+ stores elementary effects in m$ee; mu*/sigma computed here
mu_star <- apply(m$ee, 2, function(e) mean(abs(e)))
sigma   <- apply(m$ee, 2, sd)
mu      <- apply(m$ee, 2, mean)

results <- data.frame(
  param   = param_names,
  mu_star = mu_star,
  sigma   = sigma,
  mu      = mu
)
results <- results[order(-results$mu_star), ]
write.csv(results, "morris_results.csv", row.names = FALSE)

cli_alert_info("Morris results (ranked by mu*):")
print(results, digits = 3)
cli_alert_info("Wrote morris_results.csv")
