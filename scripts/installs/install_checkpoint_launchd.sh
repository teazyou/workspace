#!/bin/bash
# scripts/installs/install_checkpoint_launchd.sh
#
# Purpose:
#   Installs the hourly checkpoint job as a launchd LaunchAgent.
#
#   Why a LaunchAgent and not cron:
#     `git push` from the checkpoint job uses an HTTPS remote whose
#     credentials live in the macOS login keychain. cron runs outside
#     the GUI login session and cannot reach that keychain, so push
#     fails with:
#       fatal: could not read Username for 'https://github.com':
#              Device not configured
#     A LaunchAgent runs inside the user's GUI session and can.
#
# Behaviour:
#   - Runs /Users/<user>/workspace/scripts/checkpoint_cronjob.sh at
#     minute 0 of every hour (StartCalendarInterval).
#   - RunAtLoad is false: the job does NOT fire on login/bootstrap,
#     keeping behaviour identical to the old cron entry.
#
# Note (fresh machine):
#   The first hourly push can still fail until the GitHub credential is
#   cached in the login keychain — that happens the first time you run
#   an interactive `git push`/`git clone` over HTTPS. `git add`/`commit`
#   succeed regardless, and the job self-heals on the next run.
#
# Idempotent:
#   - Removes any leftover checkpoint cron entry (migration).
#   - If the LaunchAgent is already loaded, it is booted out and
#     re-bootstrapped so the latest plist always wins.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

LABEL="com.teazyou.checkpoint"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CHECKPOINT_SCRIPT="$HOME/workspace/scripts/checkpoint_cronjob.sh"
LOG_DIR="$HOME/workspace/logs"
UID_=$(id -u)
DOMAIN="gui/$UID_"
SERVICE_TARGET="$DOMAIN/$LABEL"

# --- 1. Migrate away from cron -------------------------------------------
# Remove the old hourly checkpoint cron entry if it is still present.
if crontab -l 2>/dev/null | grep -qF "checkpoint_cronjob.sh"; then
    log_wait "Removing old checkpoint cron entry"
    crontab -l 2>/dev/null | grep -vF "checkpoint_cronjob.sh" | crontab -
    log_ok "Old cron entry removed"
else
    log_ok "No checkpoint cron entry to migrate"
fi

# --- 2. Preconditions ----------------------------------------------------
if [[ ! -f "$CHECKPOINT_SCRIPT" ]]; then
    log_err "Checkpoint script missing: $CHECKPOINT_SCRIPT"
    exit 1
fi
mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$LOG_DIR"

# --- 3. Write the LaunchAgent plist --------------------------------------
# Unquoted heredoc: only $LABEL, $CHECKPOINT_SCRIPT and $LOG_DIR are
# interpolated. The plist XML contains no other shell metacharacters
# ($, backtick, \).
log_wait "Writing LaunchAgent plist: $PLIST"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$CHECKPOINT_SCRIPT</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/checkpoint_launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/checkpoint_launchd.err.log</string>
</dict>
</plist>
EOF
log_ok "Plist written"

# --- 4. Load (or reload) the LaunchAgent ---------------------------------
# bootstrap fails (exit 5) if the label is already loaded, so if it is
# present we bootout first. The bootout is guarded because it must not
# abort the script under `set -e` when nothing was loaded.
if launchctl print "$SERVICE_TARGET" &>/dev/null; then
    log_wait "$LABEL already loaded — reloading"
    launchctl bootout "$SERVICE_TARGET" 2>/dev/null || true
fi
launchctl bootstrap "$DOMAIN" "$PLIST"
log_ok "LaunchAgent loaded: $SERVICE_TARGET"
log_ok "Hourly checkpoint LaunchAgent installed"
