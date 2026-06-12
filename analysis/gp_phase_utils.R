library (DiceKriging)
library (dplyr, warn.conflicts = FALSE)
library (cli)
library (RcppTOML)

TOP_PARAMS <- c ("alpha", "gamma", "lambda", "eta_obs") # nolint

load_phase_params <- function (toml_path, top_params) {
    pars <- RcppTOML::parseTOML (toml_path)
    all_binf <- setNames (
        vapply (top_params, function (nm) pars$ranges [[nm]] [1L], numeric (1)),
        top_params
    )
    all_bsup <- setNames (
        vapply (top_params, function (nm) pars$ranges [[nm]] [2L], numeric (1)),
        top_params
    )
    mid_vals <- list (
        alpha   = pars$analysis$mid_alpha,
        gamma   = pars$analysis$mid_gamma,
        lambda  = pars$analysis$mid_lambda,
        eta_obs = pars$analysis$mid_eta_obs
    )
    list (all_binf = all_binf, all_bsup = all_bsup, mid_vals = mid_vals)
}

build_phase_grid <- function (p_a, p_b, all_binf, all_bsup, mid_vals,
                               top_params, n_grid = 50) {
    seq_a <- seq (all_binf [p_a], all_bsup [p_a], length.out = n_grid)
    seq_b <- seq (all_binf [p_b], all_bsup [p_b], length.out = n_grid)
    grid  <- expand.grid (A = seq_a, B = seq_b)
    colnames (grid) <- c (p_a, p_b)
    for (nm in top_params) {
        if (!(nm %in% c (p_a, p_b))) grid [[nm]] <- mid_vals [[nm]]
    }
    grid
}

predict_gp_pair <- function (fit, grid) {
    predict (
        fit,
        newdata    = grid [, colnames (fit@X), drop = FALSE],
        type       = "UK",
        checkNames = TRUE
    )
}

write_phase_csvs <- function (grid, p_a, p_b, pred_lo, pred_hi, derived,
                               out_dir, prefix, derived_col = "val") {
    tag <- paste0 (p_a, "_vs_", p_b)

    df_lo     <- grid [, c (p_a, p_b)]
    df_lo$val <- pred_lo$mean

    df_hi     <- grid [, c (p_a, p_b)]
    df_hi$val <- pred_hi$mean

    df_derived              <- grid [, c (p_a, p_b)]
    df_derived [[derived_col]] <- derived

    path_lo      <- file.path (out_dir, paste0 (prefix, "_lo_",           tag, ".csv"))
    path_hi      <- file.path (out_dir, paste0 (prefix, "_hi_",           tag, ".csv"))
    path_derived <- file.path (out_dir, paste0 (prefix, "_", derived_col, "_", tag, ".csv"))

    write.csv (df_lo,      path_lo,      row.names = FALSE)
    write.csv (df_hi,      path_hi,      row.names = FALSE)
    write.csv (df_derived, path_derived, row.names = FALSE)

    invisible (c (path_lo, path_hi, path_derived))
}
