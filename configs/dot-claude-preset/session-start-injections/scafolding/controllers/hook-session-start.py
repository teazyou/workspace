#!/usr/bin/env python3
"""Session-start hook controller.

Invoked by Claude Code's hook system (wired in .claude/settings.json) with the
hook EVENT NAME as its single argument:

    hook-session-start.py SessionStart    # main agent
    hook-session-start.py SubagentStart   # sub-agent

Responsibilities (controller = wiring only; real work lives in workers/):
  1. For SessionStart only: regenerate the index map for the repo root,
     capturing the returned _index.md content keyed by repo-relative folder path.
  2. Compile the session-start system prompt for this event (the worker maps the
     event name to its prompt file).
  3. Return, as the hook's additionalContext, the system prompt plus the repo
     ROOT index map. SessionStart injects the freshly regenerated root index;
     SubagentStart receives the existing root index (no regeneration).
  4. Emit the Claude Code hook JSON contract on stdout (and nothing else).

Fail-closed: any worker/setup error raises before the single stdout print, so a
malformed hook payload is never emitted (mirrors the old `set -euo pipefail`).
"""

import importlib.util
import json
import os
import sys

# --- debug toggle -----------------------------------------------------------
DEBUG = True  # if True, dump the full context + index mapping to ./

# --- locations --------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))          # .claude/scafolding/controllers
SCAFOLDING_DIR = os.path.dirname(SCRIPT_DIR)                      # .claude/scafolding
WORKERS_DIR = os.path.join(SCAFOLDING_DIR, "workers")
REPO_ROOT = os.path.dirname(os.path.dirname(SCAFOLDING_DIR))      # 3 levels up from controllers

SEPARATOR = "\n\n"


def _load_worker(module_name, filename):
    """Import a worker module from workers/ by file path (handles hyphenated names)."""
    path = os.path.join(WORKERS_DIR, filename)
    spec = importlib.util.spec_from_file_location(module_name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def regenerate_indexes():
    """Run build_index_map for ./.

    Returns {repo-relative-folder-key: index-content}, e.g.
    {"./": "<root index>"}.
    """
    idx = _load_worker("build_index_map", "build-index-map.py")
    mapping = {}
    mapping["./"] = idx.build_index_map(REPO_ROOT, REPO_ROOT)
    return mapping


def read_root_index():
    """Return the existing repo-root _index.md content, or "" if absent.

    Sub-agents receive the index map written at the main session start; they
    never regenerate it themselves.
    """
    path = os.path.join(REPO_ROOT, "_index.md")
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except OSError:
        return ""


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: hook-session-start.py <hookEventName>")
    event = sys.argv[1]

    # Index regen only for the main session start; sub-agents receive the existing
    # root index map (written at the main session start) without regenerating it.
    mapping = {}
    root_index = ""
    if event == "SessionStart":
        mapping = regenerate_indexes()
        root_index = mapping.get("./", "")
    else:
        root_index = read_root_index()

    # Worker maps the event name to its prompt file (SessionStart -> main-agent.md,
    # SubagentStart -> sub-agents.md). Unknown event raises here -> fail-closed.
    sysmod = _load_worker("build_system_prompt", "build-system-prompt.py")
    system_prompt = sysmod.build_system_prompt(event)

    # Context = system prompt + ROOT index.
    context = SEPARATOR.join(p for p in (system_prompt, root_index) if p)

    # Debug dump BEFORE returning.
    if DEBUG:
        with open(os.path.join(REPO_ROOT, "hook-session-start.md"),
                  "w", encoding="utf-8") as f:
            f.write(context)

    # Emit the hook JSON contract — the ONLY thing on stdout.
    print(json.dumps({
        "suppressOutput": True,
        "hookSpecificOutput": {
            "hookEventName": event,
            "additionalContext": context,
        },
    }))


if __name__ == "__main__":
    main()
