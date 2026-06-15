#!/bin/bash
# AeroSpace Display Profile Auto-Switcher
# Calculates optimal gaps based on each monitor's resolution

set -euo pipefail

AEROSPACE_CONFIG="$HOME/.aerospace.toml"
STATE_FILE="/tmp/aerospace-display-profile.state"
LOG_FILE="/tmp/aerospace-display-profile.log"

# Gap calculation settings - TUNE THESE VALUES
# Reference gap for a standard 1440p external monitor
REFERENCE_GAP=42

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
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

        # Detect Retina display (built-in or external Retina)
        if [[ "$line" =~ "Retina" ]]; then
            is_retina=true
        fi

        # Detect the main display (carries the menu bar)
        if [[ "$line" =~ Main\ Display:\ Yes ]]; then
            is_main=true
        fi

        # Detect resolution (take first resolution line per monitor)
        if [[ -z "$current_res" && "$line" =~ Resolution:\ ([0-9]+)\ x\ ([0-9]+) ]]; then
            current_res="${BASH_REMATCH[1]}x${BASH_REMATCH[2]}"
        fi
    done < <(system_profiler SPDisplaysDataType 2>/dev/null)

    # Don't forget last monitor
    if [[ -n "$current_name" && -n "$current_res" ]]; then
        monitors+=("$current_name|$current_res|$is_retina|$is_main")
    fi

    # Output monitor info
    printf '%s\n' "${monitors[@]}"
}

# Build the outer.top config string
build_top_gap_config() {
    local -a gap_entries=()
    local default_gap=30
    local main_gap=""

    while IFS='|' read -r name res is_retina is_main; do
        [[ -z "$name" ]] && continue

        # Extract width and height
        local width="${res%x*}"
        local height="${res#*x}"
        local gap
        gap=$(calculate_top_gap "$width" "$height" "$is_retina")

        # Remember the gap of the main display (the one with the menu bar)
        if [[ "$is_main" == "true" ]]; then
            main_gap="$gap"
        fi

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

        gap_entries+=("{ monitor.\"$pattern\" = $gap }")
        log "Monitor: $name ($res) -> gap: $gap (pattern: $pattern)"

        # Use largest gap as default
        if (( gap > default_gap )); then
            default_gap=$gap
        fi
    done < <(get_monitors_config)

    # When SketchyBar is hidden on the secondary monitors, keep the bar gap
    # only on the main monitor (where the bar still shows) and reclaim the
    # freed top space on every other monitor — regardless of monitor count.
    # The old `monitor.secondary` keyword only works for 2-monitor setups,
    # so use `monitor.main` + a small default instead.
    local bar_state_file="/tmp/secondary-bar.state"
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
        # Bar hidden on secondaries: keep main's gap, reclaim to 10 elsewhere.
        log "Secondary bar hidden — keeping main gap ($main_gap), reclaiming others to 10"
        echo "[{ monitor.main = $main_gap }, 10]"
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
    local resolutions
    resolutions=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Resolution:" | sort)
    # Bail if no displays detected (system_profiler returns empty in some non-GUI contexts)
    [[ -z "$resolutions" ]] && return 1
    echo "$resolutions" | /sbin/md5 | cut -c1-8
}

# Update aerospace.toml with new gap values
update_aerospace_config() {
    local outer_top="$1"

    cp "$AEROSPACE_CONFIG" "$AEROSPACE_CONFIG.bak"

    local tmp_file
    tmp_file=$(mktemp)

    awk -v ot="$outer_top" '
    /^\[gaps\]/ { in_gaps=1 }
    /^\[/ && !/^\[gaps\]/ { in_gaps=0 }

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
    { print }
    ' "$AEROSPACE_CONFIG" > "$tmp_file"

    # cp (not mv) to write through symlinks instead of replacing them
    cp "$tmp_file" "$AEROSPACE_CONFIG"
    rm -f "$tmp_file"
}

# Main
main() {
    local force="${1:-}"

    # Check for changes
    local fingerprint
    fingerprint=$(get_fingerprint) || { log "No displays detected, skipping"; exit 0; }

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
    top_gap_config=$(build_top_gap_config)
    log "New outer.top config: $top_gap_config"

    update_aerospace_config "$top_gap_config"
    log "Updated aerospace.toml"

    # Reload
    if command -v aerospace &> /dev/null; then
        aerospace reload-config
        log "Reloaded aerospace config"
    fi
}

main "$@"
