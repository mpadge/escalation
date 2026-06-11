#!/usr/bin/env Rscript
# Morris elementary-effects screening for the escalation model.
# Generates an OAT trajectory design, runs the Rust binary for each point
# (paired mu0=0.4 vs mu0=0.6), and computes mu* and sigma per parameter.
#
# Prerequisites: install.packages(c("sensitivity", "processx", "dplyr", "cli"))
# Run from project root: Rscript analysis/morris.R
# Requires a release build: cargo build --release

library (sensitivity)
library (processx)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

make_morris_design <- function (param_names, binf, bsup, fixed, results_dir,
                                r = 15) {
    p <- length (param_names)
    cli_alert_info (
        "Generating Morris design (r={.val {r}} trajectories, \\
        p={.val {p}} parameters)..."
    )
    m <- morris (
        model  = NULL,
        factors = param_names,
        r      = r,
        design = list (type = "oat", levels = 8, grid.jump = 4),
        binf   = binf [param_names],
        bsup   = bsup [param_names]
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
    cli_alert_info (
        "Wrote design_morris.csv ({.val {nrow(design_full)}} rows x \\
        {.val {ncol(design_full)}} cols)"
    )
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
            "Binary exited with status {.val {result$status}}, \\
            stderr: {result$stderr}"
        )
    }
}

compute_morris_indices <- function (m, design_full, param_names, results_dir) {
    raw <- read.csv (file.path (results_dir, "morris_raw.csv"))
    if (nrow (raw) != 2 * nrow (design_full)) {
        cli_alert_warning (
            "Expected {.val {2 * nrow(design_full)}} rows, got {.val {nrow(raw)}}"
        )
    }
    psi_vals <- raw$psi [seq (1, nrow (raw), by = 2)]
    if (any (is.na (psi_vals))) {
        cli_alert_warning (
            "{.val {sum(is.na(psi_vals))}} NA psi values replaced with 0"
        )
        psi_vals [is.na (psi_vals)] <- 0
    }

    m <- tell (m, psi_vals)

    mu_star <- apply (m$ee, 2, function (e) mean (abs (e)))
    sigma   <- apply (m$ee, 2, sd)
    mu      <- apply (m$ee, 2, mean)

    results <- data.frame (
        param   = param_names,
        mu_star = mu_star,
        sigma   = sigma,
        mu      = mu
    )
    results <- results [order (-results$mu_star), ]
    write.csv (
        results,
        file.path (results_dir, "morris_results.csv"),
        row.names = FALSE
    )
    cli_alert_info ("Morris results (ranked by mu*):")
    print (results, digits = 3)
    cli_alert_info ("Wrote morris_results.csv")
    invisible (results)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)

results_dir <- "results"
dir.create (results_dir, showWarnings = FALSE)

# Parameter space (11 free parameters after ratio reparametrisation)
param_names <- c (
    "gamma",     # network attachment exponent
    "lambda",    # mean group size (Poisson)
    "alpha",     # locality / distance decay
    "theta",     # audience radius (integer 1-4)
    "beta",      # status-advantage multiplier
    "w_win",     # win payoff (with c=0.5 fixed: r_win_cost = w_win/c)
    "b",         # cooperation benefit (with e=0.5: r_coop_exploit = b/e)
    "w_loss",    # loss cost (ratio r_loss_win = w_loss/w_win)
    "dw_obs",    # observer edge increment (with dw_coop=0.15: r_obs_coop)
    "dw_bridge", # bridge edge increment (with dw_sub=0.15: r_bridge_sub)
    "eta_obs"    # observational learning rate (with eta=0.1: kappa = eta_obs/eta)
    # delta fixed at pars_s$delta — suppresses Psi monotonically; held out of
    # analyses
)

# Structural constants from defaults.toml; t_max reduced for screening speed.
pars   <- RcppTOML::parseTOML ("defaults.toml")
pars_s <- pars$structural
pars_a <- pars$analysis

binf <- setNames (
    vapply (param_names, function (nm) pars$ranges [[nm]] [1L], numeric (1)),
    param_names
)
bsup <- setNames (
    vapply (param_names, function (nm) pars$ranges [[nm]] [2L], numeric (1)),
    param_names
)

log_dir <- if (!is.null (pars_s$log_dir)) pars_s$log_dir else "/tmp/escalation"
dir.create (log_dir, recursive = TRUE, showWarnings = FALSE)
old_done <- list.files (log_dir, pattern = "\\.done$", full.names = TRUE)
if (length (old_done) > 0) {
    chk <- file.remove (old_done)
}
cli_alert_info ("Progress files will be written to {log_dir}")

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
    cli_abort (
        "Binary not found at {.file {binary}} — \\
        run 'cargo build --release' first"
    )
}

design <- make_morris_design (param_names, binf, bsup, fixed, results_dir)
run_morris_binary (binary, results_dir, log_dir)
compute_morris_indices (design$m, design$design_full, param_names, results_dir)
