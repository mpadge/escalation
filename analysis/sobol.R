#!/usr/bin/env Rscript
# Sobol' variance-based sensitivity analysis for the escalation model.
# Reads top parameters from morris_results.csv (run morris.R first), generates
# Saltelli design, runs the Rust binary, and computes first-order (S_i) and
# total-effect (S_Ti) indices.
#
# Prerequisites: install.packages(c("sensitivity", "processx", "dplyr"))
# Run from project root: Rscript analysis/sobol.R

library(sensitivity)
library(processx)
library(dplyr)
library(jsonlite)

set.seed(42)

# ---------------------------------------------------------------------------
# Select parameters: top N by mu* from Morris (or all 12 if no prior results)
# ---------------------------------------------------------------------------
TOP_N <- 6   # number of parameters to include in Sobol

# delta is fixed (suppresses Psi monotonically) — excluded from all analyses
FIXED_EXCLUDE <- c("delta")

all_param_names <- c(
  "gamma", "lambda", "alpha", "theta", "beta",
  "w_win", "b", "w_loss", "dw_obs", "dw_bridge", "eta_obs"
)
all_binf <- c(gamma=2.0, lambda=1.0, alpha=0.1, theta=1.0, beta=0.0,
              w_win=0.1, b=0.0, w_loss=0.1, dw_obs=0.0, dw_bridge=0.0,
              eta_obs=0.001)
all_bsup <- c(gamma=4.0, lambda=5.0, alpha=2.0, theta=4.0, beta=3.0,
              w_win=2.0, b=2.0, w_loss=2.0, dw_obs=0.2, dw_bridge=0.2,
              eta_obs=0.1)

if (file.exists("morris_results.csv")) {
  morris_df <- read.csv("morris_results.csv")
  morris_df <- morris_df[!(morris_df$param %in% FIXED_EXCLUDE), ]
  param_names <- as.character(morris_df$param[seq_len(min(TOP_N, nrow(morris_df)))])
  cat("Using top", length(param_names), "parameters from Morris screening",
      "(delta excluded):\n")
  cat(" ", paste(param_names, collapse = ", "), "\n")
} else {
  param_names <- all_param_names
  cat("morris_results.csv not found; using all", length(param_names), "parameters\n")
}
p <- length(param_names)

binf <- all_binf[param_names]
bsup <- all_bsup[param_names]

# Structural constants from defaults.json; inactive free params at midpoints.
d <- jsonlite::fromJSON("defaults.json")
fixed <- list(
  n = 150L, mu0 = 0.5, sigma0 = d$sigma0,
  c = d$c, e = d$e,
  dw_coop = d$dw_coop, dw_sub = d$dw_sub, dw_excl = d$dw_excl,
  eta = d$eta,
  delta_direct = d$delta_direct, delta_exploit = d$delta_exploit,
  w_min = d$w_min, w_max = d$w_max,
  sigma_drift = d$sigma_drift, rho_contested = d$rho_contested,
  eta_trauma = d$eta_trauma,
  delta = d$delta,
  t_max = 3000L,
  # parameters not in the active set fixed at midpoint of their range
  gamma = 3.0, lambda = 3.0, alpha = 1.0, theta = 2L, beta = 1.5,
  w_win = 1.0, b = 1.0, w_loss = 1.0, dw_obs = 0.1, dw_bridge = 0.1,
  eta_obs = 0.05
)

# ---------------------------------------------------------------------------
# Saltelli design: X1 and X2 sampled uniformly on actual parameter ranges
# ---------------------------------------------------------------------------
n_sobol <- 1000   # total evaluations = n * (2p + 2); increase for production
cat("Generating Saltelli design (n=", n_sobol, ", p=", p, ")...\n")
cat("Total binary calls:", n_sobol * (2 * p + 2), "\n")

make_design <- function(n, pnames, lo, hi) {
  mat <- matrix(runif(n * length(pnames)), n, length(pnames))
  df  <- as.data.frame(mat)
  colnames(df) <- pnames
  for (nm in pnames) df[[nm]] <- lo[nm] + (hi[nm] - lo[nm]) * df[[nm]]
  df
}

X1 <- make_design(n_sobol, param_names, binf, bsup)
X2 <- make_design(n_sobol, param_names, binf, bsup)

s <- sobol2007(model = NULL, X1 = X1, X2 = X2, nboot = 100)
cat("Saltelli design has", nrow(s$X), "rows\n")

# Expand to full Params CSV
design_full <- s$X
# Set all fixed params
for (nm in names(fixed)) design_full[[nm]] <- fixed[[nm]]
# Override with free param values (already in s$X)
for (nm in param_names) design_full[[nm]] <- s$X[[nm]]
# Integer coercions
design_full$theta <- pmax(1L, pmin(4L, as.integer(round(design_full$theta))))
design_full$n     <- as.integer(design_full$n)
design_full$t_max <- as.integer(design_full$t_max)

write.csv(design_full, "design_sobol.csv", row.names = FALSE)
cat("Wrote design_sobol.csv\n")

# ---------------------------------------------------------------------------
# Run the Rust binary
# ---------------------------------------------------------------------------
binary <- "./target/release/escalation"
if (!file.exists(binary)) stop("Binary not found — run 'cargo build --release'")

cat("Running binary...\n")
result <- processx::run(
  binary,
  c("sobol", "--design", "design_sobol.csv", "--output", "sobol_raw.csv"),
  echo = TRUE, error_on_status = FALSE
)
if (result$status != 0) {
  stop("Binary failed: ", result$stderr)
}

# ---------------------------------------------------------------------------
# Extract psi (odd-indexed rows = lo runs; both lo and hi share the same psi)
# ---------------------------------------------------------------------------
raw <- read.csv("sobol_raw.csv")
psi_vals <- raw$psi[seq(1, nrow(raw), by = 2)]
psi_vals[is.na(psi_vals)] <- 0

tell(s, psi_vals)

results <- data.frame(
  param = param_names,
  S1    = s$S$original,
  ST    = s$T$original,
  S1_ci = s$S$`max. c.i.` - s$S$`min. c.i.`,
  ST_ci = s$T$`max. c.i.` - s$T$`min. c.i.`
)
results <- results[order(-results$ST), ]
write.csv(results, "sobol_results.csv", row.names = FALSE)

cat("\nSobol results (ranked by ST):\n")
print(results, digits = 3)
cat("\nWrote sobol_results.csv\n")
