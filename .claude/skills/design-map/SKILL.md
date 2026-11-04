---
name: design-map
description: Generate, complete or check specs/001-shirley-phase-one/design-map.yml, the list of Shirley UI targets that design review checks. "generate" builds or updates it from the frontend design docs (docs/frontend), Design.md, the UI spec and Figma, and marks unknown values as TBD placeholders; "ask" asks for the placeholder values; "check" lists what is still missing. Use when asked to "create the design map", "update the design map", "what's missing in the design map", after docs/frontend, Design.md or the Figma file changes, or when a design review is blocked by a TBD target.
argument-hint: "[generate | ask | check]"
user-invocable: true
---

# Design map

## Arguments

```text
$ARGUMENTS
```

Read [.agent-instructions/design-review/design-map.md](../../../.agent-instructions/design-review/design-map.md)
in full, and follow it for the mode above (`generate` when empty). It is
shared with GitHub Copilot, which also reads this skill, and with Codex
(`.agents/skills/design-map/`).
