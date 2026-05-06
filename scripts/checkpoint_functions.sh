#!/bin/bash

CHECKPOINT_FOLDERS=(
  "$HOME/workspace"
  "$HOME/secondbrain"
)

checkpoint_folder() {
  local folder="$1"
  printf "%b[ checkpoint ] %s%b\n" "$CW8" "$folder" "$CWH"
  cd "$folder" || return 1
  git add -A \
    && sh "$SCRIPTS/git/gcommit.sh" "checkpoint" \
    && sh "$SCRIPTS/git/gpush.sh"
  cd - > /dev/null
}
