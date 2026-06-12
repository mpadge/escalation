# src/ — Simulation kernel

The simulation is a parallel Rust binary. The architecture has three strictly
separated layers: **kernel** (pure computation, no I/O), **experiment runner**
(parallelism and parameter grids), and **output** (CSV serialisation). Only the
output layer touches the filesystem.

---

## Files

### `params.rs`
The `Params` struct: all model parameters (network size `n`, payoff coefficients,
escalation tendency `μ₀`, group-size rate `λ`, influence-decay `α`, hierarchy
steepness `γ`, learning rates, edge-weight bounds, etc.). Passed by value into
every simulation call; no global state.

### `network.rs`
Barabási–Albert graph construction and precomputed structural data. Builds the
fixed `Network` struct at initialisation — topology never changes after this
point. Key contents: a flat N×N hop-distance matrix, per-agent ego-net
neighbour lists (ragged arrays sorted by hop depth), audience-radius subsets,
and the `path_edges` index that maps each (agent, neighbour) pair to the
sequence of directed edge indices along the shortest topological path. The path
index is used by `ego_net.rs` for incremental weighted-distance updates.

### `ego_net.rs`
Manages the evolving weighted distances and the alias tables for partner
selection. When edge (u, v) changes weight, an inverted index (`edge_to_paths`)
identifies only the ego-nets that route through that edge and recomputes their
weighted distances in place. Agents with invalidated distances get their alias
tables rebuilt using Vose's O(1) method. Everything else is left untouched.

### `sim.rs`
The simulation kernel: a pure function `(params, seed) → MetricSeries`. Each
timestep:
1. Sample focal agent and draw group size from Poisson(λ)+1.
2. Sample partners via the focal agent's alias table.
3. Each group member independently draws a strategy (escalate or cooperate).
4. Dispatch to one of three regime handlers based on the composition of the
   group:
   - **Consensus conflict (CC)** — all escalate: dominance tournament, prestige
     radiation from winner, victory bridging to losers' neighbours.
   - **Contested (X)** — mixed group: greedy escalator–conciliator pairing,
     residual E–E tournament, cooperator solidarity among unmatched conciliators.
   - **Consensus cooperation (CK)** — all cooperate: log-scaled group payoff,
     symmetric tie strengthening, full group bridging.
5. Update propensities for group members (direct reinforcement + observational
   learning from observers within audience radius) and for non-participant
   observers of the winner.
6. Apply global edge decay; recompute affected weighted distances and alias
   tables.

No I/O, no side effects. `sim.rs` knows nothing about files or parallelism.

### `aggregate.rs`
Immediately reduces the in-memory `MetricSeries` returned by `sim.rs` to a flat
`RunSummary` of scalars (terminal-state means, trajectory shape statistics,
optional paired-run `ψ`). The series is dropped after aggregation. `RunSummary`
is the unit of parallelism — the only thing `experiment.rs` accumulates.

### `experiment.rs`
The experiment runner. Maps a parameter grid over seeds using Rayon's
`.par_iter()`. For sensitivity analysis stages the runs are *paired*: each
design point is evaluated at both `μ₀_lo` and `μ₀_hi` with the same seed, and
`ψ = (ε̄_hi − ε̄_lo) / Δμ₀` is computed from the pair before writing. Collects
`Vec<RunSummary>` and hands off to `output.rs`.

### `output.rs`
Serialises `Vec<RunSummary>` to a single CSV via `serde` + the `csv` crate. I/O
is fully separated from computation: changing the output format requires
touching only this file. An optional `--dump-series` flag writes the raw
`MetricSeries` for each run to per-run CSVs in a subdirectory — useful for
diagnostic trajectory inspection but never used in the sensitivity pipeline.

### `main.rs`
CLI entry point (built with `clap`). Dispatches subcommands (`run`, `sweep`,
`morris`, `sobol`, `gp`) to the appropriate experiment configuration in
`experiment.rs`.

---

## Data flow

```
Params + seed
    └─► sim.rs          → MetricSeries  (in-memory, dropped immediately)
    └─► aggregate.rs    → RunSummary    (scalars only)
    └─► experiment.rs   → Vec<RunSummary>  (collected across par_iter)
    └─► output.rs       → results/*.csv
```

The paired-run wrapper in `experiment.rs` computes `ψ` before `RunSummary`
reaches `output.rs`, so the CSV has one row per run (not per pair); pairs are
reconstructable from the shared seed and the two `μ₀` values.
