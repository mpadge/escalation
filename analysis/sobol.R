#!/usr/bin/env Rscript
# Sobol' variance-based sensitivity analysis for the escalation model.
# Reads top parameters from morris_results.csv (run morris.R first), generates
# Saltelli design, runs the Rust binary, and computes first-order (S_i) and
# total-effect (S_Ti) indices.
#
# Prerequisites: install.packages(c("sensitivity", "processx", "dplyr", "cli"))
# Run from project root: Rscript analysis/sobol.R

library (sensitivity)
library (processx)
library (dplyr)
library (RcppTOML)
library (cli)

set.seed (42)

results_dir <- "results"
if (!dir.exists (results_dir)) {
    cli_abort (
        "Output directory {.file {results_dir}} not found — \\
        run {.file analysis/morris.R} first"
    )
}

pars <- RcppTOML::parseTOML ("defaults.toml")
pars_s <- pars$structural
pars_a <- pars$analysis

# ---------------------------------------------------------------------------
# Select parameters: top N by mu* from Morris (or all 11 if no prior results)
# ---------------------------------------------------------------------------
# number of parameters to include in Sobol
TOP_N <- pars$sobol$top_n # nolint

# delta is fixed (suppresses Psi monotonically) — excluded from all analyses
FIXED_EXCLUDE <- c ("delta") # nolint

all_param_names <- c (
    "gamma", "lambda", "alpha", "theta", "beta",
    "w_win", "b", "w_loss", "dw_obs", "dw_bridge", "eta_obs"
)
all_binf <- c (
    gamma = 1.0, lambda = 1.0, alpha = 0.1, theta = 1.0, beta = 0.0,
    w_win = 0.0, b = 0.0, w_loss = 0.1, dw_obs = 0.0, dw_bridge = 0.0,
    eta_obs = 0.001
)
all_bsup <- c (
    gamma = 5.0, lambda = 5.0, alpha = 2.0, theta = 4.0, beta = 1.0,
    w_win = 2.0, b = 2.0, w_loss = 2.0, dw_obs = 0.2, dw_bridge = 0.2,
    eta_obs = 0.1
)

if (file.exists (file.path (results_dir, "morris_results.csv"))) {
    morris_df <- read.csv (file.path (results_dir, "morris_results.csv"))
    morris_df <- morris_df [!(morris_df$param %in% FIXED_EXCLUDE), ]
    param_names <- morris_df$param [seq_len (min (TOP_N, nrow (morris_df)))]
    cli_alert_info (
        "Using top {.value {length(param_names)}} parameters from Morris \\
        screening (delta excluded): {.field {param_names}}"
    )
} else {
    param_names <- all_param_names
    cli_alert_warning (
        "morris_results.csv not found; using all \\
        {.value {length(param_names)}} parameters"
    )
}
p <- length (param_names)

binf <- all_binf [param_names]
bsup <- all_bsup [param_names]

# Structural constants from defaults.toml; inactive free params at midpoints.
log_dir <- if (!is.null (pars_s$log_dir)) pars_s$log_dir else "/tmp/escalation"
dir.create (log_dir, recursive = TRUE, showWarnings = FALSE)
old_done <- list.files (log_dir, pattern = "\\.done$", full.names = TRUE)
if (length (old_done) > 0) file.remove (old_done)
cli_alert_info ("Progress files will be written to {log_dir}")

fixed <- list (
    n = as.integer (pars$sobol$n_sobol_pop), mu0 = pars_a$mu0, sigma0 = pars_a$sigma0,
    c = pars_a$c, e = pars_a$e,
    dw_coop = pars_a$dw_coop, dw_sub = pars_a$dw_sub, dw_excl = pars_a$dw_excl,
    eta = pars_a$eta,
    delta_direct = pars_a$delta_direct, delta_exploit = pars_a$delta_exploit,
    w_min = pars_s$w_min, w_max = pars_s$w_max,
    sigma_drift = pars_s$sigma_drift, rho_contested = pars_s$rho_contested,
    eta_trauma = pars_s$eta_trauma,
    delta = pars_s$delta,
    t_max = as.integer (pars_a$t_max_sobol),
    # parameters not in the active set fixed at midpoint of their range
    gamma = pars_a$mid_gamma, lambda = pars_a$mid_lambda, alpha = pars_a$mid_alpha,
    theta = as.integer (pars_a$mid_theta), beta = pars_a$mid_beta,
    w_win = pars_a$mid_w_win, b = pars_a$mid_b, w_loss = pars_a$mid_w_loss,
    dw_obs = pars_a$mid_dw_obs, dw_bridge = pars_a$mid_dw_bridge,
    eta_obs = pars_a$mid_eta_obs
)

# ---------------------------------------------------------------------------
# Saltelli design: x1 and x2 sampled uniformly on actual parameter ranges
# ---------------------------------------------------------------------------
n_sobol <- pars$sobol$n_sobol # total evaluations = n * (2p + 2)
cli_alert_info ("Generating Saltelli design (n={n_sobol}, p={p})...")
cli_alert_info ("Total binary calls: {n_sobol * (2 * p + 2)}")

make_design <- function (n, pnames, lo, hi) {
    mat <- matrix (runif (n * length (pnames)), n, length (pnames))
    df <- as.data.frame (mat)
    colnames (df) <- pnames
    for (nm in pnames) df [[nm]] <- lo [nm] + (hi [nm] - lo [nm]) * df [[nm]]
    df
}

x1 <- make_design (n_sobol, param_names, binf, bsup)
x2 <- make_design (n_sobol, param_names, binf, bsup)

s_obj <- sobol2007 (model = NULL, x1 = x1, x2 = x2, nboot = 100)
n_expected <- nrow (s_obj$X)
cli_alert_info ("Saltelli design has {.value {n_expected}} rows")
cli_alert_info (
    "Expected {.value {n_expected}} progress files — \\
    monitor with {.code make progress}."
)

# Expand to full Params CSV
design_full <- s_obj$X
# Set all fixed params
for (nm in names (fixed)) design_full [[nm]] <- fixed [[nm]]
# Override with free param values (already in s_obj$X)
for (nm in param_names) design_full [[nm]] <- s_obj$X [[nm]]
# Integer coercions
design_full$theta <-
    pmax (1L, pmin (4L, as.integer (round (design_full$theta))))
design_full$n <- as.integer (design_full$n)
design_full$t_max <- as.integer (design_full$t_max)

write.csv (
    design_full,
    file.path (results_dir, "design_sobol.csv"),
    row.names = FALSE
)
cli_alert_info ("Wrote design_sobol.csv")

# ---------------------------------------------------------------------------
# Run the Rust binary
# ---------------------------------------------------------------------------
binary <- "./target/release/escalation"
if (!file.exists (binary)) {
    cli_abort ("Binary not found — run 'cargo build --release'")
}

cli_alert_info ("Running binary...")
result <- processx::run (
    binary,
    c (
        "sobol", "--design",
        file.path (results_dir, "design_sobol.csv"),
        "--output", file.path (results_dir, "sobol_raw.csv"),
        "--log-dir", log_dir
    ),
    echo = TRUE, error_on_status = FALSE
)
if (result$status != 0) {
    stop ("Binary failed: ", result$stderr)
}

# ---------------------------------------------------------------------------
# Extract psi (odd-indexed rows = lo runs; both lo and hi share the same psi)
# ---------------------------------------------------------------------------
raw <- read.csv (file.path (results_dir, "sobol_raw.csv"))
psi_vals <- raw$psi [seq (1, nrow (raw), by = 2)]
psi_vals [is.na (psi_vals)] <- 0

s_obj <- tell (s_obj, psi_vals)

results <- data.frame (
    param = param_names,
    S1    = s_obj$S$original,
    ST    = s_obj$T$original,
    S1_ci = s_obj$S$`max. c.i.` - s_obj$S$`min. c.i.`,
    ST_ci = s_obj$T$`max. c.i.` - s_obj$T$`min. c.i.`
)
results <- results [order (-results$ST), ]
write.csv (
    results,
    file.path (results_dir, "sobol_results.csv"),
    row.names = FALSE
)

cli_alert_info ("Sobol results (ranked by ST):")
print (results, digits = 3)
cli_alert_info ("Wrote {.file sobol_results.csv}")
