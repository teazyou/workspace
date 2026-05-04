git() {
  if [ "$1" = "push" ]; then
    shift
    sh "$SCRIPTS/git/gpush.sh" "$@"
  else
    command git "$@"
  fi
}

alias gad="git add $@"
alias gst="sh $SCRIPTS/git/gstatus.sh"
alias gco="sh $SCRIPTS/git/gcommit.sh"
alias gpu="sh $SCRIPTS/git/gpush.sh $@"

alias gdelete="sh $SCRIPTS/git/gdelete.sh"
alias gcreate="sh $SCRIPTS/git/gcreate.sh"
alias gbranch="git remote prune origin && git branch -a"
alias gclean="git gc --prune=now --aggressive"