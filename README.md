# multica-skills

A set of agent skills that let any AI — Claude Code, Codex, Cursor, OpenCode, Gemini, or anything else that can read Markdown instructions — drive the [Multica](https://github.com/multica-ai/multica) CLI.

Once installed, an AI agent can:

- create and assign issues to Multica agents
- schedule recurring tasks via autopilots and cron
- manage projects, sprints, and epics
- run and diagnose the local agent daemon
- bootstrap a fresh machine end-to-end

All six skills call the official `multica` CLI — nothing is reimplemented, nothing talks to the Multica API directly.

## Skills in this package

| Skill | What it does |
|-------|--------------|
| `multica-setup`     | Install CLI, authenticate, bootstrap daemon, manage profiles |
| `multica-issues`    | Issue CRUD, comments, subscribers, execution runs |
| `multica-agents`    | Discover agents and delegate work |
| `multica-projects`  | Sprint / epic / workstream containers |
| `multica-autopilot` | Scheduled and on-demand recurring agent tasks |
| `multica-daemon`    | Local runtime lifecycle, workspace watch, profiles |

Each skill is a standalone directory under `skills/` containing a single `SKILL.md` file with YAML frontmatter (`name`, `description`) followed by Markdown instructions. This is the [Agent Skills](https://www.anthropic.com/engineering/claude-code-best-practices) format used by Claude Code and compatible with any agent that reads skill files.

## Prerequisites

- The `multica` CLI. If not installed, the `multica-setup` skill walks through it, or run directly:
  ```bash
  brew install multica-ai/tap/multica                                  # macOS / Linux
  irm https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.ps1 | iex   # Windows
  ```
- `jq` is recommended for the `--output json` patterns in the skills, but not required.

## Install

### Claude Code

User-global (available in every project):

```bash
./install.sh                   # copies to ~/.claude/skills/
```

Project-local (only this repo):

```bash
./install.sh --target claude-project   # copies to ./.claude/skills/
```

Manual equivalent:

```bash
mkdir -p ~/.claude/skills
cp -R skills/* ~/.claude/skills/
```

### OpenCode

```bash
./install.sh --target opencode
```

### Cursor / Windsurf / others that read Markdown rules

These agents do not yet have a standard skills loader, but the `SKILL.md` files work fine as rule or instruction files. Point your agent at the `skills/` directory, or concatenate the files into the agent's rules file:

```bash
cat skills/*/SKILL.md > .cursor/rules/multica.md
```

### Codex CLI

Codex reads an `AGENTS.md` at the project root. Either:

```bash
cat skills/*/SKILL.md > AGENTS.md
```

or import the individual files as references from your own `AGENTS.md`.

### Arbitrary directory

```bash
./install.sh --target dir --dir /path/to/your/agent/skills
```

### List what is in this package

```bash
./install.sh --list
```

## Verifying the install

After installing and restarting your agent, try a prompt like:

- "List open Multica issues assigned to Lambda."
- "Create a Multica issue titled 'stabilize flaky login test', priority high, assigned to Lambda."
- "Set up a weekday 9 AM autopilot that triages todo issues."
- "Why isn't the Multica daemon picking up work?"

The agent should invoke the `multica` CLI directly, with behavior informed by the relevant skill.

## Design notes

- **One skill per capability** — keeps each `SKILL.md` small enough that a model can load only what it needs for a given request.
- **Descriptions are the router** — each `description:` line is written as a predicate (when to use me), because that is what agent frameworks match against.
- **Commands are verbatim** — every command shown is what the skill expects an agent to actually run, with the real flags and positional forms from the Multica CLI docs.
- **Gotchas sections** capture the failure modes that burned us when we tested — wrong timezone strings, missing assignees, silent no-runtime, etc.

## Contributing

PRs welcome. The skill content is hand-written against the [Multica CLI and Daemon Guide](https://github.com/multica-ai/multica/blob/main/CLI_AND_DAEMON.md) — when that doc changes, these skills should follow.

Local sanity check:

```bash
for f in skills/*/SKILL.md; do
  head -5 "$f"                       # frontmatter visible
  grep -c '^multica ' "$f" || true   # command count, for rough parity with upstream
done
```

## License

MIT. See [LICENSE](LICENSE).
