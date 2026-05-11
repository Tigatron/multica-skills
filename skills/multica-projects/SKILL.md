---
name: multica-projects
description: Create and manage Multica projects — containers that group related issues (sprints, epics, workstreams). Covers project CRUD, status transitions, and attaching issues. Use when the user mentions a sprint, epic, project, or wants to group / filter issues by a larger initiative.
---

# Multica Projects

A **project** groups related issues (sprint, epic, workstream). Every project belongs to a workspace and can optionally have a lead (a human member or an agent).

Official docs: https://github.com/multica-ai/multica/blob/main/CLI_AND_DAEMON.md#projects

## When to use this skill

- The user wants to start a new sprint, epic, or initiative.
- Filtering the board by a container larger than a single issue.
- Assigning a lead (human or agent) responsible for a body of work.
- Attaching github_repo (or other) resources so agents working on the project can find the code.
- Closing out / archiving a completed sprint.

## Core commands

```bash
multica project list
multica project list --status in_progress
multica project list --output json

multica project get <id>
multica project get <id> --output json

multica project create --title "2026 Week 16 Sprint" --icon "S" --lead "Lambda"
multica project create --title "Auth rewrite" --repo https://github.com/acme/api --repo https://github.com/acme/web   # Attach repos inline
multica project update <id> --title "New title" --status in_progress
multica project update <id> --lead "Lambda"

multica project list --full-id                              # Show full UUIDs in table output
multica project status <id> in_progress
multica project delete <id>
```

Create flags: `--title` (required), `--description`, `--status`, `--icon`, `--lead`, `--repo` (repeatable; shortcut for adding a github_repo resource by URL).
Update flags: same set minus `--repo`. To attach / detach resources after creation, use `multica project resource` (below).
Valid statuses: `planned`, `in_progress`, `paused`, `completed`, `cancelled`.

`--lead` takes a name or UUID (same resolution rules as `--assignee` on issues).

## Project resources

A **resource** is something an agent needs to do the work — most commonly a github_repo, but other types (e.g. `notion_page`) exist. Resources attached to a project are visible to any agent assigned an issue in the project.

```bash
multica project resource list   <project-id>
multica project resource list   <project-id> --output json
multica project resource list   <project-id> --full-id

# Most common: attach a github_repo by URL
multica project resource add    <project-id> --type github_repo --url https://github.com/acme/api
multica project resource add    <project-id> --type github_repo --url https://github.com/acme/api --default-branch-hint develop
multica project resource add    <project-id> --type github_repo --url https://github.com/acme/api --label "Backend API"

# Other types: pass a generic JSON payload via --ref
multica project resource add    <project-id> --type notion_page --ref '{"page_id":"abc123"}'

multica project resource remove <project-id> <resource-id>
```

`--type` defaults to `github_repo`; `--url` and `--default-branch-hint` are shortcuts that only apply to that type. For other resource types pass the full payload via `--ref` (a JSON object describing the resource); `--ref` overrides the per-type shortcuts when set.

## Attaching issues to projects

Projects are associated via the `--project` flag on issue commands — there is no separate `project add-issue` command.

```bash
# New issue in a project
multica issue create --title "Login bug" --project <project-id>

# Move an existing issue
multica issue update <issue-id> --project <project-id>

# Filter issues by project
multica issue list --project <project-id>
multica issue list --project <project-id> --status in_progress --output json
```

## Common flows

**Spin up a weekly sprint and pre-populate it:**

```bash
PROJECT=$(multica project create \
  --title "2026-W17 Sprint" --icon "S" --lead "Lambda" \
  --output json | jq -r '.project.id')

multica issue create --title "Ship search redesign" --project "$PROJECT" --assignee "Lambda"
multica issue create --title "Audit auth middleware"  --project "$PROJECT" --assignee "Codex"
```

**Close out a sprint and reassign stragglers to the next one:**

```bash
OLD=<old-project-id>; NEW=<new-project-id>

# Move anything still open
multica issue list --project "$OLD" --output json |
  jq -r '.issues[] | select(.status != "done" and .status != "cancelled") | .id' |
  xargs -I {} multica issue update {} --project "$NEW"

multica project status "$OLD" completed
```

## Gotchas

- Deleting a project does **not** delete its issues — they just become project-less. Confirm intent before calling `project delete`.
- `--icon` is documented as an emoji in the CLI help; short glyphs / single characters also render acceptably in most clients.
- A project lead is informational (shown on the project card) and does not auto-assign issues to that lead.
