# escalation

A simulation study of social escalation dynamics: When does a higher baseline
tendency to escalate spread through a population, and does it concentrate
network power in the individuals who escalate most?

The core findings are in [`docs/report.md`](https://github.com/mpadge/escalation/blob/main/docs/report.md). Read that first if
you want the results without the pipeline details.

---

## What this is

It's a large-scale simulation of realistic social networks in which entire
groups of "agents" can choose to escalate or cooperate. Agents are embedded in
scale-free networks and repeatedly interact in small groups, each choosing to
escalate (compete for dominance) or cooperate and conciliate. Interaction
outcomes update both agents' behavioural propensities and the edge weights of
the network, so social structure and behaviour co-evolve. The analysis asks two
questions:

1. **Population level** — if one group starts with a higher escalation
   tendency, does the social environment amplify or absorb that difference by
   equilibrium?
2. **Individual level** — do the most escalatory agents become the most
   central in the network, and does that advantage grow as the population's
   baseline escalation tendency rises?

---

## `src/` — Simulation kernel (Rust)

A parallel Rust binary built with Rayon. Key modules:

- [`params.rs`](https://github.com/mpadge/escalation/blob/main/src/params.rs) — parameter struct (network size, payoff coefficients, μ₀, etc.)
- [`network.rs`](https://github.com/mpadge/escalation/blob/main/src/network.rs) / [`ego_net.rs`](https://github.com/mpadge/escalation/blob/main/src/ego_net.rs) — Barabási–Albert graph construction and ego-network sampling
- [`sim.rs`](https://github.com/mpadge/escalation/blob/main/src/sim.rs) — per-step simulation logic: group formation, payoff resolution, propensity updates
- [`experiment.rs`](https://github.com/mpadge/escalation/blob/main/src/experiment.rs) / [`aggregate.rs`](https://github.com/mpadge/escalation/blob/main/src/aggregate.rs) — batch-run harness and output aggregation
- [`main.rs`](https://github.com/mpadge/escalation/blob/main/src/main.rs) — CLI entry point (`run`, `sweep`, etc.)

Build and run via `cargo build --release` and `make run` (see [`Makefile`](https://github.com/mpadge/escalation/blob/main/Makefile)).

---

## `analysis/` — Statistical pipeline (R)

Sensitivity analysis, GP (Gaussian Process) emulation, and phase-diagram
generation. Shared utilities are factored into three files used across all
stages:

- [`gp_train_utils.R`](https://github.com/mpadge/escalation/blob/main/analysis/gp_train_utils.R) — data loading, design-matrix construction, GP fitting (DiceKriging), validation
- [`gp_phase_utils.R`](https://github.com/mpadge/escalation/blob/main/analysis/gp_phase_utils.R) — phase-grid construction and GP prediction over parameter pairs
- [`plot_utils.R`](https://github.com/mpadge/escalation/blob/main/analysis/plot_utils.R) — ggplot2 panel builders and three-panel figure export

Stage-specific scripts follow the naming convention `<verb><stage>.R`:

| Script | Stage | Purpose |
|---|---|---|
| [`morris.R`](https://github.com/mpadge/escalation/blob/main/analysis/morris.R), [`sobol.R`](https://github.com/mpadge/escalation/blob/main/analysis/sobol.R) | 0–1 | Sensitivity screening |
| [`gp_train.R`](https://github.com/mpadge/escalation/blob/main/analysis/gp_train.R), [`gp_phase.R`](https://github.com/mpadge/escalation/blob/main/analysis/gp_phase.R), [`plot.R`](https://github.com/mpadge/escalation/blob/main/analysis/plot.R) | 0–1 | GP emulation and plotting |
| [`gp_train2.R`](https://github.com/mpadge/escalation/blob/main/analysis/gp_train2.R), [`gp_phase2.R`](https://github.com/mpadge/escalation/blob/main/analysis/gp_phase2.R), [`plot2.R`](https://github.com/mpadge/escalation/blob/main/analysis/plot2.R) | 2 | Equilibrium-surface phase diagrams |
| [`gp_train3.R`](https://github.com/mpadge/escalation/blob/main/analysis/gp_train3.R), [`gp_phase3.R`](https://github.com/mpadge/escalation/blob/main/analysis/gp_phase3.R), [`plot3.R`](https://github.com/mpadge/escalation/blob/main/analysis/plot3.R) | 3 | Centrality-correlation phase diagrams |

Run individual stages via `make` targets (e.g. `make gp3`, `make plots3`).

---

## `docs/` — Report and figures

- [`report.md`](https://github.com/mpadge/escalation/blob/main/docs/report.md)
— ~3,000-word research memo covers findings from Stages 2–3 without pipeline
details
- [`plot_report.R`](https://github.com/mpadge/escalation/blob/main/docs/plot_report.R)
— standalone script that renders the three report figures from the phase CSVs
in `results/`; run with `Rscript docs/plot_report.R`
- [`figures/`](https://github.com/mpadge/escalation/blob/main/docs/figures) — PNG
figure outputs referenced by the report


---

## `specs/` — Stage-by-stage research log

The entire repo was generated with AI tools, structured with
[designlens](https://github.com/ropensci-review-tools/designlens). This leaves
structured outputs of the entire process in the `specs/` directory, in which
each numbered subdirectory documents one analysis stage. Read
[`specs/README.md`](https://github.com/mpadge/escalation/blob/main/specs/README.md)
for an overview of what the stages are.
Within each stage directory, a `README.md` lists the files in reading order.
The stages are:

| Directory | Purpose |
|---|---|
| [`000-initial-build`](https://github.com/mpadge/escalation/blob/main/specs/000-initial-build/README.md) | Initial sensitivity analysis: Morris screening → Sobol → GP |
| [`001-revise-param-ranges`](https://github.com/mpadge/escalation/blob/main/specs/001-revise-param-ranges/README.md) | Robustness check: re-run sensitivity with revised parameter ranges |
| [`002-equilibrium-surfaces`](https://github.com/mpadge/escalation/blob/main/specs/002-equilibrium-surfaces/README.md) | Phase diagrams of mean escalation; amplification ratio Ψ |
| [`003-centrality-correlation`](https://github.com/mpadge/escalation/blob/main/specs/003-centrality-correlation/README.md) | Phase diagrams of ε–degree correlation; dissociation finding |
| [`004-report-draft`](https://github.com/mpadge/escalation/blob/main/specs/004-report-draft/README.md) | Plan and tasks for the `docs/report.md` write-up |

[`specs/design-decisions.md`](https://github.com/mpadge/escalation/blob/main/specs/design-decisions.md) is a project-level narrative of key architectural
decisions accumulated across all stages.

---

## A note on AI usage

This entire repository was made to answer one very specific research question.
All of the code was produced by Claude, but all guided with very specific
instructions by me (@mpadge). Most of the initial conception is detailed in
[`specs/000-initial-build/background.md`](https://github.com/mpadge/escalation/blob/main/specs/000-initial-build/background.md).
If you're looking for the human input into this, that document is where most of
it lies. That is an extremely technical document that guided the design the
rust library in [`src/`](https://github.com/mpadge/escalation/blob/main/src).
All assumptions on individual and population-level behaviour were specified in 
[`background.md`](https://github.com/mpadge/escalation/blob/main/specs/000-initial-build/background.md),
and directly encoded in the rust source. That provided a sufficiently detailed
context for Claude to be able to design and run all experiments detailed in the
[`specs/`](https://github.com/mpadge/escalation/blob/main/specs) phases.
