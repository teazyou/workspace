#!/usr/bin/env python3
"""Compile a session-start system prompt by merging Markdown section files.

Usage:
    build-system-prompt.py SessionStart    # merges main-agent.md + all.md
    build-system-prompt.py SubagentStart   # merges sub-agents.md  + all.md

Source files live in .claude/scafolding/assets/system-prompts/session-start/. Convention:
  - An optional leading `# Title` line, plus any text before the first `## `
    header, is the file's "preamble" (its role / identity).
  - Each `## Name` line starts a section; the header text is the section name.
  - Headers are detected only OUTSIDE fenced code blocks (``` or ~~~), so a
    `##` written inside a code example stays content, not a section break.
  - A leading YAML frontmatter block (--- ... ---) is ignored, so a
    `description:` header never leaks into the compiled prompt.

Merge rule (role file = main or sub; shared file = all.md):
  - The role file drives the order: its preamble goes on top, then its
    sections in order.
  - A section in all.md with the same name is appended into that same section.
  - A section that exists only in all.md is appended at the end.

The compiled prompt is printed to stdout; no files are written.
"""

import os
import sys

EVENT_SOURCES = {
    "SessionStart": "main-agent.md",
    "SubagentStart": "sub-agents.md",
}
SHARED_SOURCE = "all.md"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))      # .claude/scafolding/workers
PROMPT_DIR = os.path.join(
    os.path.dirname(SCRIPT_DIR), "assets", "system-prompts", "session-start")


def read_text(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def strip_frontmatter(lines):
    """Drop a leading YAML frontmatter block (--- ... ---) if present."""
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                return lines[i + 1:]
    return lines


def parse(text):
    """Split text into (preamble, [(name, body), ...]).

    Sections are `## ` headers found outside fenced code blocks. Everything
    before the first such header is the preamble.
    """
    lines = strip_frontmatter(text.splitlines())
    preamble = []
    sections = []      # list of [name, [body lines]]
    current = None     # body line list for the open section, or None
    fence = None       # the open code-fence marker, or None

    for line in lines:
        stripped = line.strip()
        if fence is None and (stripped.startswith("```") or stripped.startswith("~~~")):
            fence = stripped[:3]              # entering a code block
        elif fence is not None and stripped.startswith(fence):
            fence = None                      # leaving a code block
        elif fence is None and line.startswith("## "):
            name = line[3:].strip().rstrip("#").strip()
            current = []
            sections.append([name, current])
            continue                          # header re-emitted later, not stored
        (current if current is not None else preamble).append(line)

    pre = "\n".join(preamble).strip()
    secs = [(name, "\n".join(body).strip()) for name, body in sections]
    return pre, secs


def build_system_prompt(event):
    if event not in EVENT_SOURCES:
        raise ValueError(f"unknown hook event: {event!r}")
    primary = read_text(os.path.join(PROMPT_DIR, EVENT_SOURCES[event]))
    shared = read_text(os.path.join(PROMPT_DIR, SHARED_SOURCE))

    p_pre, p_secs = parse(primary)
    s_pre, s_secs = parse(shared)

    order = []
    bodies = {}
    for name, body in p_secs + s_secs:
        if name not in bodies:
            bodies[name] = []
            order.append(name)
        if body:
            bodies[name].append(body)

    parts = []
    preamble = "\n\n".join(t for t in (p_pre, s_pre) if t)
    if preamble:
        parts.append(preamble)
    for name in order:
        section = "## " + name
        joined = "\n\n".join(bodies[name])
        if joined:
            section += "\n\n" + joined
        parts.append(section)
    return "\n\n".join(parts) + "\n"


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in EVENT_SOURCES:
        sys.exit("usage: build-system-prompt.py <SessionStart|SubagentStart>")
    print(build_system_prompt(sys.argv[1]), end="")


if __name__ == "__main__":
    main()
