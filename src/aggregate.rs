use crate::params::Params;
use crate::sim::{MetricSeries, T_MAX};

const TAIL_FRAC: f64 = 0.2;

#[derive(serde::Serialize, Clone)]
pub struct RunSummary {
    // Identity
    pub seed: u64,
    // Key params (ratios used in sensitivity analysis)
    pub mu0: f64,
    pub gamma: f64,
    pub lambda: f64,
    pub alpha: f64,
    pub theta: u8,
    pub beta: f64,
    pub delta: f64,
    pub sigma0: f64,
    pub r_win_cost: f64,
    pub r_coop_exploit: f64,
    pub r_loss_win: f64,
    pub r_obs_coop: f64,
    pub r_bridge_sub: f64,
    pub kappa: f64,
    // Terminal state
    pub mean_epsilon_final: f64,
    pub var_epsilon_final: f64,
    pub gini_k_final: f64,
    pub epsilon_k_corr_final: f64,
    pub rich_club_final: f64,
    pub regime_cc: f64,
    pub regime_x: f64,
    pub regime_ck: f64,
    // Trajectory shape
    pub epsilon_auc: f64,
    pub epsilon_slope: f64,
    pub gini_peak: f64,
    pub t_gini_peak: u32,
    // Paired-run metrics (None for unpaired runs)
    pub psi: Option<f64>,
    pub tau_psi: Option<u32>,
}

/// Collapse a MetricSeries into a RunSummary.
///
/// Terminal values are means over the last TAIL_FRAC of recorded points.
pub fn aggregate(series: MetricSeries, params: &Params, seed: u64) -> RunSummary {
    let n = series.t.len();
    let tail_start = ((n as f64 * (1.0 - TAIL_FRAC)) as usize).max(0).min(n.saturating_sub(1));

    let tail_mean = |v: &[f64]| -> f64 {
        let tail = &v[tail_start..];
        if tail.is_empty() { 0.0 } else { tail.iter().sum::<f64>() / tail.len() as f64 }
    };

    let mean_epsilon_final = tail_mean(&series.mean_epsilon);
    let var_epsilon_final = tail_mean(&series.var_epsilon);
    let gini_k_final = tail_mean(&series.gini_k);
    let epsilon_k_corr_final = tail_mean(&series.epsilon_k_corr);
    let rich_club_final = tail_mean(&series.rich_club);

    let regime_final = {
        let tail = &series.regime_dist[tail_start..];
        if tail.is_empty() {
            [0.0_f64; 3]
        } else {
            let mut acc = [0.0_f64; 3];
            for r in tail {
                acc[0] += r[0];
                acc[1] += r[1];
                acc[2] += r[2];
            }
            let n = tail.len() as f64;
            [acc[0] / n, acc[1] / n, acc[2] / n]
        }
    };

    let epsilon_auc = trapezoidal_auc(&series.t, &series.mean_epsilon);
    let epsilon_slope = ols_slope(&series.t, &series.mean_epsilon);

    let (gini_peak, t_gini_peak) = series
        .gini_k
        .iter()
        .zip(series.t.iter())
        .fold((0.0_f64, 0u32), |(peak, tp), (&g, &t)| {
            if g > peak { (g, t) } else { (peak, tp) }
        });

    RunSummary {
        seed,
        mu0: params.mu0,
        gamma: params.gamma,
        lambda: params.lambda,
        alpha: params.alpha,
        theta: params.theta,
        beta: params.beta,
        delta: params.delta,
        sigma0: params.sigma0,
        r_win_cost: params.r_win_cost(),
        r_coop_exploit: params.r_coop_exploit(),
        r_loss_win: params.r_loss_win(),
        r_obs_coop: params.r_obs_coop(),
        r_bridge_sub: params.r_bridge_sub(),
        kappa: params.kappa(),
        mean_epsilon_final,
        var_epsilon_final,
        gini_k_final,
        epsilon_k_corr_final,
        rich_club_final,
        regime_cc: regime_final[0],
        regime_x: regime_final[1],
        regime_ck: regime_final[2],
        epsilon_auc,
        epsilon_slope,
        gini_peak,
        t_gini_peak,
        psi: None,
        tau_psi: None,
    }
}

/// First timestep at which |hi[t] - lo[t]| < zeta; returns T_MAX if never crossed.
pub fn compute_tau_psi(lo: &MetricSeries, hi: &MetricSeries, zeta: f64) -> u32 {
    for (&t, (&lo_e, &hi_e)) in lo
        .t
        .iter()
        .zip(lo.mean_epsilon.iter().zip(hi.mean_epsilon.iter()))
    {
        if (hi_e - lo_e).abs() < zeta {
            return t;
        }
    }
    T_MAX
}

fn trapezoidal_auc(t: &[u32], v: &[f64]) -> f64 {
    if t.len() < 2 {
        return 0.0;
    }
    t.windows(2)
        .zip(v.windows(2))
        .map(|(ts, vs)| (ts[1] - ts[0]) as f64 * (vs[0] + vs[1]) / 2.0)
        .sum()
}

fn ols_slope(t: &[u32], v: &[f64]) -> f64 {
    let n = t.len() as f64;
    if n < 2.0 {
        return 0.0;
    }
    let sum_x: f64 = t.iter().map(|&ti| ti as f64).sum();
    let sum_y: f64 = v.iter().sum();
    let sum_xx: f64 = t.iter().map(|&ti| (ti as f64).powi(2)).sum();
    let sum_xy: f64 = t.iter().zip(v).map(|(&ti, &vi)| ti as f64 * vi).sum();
    let denom = n * sum_xx - sum_x * sum_x;
    if denom == 0.0 { 0.0 } else { (n * sum_xy - sum_x * sum_y) / denom }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::MetricSeries;

    fn make_constant_series(val: f64, n: u32) -> MetricSeries {
        let t: Vec<u32> = (1..=n).collect();
        MetricSeries {
            t: t.clone(),
            mean_epsilon: vec![val; n as usize],
            var_epsilon: vec![0.0; n as usize],
            gini_k: vec![0.0; n as usize],
            epsilon_k_corr: vec![0.0; n as usize],
            mean_edge_weight: vec![1.0; n as usize],
            regime_dist: vec![[1.0, 0.0, 0.0]; n as usize],
            modularity: vec![0.0; n as usize],
            rich_club: vec![0.0; n as usize],
        }
    }

    #[test]
    fn aggregate_constant_series() {
        let val = 0.6_f64;
        let n = 100u32;
        let series = make_constant_series(val, n);
        let params = Params::default();
        let summary = aggregate(series, &params, 0);
        approx::assert_abs_diff_eq!(summary.epsilon_slope, 0.0, epsilon = 1e-10);
        // AUC of constant val over t=1..=n: Σ (t[i+1]-t[i]) * val = (n-1) * val
        let expected_auc = (n - 1) as f64 * val;
        approx::assert_abs_diff_eq!(summary.epsilon_auc, expected_auc, epsilon = 1e-9);
    }

    #[test]
    fn compute_tau_psi_crossing() {
        let n = 100u32;
        let lo = make_constant_series(0.4, n);
        // hi starts at 0.6 and drops to 0.42 at t=50 (gap < 0.05)
        let mut hi = make_constant_series(0.6, n);
        for i in 49..n as usize {
            hi.mean_epsilon[i] = 0.44;
        }
        let tau = compute_tau_psi(&lo, &hi, 0.05);
        assert_eq!(tau, 50, "crossing should be at t=50");
    }
}
