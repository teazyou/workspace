#!/bin/bash

CHECKPOINT_FOLDERS=(
  "$HOME/workspace"
  "$HOME/secondbrain"
)

# Content fingerprint of a repo's entire working tree -- every tracked
# change plus every untracked file -- computed with git alone.
#
# The checkpoint loop compares this fingerprint between hourly runs: an
# identical fingerprint means nothing was touched in the last interval,
# so the repo is safe to commit; a different one means work is still in
# progress and the repo is skipped.
#
# Why git and not `find -mmin`: ~/secondbrain is a symlink into iCloud
# Drive, a TCC-protected location. A background LaunchAgent cannot walk
# it with `find` ("Operation not permitted"), but git keeps working.
# Staging into a throwaway index leaves the repo's real index untouched,
# and `git add -A` honours .gitignore, so ignored paths (logs/, the
# state dir, ...) never affect the fingerprint.
working_tree_signature() {
  local folder="$1" tmp_index sig
  tmp_index="$(mktemp -u "${TMPDIR:-/tmp}/checkpoint-index.XXXXXX")"
  GIT_INDEX_FILE="$tmp_index" git -C "$folder" add -A 2>/dev/null
  sig="$(GIT_INDEX_FILE="$tmp_index" git -C "$folder" write-tree 2>/dev/null)"
  rm -f "$tmp_index"
  printf '%s\n' "$sig"
}

checkpoint_folder() {
  local folder="$1"
  printf "%b[ checkpoint ] %s%b\n" "$CW8" "$folder" "$CWH"
  cd "$folder" || return 1
  git add -A \
    && sh "$SCRIPTS/git/gcommit.sh" "checkpoint" \
    && sh "$SCRIPTS/git/gpush.sh"
  cd - > /dev/null
}
