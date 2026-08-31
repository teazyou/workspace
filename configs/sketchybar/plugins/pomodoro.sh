#!/bin/bash

# One state controller backs all four Pomodoro items. Running state stores an
# absolute deadline, so delayed ticks, sleep, and bar restarts cannot add drift.

ACTION=${1:-sync}
case "$ACTION" in
  sync|cycle|toggle|reset) ;;
  *) exit 2 ;;
esac

# SketchyBar supplies BUTTON to click scripts. Direct/manual invocations have no
# BUTTON and remain useful, but any explicit non-left click is read-only.
if [ "$ACTION" != "sync" ] && [ "${BUTTON:-left}" != "left" ]; then
  exit 0
fi

umask 077

SCRIPT_PATH=${BASH_SOURCE[0]}
case "$SCRIPT_PATH" in
  */*) CONFIG_DIR=${SCRIPT_PATH%/*}/.. ;;
  *) CONFIG_DIR=. ;;
esac

# sketchybarrc exports these in production. Direct test/manual runs source the
# tracked files instead, keeping glyphs and colors centralized.
if [ -z "${POMODORO_WORK:-}" ] || [ -z "${POMODORO_BREAK:-}" ] || \
   [ -z "${POMODORO_PLAY:-}" ] || [ -z "${POMODORO_PAUSE:-}" ] || \
   [ -z "${POMODORO_RESET:-}" ]; then
  source "$CONFIG_DIR/icons.sh"
fi
if [ -z "${PINK:-}" ] || [ -z "${GREEN:-}" ] || [ -z "${GREY:-}" ]; then
  source "$CONFIG_DIR/colors.sh"
fi

if [ -n "${POMODORO_STATE_FILE:-}" ]; then
  STATE_FILE=$POMODORO_STATE_FILE
else
  STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar/pomodoro.state"
fi
case "$STATE_FILE" in
  */*) STATE_DIR=${STATE_FILE%/*} ;;
  *) STATE_DIR=. ;;
esac

LOCK_FILE="${STATE_FILE}.lock"
FALLBACK_LOCK_DIR="${LOCK_FILE}.d"
LOCKF_BIN=${POMODORO_LOCKF_BIN:-/usr/bin/lockf}
SKETCHYBAR_BIN=${POMODORO_SKETCHYBAR_BIN:-sketchybar}
LOCK_HELD=
STATE_TEMP=
NOTIFICATION=

release_lock() {
  if [ "$LOCK_HELD" = "fd" ]; then
    exec 9>&-
  elif [ "$LOCK_HELD" = "directory" ]; then
    rm -f "$FALLBACK_LOCK_DIR/pid" 2>/dev/null
    rmdir "$FALLBACK_LOCK_DIR" 2>/dev/null
  fi
  LOCK_HELD=

  if [ -n "$STATE_TEMP" ] && [ -f "$STATE_TEMP" ]; then
    rm -f "$STATE_TEMP" 2>/dev/null
  fi
  STATE_TEMP=
}

trap 'release_lock' EXIT
trap 'exit 130' HUP INT TERM

if [ ! -d "$STATE_DIR" ]; then
  mkdir -p "$STATE_DIR" || exit 1
  chmod 700 "$STATE_DIR" || exit 1
fi

if [ ! -e "$LOCK_FILE" ]; then
  # Also correct a pre-existing sketchybar state directory on first use.
  chmod 700 "$STATE_DIR" || exit 1
  : > "$LOCK_FILE" || exit 1
  chmod 600 "$LOCK_FILE" || exit 1
fi

acquire_lock() {
  LOCK_WAIT=0
  [ "$ACTION" != "sync" ] && LOCK_WAIT=2

  if [ -x "$LOCKF_BIN" ]; then
    exec 9>>"$LOCK_FILE" || return 1
    if "$LOCKF_BIN" -s -t "$LOCK_WAIT" 9 >/dev/null 2>&1; then
      LOCK_HELD=fd
      return 0
    fi
    exec 9>&-
    return 1
  fi

  # macOS provides lockf. This mkdir fallback keeps direct tests usable on
  # other Unix hosts and removes dead owners rather than leaving stale locks.
  LOCK_ATTEMPTS=1
  [ "$ACTION" != "sync" ] && LOCK_ATTEMPTS=21
  while [ "$LOCK_ATTEMPTS" -gt 0 ]; do
    if mkdir "$FALLBACK_LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$$" > "$FALLBACK_LOCK_DIR/pid"
      chmod 600 "$FALLBACK_LOCK_DIR/pid" 2>/dev/null
      LOCK_HELD=directory
      return 0
    fi

    LOCK_OWNER=
    if [ -r "$FALLBACK_LOCK_DIR/pid" ]; then
      IFS= read -r LOCK_OWNER < "$FALLBACK_LOCK_DIR/pid"
    fi
    case "$LOCK_OWNER" in
      ''|*[!0-9]*) ;;
      *)
        if ! kill -0 "$LOCK_OWNER" 2>/dev/null; then
          rm -f "$FALLBACK_LOCK_DIR/pid" 2>/dev/null
          rmdir "$FALLBACK_LOCK_DIR" 2>/dev/null
          continue
        fi
        ;;
    esac

    LOCK_ATTEMPTS=$((LOCK_ATTEMPTS - 1))
    [ "$LOCK_ATTEMPTS" -gt 0 ] && sleep 0.1
  done
  return 1
}

acquire_lock || exit 0

is_uint() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    0) return 0 ;;
    0*) return 1 ;;
    *) return 0 ;;
  esac
}

duration_for() {
  DURATION=0
  case "$PRESET:$PHASE" in
    45_15:work) DURATION=2700 ;;
    45_15:break) DURATION=900 ;;
    60_20:work) DURATION=3600 ;;
    60_20:break) DURATION=1200 ;;
  esac
}

set_default_state() {
  PRESET=45_15
  PHASE=work
  STATUS=paused
  REMAINING=2700
  DEADLINE=0
}

load_state() {
  STATE_NEEDS_SAVE=0
  if [ ! -f "$STATE_FILE" ]; then
    set_default_state
    STATE_NEEDS_SAVE=1
    return
  fi

  RAW_VERSION=
  RAW_PRESET=
  RAW_PHASE=
  RAW_STATUS=
  RAW_REMAINING=
  RAW_DEADLINE=
  SEEN_VERSION=0
  SEEN_PRESET=0
  SEEN_PHASE=0
  SEEN_STATUS=0
  SEEN_REMAINING=0
  SEEN_DEADLINE=0
  PARSE_ERROR=0

  while IFS='=' read -r STATE_KEY STATE_VALUE; do
    case "$STATE_KEY" in
      version)
        [ "$SEEN_VERSION" -eq 0 ] || PARSE_ERROR=1
        SEEN_VERSION=1
        RAW_VERSION=$STATE_VALUE
        ;;
      preset)
        [ "$SEEN_PRESET" -eq 0 ] || PARSE_ERROR=1
        SEEN_PRESET=1
        RAW_PRESET=$STATE_VALUE
        ;;
      phase)
        [ "$SEEN_PHASE" -eq 0 ] || PARSE_ERROR=1
        SEEN_PHASE=1
        RAW_PHASE=$STATE_VALUE
        ;;
      status)
        [ "$SEEN_STATUS" -eq 0 ] || PARSE_ERROR=1
        SEEN_STATUS=1
        RAW_STATUS=$STATE_VALUE
        ;;
      remaining)
        [ "$SEEN_REMAINING" -eq 0 ] || PARSE_ERROR=1
        SEEN_REMAINING=1
        RAW_REMAINING=$STATE_VALUE
        ;;
      deadline)
        [ "$SEEN_DEADLINE" -eq 0 ] || PARSE_ERROR=1
        SEEN_DEADLINE=1
        RAW_DEADLINE=$STATE_VALUE
        ;;
      *) PARSE_ERROR=1 ;;
    esac
  done < "$STATE_FILE"

  [ "$SEEN_VERSION" -eq 1 ] || PARSE_ERROR=1
  [ "$SEEN_PRESET" -eq 1 ] || PARSE_ERROR=1
  [ "$SEEN_PHASE" -eq 1 ] || PARSE_ERROR=1
  [ "$SEEN_STATUS" -eq 1 ] || PARSE_ERROR=1
  [ "$SEEN_REMAINING" -eq 1 ] || PARSE_ERROR=1
  [ "$SEEN_DEADLINE" -eq 1 ] || PARSE_ERROR=1
  [ "$RAW_VERSION" = "1" ] || PARSE_ERROR=1
  case "$RAW_PRESET" in 45_15|60_20) ;; *) PARSE_ERROR=1 ;; esac
  case "$RAW_PHASE" in work|break) ;; *) PARSE_ERROR=1 ;; esac
  case "$RAW_STATUS" in paused|running) ;; *) PARSE_ERROR=1 ;; esac
  is_uint "$RAW_REMAINING" || PARSE_ERROR=1
  is_uint "$RAW_DEADLINE" || PARSE_ERROR=1

  if [ "$PARSE_ERROR" -eq 0 ]; then
    PRESET=$RAW_PRESET
    PHASE=$RAW_PHASE
    STATUS=$RAW_STATUS
    REMAINING=$RAW_REMAINING
    DEADLINE=$RAW_DEADLINE
    duration_for
    [ "$REMAINING" -gt 0 ] || PARSE_ERROR=1
    [ "$REMAINING" -le "$DURATION" ] || PARSE_ERROR=1
    if [ "$STATUS" = "paused" ]; then
      [ "$DEADLINE" -eq 0 ] || PARSE_ERROR=1
    else
      [ "$DEADLINE" -gt 0 ] || PARSE_ERROR=1
    fi
  fi

  if [ "$PARSE_ERROR" -ne 0 ]; then
    set_default_state
    STATE_NEEDS_SAVE=1
  fi
}

save_state() {
  STATE_TEMP=$(mktemp "${STATE_FILE}.tmp.XXXXXX") || return 1
  chmod 600 "$STATE_TEMP" || return 1
  if ! {
    printf 'version=1\n'
    printf 'preset=%s\n' "$PRESET"
    printf 'phase=%s\n' "$PHASE"
    printf 'status=%s\n' "$STATUS"
    printf 'remaining=%s\n' "$REMAINING"
    printf 'deadline=%s\n' "$DEADLINE"
  } > "$STATE_TEMP"; then
    return 1
  fi
  mv -f "$STATE_TEMP" "$STATE_FILE" || return 1
  STATE_TEMP=
  return 0
}

format_seconds() {
  FORMAT_MINUTES=$(( $1 / 60 ))
  FORMAT_SECONDS=$(( $1 % 60 ))
  printf -v FORMATTED '%02d:%02d' "$FORMAT_MINUTES" "$FORMAT_SECONDS"
}

rollover() {
  STATUS=paused
  DEADLINE=0
  if [ "$PHASE" = "work" ]; then
    PHASE=break
    duration_for
    REMAINING=$DURATION
    format_seconds "$REMAINING"
    NOTIFICATION="Work complete. Break ready: $FORMATTED."
  else
    PHASE=work
    duration_for
    REMAINING=$DURATION
    format_seconds "$REMAINING"
    NOTIFICATION="Break complete. Work ready: $FORMATTED."
  fi
}

if [ -n "${POMODORO_NOW:-}" ]; then
  NOW=$POMODORO_NOW
  is_uint "$NOW" || exit 2
else
  NOW=$(date +%s) || exit 1
fi

load_state
SAVE_REQUIRED=$STATE_NEEDS_SAVE

case "$ACTION" in
  sync)
    if [ "$STATUS" = "running" ] && [ "$NOW" -ge "$DEADLINE" ]; then
      rollover
      SAVE_REQUIRED=1
    fi
    ;;
  cycle)
    if [ "$PRESET" = "45_15" ]; then PRESET=60_20; else PRESET=45_15; fi
    PHASE=work
    STATUS=paused
    DEADLINE=0
    duration_for
    REMAINING=$DURATION
    SAVE_REQUIRED=1
    ;;
  toggle)
    if [ "$STATUS" = "running" ]; then
      if [ "$NOW" -ge "$DEADLINE" ]; then
        rollover
      else
        REMAINING=$((DEADLINE - NOW))
        STATUS=paused
        DEADLINE=0
      fi
    else
      STATUS=running
      DEADLINE=$((NOW + REMAINING))
    fi
    SAVE_REQUIRED=1
    ;;
  reset)
    PHASE=work
    STATUS=paused
    DEADLINE=0
    duration_for
    REMAINING=$DURATION
    SAVE_REQUIRED=1
    ;;
esac

if [ "$SAVE_REQUIRED" -eq 1 ]; then
  save_state || exit 1
fi

render() {
  case "$PRESET" in
    45_15) PRESET_LABEL=45/15 ;;
    60_20) PRESET_LABEL=60/20 ;;
  esac

  if [ "$PHASE" = "work" ]; then
    PHASE_ICON=$POMODORO_WORK
    PHASE_COLOR=$PINK
  else
    PHASE_ICON=$POMODORO_BREAK
    PHASE_COLOR=$GREEN
  fi

  if [ "$STATUS" = "running" ]; then
    DISPLAY_REMAINING=$((DEADLINE - NOW))
    UPDATE_FREQ=1
    TOGGLE_ICON=$POMODORO_PAUSE
    TOGGLE_COLOR=$PHASE_COLOR
    COUNTDOWN_COLOR=$PHASE_COLOR
  else
    DISPLAY_REMAINING=$REMAINING
    UPDATE_FREQ=0
    TOGGLE_ICON=$POMODORO_PLAY
    TOGGLE_COLOR=$GREEN
    COUNTDOWN_COLOR=$GREY
  fi
  format_seconds "$DISPLAY_REMAINING"

  "$SKETCHYBAR_BIN" \
    --set pomodoro_preset icon="$PHASE_ICON" icon.color="$PHASE_COLOR" label="$PRESET_LABEL" label.color="$PHASE_COLOR" \
    --set pomodoro_countdown label="$FORMATTED" label.color="$COUNTDOWN_COLOR" update_freq="$UPDATE_FREQ" \
    --set pomodoro_toggle icon="$TOGGLE_ICON" icon.color="$TOGGLE_COLOR" \
    --set pomodoro_reset icon="$POMODORO_RESET" icon.color="$GREY" \
    >/dev/null 2>&1
}

render
release_lock
trap - EXIT HUP INT TERM

notify() {
  [ -n "$1" ] || return 0
  [ "${POMODORO_NOTIFICATIONS:-1}" != "0" ] || return 0

  if [ -n "${POMODORO_NOTIFY_BIN:-}" ]; then
    "$POMODORO_NOTIFY_BIN" "$1" >/dev/null 2>&1 || true
  elif [ -x /usr/bin/osascript ]; then
    /usr/bin/osascript \
      -e 'on run argv' \
      -e 'display notification (item 1 of argv) with title "Pomodoro"' \
      -e 'end run' \
      "$1" >/dev/null 2>&1 || true
  fi
}

notify "$NOTIFICATION"
