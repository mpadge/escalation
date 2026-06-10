---
description: Show designlens commands and workflow
---

Display the following:

---

**designlens** — Design history and architectural decision tracking

### Slash commands

| Command | Description |
|---|---|
| `/designlens.new-stage` | Gather requirements and create a new stage |
| `/designlens.make-tasks` | Generate tasks.md from the current plan.md |
| `/designlens.implement` | Implement all tasks in the current tasks.md |
| `/designlens.retrospective` | Generate transcript and design decisions |
| `/designlens.status` | Show current project status and next action |
| `/designlens.help` | Show this help |

### Shell commands

| Command | Description |
|---|---|
| `designlens init` | Initialize a project (run once) |
| `designlens new-stage "<desc>" "<slug>"` | Create the next stage directory and plan.md |
| `designlens status` | Show current project state |
| `designlens config show` | View current configuration |
| `designlens config set <key> <value>` | Set a configuration value |
| `designlens update` | Update to latest version |
| `designlens uninstall` | Uninstall from system |

### Typical workflow

1. `designlens init` — once per project
2. `/designlens.new-stage` — design and plan a stage
3. `/designlens.make-tasks` — break the plan into tasks
4. `/designlens.implement` — execute the tasks
5. `/designlens.retrospective` — capture decisions and update the design history
6. Repeat from step 2

### Configuration (`.designlens.json`)

- `auto_commit` — if `true`, automatically commit specs after implementation and retrospective
- `agent` — which agent is in use (`claude` or `opencode`)
- `commands_path` — where the slash command files are installed
