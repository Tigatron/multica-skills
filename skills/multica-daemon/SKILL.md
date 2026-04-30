---
name: multica-daemon
description: Run and diagnose the local Multica agent daemon and inspect agent runtimes. Covers daemon start/stop/restart/logs, daemon tuning, profiles, plus the multica runtime commands (list, ping, update, usage, activity) for cross-machine runtime visibility. Use when the user mentions the daemon, a runtime, an agent that is not picking up work, token usage on a runtime, or wants to remotely upgrade a runtime CLI.
---

# Multica Daemon & Runtimes

The **daemon** is the local agent runtime. It auto-detects installed coding-agent CLIs (`claude`, `codex`, `opencode`, `openclaw`, `hermes`, `gemini`, `pi`, `cursor-agent`, `kimi`, `kiro`), registers each one as a runtime against the Multica server, polls for claimed tasks, and streams results back.

A **runtime** is the server-side record of a daemon's registration. The `multica runtime *` commands inspect and control all runtimes in the workspace, not just the local one.

Official docs: https://github.com/multica-ai/multica/blob/main/CLI_AND_DAEMON.md#agent-daemon

## When to use this skill

- User reports an assigned agent is not picking up work.
- Starting / stopping / restarting the daemon.
- Tailing daemon logs to debug a stuck task.
- Tuning poll / heartbeat / concurrency limits.
- Running two daemons side by side via profiles (e.g. prod + staging).
- Inspecting all runtimes registered in the workspace, not just this machine.
- Pinging a remote runtime to see if it is alive.
- Triggering a CLI upgrade on a runtime remotely.
- Pulling token usage or hourly activity for a runtime.

## Quick health check

Run these together. If any fails, the daemon is effectively down for that capability:

```bash
multica daemon status --output json     # Is the local daemon running?
multica runtime list                    # Which runtimes does the workspace see?
command -v claude codex gemini 2>/dev/null   # At least one agent CLI on PATH?
```

If the daemon is running but `multica daemon status --output json` reports no detected agents, install at least one agent CLI — the daemon has no runtime to offer.

## Daemon lifecycle

```bash
multica daemon start                  # Background, logs to ~/.multica/daemon.log
multica daemon start --foreground     # Foreground (debugging, blocks terminal)
multica daemon restart                # stop + start in one shot (preserves flags)
multica daemon stop
multica daemon status
multica daemon status --output json
```

Logs:

```bash
multica daemon logs                   # Last 50 lines
multica daemon logs -n 200            # Last 200
multica daemon logs -f                # Follow (tail -f)
```

## Daemon tuning

All settings can be flags on `daemon start` / `daemon restart` or environment variables.

| Setting | Flag | Env var | Default |
|---|---|---|---|
| Poll interval | `--poll-interval` | `MULTICA_DAEMON_POLL_INTERVAL` | `3s` |
| Heartbeat | `--heartbeat-interval` | `MULTICA_DAEMON_HEARTBEAT_INTERVAL` | `15s` |
| Agent timeout | `--agent-timeout` | `MULTICA_AGENT_TIMEOUT` | `2h` |
| Max concurrent tasks | `--max-concurrent-tasks` | `MULTICA_DAEMON_MAX_CONCURRENT_TASKS` | `20` |
| Daemon ID | `--daemon-id` | `MULTICA_DAEMON_ID` | hostname |
| Device name | `--device-name` | `MULTICA_DAEMON_DEVICE_NAME` | hostname |
| Runtime name | `--runtime-name` | `MULTICA_AGENT_RUNTIME_NAME` | `Local Agent` |
| Workspaces root | — | `MULTICA_WORKSPACES_ROOT` | `~/multica_workspaces` |

Agent-specific overrides (point at a non-default binary or model):

```bash
export MULTICA_CLAUDE_PATH=/opt/homebrew/bin/claude
export MULTICA_CLAUDE_MODEL=claude-opus-4-7
export MULTICA_CODEX_PATH=/usr/local/bin/codex
export MULTICA_CODEX_MODEL=gpt-5.1
# Also available: OPENCODE, OPENCLAW, HERMES, GEMINI, PI, CURSOR, KIMI, KIRO
```

After changing env vars, run `multica daemon restart` to pick them up.

## Profiles (multiple daemons on one machine)

Each profile gets its own config dir, token, daemon state, health port, and workspace root.

```bash
multica daemon start    --profile staging
multica daemon status   --profile staging
multica daemon logs -f  --profile staging
multica daemon restart  --profile staging
multica daemon stop     --profile staging
```

Default profile and named profiles run independently and do not share task queues.

## Workspaces the daemon serves

`multica login` automatically watches every workspace the user belongs to — there is no per-workspace `watch` / `unwatch` toggle in the CLI today. The daemon will pick up tasks for any workspace the authenticated token has access to.

```bash
multica workspace list                      # Workspaces this token can see
multica workspace get     <workspace-id>
multica workspace members <workspace-id>    # Humans + agents in this workspace
```

To stop the daemon from serving a workspace, either remove the user's membership server-side or run a separate `--profile` whose `multica login` is scoped to a different account.

## `multica runtime` — workspace-wide runtime control

Where `multica daemon` is local-only, `multica runtime` works across every runtime the workspace can see.

```bash
multica runtime list                                    # Every runtime, with status (table)
multica runtime list --output json

multica runtime ping <runtime-id>                       # Send a ping; returns immediately
multica runtime ping <runtime-id> --wait                # Poll until the ping completes

multica runtime update <runtime-id> --target-version 0.2.14   # Initiate CLI upgrade
multica runtime update <runtime-id> --target-version 0.2.14 --wait

multica runtime usage    <runtime-id>                   # Token usage, last 90 days
multica runtime usage    <runtime-id> --days 30         # Custom window (max 365)
multica runtime activity <runtime-id>                   # Hourly task activity
```

Use cases:
- Diagnosing which runtimes can host a given agent before assigning work.
- Checking whether a remote teammate's runtime is up before paging them.
- Bumping every runtime to a new CLI version after a release.
- Pulling token consumption for a specific runtime over a billing window.

## `multica repo checkout`

```bash
multica repo checkout <git-url>
```

Creates a git worktree from the daemon's bare clone cache. Used internally by agents to check out repos on demand without re-cloning each task. Most users never call this directly; mention it only if a user is debugging unexpected disk usage under `MULTICA_WORKSPACES_ROOT`.

## Diagnosing "my agent isn't picking up work"

Walk this checklist in order — each step rules out a layer:

1. `multica auth status` — token valid?
2. `multica daemon status` — daemon running on the agent's runtime host? Note its PID.
3. `multica daemon status --output json` — is the agent's provider detected on this machine?
4. `multica runtime ping <runtime-id> --wait` — is the runtime answering?
5. `multica agent get <id> --output json` — agent active (not archived) and pointing at the expected runtime?
6. `multica issue get <id> --output json | jq '{status, assignee_id}'` — correctly assigned?
7. `multica issue runs <id>` — any attempted runs? Inspect with `multica issue run-messages`.
8. `multica daemon logs -n 200` — any errors around the time the issue was created?

One of those steps will show the break. If all pass and work still stalls, the daemon may have hit `--max-concurrent-tasks`; bump it (or the agent's `--max-concurrent-tasks`) and `multica daemon restart`.

## Gotchas

- `multica daemon stop` sends SIGTERM; the daemon finishes in-flight tasks before exiting. Allow up to `--agent-timeout` on shutdown.
- The daemon writes workspace checkouts under `MULTICA_WORKSPACES_ROOT`. Large runs can consume disk — clean old workspace dirs periodically.
- Running as a launchd / systemd service? Make sure the unit inherits `PATH` so agent CLIs in `/opt/homebrew/bin` or `~/.local/bin` are discoverable.
- After changing `server_url` via `multica config set`, the daemon must be restarted (`multica daemon restart`) to pick up the new endpoint.
- Two daemons on the same profile will conflict over the PID file. Use `--profile` if you really need two on one host.
- `multica runtime update` only initiates the upgrade — pass `--wait` if you need to know when it actually finishes. Without `--wait` the command returns immediately and the upgrade runs asynchronously on the runtime.
