#!/bin/bash
# scripts/installs/helper_prompt.sh
#
# Purpose:
#   Helper functions used by the install scripts (install-only — that's
#   why this file lives next to them in scripts/installs/ rather than in
#   the general-purpose functions/ folder).
#
#   - Sources the workspace color palette (zsh/configs/colors.zsh) and
#     converts the literal "\033[..m" strings into real escape characters,
#     so that plain `echo` shows colors in bash too. (zsh interprets
#     escapes natively in `echo`, bash does not — this normalises both.)
#
#   - Logging helpers (log_ok / log_err / log_wait / log_info / log_step)
#     follow the existing aesthetic from functions/brew.sh:
#       [ OK ] in green, [ KO ] in red, [ W8 ] in yellow.
#
#   - Manual-step prompts (prompt_continue / prompt_command) pause the
#     script and read from /dev/tty so they keep working even when the
#     parent script was launched via `curl ... | bash`.
#
# Source it at the top of every install script:
#   source "$INSTALLS/helper_prompt.sh"

# Default path vars in case a sub-script is invoked standalone (without
# going through installation.sh which exports these).
: "${WORKSPACE:=$HOME/workspace}"
: "${SCRIPTS:=$WORKSPACE/scripts}"
: "${INSTALLS:=$SCRIPTS/installs}"
: "${APP_CONFIGS:=$WORKSPACE/configs}"
: "${FUNCTIONS:=$WORKSPACE/functions}"

# Pull in the color exports. The values are literal escape strings
# (e.g. the 5 characters "\033[0;31m") which zsh's echo interprets but
# bash's echo does not. We normalise them below with `printf %b`.
# shellcheck source=/dev/null
source "$WORKSPACE/zsh/configs/colors.zsh"

CRE=$(printf '%b' "$CRE")
CGR=$(printf '%b' "$CGR")
CYE=$(printf '%b' "$CYE")
CBL=$(printf '%b' "$CBL")
CWH=$(printf '%b' "$CWH")
COK=$(printf '%b' "$COK")
CKO=$(printf '%b' "$CKO")
CW8=$(printf '%b' "$CW8")
export CRE CGR CYE CBL CWH COK CKO CW8

# --- LOGGING ----------------------------------------------------------------
# Status lines: small "[ OK ]" / "[ KO ]" / "[ W8 ]" prefix in colour.
log_ok()   { printf "%s%s%s\n" "$COK" "$1" "$CWH"; }
log_err()  { printf "%s%s%s\n" "$CKO" "$1" "$CWH"; }
log_wait() { printf "%s%s%s\n" "$CW8" "$1" "$CWH"; }

# Section headings, used between major install phases for readability.
log_info() { printf "\n%s== %s ==%s\n" "$CYE" "$1" "$CWH"; }
log_step() { printf "\n%s## %s ##%s\n" "$CBL" "$1" "$CWH"; }

# --- PROMPTS ----------------------------------------------------------------
# Pause until the user presses ENTER. Reads from /dev/tty so it works even
# when the parent script was launched via `curl ... | bash` (where stdin is
# the piped script content, already consumed).
prompt_continue() {
    printf "%s[ MANUAL ]%s %s\n"           "$CYE" "$CWH" "$1"
    printf "%sPress ENTER when done...%s " "$CYE" "$CWH"
    read -r _ < /dev/tty
}

# Display a copy-paste-ready command and wait for ENTER.
#   $1 = description / what the user should achieve
#   $2 = the exact command to copy and run
prompt_command() {
    printf "%s[ MANUAL ]%s %s\n"                       "$CYE" "$CWH" "$1"
    printf "%sCopy & run this in another terminal:%s\n" "$CYE" "$CWH"
    printf "%s    %s%s\n"                              "$CGR" "$2"  "$CWH"
    printf "%sPress ENTER when done...%s "             "$CYE" "$CWH"
    read -r _ < /dev/tty
}
