use std::path::PathBuf;

use clap::{Args, Parser, Subcommand};
use escalation::{
    aggregate::RunSummary,
    experiment::{run_experiment, set_num_threads},
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

    let results = run_experiment(&pairs, &seeds, args.zeta);
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
    // Read design matrix; each row is a parameter vector in the CSV schema of Params
    let mut rdr = csv::Reader::from_path(&args.design).unwrap_or_else(|e| {
        eprintln!("Cannot read design file {}: {e}", args.design.display());
        std::process::exit(1);
    });

    let param_pairs: Vec<(Params, Params)> = rdr
        .deserialize::<Params>()
        .map(|r| r.unwrap_or_else(|e| {
            eprintln!("Error reading design row: {e}");
            std::process::exit(1);
        }))
        .map(|p| (p.with_mu0(0.4), p.with_mu0(0.6)))
        .collect();

    let seeds = vec![0u64];
    let results = run_experiment(&param_pairs, &seeds, args.zeta);
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

fn cmd_gp_train(args: GpTrainArgs) {
    if let Some(t) = args.threads {
        set_num_threads(t);
    }
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

    let seeds: Vec<u64> = (0..args.replicates as u64).collect();
    let pairs: Vec<(Params, Params)> = designs
        .iter()
        .map(|p| (p.with_mu0(0.4), p.with_mu0(0.6)))
        .collect();

    let results = run_experiment(&pairs, &seeds, args.zeta);
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
