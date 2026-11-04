#!/usr/bin/env python3
"""Flag prose in a Markdown file that breaks the measurable STE limits.

Checks sentence length (20 words in steps and list items, 25 in paragraphs),
paragraph length (6 sentences), and words the house style cuts. Code, tables,
headings, and Mermaid blocks are skipped. The output is a list of candidates to
review, not a verdict: an identifier-heavy sentence can pass the rules and
still show up here.

Usage: python ste_check.py <file.md> [--json]
"""

import json
import re
import sys

PROCEDURAL_LIMIT = 20
DESCRIPTIVE_LIMIT = 25
PARAGRAPH_LIMIT = 6

CUT_WORDS = [
    "simply", "just", "easily", "obviously", "clearly", "of course",
    "basically", "essentially", "note that", "it's worth noting", "worth noting",
    "as mentioned", "utilize", "utilise", "leverage", "facilitate", "in order to",
    "prior to", "a plethora of", "powerful", "seamless", "seamlessly",
]

LIST_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
SENTENCE_END = re.compile(r"(?:(?<=[.!?])|(?<=[.!?][\"')\]]))\s+(?=[A-Z`\"'(\[*_])")


def strip_inline(text):
    text = re.sub(r"`[^`]*`", "X", text)  # an inline code span counts as one word
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"[*_]{1,3}", "", text)
    return text


def blocks(lines):
    """Return (kind, start_line, text) for each prose paragraph or list item."""
    result, para, para_start, in_fence = [], [], 0, False

    def flush():
        if para:
            result.append(("paragraph", para_start, " ".join(para)))
            para.clear()

    in_front_matter = bool(lines) and lines[0].strip() == "---"
    for number, raw in enumerate(lines, 1):
        line = raw.rstrip("\n")
        stripped = line.strip()
        if in_front_matter:
            in_front_matter = number == 1 or stripped != "---"
        elif stripped.startswith(("```", "~~~")):
            in_fence = not in_fence
            flush()
        elif in_fence:
            continue
        elif not stripped or stripped.startswith(("#", "|", ">", "<!--", "---")):
            flush()
        elif LIST_ITEM.match(line):
            flush()
            result.append(("list", number, LIST_ITEM.sub("", line, count=1)))
        else:
            if not para:
                para_start = number
            para.append(stripped)
    flush()
    return result


def check(path):
    with open(path, encoding="utf-8") as handle:
        lines = handle.readlines()

    findings = []
    for kind, line, text in blocks(lines):
        plain = strip_inline(text)
        sentences = [s for s in SENTENCE_END.split(plain) if s.strip()]
        limit = PROCEDURAL_LIMIT if kind == "list" else DESCRIPTIVE_LIMIT
        for sentence in sentences:
            words = len(sentence.split())
            if words > limit:
                findings.append({"line": line, "rule": "sentence-length",
                                 "detail": f"{words} words (limit {limit})",
                                 "text": sentence.strip()[:160]})
        if kind == "paragraph" and len(sentences) > PARAGRAPH_LIMIT:
            findings.append({"line": line, "rule": "paragraph-length",
                             "detail": f"{len(sentences)} sentences (limit {PARAGRAPH_LIMIT})",
                             "text": plain[:160]})
        lowered = f" {plain.lower()} "
        for word in CUT_WORDS:
            if re.search(rf"\b{re.escape(word)}\b", lowered):
                findings.append({"line": line, "rule": "cut-word",
                                 "detail": word, "text": plain[:160]})
    return findings


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip())
        return 2
    findings = check(sys.argv[1])
    if "--json" in sys.argv:
        print(json.dumps(findings, indent=2))
    else:
        for f in findings:
            print(f"{sys.argv[1]}:{f['line']}: {f['rule']}: {f['detail']}: {f['text']}")
        if not findings:
            print("No findings.")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
