#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# SketchyBar visual TEMPLATE — single source of truth for "division" styling.
#
# A *division* is any grouped pill on the bar: spaces 1-6, spaces 7-9, space 0,
# calendar, resources, connectivity. Every division on BOTH the left and
# right of the bar pulls its geometry from the tokens below — so the whole bar
# stays uniform and a restyle is a single edit here.
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

# ── Drop shadow (cast to the BOTTOM-RIGHT of each division) ──────────────────
# SketchyBar uses SCREEN coords (y points DOWN): angle in [0,360) with 0 = right,
# 90 = straight down, 45 = bottom-right, 270 = up. (Verified empirically: 315
# renders top-right.) Must stay positive — SketchyBar stores the angle unsigned.
export DIVISION_SHADOW_DRAWING=on
# SketchyBar shadows are HARD-EDGED — there is no blur/spray property (verified:
# `Invalid property 'blur'`). So we soften toward a more natural look via a
# lower-opacity colour instead of a real blur.
export DIVISION_SHADOW_COLOR=0x80000000   # ~50% black (softened; no native shadow blur)
export DIVISION_SHADOW_ANGLE=45            # bottom-right
export DIVISION_SHADOW_DISTANCE=4          # offset in px

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

# ── Selection underline ──────────────────────────────────────────────────────
# The "this is the selected one" marker: a thin horizontal rule drawn UNDER an
# element's label (only user today: the active VPN country — items/vpn.sh +
# plugins/vpn.sh). SketchyBar has no sub-label slot, so the element's own ICON
# slot is re-purposed. The icon normally sits BESIDE the label, so it is pulled
# back UNDER it with a NEGATIVE icon.padding_right, chosen so that
#     icon.padding_left + SEL_UNDERLINE_ADVANCE + icon.padding_right == 0
# i.e. the underline costs ZERO layout width — the element and its whole
# division measure the same whether it shows or not. Presence is therefore a
# COLOUR, never `icon.drawing`: hidden = icon.color=$TRANSPARENT (drawing=off
# would remove the glyph's advance and shift the label).
# WHY A GLYPH AND NOT A BACKGROUND: the item background CAN be a 1 px
# full-width underline, but it always spans the whole element (30 px, wider
# than the 18 px label) — `background.padding_*` does not inset it, it ADDS
# outward layout width (measured: connectivity 85 -> 97 px). A box-drawing
# glyph is both narrower and thinner.
# THINNESS FLOOR: this display is 2560x1440 @1:1, so 1 pt == 1 physical px —
# a 0.5 px rule is not expressible. U+2500 at :Regular: is the thinnest the
# font stack offers (a hairline stroke, antialiased); Bold or ▁ (U+2581, 1/8 em)
# both render visibly thicker. Smaller size = thinner stroke AND shorter rule.
# Verified live (--query, pads 0/0 width delta): at :Regular:13.0 the glyph
# advances 14 px; on a 30 px element that centres exactly (pad 8 / -22), giving
# a 14 px rule under an 18 px label, at the same rows the old ● dot inked.
export SEL_UNDERLINE_GLYPH="─"   # U+2500 BOX DRAWINGS LIGHT HORIZONTAL (tiles edge-to-edge)
export SEL_UNDERLINE_SIZE=13.0   # font size — calibrated PAIR with _ADVANCE, change both
export SEL_UNDERLINE_ADVANCE=14  # px the glyph advances at _SIZE (measured; centring needs it)
export SEL_UNDERLINE_Y_OFFSET=-9 # NEGATIVE = DOWN (verified): under the label, inside the pill
