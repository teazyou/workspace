#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# SketchyBar visual TEMPLATE — single source of truth for "division" styling.
#
# A *division* is any grouped pill on the bar: spaces 1-6, spaces 7-9, space 0,
# calendar, Pomodoro, resources, connectivity. Every division on BOTH the left
# and right of the bar pulls its geometry from the tokens below — so the whole
# bar stays uniform and a restyle is a single edit here.
#
# Sourced by sketchybarrc BEFORE any item is added; items/*.sh are sourced in the
# same shell so they inherit these without re-sourcing. (Geometry only; the colour
# palette stays in colors.sh.)
# ─────────────────────────────────────────────────────────────────────────────

# ── Corner rounding ──────────────────────────────────────────────────────────
# Lower = more square. The reference look is nearly-square pills.
export DIVISION_RADIUS=4        # every group/bracket (the divisions themselves)
export SPACE_BUBBLE_RADIUS=3    # inner per-space highlight bubble (a touch tighter)
export POPUP_RADIUS=6           # dropdown popups (calendar)

# ── Outline ──────────────────────────────────────────────────────────────────
# Divisions carry NO border.
export DIVISION_BORDER_WIDTH=0

# ── Fill / transparency ──────────────────────────────────────────────────────
# Divisions are fully OPAQUE (the fill colour DARK_BG in colors.sh is already
# opaque). Blur is disabled because an opaque fill has nothing behind it to blur.
export DIVISION_BLUR=0

# ── Inter-division spacing ───────────────────────────────────────────────────
# The single gap between every adjacent division — identical on the left (spaces)
# and right (status) clusters. Every spacer item (sketchybarrc + items/spaces.sh)
# uses this width, so the gap never changes.
export GROUP_GAP=6

# ── Intra-division padding ───────────────────────────────────────────────────
# DIVISION_PAD — inner padding between a division's edge (bracket border) and its
# first/last element. ELEMENT_GAP — gap between adjacent elements inside a division
# (icon<->label and item<->item). Applied UNIFORMLY to every status division via
# the item paddings, so spacing is controlled here instead of per-item.
# Kept equal so that when an element hides (e.g. a show-only-when-connected item
# like ethernet) the neighbour's gap cleanly doubles as the vacated pad.
export DIVISION_PAD=6
export ELEMENT_GAP=6

# NOTE (2026-07-30): there used to be a SEL_DOT_* / SEL_UNDERLINE_* block here —
# a sub-label "this is the selected one" marker for the VPN items. Removed with
# its only consumer: colour alone carries the VPN state, and when both country
# icons read grey the VPN is simply off. The mechanism (and why a background
# cannot do it) is kept as a lesson in docs/window-manager/guide-window-manager.md
# in case a sub-label marker is ever wanted again.
