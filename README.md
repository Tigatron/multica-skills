# multica-skills

Agent skills that let any AI coding agent — Claude Code, Codex, Cursor, OpenCode, Gemini CLI, and [40+ more](https://github.com/vercel-labs/skills#supported-agents) — drive the [Multica](https://github.com/multica-ai/multica) CLI.

Once installed, an agent can:

- create and assign issues to Multica agents
- schedule recurring tasks via autopilots and cron
- manage projects, sprints, and epics
- run and diagnose the local agent daemon
- bootstrap a fresh machine end-to-end

All six skills call the official `multica` CLI — nothing is reimplemented, nothing talks to the Multica API directly.

## Install

Uses [`npx skills`](https://github.com/vercel-labs/skills) (no global install needed):

```bash
# Interactive — pick which skills go to which agents
npx skills add Tigatron/multica-skills

# Preview what's available, don't install
npx skills add Tigatron/multica-skills --list

# Install everything to everything, non-interactive
npx skills add Tigatron/multica-skills --all

# Install one skill to one agent, globally
npx skills add Tigatron/multica-skills -s multica-issues -a claude-code -g

# All Multica skills to Claude Code only, project-scoped
npx skills add Tigatron/multica-skills --skill '*' -a claude-code
```

Scope flags:

- *(default)* — project-scoped, e.g. `.claude/skills/` in the current repo
- `-g, --global` — user-scoped, e.g. `~/.claude/skills/`

See `npx skills --help` for the full flag reference. Update, remove, and list are all covered:

```bash
npx skills list                  # What's installed?
npx skills update                # Pull the latest version
npx skills remove multica-issues # Uninstall one
```

## Skills in this package

| Skill | What it does |
|-------|--------------|
| `multica-setup`     | Install CLI, authenticate, bootstrap daemon, manage profiles |
| `multica-issues`    | Issue CRUD, comments, subscribers, execution runs |
| `multica-agents`    | Discover agents and delegate work |
| `multica-projects`  | Sprint / epic / workstream containers |
| `multica-autopilot` | Scheduled and on-demand recurring agent tasks |
| `multica-daemon`    | Local runtime lifecycle, workspace watch, profiles |

Each skill is a standalone directory under `skills/` containing a single `SKILL.md` file with YAML frontmatter (`name`, `description`) followed by Markdown instructions — the [Agent Skills](https://github.com/vercel-labs/skills) format.

## Prerequisites

- The `multica` CLI. If not installed, the `multica-setup` skill walks through it, or:
  ```bash
  brew install multica-ai/tap/multica                                                          # macOS / Linux
  irm https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.ps1 | iex     # Windows
  ```
- `jq` is recommended for the `--output json` patterns in the skills, but not required.

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
- **Gotchas sections** capture failure modes — wrong timezone strings, missing assignees, silent no-runtime, etc.

## Contributing

PRs welcome. The skill content is hand-written against the [Multica CLI and Daemon Guide](https://github.com/multica-ai/multica/blob/main/CLI_AND_DAEMON.md) — when that doc changes, these skills should follow.

Local sanity check (no install required):

```bash
for f in skills/*/SKILL.md; do
  head -5 "$f"                       # frontmatter visible
  grep -c '^multica ' "$f" || true   # command count
done
```

To add a new skill, follow the template used by the existing six, or run `npx skills init <name>` and adapt.

## License

MIT. See [LICENSE](LICENSE).
