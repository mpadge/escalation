# Shared utilities for analysis scripts.

safe_clear_done_files <- function (log_dir, expected_n) {
    old_done <- list.files (log_dir, pattern = "\\.done$", full.names = TRUE)
    n <- length (old_done)
    if (n == 0L) return (invisible (NULL))
    if (n == expected_n) {
        chk <- file.remove (old_done)
        return (invisible (NULL))
    }
    cli_alert_warning (
        "Found {.val {n}} of {.val {expected_n}} expected .done files in \\
        {.file {log_dir}} — a previous run was interrupted."
    )
    if (!interactive ()) {
        cli_abort (
            "Non-interactive session: cannot prompt. \\
            Clean {.file {log_dir}} manually and re-run."
        )
    }
    response <- readline ("Overwrite partial results and re-run from scratch? [y/N] ")
    if (!tolower (trimws (response)) %in% c ("y", "yes")) {
        cli_abort ("Aborted. Clean {.file {log_dir}} manually and re-run.")
    }
    chk <- file.remove (old_done)
    invisible (NULL)
}
