---
description: "4. Generate transcript and design decisions for the current stage"
---

Find the latest (highest-numbered) stage directory under `specs/`. Then follow the branching logic below.

Read `.designlens.json` to get `auto_commit` and run `git config user.name` to get the git user.

---

## DETECTION: Normal retrospective or auto-retrospective?

Check whether the latest stage directory already has a `design-decisions.md`:

**Case A — Latest stage has `design-decisions.md` (no open stage):**

Run:
```bash
designlens lib commits-since-stage
```

Parse `count=` and `threshold=` from the output.

- If `count` >= `threshold`: ask — "**`count` commits** have occurred since the last stage (threshold: `threshold`). Generate an auto-retrospective stage to capture this work? (y/n)"
- If `count` < `threshold`: ask — "Only `count` commits since the last stage (threshold: `threshold`). Generate an auto-retrospective anyway? (y/n)"

If the user answers **yes** to either prompt: proceed to **AUTO-RETROSPECTIVE FLOW** below.
If the user answers **no**: inform them there is nothing to retrospect and stop.

**Case B — Latest stage has `plan.md` and `tasks.md` but no `design-decisions.md` (open stage):**

If `design-decisions.md` already exists in that directory, ask before overwriting.

Continue to **STEP 1 OF 3** below (normal retrospective flow).

---

## AUTO-RETROSPECTIVE FLOW

*(Only reached when Case A above is confirmed by the user.)*

**1.** Create the new stage directory:
```bash
designlens new-stage "Retrospective: untracked development" "retrospective"
```

**2.** Immediately delete the generated `plan.md` from that directory — auto-retrospective stages have `design-decisions.md` only.

**3.** Survey the commit window. Use the `git_hash` printed by `designlens lib commits-since-stage` (re-run if needed to capture it), then:
```bash
git log <git_hash>..HEAD --oneline
git diff <git_hash>..HEAD --stat
```

**4.** Write `<stage_dir>/design-decisions.md` using this template:

```markdown
---
created: <current UTC timestamp in ISO 8601>
agent: <your model identifier>
git_hash: <result of git rev-parse HEAD — always current HEAD>
---

# Design Decisions: Retrospective (NNN)

## Commit Window
From: <previous git_hash, first 8 chars>
To: <current HEAD, first 8 chars>
Commits: <count>

## Summary
[1–2 sentences summarising what changed in this window, derived from git log]

## Changes Captured

### [Theme or component name]
**What changed:** [Description derived from git log/diff]
**Rationale:** [Inferred from commit messages where possible; note if inferred]
**Impact:** [What this affects going forward]

## Notes
[Patterns, pivots, or observations not captured in the sections above]
```

**5.** Write `<stage_dir>/.metadata.json`:
```json
{
  "agents": ["<model-identifier>"],
  "created": "<current UTC timestamp ISO 8601>",
  "last_updated": "<current UTC timestamp ISO 8601>",
  "sessions": 1,
  "input_tokens": null,
  "output_tokens": null,
  "user_word_count": null,
  "lines_added": null,
  "lines_deleted": null,
  "files_changed": null
}
```

**6.** Also update `specs/design-decisions.md` (the root aggregate) following the same instructions as STEP 3 OF 3 in the normal flow below — read all stage `design-decisions.md` files in order and rewrite the project-level narrative.

**7.**
```bash
git add <stage_dir>/ specs/design-decisions.md
```
- If `auto_commit` is `true`: commit with `git commit -m "<NNN>: Add auto-retrospective"`
- If `auto_commit` is `false`: stage only, leave commit to the user.

Tell the user to run `/designlens.new-stage` when ready to start the next stage. **Stop here — do not continue to STEP 1 OF 3.**

---

## STEP 1 OF 3: Session transcript

Create a semi-anonymized summary transcript of this design session and save it to `<stage_dir>/.transcript.md`.

### Format

```markdown
---
created: <current UTC timestamp in ISO 8601, e.g. 2026-03-31T14:05:00Z>
agent: <your model identifier, e.g. claude-sonnet-4-6>
---

# Session Transcript: [Stage Title]

## Session Overview
[1-2 sentences summarizing what was discussed and decided]

## Design Decisions Made

### Decision 1: [What was decided]
**Chosen:** [The option selected]
**Rationale:** [Why this was chosen over alternatives]
**Tradeoffs:** [What was sacrificed or deferred]
**Proposed by:** [git-user | agent | joint]

### Decision 2: [What was decided]
[Same structure]

## Tradeoffs Considered
- [Option A vs Option B]: [Why the chosen option won]

## Open Questions
- [Any unresolved questions or deferred items]
```

### Anonymization requirements (non-negotiable)
- Speaker labels: use `git config user.name`, not "human", "user", or real names
- No personal expressions, anecdotes, or preferences in first person
- No email addresses or identifying information
- No user counts, revenue, or business-specific details
- Focus on technical reasoning and decisions, not speakers

### Role attribution (required for every decision)
- Every decision MUST have a "Proposed by" field
- Use `git config user.name` for the human participant
- Use `agent` for the AI assistant
- Use `joint` when both contributed equally

**Length:** 150–400 words. Concise and scannable.

---

## STEP 2 OF 3: Generate `design-decisions.md`

Read `plan.md`, `tasks.md`, and `.transcript.md` from the current stage. Also read `design-decisions.md` from all previous stages (in order) for context.

Run `git rev-parse HEAD` to get the current commit hash.

Generate `<stage_dir>/design-decisions.md` documenting what is **new in this stage**:

```markdown
---
created: <current UTC timestamp in ISO 8601, e.g. 2026-03-31T14:05:00Z>
agent: <your model identifier, e.g. claude-sonnet-4-6>
git_hash: <result of git rev-parse HEAD — always overwrite with current value>
---

# Design Decisions: [Stage Title]

## Summary
[1-2 sentences of what was accomplished and the key decisions made]

## New Design Decisions

### Decision 1: [What was decided in THIS stage]
**Chosen:** [The option selected]
**Rationale:** [Why; focus on technical/business reasons]
**Tradeoffs:** [What was sacrificed]
**Proposed by:** [git-user | agent | joint]  (omit if not relevant)
**Relates to:** [Brief cross-ref if building on prior work]

### Decision 2: [What was decided]
[Same structure]

## Integration with Prior Work
[How this stage's decisions connect to and build on previous stages.]

## Issues Resolved
- [Issue from plan.md: how it was resolved]

## Deferred Items
[Things discussed but deferred to later stages]

## Process Notes
- [How design evolved or changed direction]
- [Blockers encountered]
```

Anonymization: no personal names, email addresses, or identifying information. Use passive voice or role-based language. 200–400 words; cross-reference prior stages rather than repeating them.

---

## STEP 3 OF 3: Update `specs/design-decisions.md`

Read the `design-decisions.md` from every stage in order (including the one just written). Also read the current stage's `plan.md` to understand the project's current form.

Write or update `specs/design-decisions.md` as a coherent project-level narrative. Include `git_hash` in the YAML block, always overwriting with the current value from `git rev-parse HEAD`:

```markdown
---
created: <current UTC timestamp in ISO 8601, e.g. 2026-03-31T14:05:00Z>
agent: <your model identifier, e.g. claude-sonnet-4-6>
git_hash: <result of git rev-parse HEAD — always overwrite with current value>
---

# Design Decisions: [Project Name]

## Current Architecture
[Description of the present form, synthesised from the latest plan.md]

## Key Decisions

### [Decision title]
**Outcome:** [What was decided and remains true today]
**Rationale:** [Why, synthesised across the stages that shaped it]
**Roads not taken:** [Alternatives considered and rejected, with reasons]
**Stages:** [Which stage(s) made or refined this decision]

## Architectural Evolution
[Narrative of how the design evolved — what changed across stages and why]

## Important Roads Not Taken
[Significant alternatives rejected at any stage, grouped by theme, with rationale]
```

No personal names, email addresses, or identifying information throughout.

---

## After completing all three steps

### STEP 4 OF 4: Collect session stats

Write session stats to `<stage_dir>/.metadata.json`. The schema is:

```json
{
  "agents": ["<model-identifier>"],
  "created": "<UTC timestamp ISO 8601 — set once on first write, never overwritten>",
  "last_updated": "<current UTC timestamp ISO 8601>",
  "sessions": 1,
  "input_tokens": null,
  "output_tokens": null,
  "user_word_count": null,
  "lines_added": null,
  "lines_deleted": null,
  "files_changed": null
}
```

All numeric fields are `null` on failure. If `.metadata.json` already exists, sum numeric fields with the new values, append the current agent identifier to `agents` if not already present, increment `sessions`, preserve the existing `created` value, and overwrite `last_updated`.

**If you are running under OpenCode** (i.e. a `get_session_stats` tool is available to you):
- Call the `get_session_stats` tool.
- Use its returned values to populate the fields. Set any field that errored to `null`.
- Merge with any existing `.metadata.json` as described above and write the result.

**If you are running under Claude Code** (i.e. no `get_session_stats` tool is available):
- Write a `.metadata.json` with `agents` set to your model identifier, `last_updated` set to the current UTC timestamp, `sessions` incremented (or 1 if new), and all numeric fields set to `null`.
- The Claude Code Stop hook will overwrite this file at session end with real stats. The file you write now ensures `sessions` and `agents` are not lost if the hook runs before the git add.

---

```bash
git add <stage_dir>/ specs/design-decisions.md
```

- If `auto_commit` is `true`: commit with `git commit -m "<NNN>: Add design decisions"`
- If `auto_commit` is `false`: do NOT commit — stage only, leave the commit to the user.

Tell the user to run `/designlens.new-stage` when ready to start the next stage.
