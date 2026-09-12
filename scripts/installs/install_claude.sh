#!/bin/bash
# Claude Desktop normally comes from the claude cask; native Claude Code is
# the sole CLI distribution. --cli-only is used by minimum bootstrap.
# --desktop-fallback is an explicit supervised repair for a missing app, after
# Python is available. Never replaces an existing bundle or strips quarantine.
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helper_prompt.sh"
source "$INSTALLS/recovery_checks.sh"
CLAUDE_BIN="$HOME/.local/bin/claude"
CLAUDE_TEMP=
trap '[[ -z "$CLAUDE_TEMP" ]] || rm -rf "$CLAUDE_TEMP"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

claude_download() { curl --proto '=https' --proto-redir '=https' -fSL --connect-timeout 30 --max-time 600 "$1" -o "$2"; }
mode=${1:-normal}
[[ $# -le 1 ]] || exit 2
case "$mode" in normal|--cli-only|--desktop-fallback) ;; *) echo 'Usage: install_claude.sh [--cli-only|--desktop-fallback]' >&2; exit 2 ;; esac
if [[ "$mode" != --cli-only ]]; then
    if [[ ! -e /Applications/Claude.app && ! -L /Applications/Claude.app && "$mode" == --desktop-fallback ]]; then
        claude_status=0
        pgrep -x Claude >/dev/null || claude_status=$?
        if [[ "$claude_status" == 0 ]]; then echo 'Claude is running; establish a safe session handoff before repair.' >&2; exit 1; fi
        if [[ "$claude_status" != 1 ]]; then
            echo "Could not establish that Claude is stopped (pgrep status $claude_status). No Desktop repair was attempted." >&2
            exit 1
        fi
        python3 --version
        CLAUDE_TEMP=$(mktemp -d /tmp/workspace-claude.XXXXXX)
        claude_download https://downloads.claude.ai/releases/darwin/universal/RELEASES.json "$CLAUDE_TEMP/releases.json"
        DOWNLOAD_URL=$(python3 - "$CLAUDE_TEMP/releases.json" <<'PY'
import json,sys,urllib.parse
url=json.load(open(sys.argv[1]))['releases'][0]['updateTo']['url']
u=urllib.parse.urlparse(url)
if u.scheme!='https' or u.hostname!='downloads.claude.ai' or u.username or u.password or not u.path.endswith('.zip'): raise SystemExit('Unexpected desktop download origin/artifact')
print(url)
PY
)
        claude_download "$DOWNLOAD_URL" "$CLAUDE_TEMP/claude.zip"
        mkdir "$CLAUDE_TEMP/extract"
        ditto -x -k "$CLAUDE_TEMP/claude.zip" "$CLAUDE_TEMP/extract"
        verify_app "$CLAUDE_TEMP/extract/Claude.app" com.anthropic.claudefordesktop
        spctl --assess --type execute "$CLAUDE_TEMP/extract/Claude.app"
        # Preserve first-open Gatekeeper handling even for a command-line download.
        xattr -w com.apple.quarantine "0083;$(date +%s);workspace-recovery;" "$CLAUDE_TEMP/extract/Claude.app"
        [[ ! -e /Applications/Claude.app && ! -L /Applications/Claude.app ]] || exit 1
        # -n refuses replacement; the postcondition verifies what actually exists.
        cp -Rn "$CLAUDE_TEMP/extract/Claude.app" /Applications/
    fi
    verify_app /Applications/Claude.app com.anthropic.claudefordesktop || {
        echo 'Claude Desktop is missing/damaged. Diagnose the cask; explicit --desktop-fallback is available after Python for a missing app only.' >&2; exit 1;
    }
fi
# Refuse a second distribution rather than adopting/removing it silently.
if command -v brew >/dev/null 2>&1; then
    installed_casks=$(brew list --cask -1) || { echo 'Cannot inspect Claude CLI distribution receipts.' >&2; exit 1; }
    if printf '%s\n' "$installed_casks" | grep -Eq '^claude-code(@.*)?$'; then
        echo 'A Homebrew Claude Code distribution already exists. Preserve it and diagnose migration to the sole native installation before continuing.' >&2
        exit 1
    fi
fi
while IFS= read -r existing_cli; do
    [[ -z "$existing_cli" || "$existing_cli" == "$CLAUDE_BIN" ]] || {
        echo "Another Claude executable is on PATH: $existing_cli. Diagnose its distribution before installing a second copy." >&2
        exit 1
    }
done < <(type -ap claude || true)
if [[ ! -x "$CLAUDE_BIN" ]]; then
    [[ ! -e "$CLAUDE_BIN" && ! -L "$CLAUDE_BIN" ]] || { echo 'Existing Claude executable is broken; preserve and diagnose it.' >&2; exit 1; }
    [[ -n "$CLAUDE_TEMP" ]] || CLAUDE_TEMP=$(mktemp -d /tmp/workspace-claude.XXXXXX)
    claude_download https://claude.ai/install.sh "$CLAUDE_TEMP/install.sh"
    /bin/bash -n "$CLAUDE_TEMP/install.sh"
    /bin/bash "$CLAUDE_TEMP/install.sh"
fi
verify_cli "$CLAUDE_BIN"
