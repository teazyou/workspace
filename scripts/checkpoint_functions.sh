#!/bin/bash

CHECKPOINT_FOLDERS=(
  # dot-claude (private submodule) is checkpointed BEFORE $HOME/workspace so its
  # commit is pushed before the parent repo records the bumped gitlink.
  "$HOME/workspace/configs/dot-claude"
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
# Why a git content hash and not `find -mmin`: staging into a throwaway
# index leaves the repo's real index untouched, and `git add -A` honours
# .gitignore, so ignored paths (logs/, the state dir, ...) never affect
# the fingerprint.
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
  # A normal repo has a .git directory; a submodule working tree has a .git
  # *file* (a "gitdir:" pointer). Accept either, or git would skip submodules.
  if [ ! -e "$folder/.git" ]; then
    echo "skip $folder (not a git repo)"
    return 1
  fi
  cd "$folder" || return 1
  # Stage and commit. gcommit.sh exits non-zero when there is nothing to
  # commit, so the steps are not `&&`-chained -- that exit code must not
  # gate the push decision below.
  git add -A
  sh "$SCRIPTS/git/gcommit.sh" "checkpoint"
  # Push only when the local branch is ahead of its upstream. This covers
  # both a fresh checkpoint commit and one left behind by an earlier
  # failed push: a failed push does not advance the upstream ref, so its
  # commits still count here. `git rev-list` is a local, network-free
  # query, so an idle repo no longer does a pointless `git push` round
  # trip every run. The test fails open -- if the count cannot be
  # determined (no upstream, detached HEAD) the substitution is empty,
  # "" != "0" holds, and gpush.sh still runs.
  if [ "$(git rev-list --count @{u}..HEAD 2>/dev/null)" != "0" ]; then
    sh "$SCRIPTS/git/gpush.sh"
  else
    printf "%bNo push, already up to date%b\n" "$CKO" "$CWH"
  fi
  cd - > /dev/null
}
