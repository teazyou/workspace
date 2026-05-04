#!/bin/bash

source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/colors.sh"

next() {
  osascript -e 'tell application "Spotify" to next track'
}

back() {
  osascript -e 'tell application "Spotify" to previous track'
}

play() {
  osascript -e 'tell application "Spotify" to playpause'
}

repeat() {
  REPEAT=$(osascript -e 'tell application "Spotify" to get repeating')
  if [ "$REPEAT" = "true" ]; then
    osascript -e 'tell application "Spotify" to set repeating to false'
    sketchybar --set spotify.repeat icon.highlight=off
  else
    osascript -e 'tell application "Spotify" to set repeating to true'
    sketchybar --set spotify.repeat icon.highlight=on
  fi
}

shuffle() {
  SHUFFLE=$(osascript -e 'tell application "Spotify" to get shuffling')
  if [ "$SHUFFLE" = "true" ]; then
    osascript -e 'tell application "Spotify" to set shuffling to false'
    sketchybar --set spotify.shuffle icon.highlight=off
  else
    osascript -e 'tell application "Spotify" to set shuffling to true'
    sketchybar --set spotify.shuffle icon.highlight=on
  fi
}

update() {
  RUNNING=$(pgrep -x "Spotify")
  if [ -z "$RUNNING" ]; then
    sketchybar --set spotify.anchor drawing=off
    return
  fi

  PLAYER_STATE=$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null)
  if [ "$PLAYER_STATE" = "" ]; then
    sketchybar --set spotify.anchor drawing=off
    return
  fi

  sketchybar --set spotify.anchor drawing=on

  TRACK=$(osascript -e 'tell application "Spotify" to name of current track')
  ARTIST=$(osascript -e 'tell application "Spotify" to artist of current track')
  ALBUM=$(osascript -e 'tell application "Spotify" to album of current track')
  ARTWORK=$(osascript -e 'tell application "Spotify" to artwork url of current track')
  SHUFFLE=$(osascript -e 'tell application "Spotify" to get shuffling')
  REPEAT=$(osascript -e 'tell application "Spotify" to get repeating')

  # Truncate long text
  if [ ${#TRACK} -gt 25 ]; then
    TRACK="${TRACK:0:22}..."
  fi
  if [ ${#ARTIST} -gt 25 ]; then
    ARTIST="${ARTIST:0:22}..."
  fi
  if [ ${#ALBUM} -gt 25 ]; then
    ALBUM="${ALBUM:0:22}..."
  fi

  # Download artwork
  ARTWORK_PATH="/tmp/spotify_artwork.png"
  if [ -n "$ARTWORK" ]; then
    curl -s "$ARTWORK" -o "$ARTWORK_PATH" 2>/dev/null
  fi

  # Update play button icon
  if [ "$PLAYER_STATE" = "playing" ]; then
    PLAY_ICON="󰏤"
  else
    PLAY_ICON=$SPOTIFY_PLAY_PAUSE
  fi

  # Update shuffle/repeat highlights
  SHUFFLE_HIGHLIGHT="off"
  REPEAT_HIGHLIGHT="off"
  if [ "$SHUFFLE" = "true" ]; then
    SHUFFLE_HIGHLIGHT="on"
  fi
  if [ "$REPEAT" = "true" ]; then
    REPEAT_HIGHLIGHT="on"
  fi

  sketchybar --set spotify.title label="$TRACK" \
             --set spotify.artist label="$ARTIST" \
             --set spotify.album label="$ALBUM" \
             --set spotify.cover background.image="$ARTWORK_PATH" \
             --set spotify.play icon="$PLAY_ICON" \
             --set spotify.shuffle icon.highlight=$SHUFFLE_HIGHLIGHT \
             --set spotify.repeat icon.highlight=$REPEAT_HIGHLIGHT
}

scroll() {
  DURATION=$(osascript -e 'tell application "Spotify" to duration of current track' | cut -d. -f1)
  POSITION=$(osascript -e 'tell application "Spotify" to player position' | cut -d. -f1)

  if [ -n "$DURATION" ] && [ "$DURATION" -gt 0 ]; then
    PERCENTAGE=$((POSITION * 100 / DURATION))
    ELAPSED=$(printf "%d:%02d" $((POSITION / 60)) $((POSITION % 60)))
    TOTAL=$(printf "%d:%02d" $((DURATION / 1000 / 60)) $((DURATION / 1000 % 60)))

    sketchybar --set spotify.state slider.percentage=$PERCENTAGE \
               --set spotify.state label="$ELAPSED / $TOTAL"
  fi
}

scrubbing() {
  DURATION=$(osascript -e 'tell application "Spotify" to duration of current track' | cut -d. -f1)
  TARGET=$((DURATION * PERCENTAGE / 100 / 1000))
  osascript -e "tell application \"Spotify\" to set player position to $TARGET"
}

mouse_clicked() {
  case "$NAME" in
    "spotify.next") next ;;
    "spotify.back") back ;;
    "spotify.play") play ;;
    "spotify.shuffle") shuffle ;;
    "spotify.repeat") repeat ;;
    "spotify.state") scrubbing ;;
    *) update ;;
  esac
}

mouse_entered() {
  sketchybar --set spotify.anchor popup.drawing=on
  update
}

mouse_exited() {
  sketchybar --set spotify.anchor popup.drawing=off
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked ;;
  "mouse.entered") mouse_entered; update ;;
  "mouse.exited"|"mouse.exited.global") mouse_exited ;;
  "routine"|"forced") scroll ;;
  *) update ;;
esac
