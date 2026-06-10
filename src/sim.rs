use rand::Rng;
use rand_distr::{Bernoulli, Distribution, Normal, Poisson, Uniform};

use crate::ego_net::{build_alias_tables, compute_weighted_dist, r_max, AliasTable, Network};
use crate::network::{ba_graph, hop_distances, init_weights};
use crate::params::Params;

pub const T_MAX: u32 = 10_000;
const RECORD_INTERVAL: u32 = 100;
const SLOW_INTERVAL: u32 = 1_000;

pub struct SimState {
    pub w: Vec<f64>,
    pub epsilon: Vec<f64>,
    pub payoff: Vec<f64>,
    pub weighted_dist: Vec<f64>,
    pub alias_tables: Vec<AliasTable>,
}

pub struct MetricSeries {
    pub t: Vec<u32>,
    pub mean_epsilon: Vec<f64>,
    pub var_epsilon: Vec<f64>,
    pub gini_k: Vec<f64>,
    pub epsilon_k_corr: Vec<f64>,
    pub mean_edge_weight: Vec<f64>,
    pub regime_dist: Vec<[f64; 3]>,
    pub modularity: Vec<f64>,
    pub rich_club: Vec<f64>,
}

impl MetricSeries {
    fn new() -> Self {
        MetricSeries {
            t: Vec::new(),
            mean_epsilon: Vec::new(),
            var_epsilon: Vec::new(),
            gini_k: Vec::new(),
            epsilon_k_corr: Vec::new(),
            mean_edge_weight: Vec::new(),
            regime_dist: Vec::new(),
            modularity: Vec::new(),
            rich_club: Vec::new(),
        }
    }
}

/// Pure entry point: (params, seed) → MetricSeries.
pub fn run_simulation(params: &Params, seed: u64) -> MetricSeries {
    use rand::SeedableRng;
    let mut rng = rand::rngs::StdRng::seed_from_u64(seed);
    let n = params.n;

    // Build network
    let adj = ba_graph(n, params.gamma, &mut rng);
    let hop = hop_distances(&adj);
    let w = init_weights(&adj, params.w_min, params.w_max, &mut rng);
    let w_nonzero_count = w.iter().filter(|&&v| v > 0.0).count();
    let w_avg = if w_nonzero_count == 0 {
        params.w_min
    } else {
        w.iter().filter(|&&v| v > 0.0).sum::<f64>() / w_nonzero_count as f64
    };
    let r = r_max(params.alpha, params.theta, w_avg);
    let net = Network::build(&adj, hop, r, params.theta);

    // Initial ε ~ clip(Normal(μ₀, σ₀), 0, 1)
    let normal = Normal::new(params.mu0, params.sigma0).unwrap();
    let epsilon: Vec<f64> = (0..n)
        .map(|_| normal.sample(&mut rng).clamp(0.0, 1.0))
        .collect();

    let weighted_dist = compute_weighted_dist(&net, &w, params.w_min);
    let alias_tables = build_alias_tables(&net, &weighted_dist, params.alpha);

    let mut state = SimState {
        w,
        epsilon,
        payoff: vec![0.0; n],
        weighted_dist,
        alias_tables,
    };

    let mut series = MetricSeries::new();
    let mut cc_count = 0u32;
    let mut x_count = 0u32;
    let mut ck_count = 0u32;
    let mut last_slow_recorded = false;

    let uniform_n = Uniform::new(0, n);

    for t in 0..T_MAX {
        let focal = uniform_n.sample(&mut rng);

        let poisson = Poisson::new(params.lambda).unwrap();
        let m = loop {
            let m = (poisson.sample(&mut rng) as usize) + 1;
            if m > 1 {
                break m;
            }
        };

        let mut group: Vec<u32> = vec![focal as u32];
        let [s, e] = net.shell_offsets[focal];
        let ego_size = e - s;
        if ego_size > 0 {
            let take = (m - 1).min(ego_size);
            let mut tries = 0usize;
            while group.len() < 1 + take && tries < ego_size * 4 {
                let idx = state.alias_tables[focal].sample(&mut rng);
                let partner = net.neighbour_data[s + idx];
                if !group.contains(&partner) {
                    group.push(partner);
                }
                tries += 1;
            }
        }

        let strats: Vec<bool> = group
            .iter()
            .map(|&i| Bernoulli::new(state.epsilon[i as usize]).unwrap().sample(&mut rng))
            .collect();

        let n_e = strats.iter().filter(|&&s| s).count();
        let n_c = group.len() - n_e;
        let phi = n_e as f64 / group.len() as f64;

        let omega: Vec<f64> = group
            .iter()
            .map(|&i| {
                let [as_, ae] = net.audience_offsets[i as usize];
                1.0 + ((ae - as_ + group.len() - 1) as f64).ln_1p() / (n as f64).ln()
            })
            .collect();

        let payoffs_before: Vec<f64> = group.iter().map(|&i| state.payoff[i as usize]).collect();

        if phi > 0.75 {
            cc_count += 1;
            handle_consensus_conflict(&mut state, &net, &group, &strats, n_e, &omega, params, &mut rng);
        } else if phi < 0.25 {
            ck_count += 1;
            handle_consensus_cooperation(&mut state, &group, &strats, n_c, params);
        } else {
            x_count += 1;
            handle_contested(&mut state, &net, &group, &strats, n_e, params, &mut rng);
        }

        update_propensities(&mut state, &group, &strats, &payoffs_before, params, &mut rng);

        if phi > 0.75 && n_e > 0 {
            let winner = group
                .iter()
                .zip(strats.iter())
                .filter(|(_, s)| **s)
                .max_by(|(a, _), (b, _)| {
                    let da = state.payoff[**a as usize]
                        - payoffs_before[group.iter().position(|x| x == *a).unwrap()];
                    let db = state.payoff[**b as usize]
                        - payoffs_before[group.iter().position(|x| x == *b).unwrap()];
                    da.partial_cmp(&db).unwrap()
                })
                .map(|(&i, _)| i);
            if let Some(w_node) = winner {
                update_observer_propensities(&mut state, &net, &group, w_node, params);
            }
        }

        if (t + 1) % RECORD_INTERVAL == 0 {
            let total_enc = cc_count + x_count + ck_count;
            let regime = if total_enc > 0 {
                [
                    cc_count as f64 / total_enc as f64,
                    x_count as f64 / total_enc as f64,
                    ck_count as f64 / total_enc as f64,
                ]
            } else {
                [0.0, 0.0, 0.0]
            };

            let k = compute_in_degree_weighted(&state.w, n);
            let (mean_e, var_e) = mean_var(&state.epsilon);
            let g_k = gini(&k);
            let corr = pearson_corr(&state.epsilon, &k);
            let mew = mean_edge_weight(&state.w);

            let is_slow = (t + 1) % SLOW_INTERVAL == 0;
            let (mod_q, rc) = if is_slow || !last_slow_recorded {
                last_slow_recorded = true;
                (modularity(&state.w, &state.epsilon, n), rich_club_coeff(&state.w, &k, n))
            } else {
                (
                    series.modularity.last().copied().unwrap_or(0.0),
                    series.rich_club.last().copied().unwrap_or(0.0),
                )
            };

            series.t.push(t + 1);
            series.mean_epsilon.push(mean_e);
            series.var_epsilon.push(var_e);
            series.gini_k.push(g_k);
            series.epsilon_k_corr.push(corr);
            series.mean_edge_weight.push(mew);
            series.regime_dist.push(regime);
            series.modularity.push(mod_q);
            series.rich_club.push(rc);
        }
    }

    series
}

// ─── Regime handlers ──────────────────────────────────────────────────────────

fn handle_consensus_conflict(
    state: &mut SimState,
    net: &Network,
    group: &[u32],
    strats: &[bool],
    n_e: usize,
    _omega: &[f64],
    params: &Params,
    rng: &mut impl Rng,
) {
    let mut escalators: Vec<u32> = group
        .iter()
        .copied()
        .zip(strats.iter().copied())
        .filter(|(_, s)| *s)
        .map(|(i, _)| i)
        .collect();

    let conciliators: Vec<u32> = group
        .iter()
        .copied()
        .zip(strats.iter().copied())
        .filter(|(_, s)| !*s)
        .map(|(i, _)| i)
        .collect();

    for &q in &conciliators {
        state.payoff[q as usize] -= n_e as f64 * params.e;
    }

    if escalators.len() > 1 {
        let k = compute_in_degree_weighted(&state.w, net.n);
        run_tournament(&mut escalators, &mut state.payoff, &k, params, rng);
    }
}

fn handle_contested(
    state: &mut SimState,
    net: &Network,
    group: &[u32],
    strats: &[bool],
    n_e: usize,
    params: &Params,
    rng: &mut impl Rng,
) {
    let mut escalators: Vec<u32> = group
        .iter()
        .copied()
        .zip(strats.iter().copied())
        .filter(|(_, s)| *s)
        .map(|(i, _)| i)
        .collect();

    let conciliators: Vec<u32> = group
        .iter()
        .copied()
        .zip(strats.iter().copied())
        .filter(|(_, s)| !*s)
        .map(|(i, _)| i)
        .collect();

    escalators.sort_by(|&a, &b| {
        state.epsilon[b as usize]
            .partial_cmp(&state.epsilon[a as usize])
            .unwrap()
    });

    let mut free_conciliators: Vec<u32> = conciliators.clone();
    let mut residual_escalators: Vec<u32> = Vec::new();

    for &p in &escalators {
        if free_conciliators.is_empty() {
            residual_escalators.push(p);
            continue;
        }
        let pos = free_conciliators
            .iter()
            .copied()
            .enumerate()
            .min_by(|(_, a), (_, b)| {
                let da = wd_lookup(&state.weighted_dist, net, p as usize, *a as usize);
                let db = wd_lookup(&state.weighted_dist, net, p as usize, *b as usize);
                da.partial_cmp(&db).unwrap()
            })
            .map(|(pos, _)| pos)
            .unwrap();

        let q = free_conciliators.remove(pos);
        state.payoff[p as usize] += params.e;
        state.payoff[q as usize] -= params.e;
    }

    if residual_escalators.len() > 1 {
        let k = compute_in_degree_weighted(&state.w, net.n);
        run_tournament(&mut residual_escalators, &mut state.payoff, &k, params, rng);
    }

    let n_c_free = free_conciliators.len() as f64;
    for &q in &free_conciliators {
        state.payoff[q as usize] += params.b * (n_c_free / group.len() as f64);
    }

    if n_e == 1 {
        let p = escalators[0];
        for &q in &conciliators {
            state.payoff[p as usize] -= params.dw_excl;
            state.payoff[q as usize] -= params.dw_excl;
        }
    }
}

fn handle_consensus_cooperation(
    state: &mut SimState,
    group: &[u32],
    strats: &[bool],
    n_c: usize,
    params: &Params,
) {
    let cooperators: Vec<u32> = group
        .iter()
        .copied()
        .zip(strats.iter().copied())
        .filter(|(_, s)| !*s)
        .map(|(i, _)| i)
        .collect();

    let escalators_in_g: Vec<u32> = group
        .iter()
        .copied()
        .zip(strats.iter().copied())
        .filter(|(_, s)| *s)
        .map(|(i, _)| i)
        .collect();

    for &i in &cooperators {
        state.payoff[i as usize] += params.b * (1.0 + n_c as f64).ln();
    }

    for &p in &escalators_in_g {
        for &q in &cooperators {
            state.payoff[p as usize] -= params.dw_excl;
            state.payoff[q as usize] -= params.dw_excl;
        }
    }
}

// ─── Tournament ───────────────────────────────────────────────────────────────

fn run_tournament(
    agents: &mut Vec<u32>,
    payoff: &mut [f64],
    k: &[f64],
    params: &Params,
    rng: &mut impl Rng,
) -> u32 {
    agents.sort_by(|&a, &b| {
        k[b as usize]
            .partial_cmp(&k[a as usize])
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    while agents.len() > 1 {
        let mut next: Vec<u32> = Vec::new();
        let mut i = 0;
        while i + 1 < agents.len() {
            let p = agents[i];
            let q = agents[i + 1];
            let prob_p = logistic(params.beta * (k[p as usize] - k[q as usize]));
            let (winner, loser) = if rng.gen_range(0.0..1.0) < prob_p {
                (p, q)
            } else {
                (q, p)
            };
            payoff[winner as usize] += params.w_win - params.c;
            payoff[loser as usize] -= params.w_loss + params.c;
            next.push(winner);
            i += 2;
        }
        if agents.len() % 2 == 1 {
            next.push(*agents.last().unwrap());
        }
        *agents = next;
        agents.sort_by(|&a, &b| {
            k[b as usize]
                .partial_cmp(&k[a as usize])
                .unwrap_or(std::cmp::Ordering::Equal)
        });
    }

    agents[0]
}

// ─── Propensity updates ───────────────────────────────────────────────────────

fn update_propensities(
    state: &mut SimState,
    group: &[u32],
    strats: &[bool],
    payoffs_before: &[f64],
    params: &Params,
    rng: &mut impl Rng,
) {
    let r: Vec<f64> = group
        .iter()
        .zip(strats.iter())
        .enumerate()
        .map(|(idx, (i, s))| {
            let delta = state.payoff[*i as usize] - payoffs_before[idx];
            let sign = delta.signum();
            if *s { sign } else { -sign }
        })
        .collect();

    let o: Vec<f64> = strats
        .iter()
        .enumerate()
        .map(|(idx, s_i)| {
            let same: Vec<f64> = (0..strats.len())
                .filter(|&j| j != idx && strats[j] == *s_i)
                .map(|j| r[j])
                .collect();
            if same.is_empty() {
                0.0
            } else {
                same.iter().sum::<f64>() / same.len() as f64
            }
        })
        .collect();

    let normal = Normal::new(0.0, params.sigma_drift).unwrap();
    for (idx, &i) in group.iter().enumerate() {
        let xi: f64 = normal.sample(rng);
        let delta = params.eta * r[idx] + params.eta_obs * o[idx] + xi;
        state.epsilon[i as usize] = (state.epsilon[i as usize] + delta).clamp(0.0, 1.0);
    }
}

fn update_observer_propensities(
    state: &mut SimState,
    net: &Network,
    group: &[u32],
    winner: u32,
    params: &Params,
) {
    let group_set: std::collections::HashSet<u32> = group.iter().copied().collect();
    let [as_, ae] = net.audience_offsets[winner as usize];
    let observers: Vec<u32> = net.audience_data[as_..ae]
        .iter()
        .copied()
        .filter(|k| !group_set.contains(k))
        .collect();

    let mut updates: Vec<(usize, f64)> = Vec::new();
    for k in observers {
        let wd = wd_lookup(&state.weighted_dist, net, k as usize, winner as usize);
        let weight = (-params.alpha * wd).exp();
        let o_k = if state.epsilon[k as usize] > 0.5 { 1.0 } else { -1.0 };
        updates.push((k as usize, params.eta_obs * o_k * weight));
    }
    for (i, delta) in updates {
        state.epsilon[i] = (state.epsilon[i] + delta).clamp(0.0, 1.0);
    }
}

// ─── Metrics ──────────────────────────────────────────────────────────────────

fn compute_in_degree_weighted(w: &[f64], n: usize) -> Vec<f64> {
    let mut k = vec![0.0_f64; n];
    for i in 0..n {
        for j in 0..n {
            k[j] += w[i * n + j];
        }
    }
    k
}

fn mean_var(v: &[f64]) -> (f64, f64) {
    let n = v.len() as f64;
    let mean = v.iter().sum::<f64>() / n;
    let var = v.iter().map(|&x| (x - mean).powi(2)).sum::<f64>() / n;
    (mean, var)
}

fn gini(v: &[f64]) -> f64 {
    if v.is_empty() {
        return 0.0;
    }
    let mut sorted = v.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let n = sorted.len() as f64;
    let mean = sorted.iter().sum::<f64>() / n;
    if mean == 0.0 {
        return 0.0;
    }
    let numer: f64 = sorted
        .iter()
        .enumerate()
        .map(|(i, &x)| (2.0 * (i as f64 + 1.0) - n - 1.0) * x)
        .sum();
    numer / (n * n * mean)
}

fn pearson_corr(x: &[f64], y: &[f64]) -> f64 {
    let n = x.len() as f64;
    let mx = x.iter().sum::<f64>() / n;
    let my = y.iter().sum::<f64>() / n;
    let num: f64 = x.iter().zip(y).map(|(&xi, &yi)| (xi - mx) * (yi - my)).sum();
    let sx: f64 = x.iter().map(|&xi| (xi - mx).powi(2)).sum::<f64>().sqrt();
    let sy: f64 = y.iter().map(|&yi| (yi - my).powi(2)).sum::<f64>().sqrt();
    if sx == 0.0 || sy == 0.0 { 0.0 } else { num / (sx * sy) }
}

fn mean_edge_weight(w: &[f64]) -> f64 {
    let nonzero: Vec<f64> = w.iter().copied().filter(|&v| v > 0.0).collect();
    if nonzero.is_empty() {
        0.0
    } else {
        nonzero.iter().sum::<f64>() / nonzero.len() as f64
    }
}

fn modularity(w: &[f64], epsilon: &[f64], n: usize) -> f64 {
    let s: f64 = w.iter().sum();
    if s == 0.0 {
        return 0.0;
    }
    let s_out: Vec<f64> = (0..n).map(|i| w[i * n..(i + 1) * n].iter().sum()).collect();
    let s_in: Vec<f64> = (0..n).map(|j| (0..n).map(|i| w[i * n + j]).sum()).collect();
    let mut q = 0.0_f64;
    for i in 0..n {
        for j in 0..n {
            if (epsilon[i] > 0.5) == (epsilon[j] > 0.5) {
                q += w[i * n + j] - s_out[i] * s_in[j] / s;
            }
        }
    }
    q / s
}

fn rich_club_coeff(w: &[f64], k: &[f64], n: usize) -> f64 {
    let thresh_idx = (n as f64 * 0.8) as usize;
    let mut sorted_k = k.to_vec();
    sorted_k.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let k_thresh = sorted_k[thresh_idx.min(n - 1)];
    let rich: Vec<usize> = (0..n).filter(|&i| k[i] >= k_thresh).collect();
    let n_r = rich.len();
    if n_r < 2 {
        return 0.0;
    }
    let e_r: f64 = rich
        .iter()
        .flat_map(|&i| rich.iter().map(move |&j| w[i * n + j]))
        .sum();
    e_r / (n_r * (n_r - 1)) as f64
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

fn logistic(x: f64) -> f64 {
    1.0 / (1.0 + (-x).exp())
}

fn wd_lookup(weighted_dist: &[f64], net: &Network, i: usize, j: usize) -> f64 {
    let [s, e] = net.shell_offsets[i];
    net.neighbour_data[s..e]
        .iter()
        .copied()
        .enumerate()
        .find(|(_, nbr)| *nbr as usize == j)
        .map(|(idx, _)| weighted_dist[s + idx])
        .unwrap_or(f64::INFINITY)
}

// ─── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn tiny_params(mu0: f64, sigma0: f64) -> Params {
        let mut p = Params::default();
        p.n = 30;
        p.mu0 = mu0;
        p.sigma0 = sigma0;
        p.lambda = 2.0;
        p.alpha = 0.5;
        p.theta = 2;
        p
    }

    #[test]
    fn all_escalators_is_cc_and_updates_payoffs() {
        use rand::SeedableRng;
        let mut rng = rand::rngs::StdRng::seed_from_u64(7);
        let params = tiny_params(1.0, 0.0);
        let n = params.n;
        let adj = ba_graph(n, params.gamma, &mut rng);
        let hop = hop_distances(&adj);
        let w = init_weights(&adj, params.w_min, params.w_max, &mut rng);
        let w_avg = w.iter().filter(|&&v| v > 0.0).sum::<f64>()
            / w.iter().filter(|&&v| v > 0.0).count() as f64;
        let r = r_max(params.alpha, params.theta, w_avg);
        let net = Network::build(&adj, hop, r, params.theta);
        let wd = compute_weighted_dist(&net, &w, params.w_min);
        let at = build_alias_tables(&net, &wd, params.alpha);

        let mut state = SimState {
            w: w.clone(),
            epsilon: vec![1.0_f64; n],
            payoff: vec![0.0; n],
            weighted_dist: wd,
            alias_tables: at,
        };

        let group: Vec<u32> = vec![0, 1, 2];
        let strats: Vec<bool> = vec![true, true, true];
        let phi = 1.0_f64;
        assert!(phi > 0.75);

        let payoffs_before: Vec<f64> = group.iter().map(|&i| state.payoff[i as usize]).collect();
        let omega = vec![1.0_f64; 3];
        handle_consensus_conflict(&mut state, &net, &group, &strats, 3, &omega, &params, &mut rng);

        let changed = group
            .iter()
            .enumerate()
            .any(|(idx, &i)| state.payoff[i as usize] != payoffs_before[idx]);
        assert!(changed, "tournament should update payoffs");
    }

    #[test]
    fn all_conciliators_is_ck_and_correct_payoff() {
        let params = {
            let mut p = tiny_params(0.0, 0.0);
            p.b = 1.5;
            p
        };
        let n = params.n;
        let mut state = SimState {
            w: vec![0.0; n * n],
            epsilon: vec![0.0; n],
            payoff: vec![0.0; n],
            weighted_dist: vec![],
            alias_tables: vec![],
        };

        let group: Vec<u32> = vec![0, 1, 2];
        let strats: Vec<bool> = vec![false, false, false];
        let n_c = 3;
        let n_e = 0;
        let phi = n_e as f64 / 3.0;
        assert!(phi < 0.25);

        handle_consensus_cooperation(&mut state, &group, &strats, n_c, &params);

        let expected = params.b * (1.0 + n_c as f64).ln();
        for &i in &group {
            approx::assert_abs_diff_eq!(state.payoff[i as usize], expected, epsilon = 1e-10);
        }
    }

    #[test]
    fn mean_epsilon_stays_high_under_all_cc() {
        let mut params = tiny_params(0.8, 0.05);
        params.eta = 0.15;
        params.sigma_drift = 0.0;
        let series = run_simulation(&params, 42);
        let last = *series.mean_epsilon.last().unwrap();
        assert!(
            last > 0.5,
            "expected high mean_epsilon under CC conditions, got {last:.3}"
        );
    }
}
