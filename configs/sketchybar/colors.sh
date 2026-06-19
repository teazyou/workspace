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
export DARK_BG=0xCC000000  # black at 80% opacity (0xCC alpha) — pill/bracket backgrounds

export POPUP_BACKGROUND_COLOR=0xEB1e1e2e
export POPUP_BORDER_COLOR=$BORDER_INACTIVE

export SHADOW_COLOR=$BLACK
