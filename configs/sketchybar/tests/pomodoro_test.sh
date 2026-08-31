#!/bin/bash

set -euo pipefail

TEST_DIR=${BASH_SOURCE[0]%/*}
PLUGIN="$TEST_DIR/../plugins/pomodoro.sh"
TMP_BASE=${TMPDIR:-/tmp}
TMP_ROOT=$(mktemp -d "${TMP_BASE%/}/pomodoro-test.XXXXXX")
STATE="$TMP_ROOT/state/pomodoro.state"
BAR="$TMP_ROOT/sketchybar-stub.sh"
NOTIFY="$TMP_ROOT/notify-stub.sh"
BAR_LOG="$TMP_ROOT/bar.log"
NOTIFY_LOG="$TMP_ROOT/notify.log"
ASSERTIONS=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

cat > "$BAR" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$POMODORO_BAR_LOG"
if [ -n "${POMODORO_BAR_DELAY:-}" ]; then
  sleep "$POMODORO_BAR_DELAY"
fi
STUB

cat > "$NOTIFY" <<'STUB'
#!/bin/bash
printf '%s\n' "$1" >> "$POMODORO_NOTIFY_LOG"
STUB

chmod 700 "$BAR" "$NOTIFY"
: > "$BAR_LOG"
: > "$NOTIFY_LOG"

fail() {
  printf 'pomodoro_test: FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  EXPECTED=$1
  ACTUAL=$2
  MESSAGE=$3
  ASSERTIONS=$((ASSERTIONS + 1))
  [ "$EXPECTED" = "$ACTUAL" ] || fail "$MESSAGE (expected '$EXPECTED', got '$ACTUAL')"
}

assert_contains() {
  HAYSTACK=$1
  NEEDLE=$2
  MESSAGE=$3
  ASSERTIONS=$((ASSERTIONS + 1))
  case "$HAYSTACK" in
    *"$NEEDLE"*) ;;
    *) fail "$MESSAGE (missing '$NEEDLE')" ;;
  esac
}

state_value() {
  WANTED_KEY=$1
  while IFS='=' read -r KEY VALUE; do
    if [ "$KEY" = "$WANTED_KEY" ]; then
      printf '%s\n' "$VALUE"
      return 0
    fi
  done < "$STATE"
  return 1
}

assert_state() {
  KEY=$1
  EXPECTED_VALUE=$2
  assert_eq "$EXPECTED_VALUE" "$(state_value "$KEY")" "state $KEY"
}

line_count() {
  COUNT=0
  while IFS= read -r _LINE; do COUNT=$((COUNT + 1)); done < "$1"
  printf '%s\n' "$COUNT"
}

last_line() {
  LAST=
  while IFS= read -r LINE; do LAST=$LINE; done < "$1"
  printf '%s\n' "$LAST"
}

file_mode() {
  MODE=$(stat -f '%Lp' "$1" 2>/dev/null || true)
  case "$MODE" in
    [0-9][0-9][0-9]) printf '%s\n' "$MODE" ;;
    *) stat -c '%a' "$1" ;;
  esac
}

file_inode() {
  INODE=$(stat -f '%i' "$1" 2>/dev/null || true)
  case "$INODE" in
    ''|*[!0-9]*) stat -c '%i' "$1" ;;
    *) printf '%s\n' "$INODE" ;;
  esac
}

run_action() {
  NOW_VALUE=$1
  ACTION_VALUE=$2
  BUTTON_VALUE=${3:-left}
  DELAY_VALUE=${4:-}
  POMODORO_STATE_FILE="$STATE" \
  POMODORO_NOW="$NOW_VALUE" \
  POMODORO_SKETCHYBAR_BIN="$BAR" \
  POMODORO_NOTIFY_BIN="$NOTIFY" \
  POMODORO_BAR_LOG="$BAR_LOG" \
  POMODORO_NOTIFY_LOG="$NOTIFY_LOG" \
  POMODORO_BAR_DELAY="$DELAY_VALUE" \
  BUTTON="$BUTTON_VALUE" \
  /bin/bash "$PLUGIN" "$ACTION_VALUE"
}

# Missing state initializes the secure, paused 45/15 work preset and renders all
# four items in one SketchyBar process.
run_action 1000 sync
assert_state version 1
assert_state preset 45_15
assert_state phase work
assert_state status paused
assert_state remaining 2700
assert_state deadline 0
assert_eq 700 "$(file_mode "${STATE%/*}")" "state directory mode"
assert_eq 600 "$(file_mode "$STATE")" "state file mode"
assert_eq 600 "$(file_mode "${STATE}.lock")" "lock file mode"
assert_eq 1 "$(line_count "$BAR_LOG")" "initial render invocation count"
INITIAL_RENDER=$(last_line "$BAR_LOG")
assert_contains "$INITIAL_RENDER" '--set pomodoro_preset' "preset rendered"
assert_contains "$INITIAL_RENDER" '--set pomodoro_countdown' "countdown rendered"
assert_contains "$INITIAL_RENDER" '--set pomodoro_toggle' "toggle rendered"
assert_contains "$INITIAL_RENDER" '--set pomodoro_reset' "reset rendered"
assert_contains "$INITIAL_RENDER" 'label=45:00' "default countdown"
assert_contains "$INITIAL_RENDER" 'update_freq=0' "paused frequency"
assert_eq 0 "$(line_count "$NOTIFY_LOG")" "no initialization notification"

# Start uses an absolute deadline. A future sync updates display only: the state
# inode and bytes stay untouched while running.
run_action 1000 toggle
assert_state status running
assert_state remaining 2700
assert_state deadline 3700
: > "$BAR_LOG"
BEFORE_INODE=$(file_inode "$STATE")
BEFORE_SUM=$(cksum "$STATE")
run_action 1001 sync
assert_eq "$BEFORE_INODE" "$(file_inode "$STATE")" "running tick inode unchanged"
assert_eq "$BEFORE_SUM" "$(cksum "$STATE")" "running tick bytes unchanged"
TICK_RENDER=$(last_line "$BAR_LOG")
assert_contains "$TICK_RENDER" 'label=44:59' "running countdown"
assert_contains "$TICK_RENDER" 'update_freq=1' "running frequency"

# Pausing snapshots deadline-now; resuming starts that exact remainder.
run_action 1100 toggle
assert_state status paused
assert_state remaining 2600
assert_state deadline 0
run_action 1200 toggle
assert_state status running
assert_state remaining 2600
assert_state deadline 3800

# Toggling at the exact boundary rolls once to a full paused break instead of
# starting it. Further syncs cannot repeat the committed notification.
: > "$NOTIFY_LOG"
run_action 3800 toggle
assert_state phase break
assert_state status paused
assert_state remaining 900
assert_state deadline 0
assert_eq 'Work complete. Break ready: 15:00.' "$(last_line "$NOTIFY_LOG")" "work notification"
run_action 3800 sync
assert_eq 1 "$(line_count "$NOTIFY_LOG")" "work notification not duplicated"

# Break completion follows the same one-rollover policy.
run_action 4000 toggle
assert_state status running
assert_state deadline 4900
: > "$NOTIFY_LOG"
run_action 4900 sync
assert_state phase work
assert_state status paused
assert_state remaining 2700
assert_eq 'Break complete. Work ready: 45:00.' "$(last_line "$NOTIFY_LOG")" "break notification"

# Preset cycling always returns to full work; reset preserves the selected
# preset while discarding elapsed time.
run_action 5000 cycle
assert_state preset 60_20
assert_state phase work
assert_state status paused
assert_state remaining 3600
run_action 5000 cycle
assert_state preset 45_15
assert_state remaining 2700
run_action 5000 cycle
run_action 6000 toggle
run_action 6100 toggle
assert_state remaining 3500
run_action 6200 reset
assert_state preset 60_20
assert_state phase work
assert_state status paused
assert_state remaining 3600
assert_state deadline 0

# Unknown/malformed data is parsed as data, never sourced, and safely replaced
# with the default schema.
MALICIOUS_MARKER="$TMP_ROOT/should-never-run"
printf '%s\n' \
  'version=1' \
  "preset=\$(touch \"$MALICIOUS_MARKER\")" \
  'phase=work' \
  'status=running' \
  'remaining=oops' \
  'deadline=-1' \
  > "$STATE"
chmod 600 "$STATE"
run_action 7000 sync
assert_state preset 45_15
assert_state phase work
assert_state status paused
assert_state remaining 2700
assert_state deadline 0
ASSERTIONS=$((ASSERTIONS + 1))
[ ! -e "$MALICIOUS_MARKER" ] || fail "corrupt state was executed"

# Every mutating action ignores explicit right clicks before touching state or
# rendering the bar.
RIGHT_INODE=$(file_inode "$STATE")
RIGHT_SUM=$(cksum "$STATE")
: > "$BAR_LOG"
run_action 8000 cycle right
run_action 8000 toggle right
run_action 8000 reset right
assert_eq "$RIGHT_INODE" "$(file_inode "$STATE")" "right click inode unchanged"
assert_eq "$RIGHT_SUM" "$(cksum "$STATE")" "right click bytes unchanged"
assert_eq 0 "$(line_count "$BAR_LOG")" "right click does not render"

# Two simultaneous user toggles serialize under the same lock: start then pause
# leaves the original full remainder, rather than losing either transition.
run_action 8500 reset
: > "$BAR_LOG"
run_action 9000 toggle left 0.2 &
PID_ONE=$!
run_action 9000 toggle left 0.2 &
PID_TWO=$!
wait "$PID_ONE"
wait "$PID_TWO"
assert_state status paused
assert_state remaining 2700
assert_state deadline 0
assert_eq 2 "$(line_count "$BAR_LOG")" "concurrent toggles both rendered"

printf 'pomodoro_test: PASS (%s assertions)\n' "$ASSERTIONS"
