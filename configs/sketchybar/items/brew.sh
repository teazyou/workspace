#!/bin/bash

# Trigger the brew_update event when running `brew update` or `brew upgrade`
# Add the following lines to your .zshrc:
# function brew() {
#   command brew "$@"
#   if [[ $* =~ "upgrade" ]] || [[ $* =~ "update" ]] || [[ $* =~ "outdated" ]]; then
#     sketchybar --trigger brew_update
#   fi
# }

brew=(
  icon=󰏗
  label=?
  padding_right=10
  script="$PLUGIN_DIR/brew.sh"
)

sketchybar --add event brew_update            \
           --add item brew right              \
           --set brew "${brew[@]}"            \
           --subscribe brew brew_update
