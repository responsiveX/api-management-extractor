---
name: tech-docs-writer
description: Writes and revises Markdown technical documentation for software, such as APIs, libraries, services, architectures, configuration, CLIs, runbooks, and codebases. Use this skill whenever the user asks to document something, write or update docs, a README, a how-to, a reference page, an architecture overview, an onboarding doc, or an internal wiki page, and whenever they ask to "explain how X works" in a form other people will read later. Trigger even when the user does not say the word "documentation". The skill reads the source first. It picks one Diátaxis mode (reference, explanation, how-to, or tutorial), writes in Simplified Technical English (ASD-STE100) with a neutral technical style, and adds Mermaid diagrams only where they clarify structure or flow. For code comments or docstrings, or a shared Claude Doc, use the relevant tool instead.
---

# Technical Documentation Writer

The reader is a developer who must understand an unfamiliar subject fast. The reader does not want to read the source code from start to end. The reader can be new to the team, and English can be their second language. Every rule in this skill serves that reader. When a rule and the reader's need conflict, the reader wins.

The deliverable is one or more Markdown files. The files are accurate to the source, uses one Diátaxis mode, and is written in Simplified Technical English (STE).

## Workflow

### 1. Read the source first

The source is the truth. It can be code, an API spec, a schema, a config file, pasted text, or a URL. Read enough of it to state each fact with confidence. In a repository, look for the subject yourself before you ask the user. Ask a question only when the source cannot answer it, for example the reason for a design decision.

Do not invent behavior. If the source does not specify something that the reader needs, write that down: "The source does not specify behavior on concurrent writes." A guess that looks like a fact is worse than a gap that is marked.

### 2. Set the scope

The request sets the scope. The source usually covers much more. For example, a request for the fields of a manifest file is not a request for the install process. A request about four topics is not a request about ten. Make a list of the questions the reader asked, and write the document to answer those questions.

Related material that the reader does not need now makes the document longer. It also hides the answer. Leave it out. If a reader will probably need it next, write one sentence that points to it. In the reply, list the topics that you left out, so the user can ask for them.

Each section must answer one of the reader's questions. If a section does not, remove it. Length follows from the scope. A short request gets a short document.

### 3. Find existing docs

Look for a document that already covers the subject. Check `docs/`, the README, and any wiki folder. If one exists, update it. Do not create a second document that competes with it. Keep the parts that are still correct, and keep the author's structure unless it mixes Diátaxis modes.

### 4. Pick one Diátaxis mode

Each mode answers a different reader need. A document that mixes modes answers none of them well.

- **Reference.** What something is: endpoints, signatures, config fields, CLI flags, schemas. The reader looks things up. This is the default for "docs for" a module, endpoint, or library.
- **Explanation.** How and why something works. This is the default for architecture, design, or "how X works" at system level.
- **How-to.** The steps to reach one goal that the reader already has, for example "add a migration" or "deploy to staging".
- **Tutorial.** A first success for a newcomer who starts from zero. Use it only when the user asks to teach or to onboard.

If the request is ambiguous, pick the most likely mode and state the choice in one line in your reply. The user can redirect you. If the request needs two modes, write two documents and link them. Read `references/diataxis.md` for the structure of each mode.

### 5. Write in STE and the house style

STE controls the sentence: its length, its verb forms, and its words. The house style controls tone, person, and document shape. Read both before you write:

- `references/simplified-technical-english.md`: sentence and paragraph limits, procedural and descriptive writing, verb forms, one word for one meaning.
- `references/style.md`: tone, person, plain words, words to cut, headings, and punctuation.

The rules that matter most:

- Write procedural sentences of 20 words or fewer. Write descriptive sentences of 25 words or fewer.
- Write one instruction in each step. Use the imperative.
- Use active voice and simple tenses.
- Use one term for one concept, and use it the same way in the whole document.
- Keep the tone neutral. Do not use marketing words, hedges, or rhetorical questions.

Code identifiers, commands, file paths, and product names stay exactly as they are in the source. STE applies to the prose around them.

### 6. Add a diagram only when it clarifies

A diagram is good when prose describes the structure awkwardly. Examples are three or more actors that exchange messages, a state machine, or a dependency graph. A linear flow of A to B to C is one sentence, not a diagram. Read `references/mermaid.md` to select a diagram type.

### 7. Add code examples only when they show something prose cannot

Good examples show exact syntax, a call pattern that is not obvious, or a minimal reproduction. Each example shows one concept. Remove setup that is not related to that concept.

### 8. Check the draft

- **Accuracy.** Make sure that each path, command, identifier, default value, and version in the document exists in the source. Readers copy these values directly. One wrong value costs the reader more time than the document saves.
- **STE limits.** If Python is available, run `python scripts/ste_check.py <file>` from this skill's directory. The script shows sentences over the limit, paragraphs over six sentences, and words to cut. It uses the 20-word limit for list items and the 25-word limit for other text. It skips code blocks and tables. Fix each finding or make sure that it is a false positive. A sentence that contains many identifiers is a frequent false positive.
- **Mode and scope.** Read the headings only. They must show one mode. Each heading must answer a question from the request. A reader who scans them must know what each section contains.

### 9. Save the file

- Write to the location that the user gives. If the user does not give one, ask.
- Give the file a name that describes its subject, for example `order-sync-architecture.md` or `add-a-database-migration.md`.

In the reply, give the path, the mode you picked, the topics you left out, and each gap the source did not fill. Do not paste the document into the chat. The file is the deliverable.

## Output format

- One `.md` file.
- One `# H1` title that names the subject. Add the mode when it helps the reader, for example `# Order Sync Reference`.
- `## H2` to `#### H4` headings. Do not go deeper.
- Code fences with a language hint, and Mermaid in ```` ```mermaid ```` fences.
- No emoji, no exclamation points, and no closing section such as "Conclusion". A reference or explanation document stops when the content stops.

## Reference files

- `references/simplified-technical-english.md`: the STE writing rules, adapted for software documentation.
- `references/style.md`: the house style, with examples of what to do and what not to do.
- `references/diataxis.md`: the structure of each of the four modes.
- `references/mermaid.md`: when to use each Mermaid diagram type, with syntax patterns.
- `scripts/ste_check.py`: a check of sentence and paragraph length and of words to cut.
