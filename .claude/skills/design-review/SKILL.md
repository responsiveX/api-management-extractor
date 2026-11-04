---
name: design-review
description: Review the rendered Shirley UI against Figma, the frontend design docs (docs/frontend), Design.md and the Operator Dashboard screenshots, then fix the findings until the targets pass. Use after implementing or changing any widget, design-token or knowledge management app UI, when asked to "check the UI against the design", "compare with Figma", "does this match the design", or "design review". Runs as the after_implement hook of /speckit-implement. Pass "refresh" to export the Figma references again, or target IDs from the design map to review only those.
argument-hint: "[refresh] [target-id ...]"
user-invocable: true
---

# Design review

## Arguments

```text
$ARGUMENTS
```

Read [.agent-instructions/design-review/review-and-fix.md](../../../.agent-instructions/design-review/review-and-fix.md)
in full, and follow it with the arguments above. It is shared with
GitHub Copilot, which also reads this skill, and with Codex
(`.agents/skills/design-review/`).
