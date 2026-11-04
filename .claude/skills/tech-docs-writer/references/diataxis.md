# Diátaxis Mode Guide

Diátaxis separates documentation into four modes based on the reader's need. Pick one mode per document. Mixing modes in a single document confuses the reader.

## Reference

**Reader's need:** lookup of factual information while working.

**Orientation:** describes what something *is*. Complete, accurate, dry.

**Typical structure:**

1. `# H1` — subject and "Reference" label.
2. Short paragraph (2–4 sentences) stating what the subject is and its scope. No history, no motivation.
3. Sections organized by the subject's own structure:
   - For an API: one `## H2` per endpoint or resource.
   - For a library: one `## H2` per public module, then `### H3` per exported function/class.
   - For a config schema: one `## H2` per top-level section, `### H3` per field.
   - For a CLI: one `## H2` per command, `### H3` per flag or subcommand.
4. For each item, document in this order: signature or syntax, parameters, return value or output, errors, one minimal example (only if non-obvious).

**Do:** use tables for parameters (name, type, required, default, description). Use consistent headings across parallel items.

**Don't:** explain *why* the design is this way (that belongs in Explanation). Don't walk through a scenario (that belongs in How-to).

## Explanation

**Reader's need:** understanding of how and why a system works.

**Orientation:** describes the shape of the subject at a conceptual level. Connects pieces. Answers "why is it like this".

**Typical structure:**

1. `# H1` — subject name.
2. Opening section stating what the subject does and the problem it solves. 1–3 paragraphs.
3. `## Architecture` or `## How it works` — the core concepts and how they relate. This is where a Mermaid diagram often earns its place (component diagram, sequence diagram for a core flow).
4. `## H2` sections for each major concept or subsystem. Each section explains the concept, its role, and its relationships to other concepts.
5. Optional `## Design decisions` or `## Trade-offs` — documents why specific choices were made when that context helps a reader reason about the system.

**Do:** use analogies sparingly and only when they genuinely illuminate. Define terms on first use. Connect concepts explicitly ("The scheduler reads from the queue populated by the ingestion worker.").

**Don't:** list every function or field — that is Reference. Don't give step-by-step instructions — that is How-to.

## How-to

**Reader's need:** accomplish a specific goal. The reader already knows what they want.

**Orientation:** task-oriented. Numbered steps in the imperative. The STE procedural rules apply to every step: 20 words or fewer, one instruction, and a condition before the instruction.

**Typical structure:**

1. `# H1` — named by the goal ("How to add a database migration").
2. One-sentence statement of what the guide accomplishes.
3. `## Prerequisites` — required access, tools, or prior knowledge.
4. `## Steps` — numbered list. Each step is one action with enough context to do it. Include the exact command, file change, or UI action. Put a warning before the step that it applies to, not after.
5. `## Verification` — how to confirm the task succeeded.
6. Optional `## Troubleshooting` — common failure modes and their fixes.

**Do:** assume the reader is competent and skip obvious setup. Link to Reference or Explanation documents for background instead of repeating it. When a step has a visible result, state the result so the reader can confirm it before the next step.

**Don't:** teach concepts. Don't offer alternatives inside the main flow — pick one path. Note alternatives in a separate section if they matter.

## Tutorial

**Reader's need:** learn by doing, starting from zero.

**Orientation:** learning-oriented. The reader follows along and ends with something working. Success on first try matters more than completeness.

**Typical structure:**

1. `# H1` — "Getting started with X" or similar.
2. `## What this tutorial builds` — end state, with a screenshot or code snippet of the finished result.
3. `## Prerequisites` — kept minimal; link out for installation rather than including it.
4. Numbered sections, each a small step that produces a visible result. The reader sees something work after each step. Steps follow the STE procedural rules, as in How-to.
5. `## Next steps` — pointers to Reference, Explanation, and How-to documents.

**Do:** err on the side of more hand-holding than How-to. Every code snippet should be copy-pasteable and work as-is.

**Don't:** introduce concepts that are not needed for the tutorial's narrow goal. Don't cover edge cases.

## Picking the mode from a request

| User phrasing | Likely mode |
|---|---|
| "Document the `foo` module" | Reference |
| "Write API docs for the payments service" | Reference |
| "Explain how our event bus works" | Explanation |
| "Write up the architecture of the ingestion pipeline" | Explanation |
| "How do I add a new worker type?" | How-to |
| "Write a guide for deploying to staging" | How-to |
| "Write a tutorial for new hires on using our CLI" | Tutorial |
| "Onboarding doc for the auth system" | Usually Explanation; ask if unclear |
