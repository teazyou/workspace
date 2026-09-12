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
    codesign --verify --deep --strict "$app" || return 1
    printf 'Verified application structure and signature: %s\n' "$app"
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
    [[ "$guide" == "$workspace/docs/install/supervised-recovery-plan.md" && "$workspace" == /* && "$claude" == /* && "$codex" == /* ]] || return 1
    [[ "$origin" == https://github.com/teazyou/workspace.git && "$revision" =~ ^[0-9a-f]{40}$ ]] || return 1
    # Declarations are fixed header lines, never a quoted mention in a draft.
    [[ "$(sed -n '3p' "$guide")" == 'Status: implemented candidate' ]] || return 1
    [[ "$(sed -n '4p' "$guide")" == 'Recovery contract: supervised-v1' ]] || return 1
    # Context is printed separately by bootstrap; copy only the short prompt.
    awk '
      /^<!-- recovery-prompt:start -->$/ { starts++; inside=1; next }
      /^<!-- recovery-prompt:end -->$/ { ends++; inside=0; next }
      inside {
        s=$0;
        if (index(s,"{{")) bad=1;
        if (s !~ /^```/) { output=output s "\n"; if (s ~ /[^[:space:]]/) lines++ }
      }
      END { if(starts!=1 || ends!=1 || inside || bad || !lines) exit 1; printf "%s",output }
    ' "$guide"
}
