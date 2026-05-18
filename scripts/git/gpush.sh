#!/bin/bash

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
sh $SCRIPTS/dstore.sh silent
[[ $? != 0 ]] && exit 1

sh $SCRIPTS/git/gstatus.sh

echo $CW8"Executing: git push "$@""$CWH
command git push "$@"
PUSH_SUCCESS=$?

if [[ $PUSH_SUCCESS -eq 0 ]]; then
  echo $COK"Push successful."$CWH
  run_local_post_push_hook
else
  echo $CKO"Push failed."$CWH
  exit 1
fi

echo $COK"Done!"$CWH
exit 0