#!/bin/bash

export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"
export SCRIPTS="$HOME/workspace/scripts"

LOG="$HOME/workspace/logs/checkpoint_cron.log"
MAX_LINES=1000
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt $MAX_LINES ]; then
  tail -n $MAX_LINES "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
exec >> "$LOG" 2>&1
echo "=== $(date) ==="

source "$SCRIPTS/checkpoint_functions.sh"

for folder in "${CHECKPOINT_FOLDERS[@]}"; do
  if [ ! -d "$folder/.git" ]; then
    echo "skip $folder (not a git repo)"
    continue
  fi
  cd "$folder" || continue
  if [ -z "$(git status --porcelain)" ]; then
    echo "skip $folder (clean)"
    cd - > /dev/null
    continue
  fi
  recent=$(find . -path './.git' -prune -o -path './logs' -prune -o -mmin -60 -type f -print -quit)
  if [ -n "$recent" ]; then
    echo "skip $folder (recent activity)"
    cd - > /dev/null
    continue
  fi
  cd - > /dev/null
  echo "checkpointing $folder"
  checkpoint_folder "$folder"
done
