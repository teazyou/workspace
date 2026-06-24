#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# SketchyBar visual TEMPLATE — single source of truth for "division" styling.
#
# A *division* is any grouped pill on the bar: spaces 1-6, spaces 7-9, space 0,
# calendar, audio, resources, connectivity, traffic. Every division on BOTH the
# left and right of the bar, in EVERY mode (normal + performance), pulls its
# geometry from the tokens below — so the whole bar stays uniform and a restyle
# is a single edit here.
#
# Sourced by sketchybarrc BEFORE any item is added; items/*.sh are sourced in the
# same shell so they inherit these without re-sourcing. (Geometry only; the colour
# palette stays in colors.sh.)
# ─────────────────────────────────────────────────────────────────────────────

# ── Corner rounding ──────────────────────────────────────────────────────────
# Lower = more square. The reference look is nearly-square pills.
export DIVISION_RADIUS=4        # every group/bracket (the divisions themselves)
export SPACE_BUBBLE_RADIUS=3    # inner per-space highlight bubble (a touch tighter)
export POPUP_RADIUS=6           # dropdown popups (calendar / volume)

# ── Outline ──────────────────────────────────────────────────────────────────
# Divisions carry NO border.
export DIVISION_BORDER_WIDTH=0

# ── Fill / transparency ──────────────────────────────────────────────────────
# Divisions are fully OPAQUE (the fill colour DARK_BG in colors.sh is already
# opaque). Blur is disabled because an opaque fill has nothing behind it to blur.
export DIVISION_BLUR=0

# ── Drop shadow (rendered directly BELOW each division) ──────────────────────
# Subtle lift off the wallpaper. angle is degrees in [0,360); 270 = straight down.
# (Must stay positive — SketchyBar stores the angle unsigned, so a negative like
# -90 wraps to a bogus 166°. If it ever renders above instead of below, use 90.)
export DIVISION_SHADOW_DRAWING=on
export DIVISION_SHADOW_COLOR=0x99000000   # ~60% black
export DIVISION_SHADOW_ANGLE=270
export DIVISION_SHADOW_DISTANCE=3

# ── Inter-division spacing ───────────────────────────────────────────────────
# The single gap between every adjacent division — identical on the left (spaces)
# and right (status) clusters, and identical in normal vs performance mode. Every
# spacer item (sketchybarrc + items/spaces.sh) uses this width; performance-mode.sh
# only toggles which spacers draw, never their width, so the gap never changes.
export GROUP_GAP=6
