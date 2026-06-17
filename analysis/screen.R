#!/usr/bin/env Rscript
# Morris elementary-effects screening for the bivariate (ε, σ) escalation model.
# Generates an OAT trajectory design over 14 free parameters, runs the Rust binary
# for each point (paired mu0 conditions), and computes mu*, sigma per parameter for
# both psi_sigma (primary) and psi estimands.
#
# eta_obs is held fixed to avoid collinearity with mu_sigma: both scale the
# observational-learning pathway. The sigma-degenerate case (mu_sigma=1,
# sigma_sigma=0) is recovered by inspection of the sensitivity rankings.
#
# Output: results/morris_results.csv (long format: param x estimand)
#
# Prerequisites: install.packages(c("sensitivity", "processx", "dplyr", "cli", "RcppTOML"))
# Run from project root: Rscript analysis/screen.R
# Requires: cargo build --release

library (sensitivity)
library (processx)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)

source ("analysis/utils.R")

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

make_morris_design <- function (param_names, binf, bsup, fixed, results_dir,
                                r = 15L) {
    p <- length (param_names)
    cli_alert_info (
        "Generating Morris design (r={.val {r}} trajectories, \\
        p={.val {p}} parameters)..."
    )
    m <- morris (
        model   = NULL,
        factors = param_names,
        r       = r,
        design  = list (type = "oat", levels = 8, grid.jump = 4),
        binf    = binf [param_names],
        bsup    = bsup [param_names]
    )
    cli_alert_info ("Design has {nrow(m$X)} rows")

    design_full <- as.data.frame (m$X)
    colnames (design_full) <- param_names
    for (nm in names (fixed)) design_full [[nm]] <- fixed [[nm]]
    for (nm in param_names)   design_full [[nm]] <- m$X [, nm]
    design_full$theta <-
        pmax (1L, pmin (4L, as.integer (round (design_full$theta))))
    design_full$n     <- as.integer (design_full$n)
    design_full$t_max <- as.integer (design_full$t_max)

    write.csv (
        design_full,
        file.path (results_dir, "design_morris.csv"),
        row.names = FALSE
    )
    cli_alert_info ("Wrote design_morris.csv ({.val {nrow(design_full)}} rows)")
    list (m = m, design_full = design_full)
}

run_morris_binary <- function (binary, results_dir, log_dir) {
    cli_alert_info ("Running binary...")
    result <- processx::run (
        binary,
        c (
            "morris", "--design",
            file.path (results_dir, "design_morris.csv"),
            "--output", file.path (results_dir, "morris_raw.csv"),
            "--log-dir", log_dir
        ),
        echo = TRUE, error_on_status = FALSE
    )
    if (result$status != 0) {
        cli_abort (
            "Binary exited with status {.val {result$status}}: {result$stderr}"
        )
    }
}

compute_morris_indices <- function (m, design_full, param_names, metric_col,
                                    results_dir) {
    raw <- read.csv (file.path (results_dir, "morris_raw.csv"))
    if (nrow (raw) != 2L * nrow (design_full)) {
        cli_alert_warning (
            "Expected {.val {2L * nrow(design_full)}} rows, \\
            got {.val {nrow(raw)}}"
        )
    }
    vals <- raw [[metric_col]] [seq (1L, nrow (raw), by = 2L)]
    if (any (is.na (vals))) {
        cli_alert_warning (
            "{.val {sum(is.na(vals))}} NA {metric_col} values replaced with 0"
        )
        vals [is.na (vals)] <- 0
    }

    m_copy <- m
    m_copy <- tell (m_copy, vals)

    mu_star <- apply (m_copy$ee, 2, function (e) mean (abs (e)))
    sigma   <- apply (m_copy$ee, 2, sd)
    mu      <- apply (m_copy$ee, 2, mean)

    data.frame (
        param    = param_names,
        estimand = metric_col,
        mu_star  = mu_star,
        sigma    = sigma,
        mu       = mu
    ) |>
        arrange (desc (mu_star))
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)

results_dir <- "results"
dir.create (results_dir, showWarnings = FALSE)

# 14 free parameters: original 10 (eta_obs fixed to avoid collinearity with
# mu_sigma) + 4 sigma-trait parameters introduced in the bivariate model
param_names <- c (
    "gamma",       # network attachment exponent
    "lambda",      # mean group size (Poisson)
    "alpha",       # locality / distance decay
    "theta",       # audience radius (integer 1-4)
    "beta",        # status-advantage multiplier
    "w_win",       # win payoff
    "b",           # cooperation benefit
    "w_loss",      # loss cost
    "dw_obs",      # observer edge increment
    "dw_bridge",   # bridge edge increment
    "mu_sigma",    # initial mean sigma (per-agent status sensitivity)
    "sigma_sigma", # initial SD of sigma
    "eta_sigma",   # sigma update rate
    "sigma_decay"  # per-timestep sigma drift
)

pars   <- RcppTOML::parseTOML ("defaults.toml")
pars_s <- pars$structural
pars_a <- pars$analysis

get_range <- function (nm) {
    r <- pars$ranges [[nm]]
    if (!is.null (r)) return (r)
    stop ("No range found in defaults.toml for: ", nm)
}

binf <- setNames (
    vapply (param_names, function (nm) get_range (nm) [1L], numeric (1)),
    param_names
)
bsup <- setNames (
    vapply (param_names, function (nm) get_range (nm) [2L], numeric (1)),
    param_names
)

log_dir <- if (!is.null (pars_s$log_dir)) pars_s$log_dir else "/tmp/escalation"
dir.create (log_dir, recursive = TRUE, showWarnings = FALSE)
safe_clear_done_files (log_dir, expected_n = 15L * (length (param_names) + 1L))
cli_alert_info ("Progress files will be written to {.file {log_dir}}")

fixed <- list (
    n             = as.integer (pars_a$n),
    mu0           = pars_a$mu0,
    sigma0        = pars_a$sigma0,
    c             = pars_a$c,
    e             = pars_a$e,
    dw_coop       = pars_a$dw_coop,
    dw_sub        = pars_a$dw_sub,
    dw_excl       = pars_a$dw_excl,
    eta           = pars_a$eta,
    eta_obs       = pars_a$mid_eta_obs,  # fixed to avoid collinearity with mu_sigma
    delta_direct  = pars_a$delta_direct,
    delta_exploit = pars_a$delta_exploit,
    w_min         = pars_s$w_min,
    w_max         = pars_s$w_max,
    sigma_drift   = pars_s$sigma_drift,
    rho_contested = pars_s$rho_contested,
    eta_trauma    = pars_s$eta_trauma,
    delta         = pars_s$delta,
    t_max         = as.integer (pars_a$t_max_morris)
)

binary <- "./target/release/escalation"
if (!file.exists (binary)) {
    cli_abort ("Binary not found — run 'cargo build --release'")
}

design <- make_morris_design (param_names, binf, bsup, fixed, results_dir)
run_morris_binary (binary, results_dir, log_dir)

res_psi_sigma <- compute_morris_indices (
    design$m, design$design_full, param_names, "psi_sigma", results_dir
)
res_psi <- compute_morris_indices (
    design$m, design$design_full, param_names, "psi", results_dir
)

results <- rbind (res_psi_sigma, res_psi)
write.csv (results, file.path (results_dir, "morris_results.csv"), row.names = FALSE)

cli_alert_info ("psi_sigma Morris results (ranked by mu*):")
print (res_psi_sigma [, c ("param", "mu_star", "sigma")], digits = 3, row.names = FALSE)
cli_alert_info ("psi Morris results (ranked by mu*):")
print (res_psi [, c ("param", "mu_star", "sigma")], digits = 3, row.names = FALSE)
cli_alert_success ("Wrote morris_results.csv")
