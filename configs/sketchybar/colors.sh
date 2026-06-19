#!/bin/bash

# Color Palette (CriticalElement Dotfiles)
export BLACK=0xff181926
export WHITE=0xFFFFFFFF
export RED=0xFFCE3A5B
export GREEN=0xFF638989
export BLUE=0xFF1E6E77
export YELLOW=0xffeed49f
export ORANGE=0xFFCC7B6E
export MAGENTA=0xffc6a0f6
export GREY=0xff939ab7
export TRANSPARENT=0x00000000

# Window-border-matched reds (keep in sync with configs/borders/bordersrc)
export BORDER_ACTIVE=0xffb22222    # firebrick — selected/active elements (= borders active_color)
export BORDER_INACTIVE=0xff4d1a1a  # dark red   — unselected/inactive elements (= borders inactive_color)

# Bar accent now mirrors the window borders' two-red scheme. PINK is kept as the
# accent variable name (referenced across every item) but repointed to the active
# border red so the whole bar recolors from this one line.
export PINK=$BORDER_ACTIVE

# General bar colors
export BAR_COLOR=0x00000000  # Fully transparent for floating items effect
export ICON_COLOR=$WHITE
export LABEL_COLOR=$WHITE
export BACKGROUND_1=0xEB1e1e2e
export BACKGROUND_2=0xEB1e1e2e
export WARM_GRAY=0xFFD3CDC5
export DARK_BG=0xB3000000  # black at 70% opacity (0xB3 alpha) — pill/bracket backgrounds (left spaces + right groups)

export POPUP_BACKGROUND_COLOR=0xEB1e1e2e
export POPUP_BORDER_COLOR=$BORDER_INACTIVE

export SHADOW_COLOR=$BLACK

# Spaces palette (plugins/aerospace.sh coordinator). Centralized here so the
# whole spaces strip recolors from one place, like the rest of the bar.
export SPACE_FOCUS_BG=$BORDER_ACTIVE   # focused-monitor space bubble (= active border red)
export SPACE_MON2_BG=0xff8a3048        # 2nd visible monitor bubble
export SPACE_MON3_BG=0xff75283d        # 3rd+ visible monitor bubble
export SPACE_ACTIVE_ICON=0xff1a1a2e    # number glyph on a focused/visible bubble
export SPACE_FOCUS_LABEL=0xfffff0f3    # app-name label on the focused bubble (reddish white)
export SPACE_INACTIVE_FG=0xffb35060    # inactive space number + app label (dark red)
export SPACE_DOT_COLOR=0xff6e4250      # empty-filler dot glyph (dim placeholder)
