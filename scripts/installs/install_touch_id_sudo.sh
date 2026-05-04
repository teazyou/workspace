#!/bin/bash
# scripts/installs/install_touch_id_sudo.sh
#
# Purpose:
#   Enables Touch ID for `sudo` so you can authenticate sudo commands with
#   your fingerprint instead of typing your password.
#
# How:
#   Apple ships /etc/pam.d/sudo_local.template — a file specifically
#   designed to survive macOS upgrades (the regular /etc/pam.d/sudo gets
#   rewritten by the OS). We copy it to /etc/pam.d/sudo_local (if it
#   doesn't already exist) and uncomment the pam_tid.so line.
#
# Note:
#   Touch ID for sudo will NOT work over SSH or VS Code remote sessions —
#   in those, sudo falls back to password as expected.
#
# Idempotent: skipped if pam_tid.so is already active in sudo_local.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

SUDO_LOCAL="/etc/pam.d/sudo_local"
SUDO_TEMPLATE="/etc/pam.d/sudo_local.template"

# Already enabled? grep for an *uncommented* pam_tid.so line.
if [[ -f "$SUDO_LOCAL" ]] && grep -E '^\s*auth\s+sufficient\s+pam_tid\.so' "$SUDO_LOCAL" &>/dev/null; then
    log_ok "Touch ID for sudo already enabled"
    exit 0
fi

if [[ ! -f "$SUDO_TEMPLATE" ]]; then
    log_err "Apple's /etc/pam.d/sudo_local.template is missing — your macOS may be too old (need Sonoma+)"
    exit 1
fi

log_wait "Enabling Touch ID for sudo (you'll be prompted for your password once)"

# Copy template into place if needed.
if [[ ! -f "$SUDO_LOCAL" ]]; then
    sudo cp "$SUDO_TEMPLATE" "$SUDO_LOCAL"
fi

# Try the targeted uncomment first (cheapest, preserves Apple's formatting).
# The template historically ships the line as: "#auth   sufficient   pam_tid.so"
# but the exact whitespace and the leading "# " vs "#" varies across macOS
# releases — that's why this used to fail on some machines.
sudo sed -i '' -E \
    's|^#[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so|auth       sufficient     pam_tid.so|' \
    "$SUDO_LOCAL"

# If after the sed there's still no active pam_tid.so line, just append one.
# sudo_local is explicitly meant for user-managed entries, so appending is
# safe and survives macOS upgrades.
if ! grep -E '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so' "$SUDO_LOCAL" &>/dev/null; then
    log_wait "Template format unrecognised — appending pam_tid.so line directly"
    printf '\n# Touch ID for sudo (added by workspace install)\nauth       sufficient     pam_tid.so\n' \
        | sudo tee -a "$SUDO_LOCAL" >/dev/null
fi

# Final verify.
if grep -E '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so' "$SUDO_LOCAL" &>/dev/null; then
    log_ok "Touch ID for sudo enabled (try: 'sudo -k && sudo true' to test)"
else
    log_err "sudo_local edit did not take effect — check $SUDO_LOCAL manually"
    exit 1
fi
