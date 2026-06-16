#!/usr/bin/env python3
"""Build a simple markdown index of every markdown file in a target folder.

Usage:
    build-index-map.py <target> <output>

Walks <target> recursively (including nested repositories/sub-folders), finds
every markdown (.md) file, reads its YAML frontmatter `description` key, and
writes (overriding if it exists) <output>/_index.md with one line per file:

    "path-relative-to-output": description
"""

import argparse
import os
import sys

INDEX_NAME = "_index.md"

# Files and folders to ignore, given as paths relative to the target folder.
EXCLUDE = [
    ".claude",
]


def read_description(path):
    """Return the `description` value from a file's YAML frontmatter, or ""."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            if f.readline().strip() != "---":
                return ""  # no frontmatter block
            for line in f:
                stripped = line.strip()
                if stripped == "---":
                    break  # end of frontmatter
                if stripped.startswith("description:"):
                    value = stripped[len("description:"):].strip()
                    # drop surrounding quotes if present
                    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                        value = value[1:-1]
                    return value
    except (OSError, UnicodeDecodeError):
        return ""
    return ""


def build_index_map(target, output):
    """Scan <target> for .md files, write <output>/_index.md, and RETURN its content.

    No stdout output (callers such as the hook controller reserve stdout for JSON).
    """
    target = os.path.abspath(target)
    output = os.path.abspath(output)
    if not os.path.isdir(target):
        raise NotADirectoryError(f"target folder does not exist: {target}")
    os.makedirs(output, exist_ok=True)
    index_path = os.path.join(output, INDEX_NAME)
    excluded = {os.path.abspath(os.path.join(target, e)) for e in EXCLUDE}
    md_files = []
    for root, dirs, files in os.walk(target):
        dirs[:] = [d for d in dirs
                   if os.path.abspath(os.path.join(root, d)) not in excluded]
        for name in files:
            if name == INDEX_NAME:
                continue
            if name.lower().endswith(".md"):
                full = os.path.join(root, name)
                if os.path.abspath(full) in excluded:
                    continue
                md_files.append(full)
    md_files.sort()
    lines = []
    for full in md_files:
        rel = os.path.relpath(full, output).replace(os.sep, "/")
        desc = read_description(full) or "missing description"
        lines.append(f'"{rel}": {desc}')
    content = "\n".join(lines) + "\n" if lines else ""
    with open(index_path, "w", encoding="utf-8") as f:
        f.write(content)
    return content


def main():
    parser = argparse.ArgumentParser(
        description="Build a markdown index of all markdown files in a folder.")
    parser.add_argument("target", help="folder scanned recursively for .md files")
    parser.add_argument("output", help="folder where _index.md is written")
    args = parser.parse_args()
    try:
        content = build_index_map(args.target, args.output)
    except NotADirectoryError as e:
        sys.exit(f"error: {e}")
    index_path = os.path.join(os.path.abspath(args.output), INDEX_NAME)
    n = content.count("\n") if content else 0
    print(f"wrote {index_path} ({n} files)")


if __name__ == "__main__":
    main()
