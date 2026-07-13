#!/bin/bash
# scripts/installs/install_docling.sh
#
# Purpose:
#   Installs the docling document-conversion CLI as an isolated uv tool
#   env with a uv-managed Python 3.12 (macOS system python3 is 3.9.x;
#   docling needs >= 3.10), then prefetches the docling ML models so
#   conversion works offline via `docling --artifacts-path`.
#
#   uv is NOT part of install_brew.sh's formula list, so this script
#   idempotently ensures uv itself first (via `brew install uv` — brew is
#   on PATH from bootstrap.sh onward). Kept self-contained on purpose:
#   docling is the only uv consumer in the flow.
#
# PATH note (same reasoning as install_claude.sh):
#   This runs in a bash subshell that does NOT source ~/.zshrc, so
#   ~/.local/bin — where uv drops the docling/docling-tools shims, and
#   where a standalone (astral.sh) uv would live — is NOT on PATH here.
#   Interactive shells get it from zsh/configs/path.zsh. All checks and
#   invocations below therefore use absolute paths, never bare names.
#
# Idempotent:
#   - uv:      skipped if `uv` is on PATH or at ~/.local/bin/uv
#   - docling: skipped if ~/.local/bin/docling exists
#              (force redo: `uv tool uninstall docling`)
#   - models:  skipped if ~/.cache/docling/models exists and is non-empty
#              (force redo: `rm -rf ~/.cache/docling/models`)
#   Upgrades are manual and out of scope: `uv tool upgrade docling`.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

LOCAL_BIN="$HOME/.local/bin"
DOCLING_BIN="$LOCAL_BIN/docling"
DOCLING_TOOLS_BIN="$LOCAL_BIN/docling-tools"
MODELS_DIR="$HOME/.cache/docling/models"

# --- 1. uv (tool installer + isolated-env manager) -----------------------
log_step "uv"

if command -v uv &>/dev/null; then
    UV_BIN=$(command -v uv)
    log_ok "uv already installed at $UV_BIN"
elif [[ -x "$LOCAL_BIN/uv" ]]; then
    # Standalone astral.sh install location — present but not on PATH here.
    UV_BIN="$LOCAL_BIN/uv"
    log_ok "uv already installed at $UV_BIN"
else
    if ! command -v brew &>/dev/null; then
        log_err "brew not found on PATH — did bootstrap.sh run?"
        exit 1
    fi
    log_wait "Installing uv (brew) ..."
    brew install uv
    UV_BIN=$(command -v uv)
    if [[ -z "$UV_BIN" ]]; then
        log_err "uv install completed but uv not found on PATH"
        exit 1
    fi
    log_ok "uv installed → $UV_BIN"
fi

# --- 2. docling CLI (isolated uv tool env, Python 3.12) ------------------
log_step "Docling CLI"

if [[ -x "$DOCLING_BIN" ]]; then
    log_ok "docling already installed at $DOCLING_BIN"
else
    # uv auto-downloads a managed CPython 3.12 if no matching interpreter
    # exists (brew's python is newer), so this has no python dependency.
    # Shims (docling + docling-tools) land in ~/.local/bin.
    log_wait "Installing docling (uv tool install, uv-managed Python 3.12) ..."
    "$UV_BIN" tool install docling --python 3.12

    if [[ -x "$DOCLING_BIN" ]]; then
        DOCLING_VERSION=$("$DOCLING_BIN" --version 2>/dev/null | head -1 || true)
        log_ok "docling installed → $DOCLING_BIN (${DOCLING_VERSION:-version check failed})"
    else
        log_err "docling install completed but binary not found at $DOCLING_BIN"
        exit 1
    fi
fi

# --- 3. ML models prefetch (offline conversion) --------------------------
log_step "Docling ML models"

if [[ -d "$MODELS_DIR" && -n "$(ls -A "$MODELS_DIR" 2>/dev/null)" ]]; then
    log_ok "docling models already present at $MODELS_DIR"
else
    if [[ ! -x "$DOCLING_TOOLS_BIN" ]]; then
        log_err "docling-tools not found at $DOCLING_TOOLS_BIN — cannot prefetch models"
        exit 1
    fi
    log_wait "Prefetching docling models → $MODELS_DIR (~1.2 GB download) ..."
    if "$DOCLING_TOOLS_BIN" models download; then
        log_ok "docling models downloaded → $MODELS_DIR"
    else
        # A failed/partial download must NOT satisfy the non-empty skip
        # check above, or every re-run would keep a broken cache. Models
        # are nice-to-have (docling fetches them on first use), so we
        # continue rather than abort the whole orchestrator.
        rm -rf "$MODELS_DIR"
        log_err "docling model prefetch failed (continuing — docling downloads models on first use)"
    fi
fi

log_ok "Docling install complete"
