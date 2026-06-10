use std::collections::HashMap;
use rand::Rng;

/// Compute r_max: interaction selection radius.
///
/// r_max = ceil(-ln(0.01) / (alpha * w_avg)).max(theta).max(2), capped at 10.
pub fn r_max(alpha: f64, theta: u8, w_avg: f64) -> u8 {
    if alpha <= 0.0 || w_avg <= 0.0 {
        return theta.max(2).min(10);
    }
    let r_select = (-0.01_f64.ln() / (alpha * w_avg)).ceil() as u8;
    r_select.max(theta).max(2).min(10)
}

/// Pre-computed fixed-topology neighbourhood structures.
pub struct Network {
    pub n: usize,
    pub hop_dist: Vec<u8>,
    /// Flat ragged array of ego-net neighbour indices
    pub neighbour_data: Vec<u32>,
    /// Hop depth for each entry in neighbour_data
    pub hop_data: Vec<u8>,
    /// [agent i] = [start, end] in neighbour_data
    pub shell_offsets: Vec<[usize; 2]>,
    /// Flat ragged array of audience (hop <= theta) indices
    pub audience_data: Vec<u32>,
    pub audience_offsets: Vec<[usize; 2]>,
    /// path_edges[agent][neighbour_idx] = sequence of (u,v) directed edges along shortest path
    pub path_edges: Vec<Vec<Vec<(u32, u32)>>>,
    /// Inverted index: (u,v) → [(agent_i, neighbour_idx)]
    pub edge_to_paths: HashMap<(u32, u32), Vec<(u32, usize)>>,
}

impl Network {
    pub fn build(adj: &[Vec<u32>], hop_dist: Vec<u8>, r: u8, theta: u8) -> Self {
        let n = adj.len();
        let predecessors = build_predecessors(adj, n);

        let mut neighbour_data: Vec<u32> = Vec::new();
        let mut hop_data: Vec<u8> = Vec::new();
        let mut shell_offsets = vec![[0usize; 2]; n];
        let mut audience_data: Vec<u32> = Vec::new();
        let mut audience_offsets = vec![[0usize; 2]; n];
        let mut path_edges: Vec<Vec<Vec<(u32, u32)>>> = Vec::with_capacity(n);

        for i in 0..n {
            let mut ego: Vec<(u8, u32)> = (0..n)
                .filter(|&j| j != i)
                .filter_map(|j| {
                    let d = hop_dist[i * n + j];
                    if d != u8::MAX && d <= r {
                        Some((d, j as u32))
                    } else {
                        None
                    }
                })
                .collect();
            ego.sort_unstable();

            let nd_start = neighbour_data.len();
            let aud_start = audience_data.len();

            let mut agent_paths: Vec<Vec<(u32, u32)>> = Vec::with_capacity(ego.len());
            for &(d, j) in &ego {
                neighbour_data.push(j);
                hop_data.push(d);
                if d <= theta {
                    audience_data.push(j);
                }
                let path = reconstruct_path(&predecessors, i, j as usize);
                agent_paths.push(path);
            }

            shell_offsets[i] = [nd_start, neighbour_data.len()];
            audience_offsets[i] = [aud_start, audience_data.len()];
            path_edges.push(agent_paths);
        }

        let mut edge_to_paths: HashMap<(u32, u32), Vec<(u32, usize)>> = HashMap::new();
        for i in 0..n {
            for (nbr_idx, edges) in path_edges[i].iter().enumerate() {
                for &(u, v) in edges {
                    edge_to_paths
                        .entry((u, v))
                        .or_default()
                        .push((i as u32, nbr_idx));
                }
            }
        }

        Network {
            n,
            hop_dist,
            neighbour_data,
            hop_data,
            shell_offsets,
            audience_data,
            audience_offsets,
            path_edges,
            edge_to_paths,
        }
    }

    pub fn ego_net_slice(&self, i: usize) -> std::ops::Range<usize> {
        let [s, e] = self.shell_offsets[i];
        s..e
    }
}

fn build_predecessors(adj: &[Vec<u32>], n: usize) -> Vec<Vec<Option<usize>>> {
    let mut preds = vec![vec![None::<usize>; n]; n];
    for src in 0..n {
        let mut visited = vec![false; n];
        visited[src] = true;
        let mut queue = std::collections::VecDeque::new();
        queue.push_back(src);
        while let Some(u) = queue.pop_front() {
            for &v in &adj[u] {
                let v = v as usize;
                if !visited[v] {
                    visited[v] = true;
                    preds[src][v] = Some(u);
                    queue.push_back(v);
                }
            }
        }
    }
    preds
}

fn reconstruct_path(preds: &[Vec<Option<usize>>], src: usize, dst: usize) -> Vec<(u32, u32)> {
    if src == dst {
        return vec![];
    }
    let mut nodes = vec![dst];
    let mut cur = dst;
    loop {
        match preds[src][cur] {
            None => return vec![], // disconnected
            Some(prev) => {
                nodes.push(prev);
                if prev == src {
                    break;
                }
                cur = prev;
            }
        }
    }
    nodes.reverse();
    nodes.windows(2).map(|w| (w[0] as u32, w[1] as u32)).collect()
}

/// Compute weighted distances in the same ragged layout as `neighbour_data`.
///
/// For each (i,j) pair, sums 1/max(W_uv, w_min) along the shortest topological path.
pub fn compute_weighted_dist(net: &Network, w: &[f64], w_min: f64) -> Vec<f64> {
    let mut wd = Vec::with_capacity(net.neighbour_data.len());
    for i in 0..net.n {
        for edges in &net.path_edges[i] {
            let dist: f64 = edges
                .iter()
                .map(|&(u, v)| 1.0 / w[u as usize * net.n + v as usize].max(w_min))
                .sum();
            wd.push(dist);
        }
    }
    wd
}

/// Vose's alias method — O(1) sampling from an arbitrary discrete distribution.
pub struct AliasTable {
    prob: Vec<f64>,
    alias: Vec<usize>,
}

impl AliasTable {
    pub fn new(weights: &[f64]) -> Self {
        let n = weights.len();
        assert!(n > 0);
        let total: f64 = weights.iter().sum();
        let mut prob: Vec<f64> = weights.iter().map(|&x| x * n as f64 / total).collect();
        let mut alias = vec![0usize; n];
        let mut small: Vec<usize> = Vec::new();
        let mut large: Vec<usize> = Vec::new();
        for (i, &p) in prob.iter().enumerate() {
            if p < 1.0 {
                small.push(i);
            } else {
                large.push(i);
            }
        }
        while let (Some(l), Some(g)) = (small.pop(), large.pop()) {
            alias[l] = g;
            prob[g] -= 1.0 - prob[l];
            if prob[g] < 1.0 {
                small.push(g);
            } else {
                large.push(g);
            }
        }
        for i in large {
            prob[i] = 1.0;
        }
        for i in small {
            prob[i] = 1.0;
        }
        AliasTable { prob, alias }
    }

    pub fn sample(&self, rng: &mut impl Rng) -> usize {
        let n = self.prob.len();
        let i = rng.gen_range(0..n);
        let u: f64 = rng.gen_range(0.0..1.0);
        if u < self.prob[i] {
            i
        } else {
            self.alias[i]
        }
    }
}

/// Build alias tables for all agents from their weighted-distance slices.
///
/// Selection probability ∝ exp(-alpha * weighted_dist).
pub fn build_alias_tables(net: &Network, weighted_dist: &[f64], alpha: f64) -> Vec<AliasTable> {
    (0..net.n)
        .map(|i| {
            let [s, e] = net.shell_offsets[i];
            if s == e {
                return AliasTable::new(&[1.0]);
            }
            let weights: Vec<f64> = weighted_dist[s..e]
                .iter()
                .map(|&d| (-alpha * d).exp())
                .collect();
            AliasTable::new(&weights)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use rand::{rngs::StdRng, SeedableRng};
    use crate::network::{ba_graph, hop_distances, init_weights};

    #[test]
    fn alias_table_matches_distribution() {
        let weights = [1.0_f64, 2.0, 3.0, 4.0];
        let table = AliasTable::new(&weights);
        let mut rng = StdRng::seed_from_u64(0);
        let n = 100_000;
        let mut counts = [0usize; 4];
        for _ in 0..n {
            counts[table.sample(&mut rng)] += 1;
        }
        let total: f64 = weights.iter().sum();
        for (i, &w) in weights.iter().enumerate() {
            let expected = w / total;
            let actual = counts[i] as f64 / n as f64;
            assert!(
                (actual - expected).abs() < 0.01,
                "bucket {i}: expected {expected:.3}, got {actual:.3}"
            );
        }
    }

    #[test]
    fn ego_net_hub_shell_sizes() {
        let n = 100;
        let mut rng = StdRng::seed_from_u64(1);
        let adj = ba_graph(n, 1.0, &mut rng);
        let hop = hop_distances(&adj);
        let w = init_weights(&adj, 0.1, 1.0, &mut rng);
        let w_sum: f64 = w.iter().sum();
        let w_count = w.iter().filter(|&&v| v > 0.0).count();
        let w_avg = w_sum / w_count as f64;
        let r = r_max(1.0, 2, w_avg);
        let net = Network::build(&adj, hop, r, 2);

        let mut in_deg = vec![0usize; n];
        for neighbours in &adj {
            for &j in neighbours {
                in_deg[j as usize] += 1;
            }
        }
        let hub = in_deg.iter().enumerate().max_by_key(|&(_, &d)| d).unwrap().0;
        let [s, e] = net.shell_offsets[hub];
        let hub_size = e - s;
        let avg_size: usize = (0..n)
            .map(|i| {
                let [s, e] = net.shell_offsets[i];
                e - s
            })
            .sum::<usize>()
            / n;
        assert!(
            hub_size >= avg_size,
            "hub ego-net ({hub_size}) should be >= average ({avg_size})"
        );
    }
}
