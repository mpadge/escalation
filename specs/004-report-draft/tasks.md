---
created: 2026-06-12T12:45:00Z
agent: claude-sonnet-4-6
git_hash: a938c4a2320aa587b04a674f98da674ac5819e70
---

# Tasks: report-draft

## T004-1: Write docs/report.md — Opening section
- [x] T004-1: Create `docs/` directory if it does not exist. Write the
  **Opening** section of `docs/report.md` (~200 words). Frame the central
  question: escalation is individually tempting but socially costly; the
  question is whether social feedback amplifies or absorbs escalatory
  tendencies at the population level. Introduce the two sub-questions that
  structure the rest of the memo: (1) does more escalation beget more
  escalation at the population level? (2) does escalatory behaviour
  concentrate network power in the individuals who exhibit it? Do not
  introduce model details yet.

## T004-2: Write docs/report.md — Model in brief section
- [x] T004-2: Append a **The model** section (~300 words) to `docs/report.md`.
  Describe what the simulation captures for a non-technical reader: agents
  embedded in a social network, repeated interactions whose outcomes leave a
  lasting trace in the network (edge weights as relational memory), and two
  broad interaction regimes — escalation and cooperation/conciliation.
  Foreground the payoff asymmetry without citing specific parameter values:
  escalation can win an encounter and extract short-term advantage but
  degrades shared cooperative infrastructure; cooperation is slower to pay
  off but builds durable, broadly distributed network ties. Introduce μ₀ as
  "the population's baseline tendency to escalate" on first use. No equations,
  no mention of GP emulators or sensitivity analysis methods.

## T004-3: Write docs/report.md — Amplification section
- [x] T004-3: Append a **Does more escalation beget more escalation?** section
  (~700 words) to `docs/report.md`. Draw on
  `specs/002-equilibrium-surfaces/results/summary.md` and `interpretation.md`.
  Cover: (a) the baseline result — across most structural conditions, a
  higher starting escalation tendency does *not* produce a proportionally
  higher equilibrium; the social environment absorbs the perturbation;
  (b) the amplification regime — Ψ > 1 is real but confined to two structural
  configurations: small encounter groups with strongly local network influence,
  and small groups with steep hierarchical reward structure; (c) what these
  configurations mean in plain language — insular subgroups, tightly-coupled
  cohorts, rigid hierarchies with small interaction sets; (d) a qualitative
  assessment of practical likelihood: these conditions are recognisable but
  not the default; they represent specific institutional forms rather than
  generic social environments. Introduce Ψ as "the ratio of equilibrium
  escalation gap to starting escalation gap" on first use; use "amplification
  ratio" thereafter.

## T004-4: Write docs/report.md — Centrality section
- [x] T004-4: Append a **Does escalation concentrate power?** section (~700
  words) to `docs/report.md`. Draw on
  `specs/003-centrality-correlation/results/summary.md` and
  `interpretation.md`. Cover: (a) the baseline result — escalatory individuals
  do tend to become more central in the network at equilibrium, but the
  tendency is modest (mean correlation ≈ 0.08) and highly parameter-dependent
  (reaching up to 0.63 in some regimes); (b) what governs this advantage —
  it is the *locality* of social influence (alpha), not group size or
  observational learning rate; (c) the dissociation finding — the regime
  where population-level escalation amplifies most strongly (gamma × lambda)
  is the one regime where increasing the baseline escalation tendency *reduces*
  the centrality advantage of individual escalators; in that regime, higher μ₀
  raises the population mean uniformly rather than concentrating influence in
  the most escalatory agents; (d) the interpretation: in the conditions where
  escalation is most likely to spread as a social norm, it spreads to everyone,
  rather than disproportionately empowering the instigators. This is the
  conceptual centrepiece of the memo.

## T004-5: Write docs/report.md — Cooperation and stability section
- [x] T004-5: Append a **Why escalation does not take over** section (~600
  words) to `docs/report.md`. Argue from the model's payoff asymmetry —
  without citing specific parameter values — that cooperation provides a
  stabilising counterforce that prevents convergence to a single dominant
  escalatory hierarchy. Key points: (a) escalation extracts short-term
  advantage but severs or degrades the ties through which broader social
  influence flows; (b) cooperation and conciliation continuously rebuild
  diffuse network ties — bridging connections, solidarity bonds — that
  distribute influence rather than concentrating it; (c) even in regimes where
  escalatory individuals are more central on average, their advantage is
  bounded because the network keeps reconstituting cooperative pathways around
  them; (d) connect to the empirical finding that the ε–degree correlation
  rarely exceeds 0.3 across most of parameter space, and reaches its highest
  values only under the specific local-influence conditions that are themselves
  not the amplification regime.

## T004-6: Write docs/report.md — Discussion and caveats section
- [x] T004-6: Append a **Discussion** section (~500 words) to `docs/report.md`.
  Cover: (a) the two main findings stated plainly: the population-level
  amplification is real but narrow; the individual-level centrality advantage
  is weak and dissociated from the amplification regime; (b) what the model
  does not yet address — inequality dynamics (Gini trajectories), how long
  equilibration takes, how intervention at the network level (changing group
  size or interaction locality) could shift populations out of the amplification
  regime; (c) the practical implication: the structural conditions that matter
  most are group size and interaction locality, not the intrinsic reward
  parameters; (d) a brief forward-looking sentence noting that richer
  characterisation of the equilibration trajectory and inequality dynamics
  is the natural next step.

## T004-7: Identify figures and write docs/plot_report.R
- [x] T004-7: Read the completed `docs/report.md` and identify which phase
  diagram panels are cited or would materially strengthen the narrative.
  Expected candidates: (a) the alpha × lambda Ψ surface from Stage 2 (the
  amplification regime); (b) the gamma × lambda three-panel from Stage 2 or
  Stage 3 (the dissociation); (c) optionally the alpha × gamma correlation
  surface from Stage 3 (the locality-driven centrality advantage). Then write
  `docs/plot_report.R` as a standalone script that:
  - Sources `analysis/plot_utils.R`
  - Creates `docs/figures/` if it does not exist
  - Reads only the CSV files required for the chosen figures from
    `results/gp_phase2/` and `results/gp_phase3/`
  - Calls `panel_sequential`, `panel_diverging`, and `save_three_panel` (or
    saves individual panels) to write the final figures to `docs/figures/`
  - Uses descriptive filenames (`fig1_amplification_alpha_lambda.png`, etc.)
  Add figure references (e.g. `*Figure 1*` captions) to the relevant
  paragraphs in `docs/report.md`.

## T004-8: Run docs/plot_report.R and verify figure outputs
- [x] T004-8: Run `Rscript docs/plot_report.R` and confirm all expected PNG
  files appear in `docs/figures/`. If any figure fails to render, fix the
  error before proceeding. Check that figure filenames match the references
  inserted into `docs/report.md` in T004-7.
