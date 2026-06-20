#!/bin/bash
# AeroSpace Display Profile Auto-Switcher
# Calculates optimal gaps based on each monitor's resolution

set -euo pipefail

source ~/workspace/configs/aerospace/lib-paths.sh

AEROSPACE_CONFIG="$HOME/.aerospace.toml"
STATE_FILE="/tmp/aerospace-display-profile.state"
LOG_FILE="/tmp/aerospace-display-profile.log"

# Gap calculation settings - TUNE THESE VALUES
# Reference gap for a standard 1440p external monitor
REFERENCE_GAP=42

# Extra top spacing between the SketchyBar and the app window.
# BAR_GAP_PAD:        added to every monitor's bar gap in ALL scenarios.
# MAIN_ONLY_BAR_EXTRA: added on top when the bar is shown ONLY on the main
#                      screen (secondary bar hidden) — applied to whichever
#                      display still draws the bar.
# BUILTIN_MAIN_BAR_EXTRA: extra breathing room below the bar on the MacBook
#                      built-in ONLY when it is itself the MAIN (primary)
#                      display drawing the lone bar (secondary bar hidden).
#                      Scoped to that one case, so external-main and
#                      built-in-secondary setups are untouched.
BAR_GAP_PAD=2
MAIN_ONLY_BAR_EXTRA=2
BUILTIN_MAIN_BAR_EXTRA=5

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# True (exit 0) when the MacBook built-in display currently carries the menu bar
# (is the main display). Used to decide where the "laptop-companion" workspaces
# 7-9 live: when the built-in is SECONDARY (an external is main, e.g. the home
# desk setup) they belong on the built-in; when the built-in is itself MAIN (e.g.
# the travel setup with a portable external) they must move off it onto the
# secondary external. A monitor block counts as the built-in if its name is
# "Color LCD", its Display Type says "Built-in", or its Connection Type is
# "Internal" — any one is enough.
builtin_is_main() {
    local sp_displays="${1:-$(system_profiler SPDisplaysDataType 2>/dev/null)}"
    printf '%s\n' "$sp_displays" | awk '
        /^[[:space:]]+[A-Za-z].*:$/ {
            if (blk_main && blk_builtin) found=1
            blk_main=0; blk_builtin=0
            if ($0 ~ /Color LCD/) blk_builtin=1
        }
        /Display Type:.*Built-in/              { blk_builtin=1 }
        /Connection Type:[[:space:]]*Internal/ { blk_builtin=1 }
        /Main Display:[[:space:]]*Yes/         { blk_main=1 }
        END {
            if (blk_main && blk_builtin) found=1
            exit (found ? 0 : 1)
        }
    '
}

# Monitor pattern (TOML-quoted) for workspaces 7-9, the laptop-companion screen.
# 'built-in.*' names the MacBook explicitly so it never grabs an iPad sidecar (a
# bare 'secondary' would also match the iPad when the built-in is secondary). When
# the built-in is main, 'built-in.*' would collide with workspaces 1-6 (also on
# main), so fall back to 'secondary' — the portable external reports an empty name
# to AeroSpace and can't be matched by a name regex, but it's the only non-main
# screen in the travel setup so 'secondary' resolves to it unambiguously.
companion_ws_pattern() {
    local sp_displays="${1:-$(system_profiler SPDisplaysDataType 2>/dev/null)}"
    if builtin_is_main "$sp_displays"; then
        echo "'secondary'"
    else
        echo "'built-in.*'"
    fi
}

# Calculate optimal top gap based on resolution
# Uses a lookup table for common resolutions, with interpolation for others
calculate_top_gap() {
    local width="$1"
    local height="$2"
    local is_retina="$3"
    local gap

    # Lookup table: resolution -> gap
    # Tune these values based on your preference
    # Format: total_pixels (width*height) as rough proxy for screen class

    # Retina/HiDPI displays (high pixel count but small physical size)
    if [[ "$is_retina" == "true" ]]; then
        # MacBook built-in displays - typically need smaller gaps
        case "${width}x${height}" in
            3456x2234) gap=15 ;;  # 16" MacBook Pro
            3024x1964) gap=25 ;;  # 14" MacBook Pro
            2880x1800) gap=25 ;;  # 15" MacBook Pro (older)
            2560x1600) gap=25 ;;  # 13" MacBook
            *)
                # Default for unknown retina: small gap
                gap=25
                ;;
        esac
    else
        # External monitors - scale by vertical resolution
        case "${width}x${height}" in
            3840x2160) gap=42 ;;  # 4K
            3440x1440) gap=42 ;;  # Ultrawide 1440p
            2560x1440) gap=42 ;;  # 1440p (reference)
            2560x1080) gap=38 ;;  # Ultrawide 1080p
            1920x1200) gap=35 ;;  # 1200p
            1920x1080) gap=35 ;;  # 1080p
            2048x1152) gap=42 ;;  # HDMI external
            1600x900)  gap=44 ;;  # 900p (portable)
            1366x768)  gap=28 ;;  # 768p
            *)
                # Interpolate based on vertical resolution
                if (( height >= 2160 )); then
                    gap=42
                elif (( height >= 1440 )); then
                    gap=42
                elif (( height >= 1080 )); then
                    gap=35
                elif (( height >= 900 )); then
                    gap=30
                else
                    gap=28
                fi
                ;;
        esac
    fi

    echo "$gap"
}

# Get monitor info and build config
get_monitors_config() {
    local sp_displays="${1:-$(system_profiler SPDisplaysDataType 2>/dev/null)}"
    local monitors=()
    local current_name=""
    local current_res=""
    local is_retina=false
    local is_main=false

    while IFS= read -r line; do
        # Detect monitor name (e.g., "Color LCD:", "Display:")
        if [[ "$line" =~ ^[[:space:]]+([A-Za-z].+):$ ]]; then
            # Save previous monitor if exists
            if [[ -n "$current_name" && -n "$current_res" ]]; then
                monitors+=("$current_name|$current_res|$is_retina|$is_main")
            fi
            current_name="${BASH_REMATCH[1]}"
            current_res=""
            is_retina=false
            is_main=false
        fi

        # Detect the main display (carries the menu bar)
        if [[ "$line" =~ Main\ Display:\ Yes ]]; then
            is_main=true
        fi

        # Detect resolution (take first resolution line per monitor).
        # Only treat the display as Retina when the Resolution line ITSELF says
        # "Retina" — an external display whose Display Type mentions Retina but
        # whose Resolution line does not must not be routed through the MacBook
        # retina gap table.
        if [[ -z "$current_res" && "$line" =~ Resolution:\ ([0-9]+)\ x\ ([0-9]+) ]]; then
            current_res="${BASH_REMATCH[1]}x${BASH_REMATCH[2]}"
            if [[ "$line" =~ "Retina" ]]; then
                is_retina=true
            fi
        fi
    done < <(printf '%s\n' "$sp_displays")

    # Don't forget last monitor
    if [[ -n "$current_name" && -n "$current_res" ]]; then
        monitors+=("$current_name|$current_res|$is_retina|$is_main")
    fi

    # Output monitor info
    # Guard against an empty array so set -u (nounset) doesn't abort the whole
    # gap rebuild when system_profiler yields no name+Resolution block.
    if (( ${#monitors[@]} )); then
        printf '%s\n' "${monitors[@]}"
    fi
}

# Build the outer.top config string
build_top_gap_config() {
    local sp_displays="${1:-$(system_profiler SPDisplaysDataType 2>/dev/null)}"
    local -a gap_entries=()
    local default_gap=30
    local main_gap=""
    local builtin_is_main=false

    while IFS='|' read -r name res is_retina is_main; do
        [[ -z "$name" ]] && continue

        # Extract width and height
        local width="${res%x*}"
        local height="${res#*x}"
        local gap
        gap=$(calculate_top_gap "$width" "$height" "$is_retina")

        # Build monitor pattern for TOML
        # Use lowercase name for matching
        local pattern
        local name_lower
        name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')

        # Check if it's the built-in display
        if [[ "$name_lower" == "color lcd" ]] || [[ "$name" =~ "Built-in" ]]; then
            pattern="built-in.*"
        else
            # Use first word of monitor name as pattern
            pattern=$(echo "$name" | awk '{print tolower($1)}' | sed 's/[^a-z0-9]/.*/g')
            pattern="${pattern}.*"
        fi

        # MacBook built-in only: halve its top gap (round up) when the bar IS
        # shown on it (Case B). Gated on the built-in pattern so an external
        # retina monitor is never affected. Done before main_gap is set so a
        # built-in main display feeds the halved value into the bar-off branch.
        if [[ "$pattern" == "built-in.*" ]]; then
            gap=$(( (gap + 1) / 2 ))
        fi

        # +BAR_GAP_PAD base spacing between the SketchyBar and the app, applied
        # in every scenario where the bar is shown (added AFTER the built-in
        # halving so the pad itself isn't halved). The bar-off branch below adds
        # a further MAIN_ONLY_BAR_EXTRA on the screen that still draws the bar.
        gap=$(( gap + BAR_GAP_PAD ))

        # Remember the gap of the main display (the one with the menu bar)
        if [[ "$is_main" == "true" ]]; then
            main_gap="$gap"
        fi

        # Track whether the MacBook built-in is itself the main display. The
        # bar-off branch uses this to give the built-in less top space when it's
        # main (bar shown on it) than when it's a bar-less secondary.
        if [[ "$pattern" == "built-in.*" && "$is_main" == "true" ]]; then
            builtin_is_main=true
        fi

        gap_entries+=("{ monitor.\"$pattern\" = $gap }")
        log "Monitor: $name ($res) -> gap: $gap (pattern: $pattern)"

        # Use largest gap as default
        if (( gap > default_gap )); then
            default_gap=$gap
        fi
    done < <(get_monitors_config "$sp_displays")

    # When SketchyBar is hidden on the secondary monitors, keep the bar gap
    # only on the main monitor (where the bar still shows) and reclaim the
    # freed top space on every other monitor — regardless of monitor count.
    # The old `monitor.secondary` keyword only works for 2-monitor setups,
    # so use `monitor.main` + a small default instead.
    local bar_state_file="$SECONDARY_BAR_STATE"
    local bar_off=false
    if [[ -f "$bar_state_file" ]] && [[ "$(cat "$bar_state_file" 2>/dev/null)" == "off" ]]; then
        bar_off=true
    fi

    # Build final config string
    if (( ${#gap_entries[@]} == 0 )); then
        echo "$default_gap"
    elif (( ${#gap_entries[@]} == 1 )); then
        # Single monitor - always main; bar-off doesn't apply.
        local single_gap="${gap_entries[0]}"
        single_gap="${single_gap#*= }"
        single_gap="${single_gap% \}}"
        echo "$single_gap"
    elif [[ "$bar_off" == "true" && -n "$main_gap" ]]; then
        # Bar hidden on secondaries (those screens show no bar), so reclaim top.
        # The screen that still draws the bar (the main one) gets the padded gap
        # PLUS MAIN_ONLY_BAR_EXTRA, since the bar is now only on the main screen:
        #   built-in MAIN (only bar drawn)     -> 2 + main-only extra + builtin-main extra
        #   built-in SECONDARY (no bar there)  -> 4  (reclaim, no bar)
        #   main external (only bar drawn)     -> padded $main_gap + main-only extra
        #   other external secondaries         -> $bottom_gap (match the bottom gap)
        # First match wins: built-in (FIRST) takes $builtin_top regardless of its
        # slot; a non-built-in main then matches monitor.main; remaining external
        # secondaries fall through to the bottom-matching default.
        local builtin_top=4
        [[ "$builtin_is_main" == "true" ]] && builtin_top=$(( 2 + MAIN_ONLY_BAR_EXTRA + BUILTIN_MAIN_BAR_EXTRA ))
        # Main screen still draws the bar, so add the main-only extra on top of
        # its already-padded gap.
        local main_only_gap=$(( main_gap + MAIN_ONLY_BAR_EXTRA ))
        # Mirror outer.bottom so a bar-less external secondary's top == its bottom.
        local bottom_gap
        bottom_gap=$(grep -E '^[[:space:]]*outer\.bottom' "$AEROSPACE_CONFIG" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
        [[ -z "$bottom_gap" ]] && bottom_gap=5
        log "Secondary bar hidden — built-in $builtin_top (main 2+extra+builtin-main extra / secondary 4), main external keeps $main_only_gap, external secondaries -> bottom gap $bottom_gap"
        echo "[{ monitor.\"built-in.*\" = $builtin_top }, { monitor.main = $main_only_gap }, $bottom_gap]"
    else
        # Multiple monitors - use array format (per-resolution entries).
        local result="["
        for entry in "${gap_entries[@]}"; do
            result+="$entry, "
        done
        result="${result%, }, $default_gap]"
        echo "$result"
    fi
}

# Get current fingerprint (for change detection)
get_fingerprint() {
    local sp_displays="${1:-$(system_profiler SPDisplaysDataType 2>/dev/null)}"
    local resolutions
    resolutions=$(printf '%s\n' "$sp_displays" | grep -E "Resolution:" | sort)
    # Bail if no displays detected (system_profiler returns empty in some non-GUI contexts)
    [[ -z "$resolutions" ]] && return 1
    # Fold in which display is main so swapping the main display on the SAME
    # physical monitors (e.g. via System Settings) still re-triggers a rebuild and
    # lets the 7-9 assignment follow — resolutions alone wouldn't change then.
    local bim="sec"
    builtin_is_main "$sp_displays" && bim="main"
    printf '%s|builtin=%s' "$resolutions" "$bim" | /sbin/md5 | cut -c1-8
}

# Update aerospace.toml with new gap values
update_aerospace_config() {
    local outer_top="$1"
    local ws_pattern="$2"

    cp "$AEROSPACE_CONFIG" "$AEROSPACE_CONFIG.bak"

    local tmp_file
    tmp_file=$(mktemp)

    awk -v ot="$outer_top" -v ws="$ws_pattern" '
    # Track which section we are in; reset both flags on every section header.
    /^\[/ {
        in_gaps  = ($0 ~ /^\[gaps\]/)
        in_wsmon = ($0 ~ /^\[workspace-to-monitor-force-assignment\]/)
    }

    in_gaps && /outer\.top/ {
        # Preserve any comment
        if (match($0, /#.*/)) {
            comment = " " substr($0, RSTART)
        } else {
            comment = ""
        }
        print "    outer.top =        " ot comment
        next
    }

    # Rewrite the laptop-companion workspaces 7/8/9 to the chosen monitor pattern.
    # Workspaces 1-6 (main) and 0 (sidecar) are intentionally left untouched.
    in_wsmon && /^[[:space:]]*[789][[:space:]]*=/ {
        if (match($0, /#.*/)) {
            comment = " " substr($0, RSTART)
        } else {
            comment = ""
        }
        print "    " $1 " = " ws comment
        next
    }
    { print }
    ' "$AEROSPACE_CONFIG" > "$tmp_file"

    # cp (not mv) to write through symlinks instead of replacing them
    cp "$tmp_file" "$AEROSPACE_CONFIG"
    rm -f "$tmp_file"
}

# Main
main() {
    local force="${1:-}"

    # Capture the SPDisplaysDataType blob ONCE per tick and feed it to every
    # consumer (get_fingerprint, build_top_gap_config -> get_monitors_config,
    # companion_ws_pattern) instead of each spawning its own system_profiler.
    # All those functions still default-arg to a fresh capture when called
    # standalone, so they remain independently runnable.
    local sp_displays
    sp_displays="$(system_profiler SPDisplaysDataType 2>/dev/null)"

    # Check for changes
    local fingerprint
    fingerprint=$(get_fingerprint "$sp_displays") || { log "No displays detected, skipping"; exit 0; }

    if [[ -f "$STATE_FILE" && "$force" != "--force" ]]; then
        local last_fp
        last_fp=$(cat "$STATE_FILE")
        if [[ "$fingerprint" == "$last_fp" ]]; then
            exit 0
        fi
    fi

    echo "$fingerprint" > "$STATE_FILE"
    log "Display change detected (fingerprint: $fingerprint)"

    # Calculate and apply new config
    local top_gap_config
    top_gap_config=$(build_top_gap_config "$sp_displays")
    log "New outer.top config: $top_gap_config"

    # Decide where workspaces 7-9 live based on whether the built-in is main.
    local ws_pattern
    ws_pattern=$(companion_ws_pattern "$sp_displays")
    log "Workspaces 7-9 -> $ws_pattern"

    update_aerospace_config "$top_gap_config" "$ws_pattern"
    log "Updated aerospace.toml"

    # Reload
    if command -v aerospace &> /dev/null; then
        aerospace reload-config
        log "Reloaded aerospace config"
    fi
}

main "$@"
