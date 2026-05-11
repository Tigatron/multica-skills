---
name: multica-issues
description: Create, query, update, assign, and discuss Multica issues. Also covers comments, subscribers, and viewing execution runs for an issue. Use when the user wants to file a task for an agent, triage the board, comment on an issue, or inspect what an agent actually did.
---

# Multica Issues

An **issue** in Multica is a unit of work. Agents pick up issues the same way a human teammate would — assignment, comments, status transitions, execution history.

Official docs: https://github.com/multica-ai/multica/blob/main/CLI_AND_DAEMON.md#issues

## Prerequisites

- `multica auth status` must succeed (see the `multica-setup` skill).
- The user's workspace must be set. Check with `multica config show`; set with `multica config set workspace_id <id>` or `multica workspace list` to pick one.

## When to use this skill

- Creating a task for an agent (the core "assign work" workflow).
- Listing or filtering the board.
- Updating status, priority, or title.
- Reading / writing comments on an issue (with file attachments).
- Subscribing someone to issue notifications.
- Attaching or removing labels on an issue (and managing the workspace's label catalog).
- Inspecting what an agent did — execution runs and message logs.
- Re-running a stuck or failed task without re-creating the issue.
- Searching issues by free-text query.

## Core commands

```bash
multica issue list                                         # Default 50 results
multica issue list --status in_progress
multica issue list --priority urgent --assignee "Lambda"   # Filter by name (fuzzy)
multica issue list --assignee-id <uuid>                    # Filter by UUID
multica issue list --project <project-id> --limit 20
multica issue list --limit 100 --offset 100                # Pagination
multica issue list --full-id                               # Show full UUIDs in table output
multica issue list --output json                           # For programmatic parsing

multica issue get <id>
multica issue get <id> --output json

multica issue search "auth middleware"                     # Full-text on title + description
multica issue search "flaky test" --include-closed --limit 50
```

Valid `--status` values: `backlog`, `todo`, `in_progress`, `in_review`, `done`, `blocked`, `cancelled`.
Valid `--priority` values: `no_priority`, `low`, `medium`, `high`, `urgent` (case may vary — check `multica issue get <id> --output json` for canonical values in-workspace).

## Creating an issue (assigning work to an agent)

This is the main workflow for AI-to-AI delegation. A created + assigned issue is automatically picked up by the target agent's runtime.

```bash
multica issue create \
  --title "Fix flaky login test" \
  --description "The e2e login test fails ~10% of the time on CI. Investigate and stabilize." \
  --priority high \
  --assignee "Lambda" \
  --project <project-id> \
  --attachment ./screenshot.png \
  --attachment ./failing-trace.log
```

Flags: `--title` (required), `--description`, `--description-stdin`, `--status`, `--priority`, `--assignee` (name) / `--assignee-id` (UUID), `--parent` (sub-issue), `--project`, `--due-date` (RFC3339), `--attachment` (repeatable, file path).

Tips:
- `--assignee` is a fuzzy name match; `--assignee-id` takes the UUID and is mutually exclusive with `--assignee`. Use `multica agent list` / `multica workspace members <ws-id>` to discover both.
- Put clear acceptance criteria in `--description`. The agent receives it verbatim as task input.
- `--description` decodes `\n`, `\r`, `\t`, `\\` in the passed string. For long bodies, or to preserve literal backslashes, use `--description-stdin < body.md` instead — same applies to comment `--content` / `--content-stdin` and workspace update's `--description` / `--context` family.
- `--attachment` can be passed multiple times; each value is a local file path uploaded with the issue.
- An issue has at most one parent (`parent_issue_id` is single-valued server-side). To build a tree, call `create --parent <parent-id>` once per child.
- To create many issues, loop over lines and pipe through `--output json` to capture the returned IDs.

## Updating

```bash
multica issue update <id> --title "New title" --priority urgent
multica issue update <id> --description "Revised scope..."
multica issue update <id> --description-stdin < revised.md  # Long / multi-line body from a file
multica issue update <id> --assignee-id <uuid>             # UUID variant of --assignee
multica issue update <id> --project <project-id>           # Re-attach to a project
multica issue update <id> --parent <parent-issue-id>       # Make this a sub-issue
multica issue update <id> --parent ""                      # Clear parent (back to top-level)

multica issue status <id> in_progress                      # Fast status transition
multica issue assign <id> --to "Lambda"                    # (Re)assign by name (fuzzy match)
multica issue assign <id> --to-id <uuid>                   # (Re)assign by UUID
multica issue assign <id> --unassign                       # Clear assignee

multica issue rerun <id>                                   # Re-enqueue the current assignee as a fresh task
```

`rerun` keeps the existing assignee and description but creates a new run — useful when a task crashed or the agent needs another attempt without re-filing the issue.

## Comments

Agents post comments as they work — progress updates, blockers, questions. Humans reply back.

```bash
multica issue comment list <issue-id>
multica issue comment list <issue-id> --since 2026-05-01T00:00:00Z   # Incremental poll by RFC3339 timestamp
multica issue comment add  <issue-id> --content "Looks good, merging now"
multica issue comment add  <issue-id> --parent <comment-id> --content "Thanks!"
multica issue comment add  <issue-id> --attachment ./diff.patch --content "See attached"
multica issue comment add  <issue-id> --content-stdin < notes.md     # Avoid shell escaping for long content
multica issue comment delete <comment-id>
```

`--attachment` is repeatable; `--content-stdin` is mutually exclusive with `--content` (use one or the other). `--content` decodes `\n`, `\r`, `\t`, `\\` in the passed string; pipe via `--content-stdin` to preserve literal backslashes.

## Subscribers (notification routing)

```bash
multica issue subscriber list   <issue-id>
multica issue subscriber add    <issue-id>                       # Subscribe caller
multica issue subscriber add    <issue-id> --user "Lambda"       # Subscribe someone else by name (fuzzy)
multica issue subscriber add    <issue-id> --user-id <uuid>      # Subscribe by UUID (mutually exclusive with --user)
multica issue subscriber remove <issue-id>
multica issue subscriber remove <issue-id> --user "Lambda"
multica issue subscriber remove <issue-id> --user-id <uuid>
```

## Labels

Labels are a workspace-wide tagging catalog. The `multica label` group manages the catalog itself; `multica issue label` attaches them to a specific issue.

```bash
# Manage the workspace catalog
multica label list
multica label list --output json
multica label get <label-id>
multica label create --name "regression" --color "#e11d48"     # Hex color required
multica label update <label-id> --name "regression-p1"
multica label update <label-id> --color "#7c3aed"
multica label delete <label-id>

# Attach / detach on a specific issue
multica issue label list   <issue-id>
multica issue label add    <issue-id> <label-id>
multica issue label remove <issue-id> <label-id>
```

`--color` is a hex string like `#3b82f6` and is required on `label create`. To attach more than one label, call `issue label add` once per label — there is no comma-separated batch flag.

## Execution history — what did the agent actually do?

Every agent run for an issue is recorded. Use this when diagnosing why an agent finished, failed, or got stuck.

```bash
multica issue runs <issue-id>                              # List all runs for the issue
multica issue runs <issue-id> --output json                # Machine-readable

multica issue run-messages <task-id>                       # Full message log (tools, thinking, output)
multica issue run-messages <task-id> --output json
multica issue run-messages <task-id> --since 42            # Incremental: messages after seq 42
multica issue run-messages <short-task-id> --issue <issue-id>   # Scope short task-id prefix lookup to one issue
```

Poll pattern (tail an in-progress run):

```bash
# Bash loop; bump --since based on the max seq from the previous response
LAST=0
while true; do
  NEW=$(multica issue run-messages "$TASK_ID" --since "$LAST" --output json)
  LAST=$(echo "$NEW" | jq '[.messages[].seq] | max // '"$LAST")
  echo "$NEW" | jq -r '.messages[] | "[\(.type)] \(.content // .text // "")"'
  sleep 3
done
```

## Downloading attachments

Attachments uploaded with `issue create --attachment` or `issue comment add --attachment` can be pulled back with:

```bash
multica attachment download <attachment-id>                # To current directory
multica attachment download <attachment-id> -o /tmp/files  # To a chosen directory
```

Attachment IDs come from `multica issue get <id> --output json` (look under attachments / comments).

## Common flows

**Triage todo queue and raise priority on anything blocked:**

```bash
multica issue list --status blocked --output json |
  jq -r '.issues[].id' |
  xargs -I {} multica issue update {} --priority urgent
```

**Find runs for a given issue, pull messages from the most recent:**

```bash
ISSUE=<issue-id>
LATEST=$(multica issue runs "$ISSUE" --output json | jq -r '.runs[0].id')
multica issue run-messages "$LATEST"
```

## Gotchas

- `--assignee "Lambda"` must match a name that exists in the workspace, case-sensitive on some deployments. If a create fails with "assignee not found", run `multica agent list` first.
- An issue can be assigned to a human member instead of an agent — they look identical to the CLI; members will not auto-execute.
- `multica issue status` uses a positional value (`multica issue status <id> in_progress`), not a flag.
- `--parent <issue-id>` creates a sub-issue relationship; it is *not* the same as `--project`. Each issue has at most one parent — there is no API for multiple parents or "linked issues".
- `status done` does not prevent future edits; the issue can be reopened by transitioning back to `todo` or `in_progress`.
- `multica issue search` only matches title and description; it does not look inside comments. By default closed issues are excluded — pass `--include-closed` to see them.
- `multica issue rerun` will silently no-op if the issue has no assignee — assign first, then rerun.
- An issue created with `--status backlog` (or transitioned to `backlog` later) is **not** enqueued for execution, even with an assignee set. Backlog acts as a parking state — runtimes only claim issues in `todo` / `in_progress`. To stage work without auto-starting, use `--status backlog`, then `multica issue status <id> todo` when ready. This is the cleanest way to pre-create a downstream task that another agent will release at the end of its run.
- Mutating commands print a human-readable confirmation line before the JSON body (e.g. `multica issue assign` emits `Issue <id> assigned to <name>.\n{...json...}` even with `--output json`). Piping straight into `jq` errors out — drop the first line first (`tail -n +2`) or re-fetch with `multica issue get <id> --output json` for a clean parse.
- There is no `multica issue delete`. Soft-delete / archive is tracked upstream as a feature request; today the closest is `multica issue status <id> cancelled`.
