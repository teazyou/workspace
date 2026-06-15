# iTerm2: give every new tab/window a random — but nice — color.
#
# Uses iTerm2's proprietary escape codes to tint the tab title bar.
# Docs: https://iterm2.com/documentation-escape-codes.html
#
# Instead of randomising raw RGB (which often looks muddy/ugly), we pick a
# random HUE and keep SATURATION + VALUE fixed. That guarantees every tab is
# vivid and readable, just a different shade each time.

# Only do this inside iTerm2 — the escape codes are meaningless elsewhere.
if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then

  # HSV -> "R G B" (each component 0-255). h is 0-359, s and v are 0.0-1.0.
  _iterm2_hsv_to_rgb () {
    local -i h=$1
    local -F s=$2 v=$3
    local -i sextant=$(( h / 60 ))                 # which 60deg slice (0-5)
    local -F f=$(( (h % 60) / 60.0 ))              # position within the slice
    local -F p=$(( v * (1 - s) ))
    local -F q=$(( v * (1 - f * s) ))
    local -F t=$(( v * (1 - (1 - f) * s) ))
    local -F r g b
    case $sextant in
      0) r=$v; g=$t; b=$p ;;
      1) r=$q; g=$v; b=$p ;;
      2) r=$p; g=$v; b=$t ;;
      3) r=$p; g=$q; b=$v ;;
      4) r=$t; g=$p; b=$v ;;
      5) r=$v; g=$p; b=$q ;;
    esac
    # integer-typed vars truncate, so + 0.5 rounds to nearest.
    local -i ri=$(( r * 255 + 0.5 )) gi=$(( g * 255 + 0.5 )) bi=$(( b * 255 + 0.5 ))
    printf '%d %d %d' $ri $gi $bi
  }

  # Paint the current tab a random pleasant color.
  iterm2_random_tab_color () {
    local -i hue=$(( RANDOM % 360 ))   # full color wheel
    local -a rgb
    rgb=( ${(s: :)$(_iterm2_hsv_to_rgb $hue 0.55 0.80)} )
    printf '\033]6;1;bg;red;brightness;%d\a'   ${rgb[1]}
    printf '\033]6;1;bg;green;brightness;%d\a' ${rgb[2]}
    printf '\033]6;1;bg;blue;brightness;%d\a'  ${rgb[3]}
  }

  # Clear the tab color, letting iTerm2 fall back to its theme default.
  iterm2_reset_tab_color () {
    printf '\033]6;1;bg;*;default\a'
  }

  # `recolor` -> roll a fresh random color on demand.
  alias recolor='iterm2_random_tab_color'

  # Color this tab the moment the shell starts (i.e. every new tab/window).
  iterm2_random_tab_color
fi
