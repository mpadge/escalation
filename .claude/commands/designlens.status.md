---
description: Show current project status and next action
---

Run `designlens status` and display its output verbatim to the user.

Then enrich the output as follows:

**If any tasks are incomplete:** find the highest-numbered stage directory under `specs/` and read its `tasks.md`. List the titles of every unchecked task (lines matching `- [ ]`), formatted as a brief bulleted list under the heading "Outstanding tasks:".

**If a plan exists:** read the current stage's `plan.md` and check the Open Questions section. If it contains any unresolved items (i.e. not "None" or empty), summarise them under the heading "Open questions:".

**In all cases:** end with a single line suggesting the appropriate next slash command based on the project state — matching the "Next action" shown by `designlens status`. Do not offer to run it.
