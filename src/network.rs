use rand::Rng;
use rand_distr::{Distribution, Uniform};

/// Generate a Barabási–Albert preferential-attachment graph.
///
/// Returns directed adjacency lists (both directions stored).
/// Attachment probability ∝ k_i^γ.
pub fn ba_graph(n: usize, gamma: f64, rng: &mut impl Rng) -> Vec<Vec<u32>> {
    let m0: usize = 3;
    let mut adj: Vec<Vec<u32>> = vec![vec![]; n];

    // Seed graph: fully connected m0 nodes
    for i in 0..m0 {
        for j in 0..m0 {
            if i != j {
                adj[i].push(j as u32);
            }
        }
    }

    for new_node in m0..n {
        // m = max(1, round(mean_degree / 2))
        let total_edges: usize = adj[..new_node].iter().map(|v| v.len()).sum();
        let mean_k = total_edges as f64 / new_node as f64;
        let m = (1usize).max((mean_k / 2.0).round() as usize).min(new_node);

        // Weighted selection proportional to in-degree^γ
        let degrees: Vec<f64> = (0..new_node)
            .map(|i| {
                let k = adj[..new_node].iter().filter(|v| v.contains(&(i as u32))).count();
                (k as f64 + 1.0).powf(gamma)
            })
            .collect();
        let total_w: f64 = degrees.iter().sum();

        let mut targets: Vec<usize> = Vec::with_capacity(m);
        let uniform = Uniform::new(0.0_f64, 1.0);
        while targets.len() < m {
            let r = uniform.sample(rng) * total_w;
            let mut cumsum = 0.0;
            for (i, &w) in degrees.iter().enumerate() {
                cumsum += w;
                if r <= cumsum && !targets.contains(&i) {
                    targets.push(i);
                    break;
                }
            }
        }

        for t in &targets {
            adj[new_node].push(*t as u32);
            adj[*t].push(new_node as u32);
        }
    }

    adj
}

/// Assign initial edge weights W_ij ~ Uniform(w_min, w_max).
///
/// Returns a flat N×N matrix (index i*N + j); 0.0 for non-edges.
pub fn init_weights(
    adj: &[Vec<u32>],
    w_min: f64,
    w_max: f64,
    rng: &mut impl Rng,
) -> Vec<f64> {
    let n = adj.len();
    let mut w = vec![0.0_f64; n * n];
    let dist = Uniform::new(w_min, w_max);
    for (i, neighbours) in adj.iter().enumerate() {
        for &j in neighbours {
            let j = j as usize;
            if w[i * n + j] == 0.0 {
                let val = dist.sample(rng);
                w[i * n + j] = val;
                w[j * n + i] = val;
            }
        }
    }
    w
}

/// Compute full N×N hop-distance matrix via BFS from each node.
///
/// Returns flat N×N Vec<u8>; u8::MAX for unreachable pairs.
pub fn hop_distances(adj: &[Vec<u32>]) -> Vec<u8> {
    let n = adj.len();
    let mut dist = vec![u8::MAX; n * n];
    for src in 0..n {
        dist[src * n + src] = 0;
        let mut queue = std::collections::VecDeque::new();
        queue.push_back(src);
        while let Some(u) = queue.pop_front() {
            let d_u = dist[src * n + u];
            for &v in &adj[u] {
                let v = v as usize;
                if dist[src * n + v] == u8::MAX {
                    dist[src * n + v] = d_u.saturating_add(1);
                    queue.push_back(v);
                }
            }
        }
    }
    dist
}

#[cfg(test)]
mod tests {
    use super::*;
    use rand::{SeedableRng, rngs::StdRng};

    #[test]
    fn hop_distances_fully_connected() {
        let n = 10;
        let adj: Vec<Vec<u32>> = (0..n)
            .map(|i| (0..n).filter(|&j| j != i).map(|j| j as u32).collect())
            .collect();
        let dist = hop_distances(&adj);
        for i in 0..n {
            for j in 0..n {
                if i == j {
                    assert_eq!(dist[i * n + j], 0);
                } else {
                    assert_eq!(dist[i * n + j], 1, "({i},{j}) should be 1 hop");
                }
            }
        }
    }

    #[test]
    fn ba_graph_power_law_degree() {
        let n = 500;
        let mut rng = StdRng::seed_from_u64(42);
        let adj = ba_graph(n, 1.0, &mut rng);

        // Collect in-degrees
        let mut in_deg = vec![0usize; n];
        for neighbours in &adj {
            for &j in neighbours {
                in_deg[j as usize] += 1;
            }
        }

        // A power-law degree distribution has most nodes with low degree and
        // few nodes with high degree. Verify: max degree > 3 * mean degree.
        let mean_deg = in_deg.iter().sum::<usize>() as f64 / n as f64;
        let max_deg = *in_deg.iter().max().unwrap() as f64;
        assert!(
            max_deg > 3.0 * mean_deg,
            "expected hub (max_deg={max_deg:.1}) >> mean (mean_deg={mean_deg:.1})"
        );
    }
}
