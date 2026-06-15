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
  # Single eligibility gate: checkpoint a repo only when its working-tree
  # content fingerprint is byte-for-byte identical to the previous run --
  # i.e. nothing was modified in the last interval -- so work still in
  # progress is never committed/pushed.
  #
  # There is deliberately no "skip if clean" check: a clean repo is still
  # checkpointed so that a commit left unpushed by an earlier network
  # failure gets retried -- checkpoint_folder always runs git push.
  #
  # The fingerprint is a git content hash (see checkpoint_functions.sh)
  # rather than `find -mmin`, so .gitignored paths don't affect it.
  sig=$(working_tree_signature "$folder")
  sigfile="$STATE_DIR/${folder//\//_}.sig"
  prev=$(cat "$sigfile" 2>/dev/null)
  printf '%s\n' "$sig" > "$sigfile"
  if [ -z "$sig" ]; then
    echo "skip $folder (signature unavailable)"
    continue
  fi
  if [ "$sig" != "$prev" ]; then
    echo "skip $folder (modified in the last hour)"
    continue
  fi
  echo "checkpointing $folder"
  checkpoint_folder "$folder"
done
