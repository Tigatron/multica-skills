---
name: multica-skills
description: Create, list, update, delete, and import Multica skills, plus manage the files inside each skill. A Multica skill is a reusable prompt/instruction package that can be assigned to agents in the workspace. Use when the user mentions creating a workspace skill, importing one from clawhub.ai or skills.sh, or editing skill files.
---

# Multica Skills

A **skill** in Multica is a named, reusable instruction package (SKILL.md plus optional supporting files) stored in the workspace. Skills are assigned to agents (see `multica agent skills set`) so the agent picks them up the next time it runs.

This is a workspace-level resource managed via the CLI — distinct from the agent skills shipped in this `multica-skills` GitHub repo, which are local files installed via `npx skills`.

## When to use this skill

- The user wants to create a new workspace skill from a prompt / SKILL.md they already have.
- Importing a skill from `clawhub.ai` or `skills.sh` directly into the workspace.
- Listing, updating, or deleting workspace skills.
- Editing the files (SKILL.md, supporting markdown, etc.) inside an existing workspace skill.
- Linking workspace skills to agents (see `multica-agents` skill for the assignment side).

## Core commands

```bash
multica skill list                                  # All workspace skills (table)
multica skill list --output json

multica skill get <skill-id>                        # Includes the file list
multica skill get <skill-id> --output json

multica skill create --name "deploy-runbook" \
  --description "Step-by-step deploy procedure" \
  --content "$(cat SKILL.md)"                       # SKILL.md body
# Optional: --config '<JSON>'                       # Skill config object

multica skill update <skill-id> --name "new-name"
multica skill update <skill-id> --content "$(cat updated.md)"
multica skill update <skill-id> --description "..."

multica skill delete <skill-id>                     # Prompts for confirmation
multica skill delete <skill-id> --yes               # Skip prompt

multica skill import --url https://clawhub.ai/skills/<id>
multica skill import --url https://skills.sh/<slug>
```

`multica skill import` only accepts URLs from `clawhub.ai` or `skills.sh`. Other URLs are rejected.

## Skill files

A skill is more than just `--content`: it can have multiple files (extra markdown, scripts, config snippets). Use the `files` subgroup to manage them.

```bash
multica skill files list <skill-id>                 # All files in the skill
multica skill files list <skill-id> --output json

multica skill files upsert <skill-id> \
  --path "examples/run.sh" \
  --content "$(cat run.sh)"                         # Create or replace one file

multica skill files delete <skill-id> <file-id>
```

`upsert` is path-keyed — calling it twice with the same `--path` overwrites the prior content. There is no separate "create" vs "update" command.

## Common flows

**Bootstrap a new workspace skill from a local SKILL.md and supporting file:**

```bash
SKILL=$(multica skill create \
  --name "deploy-runbook" \
  --description "Production deploy procedure" \
  --content "$(cat SKILL.md)" \
  --output json | jq -r '.skill.id')

multica skill files upsert "$SKILL" --path "rollback.md"  --content "$(cat rollback.md)"
multica skill files upsert "$SKILL" --path "scripts/preflight.sh" --content "$(cat preflight.sh)"
```

**Pull a skill from the public registry, then assign to an agent:**

```bash
SKILL=$(multica skill import --url "https://clawhub.ai/skills/triage" \
  --output json | jq -r '.skill.id')

AGENT=<agent-id>
multica agent skills set "$AGENT" --skill-ids "$SKILL"
```

`multica agent skills set` replaces the *entire* skill assignment for the agent — pass every skill ID you want, comma-separated. See the `multica-agents` skill for the assignment side.

**Sync a local skill directory into a workspace skill:**

```bash
SKILL=<skill-id>
for f in $(find . -type f -name '*.md'); do
  multica skill files upsert "$SKILL" --path "$f" --content "$(cat "$f")"
done
```

## Gotchas

- `--content` for `skill create` / `update` and `--content` for `skill files upsert` both expect raw string content, not file paths. Use `"$(cat file.md)"` to inline a file. Very large content may hit shell argv limits — split into multiple `files upsert` calls if needed.
- `skill import` is restricted to `clawhub.ai` and `skills.sh` hosts; arbitrary URLs are rejected by the server.
- `agent skills set` is *replace*, not *append* — listing only one ID will unassign every other skill currently on that agent. Read the current set with `multica agent skills list <agent-id> --output json` first if you only want to add.
- `skill files upsert --path` is the file's logical path inside the skill, not a local filesystem path. Forward slashes are fine; the path is opaque to the server.
- A workspace skill is independent of the `multica-skills` GitHub repo — the latter installs *agent* skill files locally via `npx skills`, while the former lives on the Multica server and is delivered to agents at run time.
