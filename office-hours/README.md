# /office-hours

Project-local Claude Code skill that runs two review workflows back-to-back on a schedule:

1. **`/auto-review`** — reviews other people's open PRs in `screencloud/pulse-backend`.
2. **`/address-comments`** — finds unresolved review comments on your own open PRs and auto-applies the mechanical ones (commits + pushes).

Designed to run on a loop inside a foreground Claude Code session, so your review workload is handled passively without disappearing into a background process.

## Prerequisites

- `gh` CLI, authenticated (`gh auth status`)
- `jq`
- `claude` CLI available on `PATH`
- Working tree is clean on the branches you care about (the skill aborts per-PR if not — never force-touches dirty state)

## One-time setup

```bash
bash .claude/skills/office-hours/setup.sh
```

What it does:
- `chmod +x` on `schedule.sh`
- Warns if `gh` / `jq` are missing
- Warns if `gh` isn't authenticated
- Prints the start/stop/tail commands

Re-run only if you change machines or `schedule.sh` loses its execute bit.

## Run it

### Option 1 — foreground loop (recommended)

```bash
./.claude/skills/office-hours/schedule.sh -i 30m
```

Runs in your terminal. Output streams live, Ctrl+C stops it. Internally this spawns a single `claude --dangerously-skip-permissions` process that executes `/loop 30m /office-hours` — so `/address-comments` can commit and push without approval prompts (see [Safety](#safety)). Other intervals: `-i 15m`, `-i 1h`, `-i 2h`.

### Option 2 — `/loop` inline in an existing Claude Code session

Start Claude from the terminal with bypass permissions, then run the loop:

```bash
claude --dangerously-skip-permissions
```

Inside the session:

```
/loop 30m /office-hours
```

Functionally the same as Option 1; just lets you interrupt with a message instead of Ctrl+C.

### Option 3 — one-shot

Inside any Claude Code session in this repo:

```
/office-hours
```

Runs once. Useful for manual triggers or dry runs.

### Option 4 — detached background (not recommended)

If you really want fire-and-forget that survives closing the terminal, add `-b`:

```bash
./.claude/skills/office-hours/schedule.sh -i 30m -b
```

- Logs: `tail -f ~/.claude/office-hours.log`
- Stop: `kill $(cat ~/.claude/office-hours.pid)`

Downsides: you can't see what it's doing in real time, and you have to remember it's running.

## What each skill does

### `/auto-review`
- Lists open PRs in `screencloud/pulse-backend`
- Filters out drafts, your own PRs, chore/release/bump titles
- Skips PRs you've already reviewed at the current head SHA
- Runs `/review` on each qualifying PR — leaves inline comments, approves or requests changes

### `/address-comments`
- Lists your open non-draft PRs
- Fetches unresolved, non-outdated review threads (GraphQL)
- Keeps threads where the last comment isn't yours and was posted after your current head SHA
- Per PR: checks clean tree, checks out the branch with `gh pr checkout`, applies mechanical fixes, commits (`PUL-XXXX: address review comments`), pushes, replies with the short SHA
- Non-mechanical threads get a "flagging for manual follow-up" reply instead
- Restores your starting branch via `trap` on every exit path

"Mechanical" means: renames, DRY extractions, null checks, `Promise.all`, positional→named params, unreachable guards, redundant DB queries, verbatim GitHub `suggestion` blocks, typos, missing test cases, Vitest vs Jest, ESM `.js` imports, `@screencloud/shared/db`. Anything architectural, question-shaped, or needing external context (Linear / Figma / Notion) is flagged, not applied.

## Safety

`/address-comments` commits and pushes to your PR branches without asking. That's by design — a loop that prompts on every action isn't a loop. The guardrails that matter live in the skill itself, not in Claude's permission gate:

- Working tree must be clean (skips the PR otherwise, never stashes)
- No unpushed commits on touched branches (skips otherwise)
- Origin must be `screencloud/pulse-backend`
- `trap` restores your starting branch on error, success, or interruption
- Classification is conservative — when in doubt, it flags rather than applies
- Every push fires a macOS notification; everything is visible on GitHub

Tightening the scope later means editing the classification rules in `SKILL.md`, not adding permission prompts.

## Files

```
.claude/skills/office-hours/
├── README.md         # this file
├── SKILL.md          # orchestrator — runs /auto-review then /address-comments
├── schedule.sh       # loop runner (wraps claude --dangerously-skip-permissions)
└── setup.sh          # idempotent one-time setup

.claude/skills/address-comments/
└── SKILL.md          # the comment-handling skill

.claude/skills/auto-review/
├── SKILL.md          # pre-existing
└── schedule.sh       # pre-existing
```
