#!/bin/bash

# CriticalElement style workspace indicator with multi-monitor support
# - Highlights active workspace on EACH monitor with distinct colors
# - Shows app names next to workspace number
# - Main monitor (focused): firebrick red
# - Secondary monitor (visible): darker red
# - Third monitor (visible): darkest red
#
# COORDINATOR MODEL: this script runs ONCE per aerospace_workspace_change (driven
# by the hidden `aerospace_coordinator` item added in items/spaces.sh), queries the
# three aerospace states a SINGLE time, then loops all 10 workspace ids and emits
# ONE batched `sketchybar --set ...` covering every space item. This collapses the
# old ~10 shell procs + ~30 aerospace IPC round-trips per switch (one invocation
# per space item, each shelling out to aerospace 2-3x) down to 1 shell + 3 queries
# + 1 batched set. Bash 3.2: parallel indexed arrays only (no associative arrays).

source "$HOME/.config/sketchybar/colors.sh"
# shorten_app_name() lives in icon_map.sh (co-located with the icon name map).
# icon_map.sh self-guards its __icon_map call when sourced, so nothing prints.
source "$HOME/.config/sketchybar/plugins/icon_map.sh"

# All workspace ids in bar order (main 1-6, built-in 7-9, sidecar 0).
ALL_WORKSPACES="1 2 3 4 5 6 7 8 9 0"

# First/last workspace of each monitor group (main=1..6, built-in=7..9, sidecar=0).
# Must match the bracket grouping in items/spaces.sh and the
# [workspace-to-monitor-force-assignment] block in aerospace.toml.
GROUP_FIRST_WORKSPACES=" 1 7 0 "
GROUP_LAST_WORKSPACES=" 6 9 0 "

# --- Query the three aerospace states ONCE -----------------------------------

# Visible workspaces across all monitors, in monitor-enumeration order. The
# POSITION in this list (not a stable monitor id) drives the color tier, exactly
# like the old per-item MONITOR_INDEX.
VISIBLE_WORKSPACES=$(aerospace list-workspaces --monitor all --visible 2>/dev/null)

# Focused workspace (main monitor).
FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null)

# All windows tagged by workspace, queried once instead of per-space.
ALL_WINDOWS=$(aerospace list-windows --all --format '%{workspace}|%{app-name}' 2>/dev/null)

# --- Per-workspace render state -----------------------------------------------

FONT="JetBrainsMono Nerd Font"
NUM_FONT="$FONT:Bold:13.0"        # matches the static number font in spaces.sh
TEXT_FONT="$FONT:Bold:13.0"       # app NAMES — fallback when a space has any unmapped app
APP_FONT="sketchybar-app-font:Regular:14.0"  # app ICONS — used when every app in the space is mapped
DOT_GLYPH="·"
DOT_FONT="$FONT:Bold:18.0"        # bigger + bold so the empty-marker dot is clearly visible
DOT_COLOR="$SPACE_DOT_COLOR"      # dim placeholder matching the inactive theme

# Accumulate every space item's properties into a single batched --set.
ARGS=()

for WORKSPACE_ID in $ALL_WORKSPACES; do
    IS_GROUP_FIRST=false
    case "$GROUP_FIRST_WORKSPACES" in
      *" $WORKSPACE_ID "*) IS_GROUP_FIRST=true ;;
    esac
    IS_GROUP_LAST=false
    case "$GROUP_LAST_WORKSPACES" in
      *" $WORKSPACE_ID "*) IS_GROUP_LAST=true ;;
    esac

    # Determine if this workspace is visible and on which monitor (by list position).
    IS_VISIBLE=false
    IS_FOCUSED=false
    MONITOR_INDEX=0

    if [ "$WORKSPACE_ID" = "$FOCUSED_WS" ]; then
        IS_FOCUSED=true
        IS_VISIBLE=true
    fi

    MONITOR_COUNT=0
    for ws in $VISIBLE_WORKSPACES; do
        MONITOR_COUNT=$((MONITOR_COUNT + 1))
        if [ "$ws" = "$WORKSPACE_ID" ]; then
            IS_VISIBLE=true
            if [ "$ws" != "$FOCUSED_WS" ]; then
                MONITOR_INDEX=$MONITOR_COUNT
            fi
        fi
    done

    # Get apps in this workspace from the single ALL_WINDOWS capture. When the
    # same app has multiple windows in the space, collapse them into a single
    # entry and append one '*' per EXTRA instance (no space): four iTerm2 windows
    # render as "iTerm2***". Distinct apps keep their first-seen order. Uses
    # parallel indexed arrays (no associative arrays) to stay bash 3.2 compatible.
    APPS=""        # text label: app names (+ window-count stars) — fallback
    ICONS=""       # app-font label: one icon glyph per distinct app
    ALL_KNOWN=true # false as soon as any app has no mapped icon
    APP_LIST=$(printf '%s\n' "$ALL_WINDOWS" | awk -F'|' -v ws="$WORKSPACE_ID" '$1==ws {sub(/^[^|]*\|/, ""); print}')

    if [ -n "$APP_LIST" ]; then
        ORDER=()   # distinct app names, first-seen order
        COUNTS=()  # parallel: window count per app in ORDER
        while IFS= read -r app; do
            # Skip Stickies: it's an always-on-top floating note, not a managed
            # window, so it shouldn't clutter the workspace app-name list.
            [ -z "$app" ] && continue
            [ "$app" = "Stickies" ] && continue
            found=-1
            for idx in "${!ORDER[@]}"; do
                if [ "${ORDER[idx]}" = "$app" ]; then
                    found=$idx
                    break
                fi
            done
            if [ "$found" -ge 0 ]; then
                COUNTS[found]=$(( COUNTS[found] + 1 ))
            else
                ORDER+=("$app")
                COUNTS+=(1)
            fi
        done <<< "$APP_LIST"

        for idx in "${!ORDER[@]}"; do
            app="${ORDER[idx]}"
            SHORT_NAME=$(shorten_app_name "$app")
            extra=$(( COUNTS[idx] - 1 ))
            stars=""
            [ "$extra" -gt 0 ] && stars=$(printf '%*s' "$extra" '' | tr ' ' '*')
            entry="$SHORT_NAME$stars"
            if [ -z "$APPS" ]; then
                APPS="$entry"
            else
                APPS="$APPS $entry"
            fi

            # App-font icon token for this app (":default:" when not in the map).
            # A space renders as icons only when EVERY app maps; one unmapped app
            # falls the whole space back to text names.
            token=$(__icon_map "$app")
            [ "$token" = ":default:" ] && ALL_KNOWN=false
            if [ -z "$ICONS" ]; then
                ICONS="$token"
            else
                ICONS="$ICONS $token"
            fi
        done
    fi

    # Determine highlight color based on monitor - dark red theme
    if [ "$IS_FOCUSED" = true ]; then
        # Main monitor (focused) - firebrick highlight, matches active window border
        # 0xff alpha = fully opaque — the focus bubble is solid so the active space
        # reads clearly on top of the 70% DARK_BG fill behind it
        BG_COLOR="$SPACE_FOCUS_BG"
    elif [ "$IS_VISIBLE" = true ]; then
        # Secondary/tertiary monitors - fully opaque bubble.
        # NOTE: MONITOR_INDEX is the workspace's POSITION in the visible-workspace
        # enumeration (list order), not a stable monitor id. So the color tier
        # tracks enumeration position, and a 3rd physical monitor can reuse the
        # 2nd tier's color depending on listing order — this is cosmetic, not a bug.
        if [ "$MONITOR_INDEX" -eq 2 ]; then
            BG_COLOR="$SPACE_MON2_BG"
        elif [ "$MONITOR_INDEX" -ge 3 ]; then
            BG_COLOR="$SPACE_MON3_BG"
        else
            # Visible but index unresolved (e.g. equals the focused tier) — default
            # to the 2nd-monitor color rather than leaving it unset.
            BG_COLOR="$SPACE_MON2_BG"
        fi
    else
        # Not visible - no bubble (transparent); only the focused/visible space per
        # screen gets a colored bubble
        BG_COLOR=$TRANSPARENT
    fi

    # Determine icon and label colors
    # Focused: slightly reddish white for the active app visibility
    # Visible (not focused): dark for contrast
    # Inactive: dark red for app names
    if [ "$IS_FOCUSED" = true ]; then
        ICON_COLOR="$SPACE_ACTIVE_ICON"
        LABEL_COLOR="$SPACE_FOCUS_LABEL"  # Slightly reddish white
    elif [ "$IS_VISIBLE" = true ]; then
        ICON_COLOR="$SPACE_ACTIVE_ICON"
        LABEL_COLOR="$SPACE_ACTIVE_ICON"
    else
        ICON_COLOR="$SPACE_INACTIVE_FG"  # Dark red (de-pinked, matches inactive label)
        LABEL_COLOR="$SPACE_INACTIVE_FG"  # Dark red (brighter)
    fi

    # Render in one of three states: occupied (number + apps), number-only
    # (group-first or focused/visible empty), or a minimal dot (empty filler).
    # Because the dot state swaps the icon glyph AND font, every non-dot branch
    # must reset icon/icon.font back to the number so an item never gets stuck on
    # the dot when an app appears.

    # Extra right padding for breathing room: after the leading number of a group
    # (gap between e.g. 1 and 2) and after the last item of a group (gap before the
    # bracket edge / separator).
    EDGE_PAD_R=1
    DOT_PAD_R=0
    if [ "$IS_GROUP_FIRST" = true ] || [ "$IS_GROUP_LAST" = true ]; then
      EDGE_PAD_R=6
    fi
    if [ "$IS_GROUP_LAST" = true ]; then
      DOT_PAD_R=6
    fi

    ARGS+=( --set space.$WORKSPACE_ID background.color=$BG_COLOR )

    if [ -n "$APPS" ]; then
      # OCCUPIED: number + either app ICONS (every app mapped) or app NAMES (text
      # fallback). label.font is set explicitly each paint so it never sticks on
      # the wrong font when a space flips between the two modes.
      if [ "$ALL_KNOWN" = true ]; then
        SPACE_LABEL="$ICONS"; SPACE_LABEL_FONT="$APP_FONT"
      else
        SPACE_LABEL="$APPS";  SPACE_LABEL_FONT="$TEXT_FONT"
      fi
      ARGS+=( icon="$WORKSPACE_ID" icon.font="$NUM_FONT" icon.color=$ICON_COLOR icon.padding_left=5 icon.padding_right=3 \
              label="$SPACE_LABEL" label.font="$SPACE_LABEL_FONT" label.color=$LABEL_COLOR label.drawing=on padding_left=1 padding_right=$EDGE_PAD_R )
    elif [ "$IS_GROUP_FIRST" = true ] || [ "$IS_VISIBLE" = true ]; then
      # NUMBER ONLY: group-first always, or focused/visible empty so position is visible.
      # Symmetric icon padding (5/5) so the highlight bubble has room on both sides
      # and doesn't clip the digit when the empty workspace is selected.
      ARGS+=( icon="$WORKSPACE_ID" icon.font="$NUM_FONT" icon.color=$ICON_COLOR icon.padding_left=5 icon.padding_right=5 \
              label="" label.drawing=off padding_left=1 padding_right=$EDGE_PAD_R )
    else
      # DOT: empty, not group-first, not visible -> minimal width, no pill backdrop
      ARGS+=( icon="$DOT_GLYPH" icon.font="$DOT_FONT" icon.color=$DOT_COLOR icon.padding_left=2 icon.padding_right=2 \
              label="" label.drawing=off padding_left=0 padding_right=$DOT_PAD_R \
              background.color=$TRANSPARENT )
    fi
done

# One batched set covering every space item.
sketchybar "${ARGS[@]}"
