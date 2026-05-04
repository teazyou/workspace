#!/bin/bash

SPOTIFY_EVENT="com.spotify.client.PlaybackStateChanged"
POPUP_SCRIPT="sketchybar --set spotify.anchor popup.drawing=toggle"

spotify_anchor=(
  script="$PLUGIN_DIR/spotify.sh"
  click_script="$POPUP_SCRIPT"
  popup.horizontal=on
  popup.align=center
  popup.height=120
  popup.background.color=$POPUP_BACKGROUND_COLOR
  popup.background.corner_radius=12
  popup.background.border_width=2
  popup.background.border_color=$POPUP_BORDER_COLOR
  popup.background.shadow.drawing=on
  icon=󰓇
  icon.font="$FONT:Bold:18.0"
  icon.padding_left=20
  label.drawing=off
  label.padding_right=20
)

spotify_cover=(
  script="$PLUGIN_DIR/spotify.sh"
  click_script="open -a 'Spotify'; $POPUP_SCRIPT"
  label.drawing=off
  icon.drawing=off
  padding_left=12
  padding_right=10
  background.image.scale=0.2
  background.image.drawing=on
  background.drawing=on
)

spotify_title=(
  icon.drawing=off
  padding_left=0
  padding_right=0
  width=0
  label.font="$FONT:Heavy:15.0"
  y_offset=40
)

spotify_artist=(
  icon.drawing=off
  y_offset=20
  padding_left=0
  padding_right=0
  width=0
  label.font="$FONT:Bold:14.0"
)

spotify_album=(
  icon.drawing=off
  padding_left=0
  padding_right=0
  y_offset=0
  width=0
  label.font="$FONT:Semibold:12.0"
  label.color=$WHITE
)

spotify_state=(
  icon.drawing=off
  label.drawing=off
  width=0
  padding_left=0
  padding_right=0
  slider.highlight_color=$GREEN
  slider.background.height=6
  slider.background.corner_radius=3
  slider.background.color=$BACKGROUND_2
  slider.width=115
  slider.knob.drawing=off
  slider.percentage=40
  y_offset=-20
  updates=on
  update_freq=1
  script="$PLUGIN_DIR/spotify.sh"
)

spotify_shuffle=(
  icon=$SPOTIFY_SHUFFLE
  icon.padding_left=5
  icon.padding_right=5
  icon.color=$WHITE
  icon.highlight_color=$GREEN
  label.drawing=off
  script="$PLUGIN_DIR/spotify.sh"
  y_offset=-45
)

spotify_back=(
  icon=$SPOTIFY_BACK
  icon.padding_left=5
  icon.padding_right=5
  icon.color=$WHITE
  script="$PLUGIN_DIR/spotify.sh"
  label.drawing=off
  y_offset=-45
)

spotify_play=(
  icon=$SPOTIFY_PLAY_PAUSE
  icon.padding_left=5
  icon.padding_right=5
  icon.color=$BLACK
  icon.font="$FONT:Bold:20.0"
  background.height=40
  background.corner_radius=20
  background.color=$GREEN
  background.border_color=$GREEN
  background.border_width=0
  background.drawing=on
  label.drawing=off
  script="$PLUGIN_DIR/spotify.sh"
  y_offset=-45
  updates=on
)

spotify_next=(
  icon=$SPOTIFY_NEXT
  icon.padding_left=5
  icon.padding_right=5
  icon.color=$WHITE
  label.drawing=off
  script="$PLUGIN_DIR/spotify.sh"
  y_offset=-45
)

spotify_repeat=(
  icon=$SPOTIFY_REPEAT
  icon.padding_left=5
  icon.padding_right=10
  icon.color=$WHITE
  icon.highlight_color=$GREEN
  label.drawing=off
  script="$PLUGIN_DIR/spotify.sh"
  y_offset=-45
)

sketchybar --add event spotify_change $SPOTIFY_EVENT             \
           --add item spotify.anchor center                      \
           --set spotify.anchor "${spotify_anchor[@]}"           \
           --subscribe spotify.anchor mouse.entered mouse.exited \
                                      mouse.exited.global        \
                                                                 \
           --add item spotify.cover popup.spotify.anchor         \
           --set spotify.cover "${spotify_cover[@]}"             \
                                                                 \
           --add item spotify.title popup.spotify.anchor         \
           --set spotify.title "${spotify_title[@]}"             \
                                                                 \
           --add item spotify.artist popup.spotify.anchor        \
           --set spotify.artist "${spotify_artist[@]}"           \
                                                                 \
           --add item spotify.album popup.spotify.anchor         \
           --set spotify.album "${spotify_album[@]}"             \
                                                                 \
           --add slider spotify.state popup.spotify.anchor       \
           --set spotify.state "${spotify_state[@]}"             \
           --subscribe spotify.state mouse.clicked               \
                                                                 \
           --add item spotify.shuffle popup.spotify.anchor       \
           --set spotify.shuffle "${spotify_shuffle[@]}"         \
           --subscribe spotify.shuffle mouse.clicked             \
                                                                 \
           --add item spotify.back popup.spotify.anchor          \
           --set spotify.back "${spotify_back[@]}"               \
           --subscribe spotify.back mouse.clicked                \
                                                                 \
           --add item spotify.play popup.spotify.anchor          \
           --set spotify.play "${spotify_play[@]}"               \
           --subscribe spotify.play mouse.clicked spotify_change \
                                                                 \
           --add item spotify.next popup.spotify.anchor          \
           --set spotify.next "${spotify_next[@]}"               \
           --subscribe spotify.next mouse.clicked                \
                                                                 \
           --add item spotify.repeat popup.spotify.anchor        \
           --set spotify.repeat "${spotify_repeat[@]}"           \
           --subscribe spotify.repeat mouse.clicked
