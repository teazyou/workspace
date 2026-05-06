#!/bin/bash
# scripts/installs/install_checkpoint_cronjob.sh
#
# Purpose:
#   Installs the hourly checkpoint cronjob and verifies that /usr/sbin/cron
#   has Full Disk Access (FDA) on macOS — without FDA, the cron entry runs
#   but cannot read files inside protected user directories.
#
# Idempotent:
#   - Cron entry: skipped if `crontab -l` already references
#     checkpoint_cronjob.sh.
#   - FDA grant: verified by querying the system TCC database. If already
#     granted, the manual step is skipped.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

CRON_SCRIPT="$HOME/workspace/scripts/checkpoint_cronjob.sh"
CRON_LINE="0 * * * * /bin/bash $CRON_SCRIPT"
TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"

# --- Cron entry -----------------------------------------------------------
if crontab -l 2>/dev/null | grep -qF "checkpoint_cronjob.sh"; then
    log_ok "Hourly checkpoint cronjob already in user crontab"
else
    log_wait "Adding hourly checkpoint cronjob to user crontab"
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    log_ok "Cron entry installed: $CRON_LINE"
fi

# --- Full Disk Access -----------------------------------------------------
# Returns:
#   0 = granted
#   1 = not granted (cron not in TCC list, or auth_value != 2)
#   2 = couldn't read TCC.db (the terminal itself lacks FDA — can't verify)
check_cron_fda() {
    local out
    out=$(sudo sqlite3 "$TCC_DB" \
        "SELECT auth_value FROM access WHERE service='kTCCServiceSystemPolicyAllFiles' AND client='/usr/sbin/cron';" \
        2>/dev/null) || return 2
    [ "$out" = "2" ] && return 0
    return 1
}

# Fast path: already granted, no manual step needed.
fda_status=0; check_cron_fda || fda_status=$?
if [ "$fda_status" -eq 0 ]; then
    log_ok "Full Disk Access for /usr/sbin/cron already granted"
    exit 0
fi

# Loop: open settings pane, prompt user, verify, offer retry/skip.
while true; do
    log_wait "Manual step: grant Full Disk Access to /usr/sbin/cron"
    printf "%s       (without it, the hourly checkpoint runs but cannot read your repos)%s\n\n" "$CYE" "$CWH"
    printf "%s  1. In the Full Disk Access pane that just opened, click the lock icon%s\n"      "$CYE" "$CWH"
    printf "%s     bottom-left and authenticate (Touch ID or password)%s\n"                     "$CYE" "$CWH"
    printf "%s  2. Click the '+' button to add a new entry%s\n"                                 "$CYE" "$CWH"
    printf "%s  3. In the file picker, press Cmd+Shift+G to open 'Go to folder',%s\n"           "$CYE" "$CWH"
    printf "%s     paste:%s %s/usr/sbin/cron%s%s   then press Enter, then click 'Open'%s\n"     "$CYE" "$CWH" "$CGR" "$CWH" "$CYE" "$CWH"
    printf "%s  4. Make sure the toggle next to 'cron' is ON%s\n\n"                             "$CYE" "$CWH"

    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null || true

    printf "%sPress ENTER when done...%s " "$CYE" "$CWH"
    read -r _ < /dev/tty

    fda_status=0; check_cron_fda || fda_status=$?
    case "$fda_status" in
        0) log_ok "Verified: /usr/sbin/cron has Full Disk Access"; break ;;
        1) log_err "Not detected: /usr/sbin/cron is missing or disabled in Full Disk Access" ;;
        2) log_err "Could not read TCC database — your terminal app likely needs Full Disk Access too, so sqlite3 can read the file" ;;
    esac

    printf "%s[r] Retry  [s] Skip:%s " "$CYE" "$CWH"
    read -r choice < /dev/tty
    case "$choice" in
        s|S) log_wait "Skipped — cronjob will run but may fail silently until FDA is granted manually"; break ;;
        *)   ;;  # anything else = retry
    esac
done
