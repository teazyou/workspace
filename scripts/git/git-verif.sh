#!/bin/sh

pid=$(pgrep -n -f '[g]it-credential-osxkeychain')

if [ -z "$pid" ]; then
  echo "git-credential-osxkeychain is not running."
  echo "Run git-verif while the Keychain popup is open."
  exit 1
fi

echo "git-credential-osxkeychain process chain:"
while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
  ps -ww -p "$pid" -o pid=,ppid=,user=,etime=,command=
  lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n/    cwd: /p'
  pid=$(ps -p "$pid" -o ppid= | tr -d ' ')
done
