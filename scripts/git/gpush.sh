#!/bin/bash

# Runs a cleanup tailored to the repository being pushed, matched on its
# "<owner>/<name>" id derived from the origin URL. This is a generic
# extension point: add a repo by appending an `if` block that matches
# its repo_id and runs whatever that repo needs. Each block must end with
# `return` so that, once one repo matches, the remaining blocks are
# skipped; the closing echo is reached only when no block matched.
run_repo_specific_cleanup() {
  echo $CW8"--- Checking for repository-specific tasks ---"$CWH
  url=$(git config --get remote.origin.url) || return 1
  repo_id=$(echo "$url" | sed -e 's/.*github.com[:\/]//' -e 's/\.git$//')

  echo $CW8"Detected repository: $repo_id"$CWH

  # --- teazyou/obsidian_secondbrain ------------------------------------
  # Disabled on purpose: the hourly checkpoint job pushes this repo every
  # idle hour, so an aggressive gc here would run on the vault hourly --
  # git's built-in auto-gc is enough. Kept as a working template for
  # re-enabling it, or for adding a cleanup for another repository.
  # if [[ "$repo_id" == "teazyou/obsidian_secondbrain" ]]; then
  #   echo $CW8"Target repository detected. Running aggressive cleanup..."$CWH
  #   git gc --prune=now --aggressive
  #   echo $COK"Cleanup complete."$CWH
  #   return 0
  # fi

  echo $CW8"No repository-specific tasks detected."$CWH
}

run_local_post_push_hook() {
  echo $CW8"--- Checking for local .git/hooks/post-push ---"$CWH
  local hook_path=".git/hooks/post-push"

  if [[ -f "$hook_path" && -x "$hook_path" ]]; then
    echo $CW8"Executable post-push hook found. Running it..."$CWH
    "$hook_path"
    echo $COK"Local post-push hook finished."$CWH
  else
    echo $CW8"No executable post-push hook found."$CWH
  fi
}

# --- Main Script ---
sh $SCRIPTS/dstore.sh silent
[[ $? != 0 ]] && exit 1

sh $SCRIPTS/git/gstatus.sh

echo $CW8"Executing: git push "$@""$CWH
command git push "$@"
PUSH_SUCCESS=$?

if [[ $PUSH_SUCCESS -eq 0 ]]; then
  echo $COK"Push successful."$CWH
  run_repo_specific_cleanup
  run_local_post_push_hook
else
  echo $CKO"Push failed."$CWH
  exit 1
fi

echo $COK"Done!"$CWH
exit 0