use std::path::PathBuf;

use clap::{Args, Parser, Subcommand};
use rayon::prelude::*;
use escalation::{
    aggregate::{aggregate, compute_tau_psi, RunSummary},
    experiment::{run_experiment, run_sigma_paired, set_num_threads},
    output::{write_series, write_summaries},
    params::Params,
    sim::run_simulation,
};

#[derive(Parser)]
#[command(name = "escalation", about = "Social dynamics simulation")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Run paired sensitivity simulations
    Run(RunArgs),
    /// Single diagnostic run with series output forced on
    Validate(ValidateArgs),
    /// Morris screening: read trajectory CSV, run paired sims, write output
    Morris(SensitivityArgs),
    /// Sobol analysis: read Saltelli CSV, run paired sims, write output
    Sobol(SensitivityArgs),
    /// GP training: read LHS design CSV, run R replicates, write output
    GpTrain(GpTrainArgs),
}

#[derive(Args)]
struct RunArgs {
    /// JSON string with Params overrides (uses defaults for missing fields)
    #[arg(long, default_value = "{}")]
    params: String,
    /// Number of random seeds to use
    #[arg(long, default_value_t = 10)]
    seeds: u64,
    /// Lower μ₀ value for paired runs
    #[arg(long, default_value_t = 0.4)]
    mu0_lo: f64,
    /// Upper μ₀ value for paired runs
    #[arg(long, default_value_t = 0.6)]
    mu0_hi: f64,
    /// Override T_MAX (timesteps per run)
    #[arg(long)]
    t_max: Option<u32>,
    /// Output CSV path
    #[arg(long, default_value = "results.csv")]
    output: PathBuf,
    /// Number of Rayon threads (default: all cores; also respects RAYON_NUM_THREADS)
    #[arg(long)]
    threads: Option<usize>,
    /// Write full MetricSeries to per-run CSV files in --output parent directory
    #[arg(long)]
    dump_series: bool,
    /// Convergence threshold ζ for tau_psi
    #[arg(long, default_value_t = 0.05)]
    zeta: f64,
}

#[derive(Args)]
struct ValidateArgs {
    /// JSON string with Params overrides
    #[arg(long, default_value = "{}")]
    params: String,
    /// Random seed
    #[arg(long, default_value_t = 0)]
    seed: u64,
    /// Override T_MAX
    #[arg(long)]
    t_max: Option<u32>,
    /// Output directory for series CSV files
    #[arg(long, default_value = ".")]
    output_dir: PathBuf,
}

#[derive(Args)]
struct SensitivityArgs {
    /// Design matrix CSV produced by R (one row = one parameter vector)
    #[arg(long)]
    design: PathBuf,
    /// Output CSV path
    #[arg(long, default_value = "output.csv")]
    output: PathBuf,
    /// Number of Rayon threads
    #[arg(long)]
    threads: Option<usize>,
    /// Convergence threshold ζ
    #[arg(long, default_value_t = 0.05)]
    zeta: f64,
    /// Directory for per-pair progress files ({id:06}.done); created if absent
    #[arg(long, default_value = "/tmp/escalation")]
    log_dir: PathBuf,
}

#[derive(Args)]
struct GpTrainArgs {
    /// LHS design matrix CSV
    #[arg(long)]
    design: PathBuf,
    /// Number of replicate seeds per design point
    #[arg(long, default_value_t = 5)]
    replicates: usize,
    /// Output CSV path
    #[arg(long, default_value = "gp_train.csv")]
    output: PathBuf,
    /// Number of Rayon threads
    #[arg(long)]
    threads: Option<usize>,
    /// Convergence threshold ζ
    #[arg(long, default_value_t = 0.05)]
    zeta: f64,
    /// Directory for per-pair progress files ({pair:06}_{seed:04}.done); created if absent
    #[arg(long, default_value = "/tmp/escalation")]
    log_dir: PathBuf,
    /// Resume an interrupted run: skip already-completed design rows and append to output
    #[arg(long, default_value_t = false)]
    resume: bool,
}

fn main() {
    let cli = Cli::parse();
    match cli.command {
        Command::Run(args) => cmd_run(args),
        Command::Validate(args) => cmd_validate(args),
        Command::Morris(args) => cmd_sensitivity(args, "morris"),
        Command::Sobol(args) => cmd_sensitivity(args, "sobol"),
        Command::GpTrain(args) => cmd_gp_train(args),
    }
}

fn parse_params(json: &str, t_max_override: Option<u32>) -> Params {
    let mut p: Params = if json.trim() == "{}" || json.trim().is_empty() {
        Params::default()
    } else {
        serde_json::from_str(json).unwrap_or_else(|e| {
            eprintln!("Error parsing --params JSON: {e}");
            std::process::exit(1);
        })
    };
    if let Some(t) = t_max_override {
        p.t_max = t;
    }
    p
}

fn cmd_run(args: RunArgs) {
    if let Some(t) = args.threads {
        set_num_threads(t);
    }
    let base = parse_params(&args.params, args.t_max);
    let seeds: Vec<u64> = (0..args.seeds).collect();
    let pairs: Vec<(Params, Params)> = seeds
        .iter()
        .map(|_| (base.with_mu0(args.mu0_lo), base.with_mu0(args.mu0_hi)))
        .collect();

    let results = run_experiment(&pairs, &seeds, args.zeta, None);
    let summaries: Vec<RunSummary> = results
        .iter()
        .flat_map(|(lo, hi)| [lo.clone(), hi.clone()])
        .collect();

    write_summaries(&args.output, &summaries).unwrap_or_else(|e| {
        eprintln!("Failed to write {}: {e}", args.output.display());
        std::process::exit(1);
    });

    if args.dump_series {
        let dir = args.output.parent().unwrap_or(std::path::Path::new("."));
        for (seed, (lo_params, hi_params)) in seeds.iter().zip(pairs.iter()) {
            for p in [lo_params, hi_params] {
                let series = run_simulation(p, *seed);
                let summary = escalation::aggregate::aggregate(series.clone(), p, *seed);
                write_series(dir, &summary, &series).unwrap_or_else(|e| {
                    eprintln!("Failed to write series: {e}");
                });
            }
        }
    }

    println!(
        "Wrote {} rows to {}",
        summaries.len(),
        args.output.display()
    );
}

fn cmd_validate(args: ValidateArgs) {
    let params = parse_params(&args.params, args.t_max);
    let series = run_simulation(&params, args.seed);
    let summary = escalation::aggregate::aggregate(series.clone(), &params, args.seed);

    std::fs::create_dir_all(&args.output_dir).unwrap_or_else(|e| {
        eprintln!("Cannot create output directory: {e}");
        std::process::exit(1);
    });

    write_series(&args.output_dir, &summary, &series).unwrap_or_else(|e| {
        eprintln!("Failed to write series: {e}");
        std::process::exit(1);
    });

    println!(
        "validate: mean_epsilon_final={:.4}  gini_peak={:.4}  t_gini_peak={}",
        summary.mean_epsilon_final, summary.gini_peak, summary.t_gini_peak
    );
}

fn cmd_sensitivity(args: SensitivityArgs, _mode: &str) {
    if let Some(t) = args.threads {
        set_num_threads(t);
    }
    std::fs::create_dir_all(&args.log_dir).unwrap_or_else(|e| {
        eprintln!("Cannot create log directory {}: {e}", args.log_dir.display());
        std::process::exit(1);
    });

    // Read design matrix; each row is a parameter vector in the CSV schema of Params.
    // Uses run_sigma_paired so every design point produces both psi (mu0 sensitivity)
    // and psi_sigma (mu_sigma sensitivity) in the output CSV.
    let mut rdr = csv::Reader::from_path(&args.design).unwrap_or_else(|e| {
        eprintln!("Cannot read design file {}: {e}", args.design.display());
        std::process::exit(1);
    });

    let designs: Vec<Params> = rdr
        .deserialize::<Params>()
        .map(|r| r.unwrap_or_else(|e| {
            eprintln!("Error reading design row: {e}");
            std::process::exit(1);
        }))
        .collect();

    let seeds = vec![0u64];
    let results = run_sigma_paired(&designs, &seeds, 0.4, 0.6, 0.1, args.zeta, Some(&args.log_dir));
    let summaries: Vec<RunSummary> = results
        .iter()
        .flat_map(|(lo, hi)| [lo.clone(), hi.clone()])
        .collect();

    write_summaries(&args.output, &summaries).unwrap_or_else(|e| {
        eprintln!("Failed to write output: {e}");
        std::process::exit(1);
    });
    println!("Wrote {} rows to {}", summaries.len(), args.output.display());
}

/// Count how many complete design rows are already in the output CSV.
/// Each completed row produces `2 * replicates` data rows (lo+hi per seed).
fn count_completed_design_rows(path: &std::path::Path, replicates: usize) -> usize {
    let Ok(content) = std::fs::read_to_string(path) else { return 0; };
    let data_rows = content.lines().count().saturating_sub(1); // subtract header
    data_rows / (2 * replicates)
}

fn cmd_gp_train(args: GpTrainArgs) {
    if let Some(t) = args.threads {
        set_num_threads(t);
    }
    std::fs::create_dir_all(&args.log_dir).unwrap_or_else(|e| {
        eprintln!("Cannot create log directory {}: {e}", args.log_dir.display());
        std::process::exit(1);
    });

    let mut rdr = csv::Reader::from_path(&args.design).unwrap_or_else(|e| {
        eprintln!("Cannot read design file: {e}");
        std::process::exit(1);
    });

    let designs: Vec<Params> = rdr
        .deserialize::<Params>()
        .map(|r| r.unwrap_or_else(|e| {
            eprintln!("Error reading design row: {e}");
            std::process::exit(1);
        }))
        .collect();

    // Determine resume offset
    let completed = if args.resume && args.output.exists() {
        count_completed_design_rows(&args.output, args.replicates)
    } else {
        0
    };
    if completed > 0 {
        println!("Resuming: {completed}/{} design rows already done", designs.len());
    }

    // Open output — append (no header) if resuming, create/truncate otherwise
    let file = std::fs::OpenOptions::new()
        .create(true)
        .write(!args.resume || completed == 0)
        .truncate(!args.resume || completed == 0)
        .append(args.resume && completed > 0)
        .open(&args.output)
        .unwrap_or_else(|e| {
            eprintln!("Cannot open output {}: {e}", args.output.display());
            std::process::exit(1);
        });
    let mut wtr = csv::WriterBuilder::new()
        .has_headers(completed == 0)
        .from_writer(file);

    let seeds: Vec<u64> = (0..args.replicates as u64).collect();
    let total = designs.len();
    let mut rows_written = 0usize;

    for (pair_idx, design_row) in designs.iter().enumerate().skip(completed) {
        let p_lo = design_row.with_mu0(0.4);
        let p_hi = design_row.with_mu0(0.6);
        let p_sigma = design_row.with_mu0(0.4).with_mu_sigma(design_row.mu_sigma + 0.1);
        let log_dir = &args.log_dir;
        let zeta = args.zeta;

        // Run all seeds for this design point in parallel
        let results: Vec<(RunSummary, RunSummary)> = seeds
            .par_iter()
            .map(|&seed| {
                let series_lo = run_simulation(&p_lo, seed);
                let series_hi = run_simulation(&p_hi, seed);
                let series_sigma = run_simulation(&p_sigma, seed);
                let tau = compute_tau_psi(&series_lo, &series_hi, zeta);
                let mut lo = aggregate(series_lo, &p_lo, seed);
                let mut hi = aggregate(series_hi, &p_hi, seed);
                let eps_sigma = aggregate(series_sigma, &p_sigma, seed).mean_epsilon_final;
                let psi = (hi.mean_epsilon_final - lo.mean_epsilon_final)
                    / (p_hi.mu0 - p_lo.mu0);
                let psi_sigma = (eps_sigma - lo.mean_epsilon_final) / 0.1;
                lo.psi = Some(psi);
                hi.psi = Some(psi);
                lo.tau_psi = Some(tau);
                hi.tau_psi = Some(tau);
                lo.psi_sigma = Some(psi_sigma);
                hi.psi_sigma = Some(psi_sigma);
                let path = log_dir.join(format!("{pair_idx:06}_{seed:04}.done"));
                let _ = std::fs::write(
                    &path,
                    format!(
                        "psi={psi:.6}\npsi_sigma={psi_sigma:.6}\nseed={seed}\npair={pair_idx}\n"
                    ),
                );
                (lo, hi)
            })
            .collect();

        for (lo, hi) in &results {
            wtr.serialize(lo).unwrap_or_else(|e| eprintln!("Serialize error: {e}"));
            wtr.serialize(hi).unwrap_or_else(|e| eprintln!("Serialize error: {e}"));
            rows_written += 2;
        }
        wtr.flush().unwrap_or_else(|e| eprintln!("Flush error: {e}"));

        if (pair_idx + 1) % 100 == 0 || pair_idx + 1 == total {
            println!("  {}/{} design rows complete", pair_idx + 1, total);
        }
    }

    println!("Wrote {rows_written} rows to {}", args.output.display());
}
