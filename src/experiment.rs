use rayon::prelude::*;

use crate::aggregate::{aggregate, compute_tau_psi, RunSummary};
use crate::params::Params;
use crate::sim::run_simulation;

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
pub fn run_experiment(
    pairs: &[(Params, Params)],
    seeds: &[u64],
    zeta: f64,
) -> Vec<(RunSummary, RunSummary)> {
    pairs
        .par_iter()
        .flat_map(|(p_lo, p_hi)| {
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
