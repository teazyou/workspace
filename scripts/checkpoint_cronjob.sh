#!/bin/bash

export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"
export SCRIPTS="$HOME/workspace/scripts"

LOG="$HOME/workspace/logs/checkpoint_cron.log"
STATE_DIR="$HOME/workspace/logs/checkpoint_state"
MAX_LINES=1000
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt $MAX_LINES ]; then
  tail -n $MAX_LINES "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
exec >> "$LOG" 2>&1
echo "=== $(date) ==="

source "$SCRIPTS/checkpoint_functions.sh"

mkdir -p "$STATE_DIR"

for folder in "${CHECKPOINT_FOLDERS[@]}"; do
  if [ ! -d "$folder/.git" ]; then
    echo "skip $folder (not a git repo)"
    continue
  fi
  if [ -z "$(git -C "$folder" status --porcelain)" ]; then
    echo "skip $folder (clean)"
    continue
  fi
  # Recency guard: checkpoint a repo only when its working tree is
  # byte-for-byte identical to the previous run -- i.e. nothing changed
  # in the last interval -- so work still in progress is never pushed.
  # Uses a git content fingerprint (see checkpoint_functions.sh) rather
  # than `find -mmin`, which fails inside the iCloud-backed ~/secondbrain
  # when this runs from a background LaunchAgent.
  sig=$(working_tree_signature "$folder")
  sigfile="$STATE_DIR/${folder//\//_}.sig"
  prev=$(cat "$sigfile" 2>/dev/null)
  printf '%s\n' "$sig" > "$sigfile"
  if [ -z "$sig" ]; then
    echo "skip $folder (signature unavailable)"
    continue
  fi
  if [ "$sig" != "$prev" ]; then
    echo "skip $folder (changed since last run)"
    continue
  fi
  echo "checkpointing $folder"
  checkpoint_folder "$folder"
done
