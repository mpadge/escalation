# Tasks

Checkbox items track implementation progress. Each item is a single coherent unit of work.
Check it off only when the code compiles, tests pass, and the behaviour is verified.

---

## 0. Project scaffold

- [x] `cargo new --lib escalation` with `src/main.rs` entry point
- [x] Add all dependencies to `Cargo.toml`:
  `rand`, `rand_distr`, `rayon`, `csv`, `serde` (derive feature), `clap`; dev: `approx`
- [x] Create stub files: `params.rs`, `network.rs`, `ego_net.rs`, `sim.rs`,
  `aggregate.rs`, `experiment.rs`, `output.rs`; declare all as `mod` in `lib.rs`
- [x] CI smoke test: `cargo build` and `cargo test` both pass on empty stubs

---

## 1. `params.rs` — parameter struct

- [x] Define `Params` struct with all 28 raw fields (N, γ, μ₀, σ₀, λ, α, θ, β, c, w_win,
  w_loss, e, b, Δw_sub, Δw_coop, Δw_bridge, Δw_obs, Δw_excl, δ_direct, δ_exploit, δ,
  w_min, w_max, η, η_obs, σ_drift, ρ_contested, η_trauma)
- [x] Add `#[derive(Clone, serde::Serialize, serde::Deserialize)]` to `Params`
- [x] Implement `Params::default()` using midpoint of each suggested range from background.md
- [x] Implement derived-parameter helpers:
  - `r_win_cost()`, `r_coop_exploit()`, `r_loss_win()` (payoff ratios)
  - `r_obs_coop()`, `r_bridge_sub()` (edge-weight contrast ratios)
  - `kappa()` = η_obs / η
- [x] Implement `Params::with_mu0(&self, mu0: f64) -> Self` (clones, replaces μ₀)
- [x] Unit test: `Params::default()` round-trips through serde JSON without loss

---

## 2. `network.rs` — graph generation and fixed topology

- [x] Implement Barabási–Albert preferential-attachment generator:
  - Start with a small fully-connected seed graph (m₀ = 3 nodes)
  - Add nodes one at a time up to N; each new node attaches to m = max(1, round(k̄/2))
    existing nodes with probability proportional to in-degree
  - Accept γ as a parameter controlling attachment bias: attachment probability ∝ k^γ
    (standard BA is γ=1; γ>1 steepens the hierarchy)
  - Return adjacency as `Vec<Vec<u32>>` (directed; both directions stored)
- [x] Assign initial edge weights: W_ij ~ Uniform(w_min, w_max), stored as flat `Vec<f64>`
  of length N×N with index `i*N + j`; W_ij = 0.0 for non-edges
- [x] Compute full N×N hop-distance matrix via BFS from each node:
  `hop_dist: Vec<u8>` (flat N×N, value = hop count; u8::MAX for unreachable)
- [x] Unit test: for N=10 fully-connected graph, all hop distances are 1
- [x] Unit test: degree distribution of large BA graph (N=500) follows approximate power law

---

## 3. `ego_net.rs` — precomputed neighbourhood structures

- [x] Implement `r_max(alpha: f64, theta: u8, w_avg: f64) -> u8`:
  `ceil(-ln(0.01) / (alpha * w_avg)).max(theta).max(2)`, capped at 10
- [x] For each agent i, collect all agents j with `hop_dist[i,j] <= r_max`, sorted by hop
  depth then agent index; store as flat ragged array `neighbour_data: Vec<u32>` with
  `shell_offsets: Vec<[usize; 2]>` (start/end indices per agent)
- [x] Store parallel `hop_data: Vec<u8>` in same ragged layout as `neighbour_data`
- [x] For each agent i, collect audience: agents j with `hop_dist[i,j] <= θ`; store as
  `audience_data: Vec<u32>` with `audience_offsets: Vec<[usize; 2]>`
- [x] For each (i, j) pair in i's ego-net, record the ordered edge sequence of the
  shortest topological path from i to j: `path_edges: Vec<Vec<Vec<(u32,u32)>>>`
  (outer index = agent, middle = neighbour index within ego-net, inner = hops as (u,v))
- [x] Build inverted index `edge_to_paths: HashMap<(u32,u32), Vec<(u32,usize)>>` mapping
  directed edge (u,v) → list of (agent i, neighbour_idx) whose shortest path uses (u,v)
- [x] Compute initial `weighted_dist: Vec<f64>` in same ragged layout as `neighbour_data`:
  for each (i,j) pair, sum 1/W_{uv} along the path_edges sequence
- [x] Implement `AliasTable` (Vose's method): `new(weights: &[f64]) -> AliasTable` and
  `sample(&self, rng: &mut impl Rng) -> usize` in O(1)
- [x] Build initial `alias_tables: Vec<AliasTable>` from `weighted_dist` slices,
  one per agent, over that agent's ego-net
- [x] Unit test: alias table samples match expected distribution for small known weights
- [x] Unit test: ego-net for a hub node in a BA graph contains expected shell sizes

---

## 4. `sim.rs` — simulation state and timestep loop (Phase 1: ε only)

*Phase 1: network W is fixed; only ε and π evolve. No edge updates, no decay.*

- [x] Define `SimState` struct:
  `w: Vec<f64>`, `epsilon: Vec<f64>`, `payoff: Vec<f64>`,
  `weighted_dist: Vec<f64>`, `alias_tables: Vec<AliasTable>`
- [x] Define `MetricSeries` struct with `Vec<f64>` fields for each metric and `Vec<u32>` for
  timesteps; fields: `t`, `mean_epsilon`, `var_epsilon`, `gini_k`, `epsilon_k_corr`,
  `mean_edge_weight`, `regime_dist` (`Vec<[f64;3]>`), `modularity`, `rich_club`
- [x] Implement `run_simulation(params: &Params, seed: u64) -> MetricSeries` as the main
  entry point; pure function, no I/O, no global state
- [x] Implement focal agent and group sampling:
  - Focal agent: `Uniform::new(0, N).sample(rng)`
  - Group size m: `Poisson(λ).sample(rng) + 1`; redraw if m == 1
  - Partners: sample m-1 indices from `alias_tables[i*]` without replacement
    (rejection sampling within the alias table; ego-net size >> m in practice)
- [x] Implement strategy realisation: each agent i in G draws `Bernoulli(ε_i)`; compute
  n_E, n_C, φ = n_E / m
- [x] Implement audience multiplier Ω_i for each i in G:
  `1.0 + (A_i(θ) + m - 1).ln_1p() / (N as f64).ln()`
  where `A_i(θ) = audience_offsets[i][1] - audience_offsets[i][0]`
- [x] Implement regime dispatch: φ > 0.75 → CC, 0.25..=0.75 → X, < 0.25 → CK
- [x] Implement `handle_consensus_conflict` (payoffs and ε updates only in Phase 1):
  - Pile-on: each conciliator q: π_q -= n_E * e
  - Tournament: sort escalators by k_i desc; pair sequentially; resolve via logistic
    `σ(β * (k_p - k_q))`; winner: π += w_win - c; loser: π -= w_loss + c
  - No edge updates in Phase 1
- [x] Implement `handle_contested` (payoffs and ε only):
  - Greedy E→C pairing by weighted distance; π updates
  - Residual E→E tournament
  - C solidarity payoffs
  - Lone hawk penalty payoff
- [x] Implement `handle_consensus_cooperation` (payoffs only):
  - π_i += b * (1.0 + n_C as f64).ln() for cooperators
  - Escalator exclusion payoff penalty
- [x] Implement propensity updates for participants:
  - R_i: +1 if strategy paid off, -1 if it didn't (compare π before/after)
  - O_i: mean R sign of same-strategy group members
  - ξ_i ~ Normal(0, σ_drift)
  - Δε = η*R_i + η_obs*O_i + ξ_i; clip to [0,1]
- [x] Implement observer propensity updates for non-participants within audience radius
- [x] Implement metric recording every RECORD_INTERVAL steps:
  - mean_epsilon, var_epsilon: O(N) scan
  - gini_k: sort k_i values, compute Gini coefficient
  - epsilon_k_corr: Pearson correlation of ε_i and k_i vectors
  - mean_edge_weight: mean of non-zero W entries
  - regime_dist: running counts of CC/X/CK, normalised at record time
  - modularity and rich_club: computed every SLOW_INTERVAL = 10×RECORD_INTERVAL
- [x] Unit test: with all ε_i = 1.0, all encounters are CC; verify tournament logic
- [x] Unit test: with all ε_i = 0.0, all encounters are CK; verify cooperation payoff
- [x] Unit test: mean_epsilon drifts in expected direction when η is large and one strategy
  consistently outperforms

---

## 5. `sim.rs` — Phase 2: add edge weight co-evolution

*Add all W mutation rules; weighted distances and alias tables must stay consistent.*

- [x] Implement edge weight update helper: `set_w(state, net, i, j, new_val, dirty_tables)`
  that writes to `state.w[i*N+j]`, propagates to `weighted_dist` via `edge_to_paths`,
  marks affected alias tables dirty, clamps to [w_min, w_max]
- [x] Add edge updates to `handle_consensus_conflict`:
  - Subordination links: W_qp += Δw_sub; W_pq -= δ_direct (per tournament pair)
  - Prestige radiation from winner w to observers:
    `W_kw += Ω_w * Δw_obs * exp(-α * d_kw)` for k in audience ∪ G\{w}
  - Loser distance: `W_kl -= Ω_l * Δw_obs * exp(-α * d_kl) * (1 - ε_k)` for each loser l
  - Victory bridging: for each loser l, for each neighbour n of l (n≠w, n∉G):
    `W_wn += Δw_bridge * exp(-α * d_wn)` if W_wn < w_max
- [x] Add edge updates to `handle_contested`:
  - E→C pairs: W_qp += Δw_sub; W_pq -= δ_exploit
  - Observer updates with Ω' = Ω * ρ_contested
  - C solidarity: W_{qa,qb} += Δw_coop (symmetric); bridging to each other's alters
  - Lone hawk: W_pq -= Δw_excl; W_qp -= Δw_excl
- [x] Add edge updates to `handle_consensus_cooperation`:
  - Mutual: W_ij += Δw_coop for all C pairs (symmetric)
  - Full bridging among C group
  - Escalator exclusion: W_pq -= Δw_excl; W_qp -= Δw_excl
- [x] Implement global edge decay at end of each timestep:
  `W_ij *= (1.0 - δ); W_ij = W_ij.max(w_min)`; mark all alias tables dirty
- [x] Implement weighted distance recomputation for dirty ego-nets (using `edge_to_paths`)
- [x] Implement alias table rebuild for dirty agents
- [x] Unit test: after a single CC encounter, winner's in-degree increases and loser's
  decreases; check exact magnitudes against the update equations
- [x] Unit test: edge decay applied for T steps with no interactions converges all weights
  to w_min

---

## 6. `aggregate.rs` — MetricSeries → RunSummary

- [x] Define `RunSummary` struct with all fields listed in plan.md; `#[derive(serde::Serialize)]`
- [x] Implement `aggregate(series: MetricSeries, params: &Params, seed: u64) -> RunSummary`:
  - Terminal means: average over last `TAIL_FRAC` (default 0.2) of timesteps for each metric
  - `epsilon_auc`: trapezoidal integration of `mean_epsilon` over t
  - `epsilon_slope`: OLS slope (numerically stable one-pass formula)
  - `gini_peak` and `t_gini_peak`: scan `gini_k` series for maximum
  - `psi` and `tau_psi`: set to `None` (populated later by paired-run wrapper)
- [x] Implement `compute_tau_psi(lo: &MetricSeries, hi: &MetricSeries, zeta: f64) -> u32`:
  first timestep where `|mean_epsilon_hi[t] - mean_epsilon_lo[t]| < zeta`;
  return T_MAX if never reached
- [x] Implement paired-run wrapper in `experiment.rs`:
  `run_paired(base: &Params, mu0_lo: f64, mu0_hi: f64, seed: u64, zeta: f64)`
  runs both simulations, calls `aggregate` on each, computes and attaches `psi` and `tau_psi`
- [x] Unit test: `aggregate` on a constant `mean_epsilon` series gives `epsilon_slope ≈ 0`
  and `epsilon_auc = mean * T`
- [x] Unit test: `compute_tau_psi` returns correct crossing timestep for a known synthetic series

---

## 7. `experiment.rs` — parallel runner

- [x] Implement `run_experiment(pairs: &[(Params, Params)], seeds: &[u64], zeta: f64)`
  using `rayon::par_iter` over the Cartesian product of pairs × seeds;
  returns `Vec<(RunSummary, RunSummary)>`
- [x] Implement `run_diagnostic(params: &Params, seeds: &[u64])` (unpaired, single μ₀)
  for Phase 1 and 2 validation runs
- [x] Verify Rayon thread count respects `RAYON_NUM_THREADS` env var (or `--threads` CLI flag)
- [x] Integration test: run 10 paired simulations on tiny params (N=20, T=100); verify CSV
  output has 20 rows and all fields are finite

---

## 8. `output.rs` — CSV writing

- [x] Implement `write_summaries(path: &Path, records: &[RunSummary])` using the `csv` crate
  with serde serialisation; writes header on first call
- [x] Implement `write_series(dir: &Path, summary: &RunSummary, series: &MetricSeries)`
  for the `--dump-series` diagnostic mode; one file per run named `{seed}_{mu0:.3}.csv`
- [x] Unit test: round-trip a `RunSummary` through CSV write → read; verify all f64 fields
  match to 6 significant figures

---

## 9. `main.rs` — CLI

- [x] Define CLI with `clap`:
  - `run` subcommand: `--params <json>`, `--seeds <n>`, `--mu0-lo`, `--mu0-hi`,
    `--t-max`, `--output <path>`, `--threads <n>`, `--dump-series`
  - `validate` subcommand: single run with `--dump-series` forced on, for Phase 1/2 checks
  - `morris` subcommand: reads Morris trajectory CSV (generated by R), runs paired
    simulations, writes output CSV
  - `sobol` subcommand: reads Saltelli sample CSV (generated by R), runs paired simulations,
    writes output CSV
  - `gp-train` subcommand: reads LHS design CSV (generated by R), runs R replicates per
    design point, writes output CSV
- [x] Implement `run` subcommand end-to-end
- [x] Implement `validate` subcommand
- [x] Implement `morris`, `sobol`, `gp-train` subcommands
- [x] Smoke test: `cargo run -- validate --params default` completes without panic for N=50,
  T=1000

---

## 10. Sensitivity analysis scaffolding (R)

*These are scripts in `analysis/`, not Rust. Rust binary is treated as a black box.*
*Required packages: `sensitivity`, `lhs`, `DiceKriging`, `dplyr`, `ggplot2`, `processx`.*

- [x] `analysis/morris.R`: generate Morris trajectories via `sensitivity::morris()` in
  "design" mode, write design CSV, shell-out to Rust binary via `processx::run()`, read
  output CSV, call `sensitivity::tell()` to compute μ* and σ per parameter,
  write `morris_results.csv`

  ```r
  library(sensitivity); library(processx); library(dplyr)
  m <- morris(model = NULL, factors = param_names, r = 15,
              design = list(type = "oat", levels = 8, grid.jump = 4))
  write.csv(m$X, "design_morris.csv", row.names = FALSE)
  processx::run("./target/release/escalation",
                c("morris", "--design", "design_morris.csv", "--output", "morris_raw.csv"))
  psi <- read.csv("morris_raw.csv")$psi
  tell(m, psi)
  write.csv(data.frame(param = param_names, mu_star = m$mu.star, sigma = m$sigma),
            "morris_results.csv", row.names = FALSE)
  ```

- [x] `analysis/sobol.R`: Saltelli sampling via `sensitivity::sobol2007()` in design mode,
  run binary, call `tell()` to compute S_i / S_Ti, extract second-order S_ij for top
  parameters via `sensitivity::sobolSalt()`, write `sobol_results.csv`

  ```r
  library(sensitivity)
  n <- 2000  # Saltelli total = n * (2p + 2)
  X1 <- as.data.frame(matrix(runif(n * p), n, p)); X2 <- as.data.frame(matrix(runif(n * p), n, p))
  s <- sobol2007(model = NULL, X1 = X1, X2 = X2, nboot = 100)
  write.csv(s$X, "design_sobol.csv", row.names = FALSE)
  processx::run("./target/release/escalation",
                c("sobol", "--design", "design_sobol.csv", "--output", "sobol_raw.csv"))
  tell(s, read.csv("sobol_raw.csv")$psi)
  write.csv(data.frame(param = param_names, S1 = s$S$original, ST = s$T$original),
            "sobol_results.csv", row.names = FALSE)
  ```

- [x] `analysis/gp_train.R`:
  - Generate LHS design via `lhs::maximinLHS(n = 1000, k = p)`, scale columns to
    parameter ranges, write `design_lhs.csv`
  - Shell-out to Rust `gp-train` subcommand; collect `gp_train.csv`
  - Aggregate R=5 replicates per design point with `dplyr::summarise`:
    `psi_mean`, `psi_sd`, `tau_psi_mean` → `gp_data.csv`
  - 80/20 train/hold-out split (stratified by `psi_mean` quintile to ensure coverage)
  - Fit Matérn-5/2 ARD GP on Ψ using `DiceKriging::km()`:

    ```r
    library(DiceKriging)
    fit_psi <- km(formula = ~1, design = X_train, response = y_train,
                  covtype = "matern5_2", nugget.estim = TRUE,
                  noise.var = gp_data$psi_sd[train_idx]^2)
    fit_tau <- km(formula = ~1, design = X_train, response = tau_train,
                  covtype = "matern5_2", nugget.estim = TRUE)
    ```

  - Validate on hold-out: `DiceKriging::predict.km()` returns mean and sd; compute RMSE
    and empirical 95% coverage → `gp_validation.csv`
  - Write `gp_hyperparams.csv`: extract `coef.cov(fit_psi)` (ARD length scales per
    parameter), `coef.var(fit_psi)` (output variance), `fit_psi@covariance@nugget`

- [x] `analysis/gp_phase.R`:
  - Load fitted GP objects (save/load via `saveRDS` / `readRDS`)
  - Identify top parameters by ARD length scale (short ℓ_d = sensitive dimension)
  - For each pair of top-ranked parameters, build 50×50 grid with other parameters at
    their median; call `predict.km()` on grid; write `phase_{A}_vs_{B}.csv` and
    `phase_{A}_vs_{B}_tau.csv`
  - Emulator-based Sobol: generate 10⁶ Saltelli samples, evaluate GP means (cheap),
    feed into `sensitivity::sobol2007()` via `tell()`; write `sobol_gp.csv`

- [x] `analysis/plot.R` using `ggplot2`:
  - Phase diagrams: `geom_tile()` for Ψ mean, `geom_contour()` overlay for Ψ sd
  - ARD length scales: `geom_col()` bar chart, parameters on x-axis, ℓ_d on y-axis
    (inverted so short bars = sensitive)
  - Sobol comparison: grouped bar chart of S_i / S_Ti from Morris, Sobol, and GP-Sobol
    side by side; disagreements between methods are highlighted
  - Save each plot via `ggsave()` as PNG at 300 dpi

---

## 11. Phase 3 validation and parameter reduction

- [x] Run Stage 0 manually: verify the 6 ratio reparametrisations are implemented as
  `Params` helper methods and used consistently throughout the simulation
- [x] Fix `w_min`, `w_max`, `sigma_drift`, `rho_contested`, `eta_trauma` at central values;
  document the fixed values in a `defaults.json`
- [x] Run Morris (Stage 1): execute `analysis/morris.R` on full model; inspect μ* and σ;
  identify ~6 parameters with high μ*; record findings in `specs/000-initial-build/results/morris.md`
- [x] Run Sobol (Stage 2): execute `analysis/sobol.R` on reduced set; record S_i, S_Ti,
  S_ij findings in `specs/000-initial-build/results/sobol.md`
- [ ] Run GP emulation (Stage 3): execute full `analysis/gp_train.R` + `analysis/gp_phase.R`
  pipeline; validate GP; produce phase diagrams; record findings in
  `specs/000-initial-build/results/gp.md`

---

## Implementation order

Follow these phases strictly — each phase has a clear validation gate before proceeding:

| Phase | Tasks | Gate |
|---|---|---|
| 1 | 0 → 4 (no edge updates) | Unit tests pass; diagnostic run shows ε drift in expected direction |
| 2 | 5 (edge updates) | Tournament winner gains in-degree; decay test passes |
| 3 | 6 → 9 (aggregation, runner, CLI) | Integration test: 10 paired runs produce valid CSV |
| 4 | 10 → 11 (sensitivity pipeline) | Morris results identify ≤ 8 important parameters |
