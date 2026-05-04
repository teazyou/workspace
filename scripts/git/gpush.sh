#!/bin/bash

run_repo_specific_cleanup() {
  echo $CW8"--- Checking for repository-specific tasks ---"$CWH
  url=$(git config --get remote.origin.url) || return 1
  repo_id=$(echo "$url" | sed -e 's/.*github.com[:\/]//' -e 's/\.git$//')

  echo "Detected repository: $repo_id"

  if [[ "$repo_id" == "michaellinhardt/obsidian_secondbrain" ]]; then
    echo "Target repository detected. Running aggressive cleanup..."
    git gc --prune=now --aggressive
    echo $COK"Cleanup complete."$CWH
  else
    echo "No repository-specific tasks."
  fi
}

run_local_post_push_hook() {
  echo $CW8"--- Checking for local .git/hooks/post-push ---"$CWH
  local hook_path=".git/hooks/post-push"

  if [[ -f "$hook_path" && -x "$hook_path" ]]; then
    echo "Executable post-push hook found. Running it..."
    "$hook_path"
    echo $COK"Local post-push hook finished."$CWH
  else
    echo "No executable post-push hook found."
  fi
}

# --- Main Script ---
sh $SCRIPTS/dstore.sh
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