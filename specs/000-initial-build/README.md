# Stage 000 — Initial Build

Files in reading order:

- **background.md** — Project overview: the social escalation simulation, its agents, network structure, and the central research question.
- **plan.md** — Stage design plan: goals, proposed sensitivity analysis pipeline (Morris → Sobol → GP), and open questions.
- **tasks.md** — Concrete implementation checklist; shows what was built and in what order.
- **results/morris.md** — Morris one-at-a-time screening results across all 11 parameters; identifies the top 6 influential parameters.
- **results/sobol.md** — Sobol first-order and total-effect indices for the top-6 Morris parameters; confirms dominance of the observational learning channel.
- **results/gp.md** — GP emulator training results (ARD hyperparameters, RMSE, coverage) fitted on the top-6 Sobol parameters.
- **results/summary.md** — Conclusions from the full three-stage sensitivity analysis: which parameters drive Ψ and why.
