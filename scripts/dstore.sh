#!/bin/bash
# dstore.sh — remove macOS .DS_Store / _DS_Store files from the current
# directory tree.
#
# Usage:
#   dstore.sh          verbose: echoes each step (default — manual use)
#   dstore.sh silent   quiet: prints only "dstore running silently.."
#                      and suppresses step echoes and errors
#                      (used by the git scripts)

if [ "$1" = "silent" ]; then
  echo $CW8"dstore running silently.."$CWH
  find ./ -name ".DS_Store" -depth -exec rm {} \; 2>/dev/null
  find ./ -name "_DS_Store" -depth -exec rm {} \; 2>/dev/null
  exit 0
fi

echo $CW8"find ./ -name \".DS_Store\" -depth -exec rm {} \;"$CWH
find ./ -name ".DS_Store" -depth -exec rm {} \;
echo $CW8"find ./ -name \"_DS_Store\" -depth -exec rm {} \;"$CWH
find ./ -name "_DS_Store" -depth -exec rm {} \;
echo $COK "Done!"$CWH
exit 0;
