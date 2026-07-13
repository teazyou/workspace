#!/bin/bash
# Claude Code status line: context-window usage, text only.
# Wired via statusLine.command in configs/dot-claude/settings.json (= ~/.claude/settings.json).
# Claude Code pipes a JSON payload on stdin after each assistant message (300ms debounce);
# whatever this prints on stdout IS the status line (ANSI colors supported).
# Relevant payload fields: .model.display_name, .effort.level (live session effort;
# absent when the model has no effort param), .context_window.{total_input_tokens,
# context_window_size, used_percentage} — used_percentage is pre-computed as
# (input + cache_creation + cache_read) / context_window_size.

input=$(cat)
command -v jq >/dev/null 2>&1 || { echo "statusline: jq missing"; exit 0; }

model=$(jq -r '.model.display_name // "?"' <<<"$input")
effort=$(jq -r '.effort.level // empty' <<<"$input")
size=$(jq -r '.context_window.context_window_size // 0' <<<"$input")
used=$(jq -r '.context_window.total_input_tokens // 0' <<<"$input")
pct=$(jq -r '.context_window.used_percentage // 0' <<<"$input")
pct=${pct%.*}                      # payload may send a float; the colour thresholds need an int
[ -z "$pct" ] && pct=0

# 250000 -> 250k, 1000000 -> 1M
hum() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    awk -v n="$n" 'BEGIN { printf (n % 1000000 ? "%.1fM" : "%.0fM"), n / 1000000 }'
  elif [ "$n" -ge 1000 ]; then
    printf '%dk' $(( (n + 500) / 1000 ))
  else
    printf '%d' "$n"
  fi
}

if   [ "$pct" -ge 80 ]; then color=$'\033[31m'   # red
elif [ "$pct" -ge 50 ]; then color=$'\033[33m'   # yellow
else                         color=$'\033[32m'   # green
fi
grey=$'\033[38;5;250m'; reset=$'\033[0m'

left="${grey}${model}${reset}"
[ -n "$effort" ] && left+=" ${grey}${effort}${reset}"

printf '%s\n' "${left} ${color}${pct}%${reset} ${grey}$(hum "$used")/$(hum "$size")${reset}"
