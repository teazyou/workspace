#!/bin/bash

CHECKPOINT_FOLDERS=(
  "$HOME/workspace"
  "$HOME/secondbrain"
)

checkpoint_folder() {
  local folder="$1"
  echo "$CW8[ checkpoint ] $folder$CWH"
  cd "$folder" || return 1
  git add -A \
    && sh "$SCRIPTS/git/gcommit.sh" "checkpoint" \
    && sh "$SCRIPTS/git/gpush.sh"
  cd - > /dev/null
}
