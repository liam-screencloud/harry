---
name: work
description: Read a Linear issue and implement it in pulse-backend
---

Implement Linear issue $ARGUMENTS:

1. Read the full issue using the Linear MCP tool — title, description, acceptance criteria, and comments
2. Identify which service(s) under `services/` and/or packages under `packages/` need to change
3. **Enter plan mode now** — call the `EnterPlanMode` tool immediately if not already in plan mode. Then explore the relevant code and draft a concrete implementation plan with file paths. Once the plan is written, run `/audit-plan` before exiting plan mode: identify the key assumptions in the plan, verify what you can by reading files directly, then use `AskUserQuestion` to resolve the rest interactively. Update the plan file with the confirmed information before calling ExitPlanMode.
4. **Before writing any code — create the working branch**:
   - If on `main`: create the branch now (`git checkout -b <branch-name>`)
   - If not on `main`: `git checkout main && git pull origin main`, then create the branch
   - Branch name format: `<your-username>/pul-<number>-<short-description>`
5. Implement — applying these standards throughout:
   - **DRY**: if a shape, value, or pattern appears twice, extract it first
   - **Parallelise** independent async operations with `Promise.all`
   - **No redundant DB queries**: pass pre-fetched data down rather than re-querying in the same transaction
   - **Named destructured params** for any function with 2+ related arguments
   - **Handle all lifecycle states**: consider fresh/unpaired/empty entities, not just the happy path
   - **Return values over mutation**: prefer pure functions; document when mutation is chosen for perf
   - **Full data contract**: understand what the caller/consumer reads — don't return empty for relied-upon fields
   - **No unreachable guards**: only add null checks that can actually trigger given the preceding logic
6. Format only the files you changed: `pnpm prettier --write <file1> <file2> ...` — never run `pnpm fmt` globally as it reformats the entire repo
7. Write or update Vitest tests that verify each acceptance criterion
   - Unit tests: `pnpm --filter <service> test:unit`
   - Integration tests: **must be run from inside the service directory** — integration tests resolve path aliases against `dist/`, so build first:
     `cd services/<service> && pnpm build && pnpm run test:integration`
8. **Before pushing — run ci:test from inside the service directory and fix any failures**:
   `cd services/<service> && pnpm run ci:test`
   This runs unit + integration combined. Do not push until this passes. Never skip this step.
9. **Version bump** — determine the bump type from the nature of the changes:

   | Bump | When |
   |------|------|
   | `major` | New, removed, or renamed API endpoints; breaking schema changes (column removed/renamed, type changed) |
   | `minor` | New business logic, new non-breaking fields, behaviour changes that don't break existing callers |
   | `patch` | Bug fixes, internal refactors, test additions, dependency updates with no behaviour change |

   Then for each affected service/package:
   - Run `pnpm --filter <name> version <major|minor|patch> --message "PUL-XXXX: <short reason for bump>"`
   - If multiple services/packages changed, version each one separately with the appropriate bump level — they may differ (e.g. a shared package gets `minor`, the service consuming it gets `patch`)

   Tell the user which modules were bumped, to which version, and why that bump level was chosen.

10. Commit with the issue number in the message (e.g. "PUL-123: description")
11. Ask the user: "Are you happy with the changes?"
    - **Yes → Create PR**: Run the `/pr` skill to create a GitHub pull request, then offer to run `/request-review` to draft a Slack message asking for a review
    - **No → Request changes**: Ask what they'd like changed and go back to step 5
