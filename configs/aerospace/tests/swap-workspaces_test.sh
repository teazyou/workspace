#!/bin/bash
# Deterministic mocked coverage for configs/aerospace/swap-workspaces.sh.
# Run: bash configs/aerospace/tests/swap-workspaces_test.sh

set -u

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
SWAP_SCRIPT=$(cd "$TEST_DIR/.." && pwd)/swap-workspaces.sh
MOCK_AEROSPACE="$TEST_DIR/mock-aerospace.sh"
MOCK_SKETCHYBAR="$TEST_DIR/mock-sketchybar.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/aerospace-swap-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

fail() {
    printf 'not ok: %s\n' "$*" >&2
    exit 1
}

ok() {
    printf 'ok: %s\n' "$1"
}

root_of() {
    awk -F'|' -v ws="$1" '$1 == "W" && $2 == ws { print $3; exit }' "$STATE"
}

workspace_of() {
    awk -F'|' -v id="$1" '$1 == "N" && $2 == id { print $3; exit }' "$STATE"
}

parent_of() {
    awk -F'|' -v id="$1" '$1 == "N" && $2 == id { print $4; exit }' "$STATE"
}

fullscreen_of() {
    awk -F'|' -v id="$1" '$1 == "N" && $2 == id { print $5; exit }' "$STATE"
}

order_of() {
    awk -F'|' -v ws="$1" '$1 == "O" && $2 == ws { print $3; exit }' "$STATE"
}

focused_workspace() {
    awk -F'|' '$1 == "F" { print $2; exit }' "$STATE"
}

focused_window() {
    awk -F'|' '$1 == "FW" { print $2; exit }' "$STATE"
}

expect_eq() {
    [ "$1" = "$2" ] || fail "$3 (expected '$2', got '$1')"
}

expect_log() {
    /usr/bin/grep -F -- "$1" "$LOG" >/dev/null || fail "missing mock command: $1"
}

line_number_of() {
    /usr/bin/grep -n -F -- "$1" "$LOG" | /usr/bin/head -n 1 | /usr/bin/cut -d: -f1
}

prepare_case() {
    local name="$1"
    STATE="$TMP_ROOT/$name.state"
    LOG="$TMP_ROOT/$name.commands"
    SKETCHY_LOG="$TMP_ROOT/$name.sketchy"
    : > "$STATE"
    : > "$LOG"
    : > "$SKETCHY_LOG"
    LOCK="$TMP_ROOT/$name.lock"
    SWAP_TEMP_WORKSPACE='aerospace-swap-staging'
}

run_swap() {
    AEROSPACE_BIN="$MOCK_AEROSPACE" \
    SKETCHYBAR_BIN="$MOCK_SKETCHYBAR" \
    MOCK_STATE="$STATE" MOCK_LOG="$LOG" MOCK_SKETCHY_LOG="$SKETCHY_LOG" \
    SWAP_LOCK_DIR="$LOCK" SWAP_TEMP_WORKSPACE="$SWAP_TEMP_WORKSPACE" \
    "$SWAP_SCRIPT" "$1"
}

prepare_case noop
cat > "$STATE" <<'EOF'
W|1|h_tiles
W|2|v_tiles
N|101|1|h_tiles|false
O|1|101
O|2|
F|1
FW|101
EOF
cp "$STATE" "$TMP_ROOT/noop.before"
run_swap 1 || fail 'same-workspace swap failed'
cmp -s "$STATE" "$TMP_ROOT/noop.before" || fail 'same-workspace swap changed state'
if /usr/bin/grep -E '^(workspace|focus|move-node-to-workspace|flatten-workspace-tree|layout|swap|join-with|balance-sizes|fullscreen|move-mouse) ' "$LOG" >/dev/null; then
    fail 'same-workspace swap issued a mutating AeroSpace command'
fi
[ ! -s "$SKETCHY_LOG" ] || fail 'same-workspace swap repainted SketchyBar'
ok 'same digit is an AeroSpace no-op'

prepare_case extra_argument
cat > "$STATE" <<'EOF'
W|1|h_tiles
W|2|v_tiles
N|111|1|h_tiles|false
O|1|111
O|2|
F|1
FW|111
EOF
if AEROSPACE_BIN="$MOCK_AEROSPACE" SKETCHYBAR_BIN="$MOCK_SKETCHYBAR" \
   MOCK_STATE="$STATE" MOCK_LOG="$LOG" MOCK_SKETCHY_LOG="$SKETCHY_LOG" \
   SWAP_LOCK_DIR="$LOCK" SWAP_TEMP_WORKSPACE="$SWAP_TEMP_WORKSPACE" \
   "$SWAP_SCRIPT" 2 ignored; then
    fail 'extra workspace argument was accepted'
fi
[ ! -s "$LOG" ] || fail 'invalid argument count reached AeroSpace'
ok 'exactly one digit argument is required'

prepare_case occupied_reserved_temp
SWAP_TEMP_WORKSPACE='__test_reserved_workspace__'
cat > "$STATE" <<'EOF'
W|1|h_tiles
W|2|v_tiles
W|__test_reserved_workspace__|h_tiles
N|121|1|h_tiles|false
N|221|2|v_tiles|false
N|991|__test_reserved_workspace__|h_tiles|false
O|1|121
O|2|221
O|__test_reserved_workspace__|991
F|1
FW|121
EOF
if run_swap 2; then fail 'occupied reserved temporary workspace was accepted'; fi
expect_eq "$(workspace_of 991)" __test_reserved_workspace__ 'reserved workspace content was preserved'
if /usr/bin/grep -E '^(move-node-to-workspace|flatten-workspace-tree|layout|swap|join-with|balance-sizes|fullscreen) ' "$LOG" >/dev/null; then
    fail 'occupied reserved workspace caused a window/layout mutation'
fi
ok 'occupied stable temporary workspace is refused before mutation'

prepare_case flat
cat > "$STATE" <<'EOF'
W|1|h_tiles
W|2|v_tiles
N|101|1|h_tiles|false
N|102|1|h_tiles|true
N|103|1|floating|false
N|201|2|v_tiles|true
N|202|2|floating|false
O|1|102,101
O|2|201
F|1
FW|102
EOF
MOCK_FAIL_ON='move-mouse window-lazy-center'
export MOCK_FAIL_ON
run_swap 2 || fail 'flat swap failed'
unset MOCK_FAIL_ON
expect_eq "$(root_of 1)" v_tiles 'original workspace received target root'
expect_eq "$(root_of 2)" h_tiles 'target workspace received source root'
expect_eq "$(order_of 1)" '201' 'target tiled DFS was restored at original workspace'
expect_eq "$(order_of 2)" '102,101' 'source tiled DFS was restored at target workspace'
expect_eq "$(parent_of 202)" floating 'target floating window remained floating'
expect_eq "$(parent_of 103)" floating 'source floating window remained floating'
expect_eq "$(fullscreen_of 102)" true 'source fullscreen state was restored'
expect_eq "$(fullscreen_of 201)" true 'target fullscreen state was restored'
expect_eq "$(focused_workspace)" 1 'original workspace stayed focused'
expect_eq "$(focused_window)" 201 'first incoming tiled window received focus'
expect_log 'swap --window-id 102 dfs-prev'
expect_log 'fullscreen off --window-id 102'
expect_log 'fullscreen on --window-id 102'
expect_log 'fullscreen off --window-id 201'
expect_log 'fullscreen on --window-id 201'
expect_log 'move-mouse window-lazy-center'
expect_log 'move-mouse monitor-lazy-center'
first_move_line=$(line_number_of 'move-node-to-workspace --window-id 101 -- aerospace-swap-staging')
source_fullscreen_off_line=$(line_number_of 'fullscreen off --window-id 102')
target_fullscreen_off_line=$(line_number_of 'fullscreen off --window-id 201')
[ "$source_fullscreen_off_line" -lt "$first_move_line" ] || fail 'source fullscreen was not suspended before moving windows'
[ "$target_fullscreen_off_line" -lt "$first_move_line" ] || fail 'target fullscreen was not suspended before moving windows'
if /usr/bin/grep -F -- 'swap --window-id 103 dfs-prev' "$LOG" >/dev/null || \
   /usr/bin/grep -F -- 'swap --window-id 202 dfs-prev' "$LOG" >/dev/null; then
    fail 'floating windows entered tiled DFS swap order'
fi
expect_eq "$(cat "$SKETCHY_LOG")" '--trigger aerospace_workspace_change FOCUSED_WORKSPACE=1' 'success repainted SketchyBar once'
ok 'flat roots, DFS, floating windows, fullscreen, bar and mouse policy swap'

prepare_case grid
cat > "$STATE" <<'EOF'
W|1|h_tiles
W|2|v_tiles
N|301|1|v_tiles|false
N|302|1|v_tiles|false
N|303|1|v_tiles|false
N|304|1|v_tiles|false
N|401|2|v_tiles|false
O|1|302,301,304,303
O|2|401
F|1
FW|302
EOF
run_swap 2 || fail 'grid swap failed'
expect_eq "$(root_of 2)" h_tiles 'normal grid root restored'
for id in 301 302 303 304; do expect_eq "$(parent_of "$id")" v_tiles "normal grid child parent for $id"; done
expect_eq "$(order_of 2)" '302,301,304,303' 'normal grid DFS restored'
expect_log 'join-with --window-id 301 left'
expect_log 'join-with --window-id 303 left'
ok 'h_tiles/v_tiles 2x2 grid swaps and rebuilds'

prepare_case rotated_grid
cat > "$STATE" <<'EOF'
W|1|v_tiles
W|2|h_tiles
N|501|1|h_tiles|false
N|502|1|h_tiles|false
N|503|1|h_tiles|false
N|504|1|h_tiles|false
O|1|502,501,504,503
O|2|
F|1
FW|502
EOF
run_swap 2 || fail 'rotated grid swap failed'
expect_eq "$(root_of 2)" v_tiles 'rotated grid root restored'
for id in 501 502 503 504; do expect_eq "$(parent_of "$id")" h_tiles "rotated grid child parent for $id"; done
expect_log 'join-with --window-id 501 up'
expect_log 'join-with --window-id 503 up'
expect_eq "$(focused_window)" '' 'empty incoming workspace leaves no stale focused window'
expect_log 'move-mouse monitor-lazy-center'
ok 'rotated v_tiles/h_tiles 2x2 grid swaps and rebuilds'

prepare_case unsupported
cat > "$STATE" <<'EOF'
W|1|h_tiles
W|2|v_tiles
N|601|1|v_tiles|false
N|602|1|v_tiles|false
N|603|1|v_tiles|false
N|701|2|v_tiles|false
O|1|601,602,603
O|2|701
F|1
FW|601
EOF
cp "$STATE" "$TMP_ROOT/unsupported.before"
if run_swap 2; then fail 'unsupported nested layout was accepted'; fi
cmp -s "$STATE" "$TMP_ROOT/unsupported.before" || fail 'unsupported layout changed window/layout state'
if /usr/bin/grep -E '^(move-node-to-workspace|flatten-workspace-tree|layout|swap|join-with|balance-sizes|fullscreen) ' "$LOG" >/dev/null; then
    fail 'unsupported layout mutated a window or layout'
fi
expect_eq "$(focused_workspace)" 1 'unsupported layout restored original workspace focus'
ok 'unsupported nesting is rejected before window/layout mutation'

prepare_case rollback
cat > "$STATE" <<'EOF'
W|1|h_tiles
W|2|v_tiles
N|801|1|h_tiles|true
N|802|1|h_tiles|false
N|901|2|v_tiles|false
O|1|802,801
O|2|901
F|1
FW|802
EOF
MOCK_FAIL_WINDOW_ID=801
export MOCK_FAIL_WINDOW_ID
if run_swap 2; then fail 'injected transfer failure was accepted'; fi
unset MOCK_FAIL_WINDOW_ID
expect_eq "$(workspace_of 801)" 1 'rollback returned first source window'
expect_eq "$(workspace_of 802)" 1 'rollback returned second source window'
expect_eq "$(workspace_of 901)" 2 'rollback retained target window'
expect_eq "$(root_of 1)" h_tiles 'rollback restored source root'
expect_eq "$(root_of 2)" v_tiles 'rollback restored target root'
expect_eq "$(fullscreen_of 801)" true 'rollback restored fullscreen state'
expect_eq "$(focused_workspace)" 1 'rollback restored original workspace focus'
expect_log 'move-node-to-workspace --window-id 801 -- 1'
expect_log 'move-node-to-workspace --window-id 802 -- 1'
[ ! -s "$SKETCHY_LOG" ] || fail 'failed swap repainted SketchyBar as success'
ok 'mid-transfer failure performs best-effort rollback'

printf 'all swap-workspaces tests passed\n'
