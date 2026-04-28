---
name: request-review
description: Draft a Slack message asking for a PR review, with a short summary and PR link
---

Draft a Slack message requesting a PR review for the current branch:

1. Get the current branch's open PR using `gh pr view --json title,url,body`
2. Read `.claude/skills/request-review/phrases.json` to load the phrase bank, then ask the user to pick a tone using AskUserQuestion with these 4 options (show 2–3 randomly sampled examples from the JSON for each):
   - **Dramatic** — big announcement energy, makes it sound world-changing (`dramatic` array)
   - **Humble beg** — soft and self-deprecating, politely begging for attention (`humble_beg` array)
   - **Fake urgency** — mock-serious, like it’s a crisis (`fake_urgency` array)
   - **Surprise me** — Claude picks something random and creative
3. Use the Slack MCP tool (`slack_send_message_draft`) to draft the message — do NOT send it directly

   - Channel: use `#team-pulse-bkk` by default, unless a different channel is provided as $ARGUMENTS
   - **IMPORTANT**: `#team-pulse-bkk` is a **private** channel. Always search with `channel_types: "public_channel,private_channel"` — the default public-only search will return no results.
   - Write the opener to match the chosen tone — keep it punchy and funny
   - The issue title should be shortened to a few words max (e.g. "isPreviewScreen in GET /screens"), not the full Linear title
   - The summary must be one sentence max — what changed and why, nothing more
   - Links must be plain URLs with no angle brackets or markdown link syntax — just the raw URL on its own line
   - Message structure:

     ```
     <opener matching chosen tone>

     *<issue-id>: <short issue title>*
     <one sentence summary>

     PR: https://github.com/...
     ```

4. Tell the user the message has been drafted and is ready to send
