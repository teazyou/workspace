#!/bin/bash
#
# caveman_compress.sh — compress a text file in place through a background
# interactive Claude session running the /caveman-compress slash command
# (configs/dot-claude/commands/caveman-compress.md = ~/.claude/commands/).
#
# Usage:
#   caveman-compress [--opus|--sonnet|--haiku] [--low|--medium|--high|--xhigh|--max] [--<seconds>] <file>
#     model   --opus (default) | --sonnet | --haiku
#     effort  --xhigh (default) | --low | --medium | --high | --max
#     --<int> timeout in seconds before giving up (default 600)
#
# Mechanics: deliberately NOT `claude -p` (print mode soon removed from
# subscription plans). An interactive session needs a TTY for its Ink UI, so
# the call is wrapped in `script -q <log>` (pseudo-TTY — same trick as
# quota_keepalive.sh), which TEES the session to both the log file and the
# terminal: the claude TUI renders live while running, and keystrokes are
# forwarded (an unexpected permission prompt can be answered by hand).
# The target file's mtime+size are recorded up front, then polled every 300 ms:
#   file changed -> short grace (until </result> shows up in the log, max
#                   RESULT_GRACE_SECONDS, so the final answer isn't cut off)
#                -> kill the session -> print what it wrapped in <result></result>
#   timeout      -> kill the session, keep the log for debugging, exit 1
# Kill safety: only the process THIS script started is ever killed — the pty
# wrapper PID must still be a direct child of this shell (guards against PID
# reuse), and its claude child is collected via pgrep -P before the kill.
#
# Env overrides: CAVEMAN_CLAUDE_BIN (claude binary path).

RESULT_GRACE_SECONDS=60

MODEL="opus"
EFFORT="xhigh"
TIMEOUT=600
FILE=""

usage() {
  echo "usage: caveman-compress [--opus|--sonnet|--haiku] [--low|--medium|--high|--xhigh|--max] [--<seconds>] <file>" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --opus|--sonnet|--haiku) MODEL="${1#--}" ;;
    --low|--medium|--high|--xhigh|--max) EFFORT="${1#--}" ;;
    --*)
      n="${1#--}"
      if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -gt 0 ]; then
        TIMEOUT="$n"
      else
        echo "KO unknown option: $1" >&2; usage; exit 2
      fi ;;
    *)
      if [ -n "$FILE" ]; then echo "KO unexpected extra argument: $1" >&2; usage; exit 2; fi
      FILE="$1" ;;
  esac
  shift
done

if [ -z "$FILE" ]; then usage; exit 2; fi
if [ ! -f "$FILE" ]; then echo "KO file not found: $FILE" >&2; exit 1; fi

CLAUDE_BIN="${CAVEMAN_CLAUDE_BIN:-$HOME/.local/bin/claude}"
if [ ! -x "$CLAUDE_BIN" ]; then CLAUDE_BIN="$(command -v claude 2>/dev/null)"; fi
if [ -z "$CLAUDE_BIN" ] || [ ! -x "$CLAUDE_BIN" ]; then
  echo "KO claude binary not found (set CAVEMAN_CLAUDE_BIN)" >&2; exit 1
fi

FILE_ABS="$(cd "$(dirname "$FILE")" && pwd)/$(basename "$FILE")"

stat_sig() { stat -f '%Fm %z' "$FILE_ABS" 2>/dev/null; }
ORIG_SIG="$(stat_sig)"

LOG="$(mktemp -t caveman-compress)"
PROMPT="/caveman-compress $FILE_ABS -- act silently until it's done, there is no human to read your output. Wrap your final answer between <result>...</result>"

script -q "$LOG" "$CLAUDE_BIN" --model "$MODEL" --effort "$EFFORT" \
  --add-dir "$(dirname "$FILE_ABS")" "$PROMPT" &
WRAPPER_PID=$!

# Kill ONLY the session started above: the wrapper must still be a direct
# child of this shell (PID-reuse guard); collect the claude child before
# killing the wrapper (it gets reparented once the wrapper dies and would no
# longer be findable via -P).
kill_claude() {
  [ -n "$WRAPPER_PID" ] || return 0
  if [ "$(ps -o ppid= -p "$WRAPPER_PID" 2>/dev/null | tr -d ' ')" = "$$" ]; then
    CHILD_PIDS=$(pgrep -P "$WRAPPER_PID" 2>/dev/null | tr '\n' ' ')
    kill $CHILD_PIDS "$WRAPPER_PID" 2>/dev/null
    sleep 1
    kill -9 $CHILD_PIDS "$WRAPPER_PID" 2>/dev/null
    wait "$WRAPPER_PID" 2>/dev/null
  fi
  WRAPPER_PID=""
  # The killed TUI leaves the terminal in raw mode / alt-screen / hidden
  # cursor — repair it before printing anything.
  if [ -t 1 ]; then
    stty sane 2>/dev/null
    printf '\033[?1049l\033[?25h\033[0m\n'
  fi
}
trap kill_claude EXIT INT TERM

# Poll every 300 ms until the file's mtime or size changes, the session dies
# on its own, or the timeout elapses.
START_S=$SECONDS
STATUS=""
while :; do
  sleep 0.3
  if ! kill -0 "$WRAPPER_PID" 2>/dev/null; then STATUS="exited"; break; fi
  if [ "$(stat_sig)" != "$ORIG_SIG" ]; then STATUS="changed"; break; fi
  if [ $((SECONDS - START_S)) -ge "$TIMEOUT" ]; then STATUS="timeout"; break; fi
done

# The edit lands before the final answer finishes streaming — give the session
# a short grace to print its </result> before killing it.
if [ "$STATUS" = "changed" ]; then
  G_START=$SECONDS
  while [ $((SECONDS - G_START)) -lt "$RESULT_GRACE_SECONDS" ]; do
    if grep -q '</result>' "$LOG" 2>/dev/null; then sleep 1; break; fi
    kill -0 "$WRAPPER_PID" 2>/dev/null || break
    sleep 0.3
  done
fi

kill_claude

# Strip pty/ANSI escapes from the typescript log, print the LAST
# <result>...</result> block (streaming repaints can render it several times).
extract_result() {
  perl -0777 -e '
    my $t = do { local $/; <STDIN> };
    $t =~ s/\x1b\[[0-9;:?]*[ -\/]*[@-~]//g;
    $t =~ s/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)?//g;
    $t =~ s/\x1b[@-_]//g;
    $t =~ s/\r//g;
    if ($t =~ /.*<result>(.*?)<\/result>/s) {
      my $r = $1;
      $r =~ s/^\s+|\s+$//g;
      print $r, "\n";
    } else {
      exit 1;
    }
  ' < "$LOG"
}

if RESULT="$(extract_result)"; then
  printf '%s\n' "$RESULT"
  rm -f "$LOG"
  exit 0
fi

case "$STATUS" in
  timeout) echo "KO timeout after ${TIMEOUT}s, file never changed — log: $LOG" >&2 ;;
  exited)  echo "KO claude exited without a <result> — log: $LOG" >&2 ;;
  *)       echo "KO no <result> found in session output — log: $LOG" >&2 ;;
esac
exit 1
