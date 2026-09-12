#!/bin/bash
# Shared, side-effect-free readiness checks. Source only after bootstrap validates
# the checkout. Package inventory belongs exclusively to install_brew.sh.
verify_app() {
    local app="$1" identity="$2" executable actual
    [[ -d "$app" && ! -L "$app" ]] || { echo "Missing/redirected application: $app" >&2; return 1; }
    plutil -convert xml1 -o /dev/null "$app/Contents/Info.plist" || return 1
    actual=$(plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist") || return 1
    executable=$(plutil -extract CFBundleExecutable raw -o - "$app/Contents/Info.plist") || return 1
    [[ "$actual" == "$identity" && -n "$executable" && "$executable" != */* && -x "$app/Contents/MacOS/$executable" ]] || {
        echo "Application identity/executable failed: $app" >&2; return 1;
    }
    printf 'Verified application identity and executable: %s\n' "$app"
}

verify_cli() {
    [[ "$1" == /* && -x "$1" ]] || { echo "Missing executable: $1" >&2; return 1; }
    "$1" --version || return 1
}

render_recovery_prompt() {
    local guide="$1" workspace="$2" origin="$3" revision="$4" claude="$5" codex="$6" value
    for value in "$guide" "$workspace" "$origin" "$revision" "$claude" "$codex"; do
        [[ -n "$value" && "$value" != *'{{'* && "$value" != *$'\n'* && "$value" != *$'\r'* ]] || return 1
    done
    [[ "$guide" == "$workspace/docs/install/bootstrap-flow.md" && "$workspace" == /* && "$claude" == /* && "$codex" == /* ]] || return 1
    [[ "$origin" == https://github.com/teazyou/workspace.git && "$revision" =~ ^[0-9a-f]{40}$ ]] || return 1
    [[ -f "$guide" && -s "$guide" && ! -L "$guide" ]] || return 1
    # Bootstrap validates the published guide bytes and prints context separately.
    # The prompt file contains the instructions; terminal output points to it.
    local prompt_file="$workspace/docs/install/recovery-prompt.md"
    [[ -f "$prompt_file" && -s "$prompt_file" && ! -L "$prompt_file" ]] || return 1
    printf 'Read and execute %s\n' "$prompt_file"
}
