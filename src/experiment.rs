use std::sync::Arc;

use rayon::prelude::*;

use crate::aggregate::{aggregate, compute_tau_psi, RunSummary};
use crate::params::Params;
use crate::sim::run_simulation;

/// Configure Rayon's global thread pool.
///
/// Rayon also respects the `RAYON_NUM_THREADS` environment variable automatically.
pub fn set_num_threads(n: usize) {
    rayon::ThreadPoolBuilder::new()
        .num_threads(n)
        .build_global()
        .ok(); // ignore if already initialised
}

/// Run a paired simulation: two runs sharing seed but differing in μ₀.
///
/// Returns two RunSummary records with psi and tau_psi populated.
pub fn run_paired(
    base: &Params,
    mu0_lo: f64,
    mu0_hi: f64,
    seed: u64,
    zeta: f64,
) -> (RunSummary, RunSummary) {
    let p_lo = base.with_mu0(mu0_lo);
    let p_hi = base.with_mu0(mu0_hi);

    let series_lo = run_simulation(&p_lo, seed);
    let series_hi = run_simulation(&p_hi, seed);

    let tau = compute_tau_psi(&series_lo, &series_hi, zeta);

    let mut lo = aggregate(series_lo, &p_lo, seed);
    let mut hi = aggregate(series_hi, &p_hi, seed);

    let psi = (hi.mean_epsilon_final - lo.mean_epsilon_final) / (mu0_hi - mu0_lo);
    lo.psi = Some(psi);
    hi.psi = Some(psi);
    lo.tau_psi = Some(tau);
    hi.tau_psi = Some(tau);

    (lo, hi)
}

/// Run all paired simulations in parallel over the given seeds.
///
/// If `log_dir` is `Some`, writes a `{pair_idx:06}_{seed:04}.done` file there
/// after each completed (pair, seed) — callers can watch the file count to
/// track progress without polling stdout.
pub fn run_experiment(
    pairs: &[(Params, Params)],
    seeds: &[u64],
    zeta: f64,
    log_dir: Option<&std::path::Path>,
) -> Vec<(RunSummary, RunSummary)> {
    let log_dir: Option<Arc<std::path::PathBuf>> = log_dir.map(|p| Arc::new(p.to_owned()));

    pairs
        .par_iter()
        .enumerate()
        .flat_map(|(pair_idx, (p_lo, p_hi))| {
            let log_dir = log_dir.clone();
            seeds.par_iter().map(move |&seed| {
                let series_lo = run_simulation(p_lo, seed);
                let series_hi = run_simulation(p_hi, seed);
                let tau = compute_tau_psi(&series_lo, &series_hi, zeta);
                let mut lo = aggregate(series_lo, p_lo, seed);
                let mut hi = aggregate(series_hi, p_hi, seed);
                let psi = (hi.mean_epsilon_final - lo.mean_epsilon_final)
                    / (p_hi.mu0 - p_lo.mu0);
                lo.psi = Some(psi);
                hi.psi = Some(psi);
                lo.tau_psi = Some(tau);
                hi.tau_psi = Some(tau);

                if let Some(ref dir) = log_dir {
                    let path = dir.as_ref().join(format!("{pair_idx:06}_{seed:04}.done"));
                    let _ = std::fs::write(
                        &path,
                        format!("psi={psi:.6}\nseed={seed}\npair={pair_idx}\n"),
                    );
                }

                (lo, hi)
            })
        })
        .collect()
}

/// Run sigma-paired simulations for bivariate (ε, σ) sensitivity analysis.
///
/// For each (design, seed) triple, runs three simulations sharing the same seed:
///   (a) mu0=mu0_lo, nominal mu_sigma
///   (b) mu0=mu0_hi, nominal mu_sigma
///   (c) mu0=mu0_lo, mu_sigma + delta_mu_sigma
///
/// Computes psi = (ε̄_b − ε̄_a) / (mu0_hi − mu0_lo) and
/// psi_sigma = (ε̄_c − ε̄_a) / delta_mu_sigma.
/// Both fields are populated on both the lo and hi RunSummary records.
pub fn run_sigma_paired(
    designs: &[Params],
    seeds: &[u64],
    mu0_lo: f64,
    mu0_hi: f64,
    delta_mu_sigma: f64,
    zeta: f64,
    log_dir: Option<&std::path::Path>,
) -> Vec<(RunSummary, RunSummary)> {
    let log_dir: Option<Arc<std::path::PathBuf>> = log_dir.map(|p| Arc::new(p.to_owned()));

    designs
        .par_iter()
        .enumerate()
        .flat_map(|(design_idx, base)| {
            let log_dir = log_dir.clone();
            seeds.par_iter().map(move |&seed| {
                let p_lo = base.with_mu0(mu0_lo);
                let p_hi = base.with_mu0(mu0_hi);
                let p_sigma = base.with_mu0(mu0_lo).with_mu_sigma(base.mu_sigma + delta_mu_sigma);

                let series_lo = run_simulation(&p_lo, seed);
                let series_hi = run_simulation(&p_hi, seed);
                let series_sigma = run_simulation(&p_sigma, seed);

                let tau = compute_tau_psi(&series_lo, &series_hi, zeta);
                let mut lo = aggregate(series_lo, &p_lo, seed);
                let mut hi = aggregate(series_hi, &p_hi, seed);
                let eps_sigma = aggregate(series_sigma, &p_sigma, seed).mean_epsilon_final;

                let psi = (hi.mean_epsilon_final - lo.mean_epsilon_final) / (mu0_hi - mu0_lo);
                let psi_sigma = (eps_sigma - lo.mean_epsilon_final) / delta_mu_sigma;

                lo.psi = Some(psi);
                hi.psi = Some(psi);
                lo.tau_psi = Some(tau);
                hi.tau_psi = Some(tau);
                lo.psi_sigma = Some(psi_sigma);
                hi.psi_sigma = Some(psi_sigma);

                if let Some(ref dir) = log_dir {
                    let path = dir.as_ref().join(format!("{design_idx:06}_{seed:04}.done"));
                    let _ = std::fs::write(
                        &path,
                        format!(
                            "psi={psi:.6}\npsi_sigma={psi_sigma:.6}\nseed={seed}\npair={design_idx}\n"
                        ),
                    );
                }

                (lo, hi)
            })
        })
        .collect()
}

/// Run unpaired diagnostic simulations in parallel (single μ₀, no psi computation).
pub fn run_diagnostic(params: &Params, seeds: &[u64]) -> Vec<RunSummary> {
    seeds
        .par_iter()
        .map(|&seed| aggregate(run_simulation(params, seed), params, seed))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::output::write_summaries;

    fn tiny_params() -> Params {
        let mut p = Params::default();
        p.n = 20;
        p.t_max = 100;
        p.lambda = 2.0;
        p.alpha = 0.5;
        p.theta = 2;
        p
    }

    #[test]
    fn integration_10_pairs_csv_20_rows() {
        let base = tiny_params();
        let mu0_lo = 0.4;
        let mu0_hi = 0.6;
        let pairs: Vec<(Params, Params)> = (0..10)
            .map(|_| (base.with_mu0(mu0_lo), base.with_mu0(mu0_hi)))
            .collect();
        let seeds: Vec<u64> = (0..1).collect();
        let results = run_experiment(&pairs, &seeds, 0.05, None);

        assert_eq!(results.len(), 10, "10 pairs × 1 seed = 10 results");

        // Flatten into RunSummary vec (2 per pair = 20 rows)
        let summaries: Vec<_> = results
            .iter()
            .flat_map(|(lo, hi)| [lo.clone(), hi.clone()])
            .collect();
        assert_eq!(summaries.len(), 20);

        // Write to CSV and verify
        let path = std::path::Path::new("/tmp/escalation_integration_test.csv");
        write_summaries(path, &summaries).expect("CSV write failed");

        let content = std::fs::read_to_string(path).unwrap();
        let rows: Vec<&str> = content.lines().collect();
        // Header + 20 data rows
        assert_eq!(rows.len(), 21, "expected header + 20 rows, got {}", rows.len());

        // All numeric fields should be finite
        for s in &summaries {
            assert!(s.mean_epsilon_final.is_finite(), "mean_epsilon_final non-finite");
            assert!(s.epsilon_auc.is_finite(), "epsilon_auc non-finite");
            assert!(s.epsilon_slope.is_finite(), "epsilon_slope non-finite");
        }
    }

    #[test]
    fn psi_sigma_zero_in_degenerate_case() {
        // With sigma_sigma=0, eta_sigma=0, sigma_decay=0: all agents have fixed
        // sigma_i = mu_sigma throughout. When all sigmas are identical, perturbing
        // mu_sigma scales the observational pathway uniformly for all agents, leaving
        // the equilibrium epsilon distribution invariant (same fixed point, faster/slower
        // convergence). psi_sigma should be negligible over t_max=500 steps.
        let mut base = tiny_params();
        base.n = 30;
        base.t_max = 500;
        base.mu_sigma = 1.0;
        base.sigma_sigma = 0.0;
        base.eta_sigma = 0.0;
        base.sigma_decay = 0.0;

        let designs = vec![base];
        let seeds: Vec<u64> = (0..5).collect();
        let results = run_sigma_paired(&designs, &seeds, 0.4, 0.6, 0.1, 0.05, None);

        for (lo, _hi) in &results {
            let ps = lo.psi_sigma.expect("psi_sigma should be Some in sigma-paired run");
            assert!(
                ps.abs() < 1e-3,
                "psi_sigma={ps:.6} should be ~0 in degenerate σ case \
                 (sigma_sigma=0, eta_sigma=0, sigma_decay=0)"
            );
        }
    }
}
