#!/usr/bin/env Rscript
# Recoverability check for Stage 6 bivariate model (Stage 6).
#
# Runs the Morris binary with σ fixed at degenerate values (mu_sigma=1.0,
# sigma_sigma=0.0, eta_sigma=0.0, sigma_decay=0.002), which recovers the exact
# original univariate model (verified by T005-8). Compares the resulting Ψ (psi)
# Morris rankings to the Stage 002/003 archived results, confirming that the
# bivariate binary reproduces the original sensitivity structure when σ is inert.
#
# Spearman rank correlation ≥ 0.95 between μ* vectors confirms recoverability.
#
# Prerequisites: install.packages(c("sensitivity", "processx", "dplyr", "cli"))
# Run from project root: Rscript analysis/recover-bivar.R
# Requires a release build: cargo build --release

library (sensitivity)
library (processx)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)

source ("analysis/utils.R")

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

make_morris_design_degen <- function (param_names, binf, bsup, fixed,
                                      results_dir, r = 15) {
    p <- length (param_names)
    cli_alert_info (
        "Generating degenerate-σ Morris design (r={.val {r}} trajectories, \\
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
        file.path (results_dir, "design_morris_bivar_degen.csv"),
        row.names = FALSE
    )
    cli_alert_info (
        "Wrote design_morris_bivar_degen.csv \\
        ({.val {nrow(design_full)}} rows x {.val {ncol(design_full)}} cols)"
    )
    list (m = m, design_full = design_full)
}

run_morris_binary_degen <- function (binary, results_dir, log_dir) {
    cli_alert_info ("Running degenerate-σ Morris binary...")
    result <- processx::run (
        binary,
        c (
            "morris", "--design",
            file.path (results_dir, "design_morris_bivar_degen.csv"),
            "--output", file.path (results_dir, "morris_bivar_raw_degen.csv"),
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

compute_morris_indices_degen <- function (m, design_full, param_names,
                                          results_dir) {
    raw <- read.csv (file.path (results_dir, "morris_bivar_raw_degen.csv"))
    if (nrow (raw) != 2 * nrow (design_full)) {
        cli_alert_warning (
            "Expected {.val {2 * nrow(design_full)}} rows, \\
            got {.val {nrow(raw)}}"
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

    data.frame (
        param   = param_names,
        mu_star = mu_star,
        sigma   = sigma,
        mu      = mu
    )
}

compare_rankings <- function (res_degen, archive_path, results_dir) {
    if (!file.exists (archive_path)) {
        cli_abort (
            "Archived Morris results not found at {.file {archive_path}}. \\
            Expected after `make archive` following Stage 002/003 runs."
        )
    }

    ref <- read.csv (archive_path)

    # Align on shared parameters (both sets use the original 11 param_names)
    shared <- intersect (res_degen$param, ref$param)
    if (length (shared) < length (res_degen$param)) {
        cli_alert_warning (
            "Only {.val {length(shared)}} of \\
            {.val {length(res_degen$param)}} params matched in archive"
        )
    }

    degen_matched <- res_degen [match (shared, res_degen$param), ]
    ref_matched   <- ref       [match (shared, ref$param), ]

    rho <- cor (ref_matched$mu_star, degen_matched$mu_star, method = "spearman")

    comparison <- data.frame (
        parameter         = shared,
        mu_star_000       = ref_matched$mu_star,
        mu_star_006_degen = degen_matched$mu_star,
        rank_000          = rank (-ref_matched$mu_star,   ties.method = "min"),
        rank_006_degen    = rank (-degen_matched$mu_star, ties.method = "min")
    )
    comparison <- comparison [order (comparison$rank_000), ]

    write.csv (
        comparison,
        file.path (results_dir, "recover_bivar_comparison.csv"),
        row.names = FALSE
    )
    cli_alert_info ("Wrote {.file recover_bivar_comparison.csv}")

    cli_inform ("")
    cli_alert_info ("Parameter ranking comparison (Stage 002/003 vs degenerate-σ Stage 006):")
    print (comparison [, c ("parameter", "rank_000", "rank_006_degen",
                             "mu_star_000", "mu_star_006_degen")],
           digits = 3, row.names = FALSE)
    cli_inform ("")

    if (rho >= 0.95) {
        cli_alert_success (
            "Spearman rho = {.val {round(rho, 4)}} — recoverability confirmed (>= 0.95)"
        )
    } else {
        cli_alert_warning (
            "Spearman rho = {.val {round(rho, 4)}} — below 0.95 threshold"
        )
    }

    invisible (list (comparison = comparison, rho = rho))
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)

results_dir  <- "results"
archive_path <- "results/003-centrality-correlation/morris_results.csv"

dir.create (results_dir, showWarnings = FALSE)

# Original 11 param_names — same as morris.R, no σ params varied
param_names <- c (
    "gamma", "lambda", "alpha", "theta", "beta",
    "w_win", "b", "w_loss", "dw_obs", "dw_bridge", "eta_obs"
)

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
safe_clear_done_files (log_dir, expected_n = 15L * (length (param_names) + 1L))
cli_alert_info ("Progress files will be written to {log_dir}")

# Degenerate σ: recovers original univariate model exactly (T005-8)
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
    t_max         = as.integer (pars_a$t_max_morris),
    # Degenerate σ values — all agents have sigma_i = 1.0 throughout
    mu_sigma      = 1.0,
    sigma_sigma   = 0.0,
    eta_sigma     = 0.0,
    sigma_decay   = 0.002
)

binary <- "./target/release/escalation"
if (!file.exists (binary)) {
    cli_abort (
        "Binary not found at {.file {binary}} — \\
        run 'cargo build --release' first"
    )
}

design  <- make_morris_design_degen (param_names, binf, bsup, fixed, results_dir)
run_morris_binary_degen (binary, results_dir, log_dir)
res_degen <- compute_morris_indices_degen (
    design$m, design$design_full, param_names, results_dir
)
compare_rankings (res_degen, archive_path, results_dir)
