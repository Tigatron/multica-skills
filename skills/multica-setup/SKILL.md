---
name: multica-setup
description: Install the Multica CLI, authenticate, and bootstrap the local daemon on a fresh machine. Use when the user mentions installing Multica, logging in, switching to a self-hosted server, configuring the server URL, or creating a new profile.
---

# Multica Setup

Bootstrap the `multica` CLI so the rest of the Multica skills can be used. The CLI is one binary that covers authentication, configuration, and the local agent daemon.

Official docs: https://github.com/multica-ai/multica/blob/main/CLI_AND_DAEMON.md

## When to use this skill

- First-time install on a machine.
- User reports `multica: command not found` or `multica auth status` fails.
- Switching between Multica Cloud and a self-hosted server.
- Setting up a second environment (e.g. staging) alongside production via profiles.
- Updating the CLI to a newer version.

## Install

Check first with `command -v multica`. If missing, pick one path:

```bash
# macOS / Linux, Homebrew (preferred)
brew install multica-ai/tap/multica

# macOS / Linux, no Homebrew
curl -fsSL https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.sh | bash

# Windows PowerShell
irm https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.ps1 | iex
```

Self-hosting server on the same machine (requires Docker):

```bash
curl -fsSL https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.sh | bash -s -- --with-server
```

## One-command bootstrap

`multica setup` is now a parent command with two subcommands. It configures the CLI, opens a browser for OAuth, and starts the daemon.

```bash
multica setup cloud                                                # Multica Cloud (multica.ai)
multica setup                                                      # Alias for `setup cloud`

multica setup self-host                                            # Local self-hosted (http://localhost:8080 / :3000)
multica setup self-host --port 9090 --frontend-port 4000
multica setup self-host --server-url https://api.example.com --app-url https://app.example.com
multica setup self-host --server-url https://api.example.com --callback-host runner.example.com
```

`setup self-host` flags:
- `--server-url` — full backend URL (e.g. `https://api.internal.co`)
- `--app-url` — full frontend URL (e.g. `https://app.internal.co`)
- `--port` (default 8080) — backend port when `--server-url` is not set
- `--frontend-port` (default 3000) — frontend port when `--app-url` is not set
- `--callback-host` — host the OAuth callback URL points at; auto-detected when empty. Set this when the machine running the CLI is behind a reverse proxy / different FQDN than what auto-detection picks, so the browser can return the token to the CLI.

After setup, the daemon runs in the background. Verify with `multica daemon status` and `multica auth status`.

## Step-by-step (when `setup` is not enough)

```bash
multica login                                  # Browser OAuth, 90-day token, auto-adds all workspaces
multica login --token                          # Prompt interactively for a personal access token
multica login --token mul_xxxxx                # Inline PAT (visible in shell history — prefer the prompt form)
multica login --callback-host runner.acme.co   # Reverse-proxy / FQDN setups where auto-detection picks the wrong interface
multica daemon start                           # Start background daemon (logs to ~/.multica/daemon.log)
```

## Authentication checks

```bash
multica auth status            # Shows server, user, token validity
multica auth logout            # Removes stored token
```

## Configuration

Config lives in `~/.multica/config.yaml` (default profile) or `~/.multica/profiles/<name>/config.yaml`.

```bash
multica config show
multica config set server_url https://api.example.com
multica config set app_url https://app.example.com
multica config set workspace_id <workspace-id>
```

## Profiles (multiple Multica servers on one machine)

Each profile has its own config, token, daemon state, health port, and workspace root.

```bash
multica setup self-host --profile staging \
  --server-url https://api-staging.example.com \
  --app-url https://staging.example.com

multica daemon start    --profile staging     # Runs in parallel with default
multica daemon restart  --profile staging     # Restart just this profile
multica auth status     --profile staging
```

All other commands accept `--profile <name>` the same way.

## Updating

```bash
multica update                                     # Auto-detects install method
multica update --download-timeout 5m               # Bump the default 2-minute archive download timeout on slow networks
brew upgrade multica-ai/tap/multica                # If installed via Homebrew
multica version                                    # Show current version + commit
```

## Workspace metadata

Admins / owners can edit workspace name, description, context, and issue prefix without leaving the CLI:

```bash
multica workspace update                                          # Acts on the currently-configured workspace
multica workspace update <workspace-id>                           # Explicit target
multica workspace update --name "Backend Team"
multica workspace update --issue-prefix BE                        # Uppercased server-side
multica workspace update --description "Owns the API & data layers"
multica workspace update --description-stdin < readme.md          # Multi-line; preserves literal backslashes
multica workspace update --context-stdin   < context.md           # Same pattern for the workspace context blob
```

`--description` and `--context` decode `\n`, `\r`, `\t`, `\\` in the inline string; pipe the `*-stdin` variant when you want the body verbatim.

## Verification checklist

After any setup flow, confirm all three succeed before handing off to another skill:

```bash
multica auth status                        # "Authenticated as <user>"
multica daemon status                      # "Running" with a PID
multica workspace list                     # At least one workspace
```

`multica login` automatically watches every workspace the user belongs to — there is no per-workspace `watch` toggle in the CLI. If a workspace is missing from the list, the user does not have membership; have it granted server-side and re-run `multica login`.

## Gotchas

- The daemon does **not** run agents; it invokes locally installed agent CLIs (`claude`, `codex`, `gemini`, etc.). At least one of those must be on `PATH` or no runtime is registered.
- `multica login` creates a token tied to the currently configured `server_url`. Changing the server URL invalidates the token — re-run `multica login`.
- On macOS, the first daemon start may trigger a Gatekeeper prompt. Ask the user to approve it in System Settings.
- Tokens expire after 90 days. If commands start returning 401, re-run `multica login`.
