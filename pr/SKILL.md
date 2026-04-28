---
name: pr
description: Create a GitHub pull request for the current branch
---

Create a GitHub pull request for the current branch:

1. Run `git status` and `git log main..HEAD` to understand what's been committed
2. Identify the Linear issue number from the commit messages (e.g. PUL-1234)
3. Read the Linear issue using the MCP tool to get the title and description
4. Push the current branch to origin if not already pushed (`git push -u origin <branch>`)
5. Create the PR using `gh pr create` with:
   - Title: `<issue-id>: <issue title>` (e.g. "PUL-1234: Fix something")
   - Body including:
     - A short summary of what was changed and why
     - Link to the Linear issue: `https://linear.app/screencloud/issue/<issue-id>`
     - Test plan: bullet checklist of what was tested
     - `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
   - Base branch: `main`
6. Output the PR URL so the user can open it
