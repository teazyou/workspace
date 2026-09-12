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
    # ENVIRON avoids awk -v interpreting backslashes in paths; no eval of prose.
    REC_GUIDE="$guide" REC_WORKSPACE="$workspace" REC_ORIGIN="$origin" REC_REV="$revision" REC_CLAUDE="$claude" REC_CODEX="$codex" awk '
      function replace(s, key, value, p) {
        while ((p=index(s,key))) s=substr(s,1,p-1) value substr(s,p+length(key));
        return s;
      }
      /^<!-- recovery-prompt:start -->$/ { starts++; inside=1; next }
      /^<!-- recovery-prompt:end -->$/ { ends++; inside=0; next }
      inside {
        s=$0;
        if(index(s,"{{WORKSPACE_ABSOLUTE_PATH}}")) fields[1]++;
        if(index(s,"{{GUIDE_ABSOLUTE_PATH}}")) fields[2]++;
        if(index(s,"{{ORIGIN_HTTPS_URL}}")) fields[3]++;
        if(index(s,"{{FULL_COMMIT_ID}}")) fields[4]++;
        if(index(s,"{{CLAUDE_ABSOLUTE_PATH}}")) fields[5]++;
        if(index(s,"{{CODEX_ABSOLUTE_PATH}}")) fields[6]++;
        s=replace(s,"{{WORKSPACE_ABSOLUTE_PATH}}",ENVIRON["REC_WORKSPACE"]);
        s=replace(s,"{{GUIDE_ABSOLUTE_PATH}}",ENVIRON["REC_GUIDE"]);
        s=replace(s,"{{ORIGIN_HTTPS_URL}}",ENVIRON["REC_ORIGIN"]);
        s=replace(s,"{{FULL_COMMIT_ID}}",ENVIRON["REC_REV"]);
        s=replace(s,"{{CLAUDE_ABSOLUTE_PATH}}",ENVIRON["REC_CLAUDE"]);
        s=replace(s,"{{CODEX_ABSOLUTE_PATH}}",ENVIRON["REC_CODEX"]);
        if (index(s,"{{")) bad=1;
        if (s !~ /^```/) { output=output s "\n"; lines++ }
      }
      END { for(i=1;i<=6;i++) if(fields[i]!=1) bad=1; if(starts!=1 || ends!=1 || inside || bad || lines<10) exit 1; printf "%s",output }
    ' "$guide"
}
