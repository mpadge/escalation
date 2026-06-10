# Implementation Plan

## Language and tooling

**Rust**. Reasons:
- Rayon makes embarrassingly parallel parameter sweeps trivial (one `.par_iter()` call saturates
  all cores across Morris/Sobol runs).
- Memory safety eliminates the class of index-arithmetic bugs that dominate graph mutation code.
- Performance is equivalent to C++ for this workload.
- Cargo handles build and dependency management with no friction.

Graph topology is fixed after initialisation; only edge weights evolve. This means no dynamic
graph structures and no borrow-checker friction around self-referential data.

**Output**: CSV throughout. All aggregate outputs are small enough that binary formats add
complexity without benefit. The simulation kernel computes scalar summaries inline; individual
runs never write raw time series to disk during normal sensitivity analysis sweeps. If full time
series are needed for diagnostic or exploratory runs, they can be written as per-run CSV files,
but this is a debug mode, not the default. The `csv` crate handles writing; keep I/O completely
separate from computation so the format can change without touching the kernel.

---

## Code architecture

Three strictly separated layers:

```
src/
  params.rs       — Params struct; all 28 parameters plus derived constants
  network.rs      — Initialisation: BA graph generation, precomputed structures
  ego_net.rs      — EgoNet / NeighbourhoodStore; weighted distance management
  sim.rs          — Simulation kernel: pure function (params, seed) → MetricSeries
  aggregate.rs    — Inline aggregation: MetricSeries → RunSummary (scalars only)
  experiment.rs   — Experiment runner: generates parameter combinations, calls sim in parallel
  output.rs       — Writes RunSummary records to CSV; optional MetricSeries dump for diagnostics
  main.rs         — CLI entry point; dispatches to experiment runner
```

The simulation kernel (`sim.rs`) takes a `Params` struct and a seed, returns a `MetricSeries`
(in-memory time series). `aggregate.rs` immediately reduces that to a `RunSummary` of scalar
statistics; the `MetricSeries` is then dropped. Only `RunSummary` values are written to disk.
No I/O, no global state, no side effects in the kernel or aggregation layer. These are the units
that Rayon maps over.

---

## Data structures

### Fixed at initialisation (never mutated after `init`)

```rust
struct Network {
    n: usize,
    // Flat N×N hop-distance matrix (u8 sufficient for depth ≤ 255)
    hop_dist: Vec<u8>,                // [i*N + j]
    // For each agent: agents within r_max hops, sorted by hop depth then index
    // Stored as a flat ragged array
    neighbour_data: Vec<u32>,         // concatenated ego-net indices
    hop_data: Vec<u8>,                // hop depth for each entry, same layout
    shell_offsets: Vec<[usize; 2]>,   // [agent i] = [start, end] in neighbour_data
    // For each agent: agents within audience radius theta (subset of above)
    audience_data: Vec<u32>,
    audience_offsets: Vec<[usize; 2]>,
    // Path edges: for each (i, j) in i's ego-net, the sequence of directed
    // edge indices along the shortest topological path from i to j.
    // Used to propagate W changes to weighted distances.
    path_edges: Vec<Vec<Vec<(u32,u32)>>>,  // [agent][neighbour_idx][hop] = (u,v)
}
```

### Evolving state (mutated each timestep)

```rust
struct SimState {
    w: Vec<f64>,          // N×N flat weight matrix [i*N + j]
    epsilon: Vec<f64>,    // N propensities
    payoff: Vec<f64>,     // N cumulative payoffs
    // Weighted distances, same ragged layout as Network::neighbour_data
    weighted_dist: Vec<f64>,
    // Normalised selection probabilities, alias table per agent
    // Rebuilt when weighted distances change
    alias_tables: Vec<AliasTable>,
}
```

### Alias table

Vose's alias method gives O(1) sampling from an arbitrary discrete distribution. An `AliasTable`
holds the standard `prob` and `alias` arrays. Rebuilt for agent i whenever any of i's ego-net
weighted distances change (a bounded set per edge update).

---

## Initialisation sequence

1. Generate Barabási–Albert graph with exponent γ, N nodes.
2. Assign initial weights W_ij ~ Uniform(w_min, w_max) to all edges.
3. Compute full N×N hop-distance matrix via BFS from each node.
4. For each agent i, collect all agents within r_max hops; store in ragged arrays.
5. For each agent i, collect all agents within θ hops; store audience arrays.
6. For each (i, j) pair in i's ego-net, record the edge sequence of the shortest topological
   path (used for incremental weighted-distance updates).
7. Compute initial weighted distances from initial W.
8. Build alias tables for all agents.
9. Sample ε_i ~ clip(Normal(μ₀, σ₀), 0, 1) for all i.

`r_max` is computed once per run:
```rust
fn r_max(alpha: f64, theta: u8, w_avg: f64) -> u8 {
    let r_select = (0.01_f64.ln() / (-alpha * w_avg)).ceil() as u8;
    r_select.max(theta).max(2)
}
```

---

## Timestep loop

```
for t in 0..T_MAX:
    1. Sample focal agent i* ~ Uniform{0..N}
    2. Draw m ~ Poisson(λ) + 1; if m == 1 redraw
    3. Sample m-1 partners from alias_table[i*] → group G
    4. Each i ∈ G draws s_i ~ Bernoulli(ε_i)
    5. Compute n_E, n_C, φ
    6. Compute Ω_i for each i ∈ G
    7. Dispatch to regime handler (CC / X / CK)
    8. Apply propensity updates for G and observers
    9. Apply global edge decay: W *= (1-δ), clamp to [w_min, w_max]
   10. Recompute weighted distances for affected ego-nets
   11. Rebuild alias tables for affected agents
   12. Record metrics (every RECORD_INTERVAL steps)
```

---

## Regime handlers

Each handler is a pure function taking `&mut SimState`, `&Network`, `&Group`, `&Params`:

### `handle_consensus_conflict`
- Pile-on: each conciliator q: π_q -= n_E * e; edge updates for each (p,q) pair.
- Dominance tournament: sort escalators by k_i, pair sequentially, resolve via logistic,
  update payoffs and edges.
- Prestige radiation from winner w to all observers in audience_data[w] ∪ G \ {w}.
- Victory bridging: w gains weak edges to losers' neighbours.

### `handle_contested`
- Greedy E→C pairing (escalators sorted by ε descending, paired to nearest conciliator).
- Payoff/edge updates with Ω' = Ω * ρ_contested.
- Residual E→E tournament with Ω'.
- C solidarity among unexploited conciliators.
- Lone hawk penalty if n_E == 1.

### `handle_consensus_cooperation`
- Payoff: π_i += b * ln(1 + n_C) for each cooperator.
- Symmetric edge strengthening among all C pairs.
- Full group bridging.
- Escalator exclusion for any p ∈ G with s_p == 1.

---

## Propensity update

After regime resolution:

```rust
fn update_propensities(
    state: &mut SimState, net: &Network, group: &[u32],
    payoffs_before: &[f64], params: &Params, rng: &mut impl Rng
) {
    for &i in group {
        let r_i = reinforcement_signal(state, i, payoffs_before, params);
        let o_i = observational_signal(state, group, i, params);
        let xi: f64 = Normal::new(0.0, params.sigma_drift).sample(rng);
        let delta = params.eta * r_i + params.eta_obs * o_i + xi;
        state.epsilon[i] = (state.epsilon[i] + delta).clamp(0.0, 1.0);
    }
    // Observer updates for non-participants within audience radius of winner
    update_observer_propensities(state, net, group, params, rng);
}
```

---

## Weighted distance updates

When edge (u, v) changes weight, update weighted distances for all ego-nets that contain this
edge on a shortest path. The inverted index `edge_to_paths: HashMap<(u32,u32), Vec<(u32,usize)>>`
mapping (u,v) → [(agent_i, neighbour_idx)] is built at init. After each edge change:

```rust
for (i, nbr_idx) in &edge_to_paths[&(u,v)] {
    state.weighted_dist[offset + nbr_idx] = recompute_path_weight(net, state, *i, *nbr_idx);
    // Invalidate alias table for agent i
    alias_dirty[*i] = true;
}
// Rebuild alias tables for dirty agents
for i in dirty_agents {
    state.alias_tables[i] = AliasTable::build(&state.weighted_dist[net.ego_net_slice(i)]);
}
```

---

## Metrics recording and inline aggregation

### MetricSeries — in-memory only

```rust
struct MetricSeries {
    t: Vec<u32>,
    mean_epsilon: Vec<f64>,
    var_epsilon: Vec<f64>,
    gini_k: Vec<f64>,
    epsilon_k_corr: Vec<f64>,
    mean_edge_weight: Vec<f64>,
    regime_dist: Vec<[f64; 3]>,      // (f_CC, f_X, f_CK)
    // modularity and rich-club are expensive; compute every SLOW_INTERVAL steps
    modularity: Vec<f64>,
    rich_club: Vec<f64>,
}
```

Record every `RECORD_INTERVAL` timesteps. Modularity and rich-club computed every
`SLOW_INTERVAL` = 10 × RECORD_INTERVAL. For T=10,000 and RECORD_INTERVAL=100 this is
100 time points × ~10 metrics ≈ 8 KB per run — negligible in RAM during computation, but
60,000 runs × 8 KB = 480 MB if held simultaneously, so aggregate immediately and drop.

### RunSummary — the unit written to disk

`aggregate.rs` collapses each `MetricSeries` into a flat struct of scalars immediately after
the run completes:

```rust
#[derive(serde::Serialize)]
struct RunSummary {
    // Identity
    seed: u64,
    mu0: f64,
    // all other Params fields flattened ...

    // Terminal state (mean of last TAIL_FRAC fraction of timesteps)
    mean_epsilon_final: f64,
    var_epsilon_final: f64,
    gini_k_final: f64,
    epsilon_k_corr_final: f64,
    rich_club_final: f64,
    regime_dist_final: [f64; 3],

    // Trajectory shape
    epsilon_auc: f64,           // area under mean_epsilon(t) curve (trapezoidal)
    epsilon_slope: f64,         // OLS slope of mean_epsilon over full run
    gini_peak: f64,             // max Gini reached during run
    t_gini_peak: u32,           // timestep at which Gini peaked

    // For paired runs: computed after both lo and hi runs finish
    psi: Option<f64>,           // (mean_epsilon_final_hi - lo) / delta_mu0
    tau_psi: Option<u32>,       // first t where |mean_epsilon_hi - lo| < zeta
}
```

`psi` and `tau_psi` are `None` for unpaired runs (diagnostic mode) and populated by the
paired-run wrapper in `experiment.rs`.

### Paired-run aggregation

```rust
fn run_paired(base: &Params, mu0_lo: f64, mu0_hi: f64, seed: u64,
              zeta: f64) -> (RunSummary, RunSummary) {
    let lo = aggregate(run_simulation(&with_mu0(base, mu0_lo), seed));
    let hi = aggregate(run_simulation(&with_mu0(base, mu0_hi), seed));
    let psi = (hi.mean_epsilon_final - lo.mean_epsilon_final) / (mu0_hi - mu0_lo);
    let tau_psi = compute_tau_psi(&lo_series, &hi_series, zeta);
    // attach psi and tau_psi to both summaries, return
}
```

The output CSV has one row per run (not per pair). The pairing is reconstructable from the
shared seed and the two mu0 values.

### CSV output schema

The experiment runner collects `Vec<RunSummary>` and writes a single CSV:

```
seed, mu0, gamma, lambda, alpha, theta, beta, r_win_cost, r_coop_exploit, r_loss_win,
r_obs_coop, r_bridge_sub, kappa, delta, sigma0,
mean_epsilon_final, var_epsilon_final, gini_k_final, epsilon_k_corr_final,
rich_club_final, regime_cc, regime_x, regime_ck,
epsilon_auc, epsilon_slope, gini_peak, t_gini_peak,
psi, tau_psi
```

One file per stage (Morris, Sobol, GP training). File sizes: Morris ≈ 300 rows, Sobol ≈ 60,000
rows, GP training ≈ 2,000–10,000 rows — all comfortably under 50 MB even as plain text.

### Optional diagnostic dump

When run with `--dump-series`, `output.rs` writes the full `MetricSeries` for each run to a
per-run CSV in a subdirectory. This is only useful for inspecting individual trajectories
during Phase 1 and 2 validation; never needed for the sensitivity pipeline.

---

## Experiment runner

```rust
fn run_experiment(param_grid: &[Params], seeds: &[u64]) -> Vec<ExperimentResult> {
    param_grid
        .par_iter()
        .flat_map(|p| seeds.par_iter().map(move |&s| run_simulation(p, s)))
        .collect()
}
```

For the paired sensitivity design used in Morris and Sobol stages:

```rust
fn run_paired(params_base: &Params, mu0_lo: f64, mu0_hi: f64, seed: u64) -> f64 {
    let mut p_lo = params_base.clone(); p_lo.mu0 = mu0_lo;
    let mut p_hi = params_base.clone(); p_hi.mu0 = mu0_hi;
    let lo = run_simulation(&p_lo, seed);
    let hi = run_simulation(&p_hi, seed);
    let psi = (mean_epsilon_final(&hi) - mean_epsilon_final(&lo)) / (mu0_hi - mu0_lo);
    psi
}
```

---

## Sensitivity analysis pipeline

### Stage 0 — parameter reduction (manual, before coding)

Reparametrise:
- `r_win_cost = w_win / c` — escalation return-to-cost ratio
- `r_coop_exploit = b / e` — cooperation vs exploitation advantage
- `r_loss_win = w_loss / w_win` — risk-reward asymmetry
- `r_obs_coop = delta_w_obs / delta_w_coop` — prestige vs bonding contrast
- `r_bridge_sub = delta_w_bridge / delta_w_sub` — reach vs subordination contrast
- `kappa = eta_obs / eta` — observational vs direct learning ratio

Fix at central values: w_min, w_max, sigma_drift, rho_contested, eta_trauma.

Working parameter set: ~12 free parameters.

### Stage 1 — Morris screening

Generate ~150 Morris trajectories using `SALib` (Python wrapper calling the Rust binary) or a
Rust implementation of the Morris algorithm. Output metric: Ψ from paired runs.

### Stage 2 — Sobol indices

Run Saltelli sampling for the ~6 parameters identified in Stage 1. ~30,000 paired runs.
Compute S_i, S_Ti, and second-order S_ij for the top 4–5 parameters.

### Stage 3 — GP emulation

**Purpose**: use the ~6–8 parameters surviving Sobol to build a cheap surrogate for Ψ(θ) that
can be evaluated millions of times and differentiated analytically. This is the step that
produces interpretable, visual results.

**Design**

Generate ~1000 points by Latin Hypercube Sampling (LHS) over the surviving parameters. Run
R=5 paired replicates per design point (same θ, five different seeds). Each replicate returns
one row in the output CSV with a `psi` value and a `tau_psi` value.

```
design.csv        — 1000 rows × p columns (the LHS parameter matrix)
gp_train.csv      — 5000 rows (1000 points × 5 seeds), full RunSummary schema
```

**Per-point aggregation** (Python, after collecting `gp_train.csv`):

For each of the 1000 design points, average over the 5 replicates:

```python
gp_data = (
    df.groupby(param_cols)
      .agg(psi_mean=("psi", "mean"),
           psi_sd=("psi", "std"),
           tau_psi_mean=("tau_psi", "mean"))
      .reset_index()
)
```

`psi_sd` per design point is the observation noise for the GP — use it as a heteroskedastic
noise term rather than assuming constant variance.

**GP specification** (Python, `GPyTorch` or `scikit-learn` GaussianProcessRegressor):

- Kernel: Matérn-5/2 with ARD (Automatic Relevance Determination) — one length scale ℓ_d per
  input dimension d. Matérn-5/2 is preferred over RBF for simulation emulators because it
  allows for non-smooth responses without requiring differentiability everywhere.
- Fit two independent GPs: one for Ψ, one for τ_Ψ.
- Hyperparameters (ℓ_d, output variance, noise variance) fitted by maximising marginal
  log-likelihood.
- Heteroskedastic noise: pass `psi_sd²` per point as the noise term.
- Validation: hold out 20% of design points; check RMSE and empirical coverage of 95%
  predictive intervals on the hold-out set before using the emulator for anything.

**Outputs from the GP fit**

*ARD length scales as a free sensitivity ranking*: short ℓ_d means Ψ changes rapidly along
dimension d — that parameter strongly controls how much μ₀ matters. This ranking costs nothing
extra; it drops out of the GP hyperparameters and can be reported directly as a table.

*2D phase diagrams* (the primary visual output): for each pair of "important" parameters
(those with short ARD length scales), fix all other parameters at their median values and
evaluate the GP predictive mean on a 50×50 grid. Write as CSV:

```
# beta_vs_r_coop_exploit_phase.csv
beta, r_coop_exploit, psi_mean, psi_sd
0.10, 0.20, 0.34, 0.04
...
```

Plot as a heatmap with a contour overlay of `psi_sd` to show where the emulator is uncertain.
Also produce the equivalent grid for τ_Ψ to show whether the persistence of μ₀ effects tracks
or diverges from their asymptotic magnitude.

*Emulator-based Sobol indices*: use the fitted GP as a cheap surrogate for a standard
quasi-Monte Carlo Sobol estimate. Draw 10⁶ Saltelli samples over the parameter ranges, evaluate
the GP (microseconds each), compute S_i and S_Ti analytically. Write as:

```
# sobol_gp.csv
parameter, S_i, S_Ti, S_Ti_minus_Si
beta, 0.31, 0.48, 0.17
...
```

This provides a third sensitivity ranking (after Morris μ* and ARD ℓ_d) to cross-validate
against. Disagreement between the three rankings is itself informative — it indicates
nonlinearity or interaction structure that the simpler methods missed.

**Adaptive refinement** (optional, if GP validation RMSE is poor in specific regions):

Re-run 200 additional design points chosen by maximum predictive variance (i.e., where the GP
is most uncertain). This targeted refinement is much more efficient than simply doubling the
initial design. Add these rows to `gp_train.csv` and refit.

**Final deliverables**

All written as CSV or plain text:

| File | Contents |
|---|---|
| `ard_length_scales.csv` | Parameter, ℓ_d, rank |
| `sobol_gp.csv` | Parameter, S_i, S_Ti |
| `phase_{paramA}_vs_{paramB}.csv` | Grid of (paramA, paramB, psi_mean, psi_sd) |
| `phase_{paramA}_vs_{paramB}_tau.csv` | Same grid for τ_Ψ |
| `gp_validation.csv` | Hold-out predictions vs actuals (RMSE, coverage) |
| `gp_hyperparams.csv` | Fitted ℓ_d, output variance, noise variance |

---

## Implementation phases

### Phase 1 — Static propensity validation

Network and W fixed; only ε evolves (no network updates). Validates payoff and propensity
dynamics in isolation.

### Phase 2 — Network co-evolution

Add edge weight updates, prestige radiation, bridging, decay. Validates rich-club vs bridging
dynamics.

### Phase 3 — Full model with parameter sweeps

Activate all mechanisms. Run Morris → Sobol → GP emulation pipeline.

---

## Dependencies (Cargo.toml)

```toml
[dependencies]
rand = "0.8"
rand_distr = "0.4"       # Normal, Poisson, Bernoulli distributions
rayon = "1.7"            # parallel iterators for experiment runner
csv = "1.3"              # output
serde = { version = "1", features = ["derive"] }  # RunSummary serialisation
clap = "4"               # CLI argument parsing

[dev-dependencies]
approx = "0.5"           # floating-point assertions in tests
```

---

## Key implementation risks and mitigations

| Risk | Mitigation |
|---|---|
| Alias table rebuild is too frequent and dominates runtime | Profile; if hot, batch dirty-table rebuilds to end of timestep |
| edge_to_paths inverted index consumes too much memory | Build on demand per timestep using the path_edges structure; trade memory for init cost |
| Dominance tournament has unbounded depth for large n_E | Cap tournament rounds at ceil(log2(n_E)) + 1; empirically n_E rarely exceeds 5 |
| Observer propensity updates create feedback instability | Clip ε after every update; confirm with Phase 1 validation runs |
| Weighted-distance computation diverges when W_ij → 0 | Use 1/max(W_ij, w_min) as edge cost; w_min floor prevents division by zero |
