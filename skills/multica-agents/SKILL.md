---
name: multica-agents
description: Discover, create, update, archive, and assign work to Multica agents. Also covers attaching workspace skills to an agent and inspecting an agent's task history. Use when the user asks which agents exist, who can do X, wants to spin up a new agent, change its model or instructions, or hand a task off to a managed agent.
---

# Multica Agents

An **agent** in Multica is a named teammate backed by a coding-agent CLI (Claude Code, Codex, OpenCode, OpenClaw, Hermes, Gemini, Pi, Cursor Agent, Kimi, Kiro) running on a registered runtime. Agents appear on the board and can be assigned issues exactly like humans.

## When to use this skill

- The user asks "which agents do we have?" or "who can do X?".
- Creating a new agent without leaving the terminal (CLI fully supports it).
- Updating an agent's model, instructions, runtime, or concurrency limit.
- Archiving / restoring agents.
- Assigning workspace skills to an agent (see also the `multica-skills` skill).
- Inspecting an agent's recent tasks.
- Debugging why an assignment did not start (agent exists but no runtime, etc.).

## Discovery

```bash
multica agent list                          # Active agents in the current workspace
multica agent list --include-archived       # Include archived ones
multica agent list --output json

multica agent get <agent-id>                # Full config (model, runtime, instructions, ...)
multica agent get <agent-id> --output json

multica workspace list                      # Which workspace am I in?
multica workspace members <workspace-id>    # Humans + agents together
```

Use `agent list` to validate an `--assignee` value before running `multica issue create` or `multica issue assign`.

## Creating an agent

Pick a runtime first (a machine running `multica daemon` with a detected CLI — see the `multica-daemon` skill, including `multica runtime list`). The runtime ID is required.

```bash
RUNTIME=$(multica runtime list --output json | jq -r '.runtimes[0].id')

multica agent create \
  --name "Lambda" \
  --runtime-id "$RUNTIME" \
  --model "claude-sonnet-4-6" \
  --instructions "Senior backend engineer. Prefer minimal diffs." \
  --description "Backend specialist" \
  --max-concurrent-tasks 4 \
  --visibility workspace
```

Create flags:
- `--name` (required) — the string used as `--assignee` everywhere
- `--runtime-id` (required) — from `multica runtime list`
- `--model` — provider-specific identifier (`claude-sonnet-4-6`, `openai/gpt-4o`, etc.). Prefer this over passing `--model` inside `--custom-args`; some providers (codex app-server, openclaw) reject `--model` in custom args.
- `--instructions` — system prompt prepended to every task
- `--description` — shown on the agent card
- `--max-concurrent-tasks` (default 6) — how many tasks this agent runs in parallel
- `--visibility` — `private` (default, only creator) or `workspace` (everyone)
- `--custom-args` — JSON array of extra CLI args, e.g. `'["--verbose"]'`
- `--runtime-config` — JSON object of runtime overrides

## Updating

```bash
multica agent update <id> --model "claude-opus-4-7"
multica agent update <id> --instructions "Updated system prompt..."
multica agent update <id> --max-concurrent-tasks 8
multica agent update <id> --visibility workspace
multica agent update <id> --runtime-id <new-runtime-id>
multica agent update <id> --status active        # or paused
multica agent update <id> --model ""             # Clear and fall back to runtime default
```

Same flag set as `create`, all optional, plus `--status`. Pass an empty string to `--model` to clear it.

## Archive / restore (the CLI delete pattern)

There is no hard `agent delete`; archive is the way to remove an agent without losing history.

```bash
multica agent archive <id>                       # Hide from default list, stop assignments
multica agent restore <id>                       # Reactivate
multica agent list --include-archived            # See archived agents
```

## Assigning workspace skills to an agent

Workspace skills (created via `multica skill create` — see the `multica-skills` skill) are attached to agents via this subgroup.

```bash
multica agent skills list <agent-id>             # Currently assigned skills
multica agent skills list <agent-id> --output json

multica agent skills set <agent-id> --skill-ids "id1,id2,id3"   # Replace ALL assignments
```

`set` is a *replace* operation, not append. To add one skill without losing the others, read the current list first:

```bash
CURRENT=$(multica agent skills list <agent-id> --output json | jq -r '[.skills[].id] | join(",")')
multica agent skills set <agent-id> --skill-ids "$CURRENT,<new-skill-id>"
```

## Agent task history

```bash
multica agent tasks <id>                         # Tasks this agent has run
multica agent tasks <id> --output json
```

For a specific issue's runs, use `multica issue runs <issue-id>` (see the `multica-issues` skill).

## Delegation pattern (the main workflow)

```bash
# 1. Pick an agent
AGENT=$(multica agent list --output json | jq -r '.agents[0].name')

# 2. File an issue assigned to them
multica issue create \
  --title "Migrate auth middleware to new session store" \
  --description "..." \
  --priority high \
  --assignee "$AGENT"
```

See the `multica-issues` skill for the full issue command reference. See the `multica-autopilot` skill for scheduled / recurring agent dispatch.

## Which agent to pick?

Multica does not expose capability tags directly, so rely on naming conventions, attached skills, and recent history:

```bash
# Past issues this agent has worked on
multica issue list --assignee "<name>" --output json | jq '.issues[] | {id,title,status}'

# Skills attached to this agent
multica agent skills list <agent-id>
```

If the workspace has agents named by role (e.g. "Frontend-Claude", "Backend-Codex"), follow that convention; otherwise default to whichever agent is online (see next section) and let the user refine.

## Is the agent actually reachable?

An agent is only useful if its assigned runtime is online and has the right CLI installed.

```bash
multica runtime list                             # All runtimes the workspace can see
multica runtime ping <runtime-id> --wait         # Active probe
multica daemon status --output json              # On the local machine
```

If the runtime is offline or has no matching CLI, the issue will sit in its status without execution. See the `multica-daemon` skill for runtime diagnostics.

## Gotchas

- `--name` is the source of truth for `--assignee` everywhere — case- and whitespace-sensitive on most deployments. Prefer copying from `multica agent list --output json` over retyping.
- `--runtime-id` is a *runtime*, not a daemon. One daemon process registers one runtime. List them with `multica runtime list`.
- `--model` flag and `--model` inside `--custom-args` are not interchangeable: codex app-server and openclaw reject `--model` in custom args, so always pass models via the dedicated flag.
- Setting `--max-concurrent-tasks` higher than the runtime's `--max-concurrent-tasks` (daemon flag) does nothing — the runtime is the hard ceiling.
- An issue assigned to an archived agent will not run. Check with `multica agent get <id>` if a task is stuck in queue.
- `agent skills set` replaces the entire assignment — running it with one ID will unlink every other skill from that agent.
