#!/bin/bash
# functions/brew.sh
#
# Helper wrappers around `brew` used by scripts/installs/install_brew.sh.
#
# Conventions:
#   - All three helpers are idempotent: if the formula/cask/tap is already
#     present, they short-circuit with an [ OK ] log and return 0.
#   - Each takes a human label as $1 (used only in log lines) and the real
#     brew identifier as $2. Cask identifiers may be tap-qualified, e.g.
#     "nikitabobko/tap/aerospace" — `brew install --cask` accepts that
#     directly without a separate `brew tap` call.
#   - Failures don't abort the parent script. The caller (install_brew.sh)
#     runs with `set -e` so we explicitly `return 0` on failure to keep the
#     full install going; the [ KO ] line surfaces the failure to the user.
#
# Homebrew itself is installed by scripts/installs/bootstrap.sh — by the
# time anything sources this file, `brew` is guaranteed to be on PATH.

# `brew update` once per session so the formula/cask metadata is fresh.
# Skip silently if brew isn't on PATH (caller will fail loudly later).
if command -v brew &>/dev/null; then
    brew update &>/dev/null || true
fi

# Strip a tap prefix to get the bare formula/cask name (the form
# `brew list` recognises). Examples:
#   nikitabobko/tap/aerospace  → aerospace
#   felixkratz/formulae/borders → borders
#   ripgrep                    → ripgrep
_brew_basename() {
    printf '%s\n' "${1##*/}"
}

# brewInstall <label> <formula>
brewInstall() {
    local label="$1" formula="$2"
    local short
    short=$(_brew_basename "$formula")

    # Match either the exact name (e.g. ripgrep) or any versioned variant
    # (e.g. python → python@3.13, postgresql → postgresql@17). The latter
    # is needed because `brew install python` resolves to python@3.X but
    # `brew list python` then returns nothing.
    if brew list --formula -1 2>/dev/null | grep -Eq "^${short}(@.+)?$"; then
        printf "%s[ OK ] %s already installed%s\n" "$COK" "$label" "$CWH"
        return 0
    fi

    printf "%s[ W8 ] installing %s (%s)...%s\n" "$CW8" "$label" "$formula" "$CWH"
    if brew install "$formula"; then
        printf "%s[ OK ] %s install success%s\n" "$COK" "$label" "$CWH"
    else
        printf "%s[ KO ] %s install fail%s\n" "$CKO" "$label" "$CWH"
    fi
    return 0
}

# caskInstall <label> <cask>
# <cask> may be tap-qualified (e.g. nikitabobko/tap/aerospace).
caskInstall() {
    local label="$1" cask="$2"
    local short
    short=$(_brew_basename "$cask")

    if brew list --cask "$short" &>/dev/null; then
        printf "%s[ OK ] %s already installed%s\n" "$COK" "$label" "$CWH"
        return 0
    fi

    printf "%s[ W8 ] installing %s (%s)...%s\n" "$CW8" "$label" "$cask" "$CWH"
    if brew install --cask "$cask"; then
        printf "%s[ OK ] %s install success%s\n" "$COK" "$label" "$CWH"
    else
        printf "%s[ KO ] %s install fail%s\n" "$CKO" "$label" "$CWH"
    fi
    return 0
}

# brewTap <tap>
brewTap() {
    local tap="$1"
    if brew tap | grep -Fxq "$tap"; then
        printf "%s[ OK ] tap %s already added%s\n" "$COK" "$tap" "$CWH"
        return 0
    fi

    printf "%s[ W8 ] tapping %s...%s\n" "$CW8" "$tap" "$CWH"
    if brew tap "$tap"; then
        printf "%s[ OK ] tap %s success%s\n" "$COK" "$tap" "$CWH"
    else
        printf "%s[ KO ] tap %s fail%s\n" "$CKO" "$tap" "$CWH"
    fi
    return 0
}
