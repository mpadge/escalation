#!/usr/bin/env Rscript
# Sobol variance-based sensitivity analysis for the bivariate (ε, σ) model.
# Reads top parameters from morris_results.csv (psi_sigma estimand), generates
# a Saltelli design, runs the Rust binary, and computes first-order (S1) and
# total-effect (ST) indices for psi_sigma (primary) and psi.
#
# Output: results/sobol_results.csv (long format: param x estimand)
#
# Prerequisites: install.packages(c("sensitivity", "processx", "dplyr", "cli", "RcppTOML"))
# Run from project root: Rscript analysis/sobol.R
# Requires: make screen completed (results/morris_results.csv)

Sys.setenv (`_R_S3_METHOD_REGISTRATION_NOTE_OVERWRITES_` = "false")
library (sensitivity)
library (processx)
library (dplyr, warn.conflicts = FALSE)
library (RcppTOML)
library (cli)

source ("analysis/utils.R")

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

select_sobol_params <- function (results_dir, top_n) {
    morris_file <- file.path (results_dir, "morris_results.csv")
    fallback <- c ("mu_sigma", "lambda", "sigma_sigma", "dw_obs", "dw_bridge", "alpha")
    if (!file.exists (morris_file)) {
        cli_alert_warning (
            "morris_results.csv not found; using known bivariate top-6 params"
        )
        return (fallback)
    }
    df <- read.csv (morris_file)
    df_psi_sigma <- df [df$estimand == "psi_sigma", ]
    df_psi_sigma <- df_psi_sigma [order (-df_psi_sigma$mu_star), ]
    param_names  <- df_psi_sigma$param [seq_len (min (top_n, nrow (df_psi_sigma)))]
    cli_alert_info (
        "Using top {.val {length(param_names)}} parameters from Morris \\
        (psi_sigma ranking): {.field {param_names}}"
    )
    param_names
}

make_saltelli_design <- function (param_names, binf, bsup, fixed, n_sobol,
                                   results_dir) {
    p <- length (param_names)
    cli_alert_info ("Generating Saltelli design (n={.val {n_sobol}}, p={.val {p}})...")
    cli_alert_info ("Total binary calls: {.val {n_sobol * (2L * p + 2L)}}")

    make_uniform <- function (n, pnames, lo, hi) {
        mat <- matrix (runif (n * length (pnames)), n, length (pnames))
        df  <- as.data.frame (mat)
        colnames (df) <- pnames
        for (nm in pnames) df [[nm]] <- lo [nm] + (hi [nm] - lo [nm]) * df [[nm]]
        df
    }

    x1    <- make_uniform (n_sobol, param_names, binf, bsup)
    x2    <- make_uniform (n_sobol, param_names, binf, bsup)
    s_obj <- sobol2007 (model = NULL, X1 = x1, X2 = x2, nboot = 100)

    n_expected <- nrow (s_obj$X)
    cli_alert_info ("Saltelli design has {.val {n_expected}} rows")

    design_full <- s_obj$X
    for (nm in names (fixed)) design_full [[nm]] <- fixed [[nm]]
    for (nm in param_names)   design_full [[nm]] <- s_obj$X [[nm]]
    design_full$theta <-
        pmax (1L, pmin (4L, as.integer (round (design_full$theta))))
    design_full$n     <- as.integer (design_full$n)
    design_full$t_max <- as.integer (design_full$t_max)

    write.csv (
        design_full,
        file.path (results_dir, "design_sobol.csv"),
        row.names = FALSE
    )
    cli_alert_info ("Wrote design_sobol.csv")
    list (s_obj = s_obj, n_expected = n_expected)
}

run_sobol_binary <- function (binary, results_dir, log_dir) {
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
        cli_abort ("Binary failed: {result$stderr}")
    }
}

compute_sobol_indices <- function (s_obj, results_dir, param_names, metric_col) {
    raw      <- read.csv (file.path (results_dir, "sobol_raw.csv"))
    vals     <- raw [[metric_col]] [seq (1L, nrow (raw), by = 2L)]
    if (any (is.na (vals))) {
        cli_alert_warning (
            "{.val {sum(is.na(vals))}} NA {metric_col} values replaced with 0"
        )
        vals [is.na (vals)] <- 0
    }

    s_obj_copy <- s_obj
    s_obj_copy <- tell (s_obj_copy, vals)

    data.frame (
        param    = param_names,
        estimand = metric_col,
        S1       = s_obj_copy$S$original,
        ST       = s_obj_copy$T$original,
        S1_ci    = s_obj_copy$S$`max. c.i.` - s_obj_copy$S$`min. c.i.`,
        ST_ci    = s_obj_copy$T$`max. c.i.` - s_obj_copy$T$`min. c.i.`
    ) |>
        arrange (desc (ST))
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

set.seed (42)

results_dir <- "results"
if (!dir.exists (results_dir)) {
    cli_abort (
        "Output directory {.file {results_dir}} not found — \\
        run {.code make screen} first"
    )
}

pars   <- RcppTOML::parseTOML ("defaults.toml")
pars_s <- pars$structural
pars_a <- pars$analysis

param_names <- select_sobol_params (results_dir, pars$sobol$top_n)
p    <- length (param_names)

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
safe_clear_done_files (log_dir, expected_n = pars$sobol$n_sobol * (2L * p + 2L))
cli_alert_info ("Progress files will be written to {.file {log_dir}}")

# All non-selected params fixed at midpoints; sigma params included
all_mid <- list (
    gamma       = pars_a$mid_gamma,
    lambda      = pars_a$mid_lambda,
    alpha       = pars_a$mid_alpha,
    theta       = as.integer (pars_a$mid_theta),
    beta        = pars_a$mid_beta,
    w_win       = pars_a$mid_w_win,
    b           = pars_a$mid_b,
    w_loss      = pars_a$mid_w_loss,
    dw_obs      = pars_a$mid_dw_obs,
    dw_bridge   = pars_a$mid_dw_bridge,
    mu_sigma    = pars_a$mid_mu_sigma,
    sigma_sigma = pars_a$mid_sigma_sigma,
    eta_sigma   = pars_a$mid_eta_sigma,
    sigma_decay = pars_a$mid_sigma_decay
)

fixed <- c (
    list (
        n             = as.integer (pars$sobol$n_sobol_pop),
        mu0           = pars_a$mu0,
        sigma0        = pars_a$sigma0,
        c             = pars_a$c,
        e             = pars_a$e,
        dw_coop       = pars_a$dw_coop,
        dw_sub        = pars_a$dw_sub,
        dw_excl       = pars_a$dw_excl,
        eta           = pars_a$eta,
        eta_obs       = pars_a$mid_eta_obs,
        delta_direct  = pars_a$delta_direct,
        delta_exploit = pars_a$delta_exploit,
        w_min         = pars_s$w_min,
        w_max         = pars_s$w_max,
        sigma_drift   = pars_s$sigma_drift,
        rho_contested = pars_s$rho_contested,
        eta_trauma    = pars_s$eta_trauma,
        delta         = pars_s$delta,
        t_max         = as.integer (pars_a$t_max_sobol)
    ),
    all_mid [setdiff (names (all_mid), param_names)]
)

binary <- "./target/release/escalation"
if (!file.exists (binary)) {
    cli_abort ("Binary not found — run 'cargo build --release'")
}

cli_inform ("")
design <- make_saltelli_design (
    param_names, binf, bsup, fixed, pars$sobol$n_sobol, results_dir
)
cli_alert_info (
    "Expected {.val {design$n_expected}} progress files — \\
    monitor with {.code make progress}."
)
cli_inform ("")
run_sobol_binary (binary, results_dir, log_dir)
cli_inform ("")

res_psi_sigma <- compute_sobol_indices (
    design$s_obj, results_dir, param_names, "psi_sigma"
)
res_psi <- compute_sobol_indices (
    design$s_obj, results_dir, param_names, "psi"
)

results <- rbind (res_psi_sigma, res_psi)
write.csv (results, file.path (results_dir, "sobol_results.csv"), row.names = FALSE)

cli_alert_info ("Sobol results for psi_sigma (ranked by ST):")
print (res_psi_sigma [, c ("param", "S1", "ST")], digits = 3, row.names = FALSE)
cli_alert_info ("Sobol results for psi (ranked by ST):")
print (res_psi [, c ("param", "S1", "ST")], digits = 3, row.names = FALSE)
cli_alert_success ("Wrote sobol_results.csv")
