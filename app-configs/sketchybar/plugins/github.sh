#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"

NOTIFICATIONS="$(gh api notifications --cache 1m 2>/dev/null)"
COUNT="$(echo "$NOTIFICATIONS" | jq -r 'length' 2>/dev/null)"

render_popup() {
  sketchybar --remove '/github.notification\..*/'

  if [ -z "$NOTIFICATIONS" ] || [ "$NOTIFICATIONS" = "[]" ]; then
    return
  fi

  COUNTER=0
  echo "$NOTIFICATIONS" | jq -rc '.[] | {title: .subject.title, type: .subject.type, url: .subject.url, repo: .repository.full_name}' 2>/dev/null | while read -r notification; do
    TITLE=$(echo "$notification" | jq -r '.title')
    TYPE=$(echo "$notification" | jq -r '.type')
    REPO=$(echo "$notification" | jq -r '.repo')
    URL=$(echo "$notification" | jq -r '.url')

    # Determine icon and color based on type
    case "$TYPE" in
      "Issue") ICON=$GIT_ISSUE; COLOR=$GREEN ;;
      "PullRequest") ICON=$GIT_PULL_REQUEST; COLOR=$MAGENTA ;;
      "Discussion") ICON=$GIT_DISCUSSION; COLOR=$WHITE ;;
      *) ICON=$GIT_COMMIT; COLOR=$WHITE ;;
    esac

    # Check for important keywords
    if [[ "$TITLE" =~ (deprecat|break|broke) ]]; then
      COLOR=$RED
    fi

    # Truncate long titles
    if [ ${#TITLE} -gt 40 ]; then
      TITLE="${TITLE:0:37}..."
    fi

    sketchybar --add item github.notification.$COUNTER popup.github.bell \
               --set github.notification.$COUNTER icon="$ICON" \
                                                   icon.color="$COLOR" \
                                                   label="$TITLE" \
                                                   label.color="$WHITE" \
                                                   background.corner_radius=12 \
                                                   padding_left=7 \
                                                   padding_right=7 \
               --subscribe github.notification.$COUNTER mouse.clicked

    COUNTER=$((COUNTER + 1))
  done
}

update() {
  if [ -z "$COUNT" ] || [ "$COUNT" = "0" ] || [ "$COUNT" = "null" ]; then
    COUNT=0
    sketchybar --set $NAME icon=$BELL label=$COUNT
  else
    sketchybar --set $NAME icon=$BELL_DOT label=$COUNT label.highlight=on
  fi
}

popup_on() {
  sketchybar --set $NAME popup.drawing=on
  render_popup
}

popup_off() {
  sketchybar --set $NAME popup.drawing=off
}

case "$SENDER" in
  "mouse.entered") popup_on
  ;;
  "mouse.exited"|"mouse.exited.global") popup_off
  ;;
  *) update
  ;;
esac
