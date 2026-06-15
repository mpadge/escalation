#!/usr/bin/env Rscript
# Bivariate Morris elementary-effects screening for the (ε, σ) model (Stage 6).
#
# Extends morris.R to 14 free parameters: the original 11 minus eta_obs (moved to
# fixed below to avoid collinearity with mu_sigma — both scale the observational-
# learning pathway) plus the four σ-trait parameters introduced in Stage 5:
# mu_sigma, sigma_sigma, eta_sigma, sigma_decay.
#
# Two output metrics are computed from the same design run:
#   psi_sigma — sensitivity of ε̄(∞) to a μ_σ perturbation (primary estimand)
#   psi       — sensitivity of ε̄(∞) to a μ₀ perturbation (Ψ with σ active)
#
# Prerequisites: install.packages(c("sensitivity", "processx", "dplyr", "cli", "ggplot2"))
# Run from project root: Rscript analysis/morris-bivar.R
# Requires a release build: cargo build --release

library (sensitivity)
library (processx)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)
library (ggplot2)

source ("analysis/utils.R")

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

make_morris_design_bivar <- function (param_names, binf, bsup, fixed,
                                      results_dir, r = 15) {
    p <- length (param_names)
    cli_alert_info (
        "Generating bivariate Morris design (r={.val {r}} trajectories, \\
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
        file.path (results_dir, "design_morris_bivar.csv"),
        row.names = FALSE
    )
    cli_alert_info (
        "Wrote design_morris_bivar.csv ({.val {nrow(design_full)}} rows x \\
        {.val {ncol(design_full)}} cols)"
    )
    list (m = m, design_full = design_full)
}

run_morris_binary_bivar <- function (binary, results_dir, log_dir) {
    cli_alert_info ("Running bivariate Morris binary...")
    result <- processx::run (
        binary,
        c (
            "morris", "--design",
            file.path (results_dir, "design_morris_bivar.csv"),
            "--output", file.path (results_dir, "morris_bivar_raw.csv"),
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

compute_morris_indices_bivar <- function (m, design_full, param_names,
                                          metric_col, out_file, results_dir) {
    raw <- read.csv (file.path (results_dir, "morris_bivar_raw.csv"))
    if (nrow (raw) != 2 * nrow (design_full)) {
        cli_alert_warning (
            "Expected {.val {2 * nrow(design_full)}} rows, \\
            got {.val {nrow(raw)}}"
        )
    }

    # Extract one value per design row (lo row = odd 1-indexed rows)
    vals <- raw [[metric_col]] [seq (1, nrow (raw), by = 2)]
    if (any (is.na (vals))) {
        cli_alert_warning (
            "{.val {sum(is.na(vals))}} NA {metric_col} values replaced with 0"
        )
        vals [is.na (vals)] <- 0
    }

    m <- tell (m, vals)

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
        file.path (results_dir, out_file),
        row.names = FALSE
    )
    cli_alert_info (
        "Morris indices for {.field {metric_col}} (ranked by mu*):"
    )
    print (results, digits = 3)
    cli_alert_info ("Wrote {.file {out_file}}")
    invisible (results)
}

plot_morris_bivar <- function (res_psi_sigma, res_psi, results_dir) {
    plots_dir <- file.path (results_dir, "plots")
    dir.create (plots_dir, showWarnings = FALSE, recursive = TRUE)

    df <- rbind (
        transform (res_psi_sigma, metric = "psi_sigma"),
        transform (res_psi,       metric = "psi")
    )

    p <- ggplot (df, aes (x = mu_star, y = sigma, colour = metric, shape = metric)) +
        geom_point (size = 3) +
        geom_text (
            aes (label = param),
            size = 3, vjust = -0.8, hjust = 0.5, show.legend = FALSE
        ) +
        scale_colour_manual (values = c (psi_sigma = "#d6604d", psi = "#2166ac")) +
        scale_shape_manual  (values = c (psi_sigma = 16, psi = 17)) +
        labs (
            title  = "Morris elementary effects — bivariate (ε, σ) model",
            x      = expression (mu * "*"),
            y      = expression (sigma),
            colour = "Metric",
            shape  = "Metric"
        ) +
        theme_bw (base_size = 12) +
        theme (legend.position = "bottom")

    out <- file.path (plots_dir, "morris_bivar_plot.png")
    ggsave (out, p, width = 9, height = 6, dpi = 300)
    cli_alert_info ("Saved {.file {out}}")
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)

results_dir <- "results"
dir.create (results_dir, showWarnings = FALSE)

# 14 free parameters: original 11 minus eta_obs (moved to fixed to avoid
# collinearity with mu_sigma) plus the four σ-trait parameters from Stage 5.
param_names <- c (
    "gamma",       # network attachment exponent
    "lambda",      # mean group size (Poisson)
    "alpha",       # locality / distance decay
    "theta",       # audience radius (integer 1-4)
    "beta",        # status-advantage multiplier
    "w_win",       # win payoff (with c=0.5 fixed: r_win_cost = w_win/c)
    "b",           # cooperation benefit (with e=0.5: r_coop_exploit = b/e)
    "w_loss",      # loss cost (ratio r_loss_win = w_loss/w_win)
    "dw_obs",      # observer edge increment (with dw_coop=0.15: r_obs_coop)
    "dw_bridge",   # bridge edge increment (with dw_sub=0.15: r_bridge_sub)
    # eta_obs is held fixed (not varied) to avoid collinearity with mu_sigma:
    # both scale the observational-learning pathway (eta_obs as global reference,
    # mu_sigma as per-agent multiplier). Joint variation is deferred to Stage 7.
    "mu_sigma",    # initial mean σ (per-agent status sensitivity)
    "sigma_sigma", # initial SD of σ
    "eta_sigma",   # σ update rate (vicarious reinforcement)
    "sigma_decay"  # per-timestep σ drift toward 0
)

pars   <- RcppTOML::parseTOML ("defaults.toml")
pars_s <- pars$structural
pars_a <- pars$analysis

# Ranges: read from defaults.toml where available; fall back to stage-6 defaults.
get_range <- function (nm, lo_default, hi_default) {
    r <- pars$ranges [[nm]]
    if (!is.null (r)) r else c (lo_default, hi_default)
}

all_ranges <- list (
    gamma       = get_range ("gamma",       1.0,   5.0),
    lambda      = get_range ("lambda",      1.0,   5.0),
    alpha       = get_range ("alpha",       0.1,   2.0),
    theta       = get_range ("theta",       1.0,   4.0),
    beta        = get_range ("beta",        0.0,   1.0),
    w_win       = get_range ("w_win",       0.0,   2.0),
    b           = get_range ("b",           0.0,   2.0),
    w_loss      = get_range ("w_loss",      0.1,   2.0),
    dw_obs      = get_range ("dw_obs",      0.0,   0.2),
    dw_bridge   = get_range ("dw_bridge",   0.0,   0.2),
    mu_sigma    = get_range ("mu_sigma",    0.5,   2.0),
    sigma_sigma = get_range ("sigma_sigma", 0.0,   0.5),
    eta_sigma   = get_range ("eta_sigma",   0.0,   0.2),
    sigma_decay = get_range ("sigma_decay", 0.001, 0.01)
)

binf <- setNames (vapply (param_names, function (nm) all_ranges [[nm]] [1L], numeric (1)),
                  param_names)
bsup <- setNames (vapply (param_names, function (nm) all_ranges [[nm]] [2L], numeric (1)),
                  param_names)

log_dir <- if (!is.null (pars_s$log_dir)) pars_s$log_dir else "/tmp/escalation"
dir.create (log_dir, recursive = TRUE, showWarnings = FALSE)
safe_clear_done_files (log_dir, expected_n = 15L * (length (param_names) + 1L))
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
    cli_abort (
        "Binary not found at {.file {binary}} — \\
        run 'cargo build --release' first"
    )
}

design <- make_morris_design_bivar (param_names, binf, bsup, fixed, results_dir)
run_morris_binary_bivar (binary, results_dir, log_dir)

# Compute Morris indices for both metrics from the same raw output.
# R's copy-on-write semantics mean each call receives an independent copy of m.
res_psi_sigma <- compute_morris_indices_bivar (
    design$m, design$design_full, param_names,
    metric_col = "psi_sigma",
    out_file   = "morris_bivar_results_psi_sigma.csv",
    results_dir
)
res_psi <- compute_morris_indices_bivar (
    design$m, design$design_full, param_names,
    metric_col = "psi",
    out_file   = "morris_bivar_results_psi.csv",
    results_dir
)

plot_morris_bivar (res_psi_sigma, res_psi, results_dir)
