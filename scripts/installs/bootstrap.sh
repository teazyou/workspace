#!/bin/bash
# Phase 1 only. Public entry (clean-Mac validation is still separate):
# curl -fsSL https://raw.githubusercontent.com/teazyou/workspace/master/scripts/installs/bootstrap.sh | bash
# Candidate testing: download this file from an authorized immutable revision,
# then run: bash bootstrap.sh --revision <full-40-character-commit>
# Bash 3.2; no login-shell sourcing, full installer, app launch, or auth automation.
set -e
REPO_URL=https://github.com/teazyou/workspace.git
RAW_ROOT=https://raw.githubusercontent.com/teazyou/workspace
BOOTSTRAP_SOURCE=${BASH_SOURCE[0]:-}
BOOTSTRAP_TEMP=
SUDO_KEEPALIVE_PID=

fail() { printf '[ STOP ] %s\n' "$*" >&2; return 1; }
download() { curl --proto '=https' --proto-redir '=https' -fSL --connect-timeout 30 --max-time 300 "$1" -o "$2"; }
cleanup() {
    local result=$?
    trap - EXIT
    if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true; wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true; fi
    if [[ -n "$BOOTSTRAP_TEMP" && -d "$BOOTSTRAP_TEMP" ]]; then rm -rf "$BOOTSTRAP_TEMP"; fi
    if [[ $result != 0 ]]; then echo 'Recovery preparation stopped. Preserve the workspace; diagnose the message, then rerun the same bootstrap command. If phase 2 already made reviewed changes, resume that session instead.' >&2; fi
    exit "$result"
}
# No imported Git aliases, hooks, global filters, or credential helpers are needed
# for this public source check. Existing repository config is never rewritten.
repo_git() { GIT_NO_REPLACE_OBJECTS=1 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git -c core.hooksPath=/dev/null -c http.lowSpeedLimit=1 -c http.lowSpeedTime=60 "$@"; }
clt_ready() {
    xcode-select -p >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1 && xcrun --find swift >/dev/null 2>&1
}
ensure_clt() {
    local elapsed=0
    if clt_ready; then return 0; fi
    echo 'Complete the Command Line Tools dialog. Waiting up to 30 minutes; Control-C cancels safely.'
    xcode-select --install || { fail 'CLT request failed. Complete or repair the system installation, then rerun.'; return 1; }
    until clt_ready; do
        [[ $elapsed -lt 1800 ]] || { fail 'CLT timed out after 30 minutes.'; return 1; }
        printf 'Waiting for CLT: %s / 1800 seconds\n' "$elapsed"
        sleep 10
        elapsed=$((elapsed + 10))
    done
}
platform_preflight() {
    [[ "$(uname -s)" == Darwin ]] || { fail 'This bootstrap requires macOS.'; return 1; }
    local arch major free translated
    arch=$(uname -m)
    translated=$(sysctl -in sysctl.proc_translated 2>/dev/null || true)
    [[ "$translated" != 1 ]] || { fail 'Use a native terminal, not Rosetta translation.'; return 1; }
    case "$arch" in
        arm64) BREW_PREFIX=/opt/homebrew ;;
        x86_64) BREW_PREFIX=/usr/local; echo 'Intel is a separately unverified compatibility path; native VPN acceptance is not established.' ;;
        *) fail "Unsupported architecture: $arch"; return 1 ;;
    esac
    major=$(sw_vers -productVersion); major=${major%%.*}
    [[ "$major" =~ ^[0-9]+$ && $major -ge 15 ]] || { fail 'Homebrew minimum supported baseline is macOS 15.'; return 1; }
    [[ "$major" == 26 ]] || echo 'Acceptance target is macOS 26; manual shortcut restoration and compatibility checks remain required.'
    free=$(df -Pk "$HOME" | awk 'END {print $4}')
    [[ "$free" =~ ^[0-9]+$ && $free -ge 12582912 ]] || { fail 'At least 12 GiB free is required for minimum preparation; full Xcode needs additional space.'; return 1; }
    BREW_BIN="$BREW_PREFIX/bin/brew"
    # Also performs the network preflight with a bounded HTTPS request.
    download "$RAW_ROOT/master/AGENTS.md" "$BOOTSTRAP_TEMP/network-check" || return 1
}
ensure_brew() {
    local current environment
    current=$(command -v brew || true)
    [[ -z "$current" || "$current" == "$BREW_BIN" ]] || { fail "Unexpected Homebrew executable: $current (expected $BREW_BIN)"; return 1; }
    if [[ ! -x "$BREW_BIN" ]]; then
        dseditgroup -o checkmember -m "$(whoami)" admin >/dev/null || { fail 'Homebrew installation requires an administrator account.'; return 1; }
        sudo -v || return 1
        # No sudo refresher survives this operation; parent traps cover interruption.
        ( while kill -0 "$$" 2>/dev/null; do sudo -n true || exit; sleep 30; done ) &
        SUDO_KEEPALIVE_PID=$!
        download https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh "$BOOTSTRAP_TEMP/homebrew.sh" || return 1
        /bin/bash -n "$BOOTSTRAP_TEMP/homebrew.sh" || return 1
        NONINTERACTIVE=1 /bin/bash "$BOOTSTRAP_TEMP/homebrew.sh" || return 1
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
        wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
        SUDO_KEEPALIVE_PID=
    fi
    [[ -x "$BREW_BIN" && "$("$BREW_BIN" --prefix)" == "$BREW_PREFIX" ]] || { fail 'Homebrew executable/prefix verification failed.'; return 1; }
    "$BREW_BIN" --version || return 1
    environment=$("$BREW_BIN" shellenv) || return 1
    eval "$environment"
    [[ "$(command -v brew)" == "$BREW_BIN" ]] || return 1
    export HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_INSTALL_UPGRADE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
    if ! "$BREW_BIN" list --formula git >/dev/null 2>&1; then
        "$BREW_BIN" install --dry-run --formula git || return 1
        "$BREW_BIN" install --formula git || return 1
    fi
    [[ -x "$BREW_PREFIX/bin/git" ]] || return 1
    "$BREW_PREFIX/bin/git" --version || return 1
}
resolve_source() {
    if [[ -z "$REVISION" ]]; then
        REVISION=$(repo_git ls-remote "$REPO_URL" refs/heads/master | awk 'NF==2 && $2=="refs/heads/master" {print $1}') || return 1
    fi
    [[ "$REVISION" =~ ^[0-9a-f]{40}$ ]] || { fail 'Expected one full published commit ID.'; return 1; }
    download "$RAW_ROOT/$REVISION/scripts/installs/bootstrap.sh" "$BOOTSTRAP_TEMP/immutable-bootstrap.sh" || return 1
    cmp -s "$BOOTSTRAP_SOURCE" "$BOOTSTRAP_TEMP/immutable-bootstrap.sh" || {
        fail 'Executing bootstrap differs from the resolved revision (branch moved, unpublished edits, or wrong candidate). Rerun without mixing versions.'; return 1;
    }
}
validate_checkout() {
    local top origins entry mode type oid relative component path actual
    [[ -d "$WORKSPACE" && ! -L "$WORKSPACE" ]] || { fail 'Workspace is missing, redirected, or a conflicting file.'; return 1; }
    top=$(repo_git -C "$WORKSPACE" rev-parse --show-toplevel) || return 1
    [[ "$top" == "$WORKSPACE" && "$(cd "$WORKSPACE" && pwd -P)" == "$WORKSPACE" ]] || { fail 'Workspace path is redirected or inside another checkout.'; return 1; }
    origins=$(repo_git -C "$WORKSPACE" config --get-all remote.origin.url) || return 1
    [[ "$origins" == "$REPO_URL" ]] || { fail 'Workspace origin mismatch; preserved existing checkout.'; return 1; }
    [[ "$(repo_git -C "$WORKSPACE" rev-parse HEAD)" == "$REVISION" ]] || { fail 'Workspace revision is stale/different; no automatic pull/reset is allowed.'; return 1; }
    local scope=(AGENTS.md _index.md .gitignore scripts functions configs zsh docs)
    repo_git -C "$WORKSPACE" ls-tree -r "$REVISION" -- "${scope[@]}" > "$BOOTSTRAP_TEMP/tree" || return 1
    [[ -s "$BOOTSTRAP_TEMP/tree" ]] || return 1
    # Hash actual bytes, independent of assume-unchanged/skip-worktree, index
    # contents, timestamps or diff filters. Reject redirected source components.
    while IFS=$'\t' read -r entry relative; do
        read -r mode type oid <<< "$entry"
        [[ "$relative" != *'"'* && "$type" == blob && "$mode" != 120000 ]] || { fail "Unsupported recovery source: $relative"; return 1; }
        path="$WORKSPACE"
        local rest="$relative"
        while [[ "$rest" == */* ]]; do
            component=${rest%%/*}; rest=${rest#*/}; path="$path/$component"
            [[ -d "$path" && ! -L "$path" ]] || { fail "Redirected recovery source: $relative"; return 1; }
        done
        path="$WORKSPACE/$relative"
        [[ -f "$path" && ! -L "$path" ]] || { fail "Missing/redirected recovery source: $relative"; return 1; }
        actual=$(repo_git hash-object --no-filters "$path") || return 1
        [[ "$actual" == "$oid" ]] || { fail "Recovery source differs: $relative. Preserve reviewed phase-2 changes and resume that session."; return 1; }
        if [[ "$mode" == 100755 ]]; then [[ -x "$path" ]] || return 1; else [[ ! -x "$path" ]] || return 1; fi
    done < "$BOOTSTRAP_TEMP/tree"
    # Index changes count too, including staged-only recovery edits.
    repo_git -C "$WORKSPACE" diff --cached --quiet "$REVISION" -- "${scope[@]}" || { fail 'Staged recovery source changes require review.'; return 1; }
    repo_git -C "$WORKSPACE" ls-files --others -- "${scope[@]}" > "$BOOTSTRAP_TEMP/untracked" || return 1
    [[ ! -s "$BOOTSTRAP_TEMP/untracked" ]] || { fail 'Untracked recovery source may shadow trusted files; preserve and review it.'; return 1; }
    for relative in AGENTS.md _index.md docs/install/bootstrap-flow.md docs/install/recovery-prompt.md scripts/installs/install_brew.sh scripts/installs/install_claude.sh scripts/installs/recovery_checks.sh; do
        repo_git -C "$WORKSPACE" cat-file -e "$REVISION:$relative" || { fail "Required published file missing: $relative"; return 1; }
    done
}
prepare_checkout() {
    if [[ ! -e "$WORKSPACE" && ! -L "$WORKSPACE" ]]; then
        repo_git clone --no-checkout --template= "$REPO_URL" "$WORKSPACE" || return 1
        repo_git -C "$WORKSPACE" fetch origin "$REVISION" || return 1
        repo_git -C "$WORKSPACE" checkout --detach "$REVISION" || return 1
    fi
    validate_checkout
}
minimum_handoff() {
    export WORKSPACE SCRIPTS="$WORKSPACE/scripts" INSTALLS="$WORKSPACE/scripts/installs" FUNCTIONS="$WORKSPACE/functions" APP_CONFIGS="$WORKSPACE/configs"
    export PATH="$HOME/.local/bin:$PATH"
    source "$INSTALLS/recovery_checks.sh"
    local guide="$WORKSPACE/docs/install/bootstrap-flow.md" claude="$HOME/.local/bin/claude" codex="$BREW_PREFIX/bin/codex" prompt
    # Require the process guide and valid handoff context before minimum installs.
    prompt=$(render_recovery_prompt "$guide" "$WORKSPACE" "$REPO_URL" "$REVISION" "$claude" "$codex") || { fail 'Recovery guide/prompt file missing/empty or handoff context invalid.'; return 1; }
    # Package readiness checks app identity/executables and CLI versions only.
    /bin/bash "$INSTALLS/install_brew.sh" --phase minimal || return 1
    /bin/bash "$INSTALLS/install_claude.sh" --cli-only || return 1
    /bin/bash "$INSTALLS/install_brew.sh" --phase minimal --verify-only || return 1
    verify_cli "$claude" && verify_cli "$codex" || return 1
    validate_checkout || return 1
    printf '\nStep1done: minimum applications and terminal agents are installed. Sign in to either Claude Code or a local Codex-capable ChatGPT session, then paste the prompt below.\n'
    echo 'Authentication, human first-open checks, and remaining setup are pending. No full installer was started.'
    echo 'Open Brave Browser yourself for account sign-in; choose/open an auth URL there if needed. No default-browser or browser-data changes are made.'
    echo 'Desktop: use a local coding session at the workspace. Ordinary chat/cloud does not prove local file and shell access.'
    echo 'Alternatively, run ONE of these in stock Terminal or iTerm, sign in, and paste the same prompt. One provider is sufficient:'
    printf 'cd %q && %q\n' "$WORKSPACE" "$claude"
    printf 'cd %q && %q\n' "$WORKSPACE" "$codex"
    echo 'Run recovery directly in the main session, without agents. If local file or shell access is unavailable, use an installed CLI.'
    printf '\nVerified handoff context:\nWorkspace: %s\nRecovery guide: %s\nTrusted origin: %s\nPublished bootstrap revision: %s\nNative Claude executable: %s\nCodex executable: %s\n' "$WORKSPACE" "$guide" "$REPO_URL" "$REVISION" "$claude" "$codex"
    printf '\n%s\n' "$prompt"
}
bootstrap_main() {
    REVISION=
    if [[ $# -gt 0 ]]; then
        [[ $# == 2 && "$1" == --revision && "$2" =~ ^[0-9a-f]{40}$ ]] || { fail 'Usage: bootstrap.sh [--revision FULL_COMMIT_ID]'; return 1; }
        REVISION=$2
    fi
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    BOOTSTRAP_TEMP=$(mktemp -d /tmp/workspace-bootstrap.XXXXXX) || return 1
    if [[ -z "$BOOTSTRAP_SOURCE" || ! -f "$BOOTSTRAP_SOURCE" ]]; then
        # The initial stdin is source code: no child installer can consume it.
        ( : < /dev/tty ) 2>/dev/null || { fail 'No controlling terminal. Download to a file, then run it in stock Terminal.'; return 1; }
        download "$RAW_ROOT/${REVISION:-master}/scripts/installs/bootstrap.sh" "$BOOTSTRAP_TEMP/bootstrap.sh" || return 1
        /bin/bash -n "$BOOTSTRAP_TEMP/bootstrap.sh" || return 1
        /bin/bash "$BOOTSTRAP_TEMP/bootstrap.sh" "$@" < /dev/tty
        return
    fi
    [[ -t 0 ]] || { fail 'Run the downloaded bootstrap from an interactive terminal.'; return 1; }
    WORKSPACE="$HOME/workspace"
    platform_preflight
    ensure_clt
    ensure_brew
    resolve_source
    prepare_checkout
    minimum_handoff
}
# Functions may be sourced by isolated tests; sourcing never installs anything.
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then bootstrap_main "$@"; fi
