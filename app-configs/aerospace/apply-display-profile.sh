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

    while IFS= read -r line; do
        # Detect monitor name (e.g., "Color LCD:", "Display:")
        if [[ "$line" =~ ^[[:space:]]+([A-Za-z].+):$ ]]; then
            # Save previous monitor if exists
            if [[ -n "$current_name" && -n "$current_res" ]]; then
                monitors+=("$current_name|$current_res|$is_retina")
            fi
            current_name="${BASH_REMATCH[1]}"
            current_res=""
            is_retina=false
        fi

        # Detect Retina display (built-in or external Retina)
        if [[ "$line" =~ "Retina" ]]; then
            is_retina=true
        fi

        # Detect resolution (take first resolution line per monitor)
        if [[ -z "$current_res" && "$line" =~ Resolution:\ ([0-9]+)\ x\ ([0-9]+) ]]; then
            current_res="${BASH_REMATCH[1]}x${BASH_REMATCH[2]}"
        fi
    done < <(system_profiler SPDisplaysDataType 2>/dev/null)

    # Don't forget last monitor
    if [[ -n "$current_name" && -n "$current_res" ]]; then
        monitors+=("$current_name|$current_res|$is_retina")
    fi

    # Output monitor info
    printf '%s\n' "${monitors[@]}"
}

# Build the outer.top config string
build_top_gap_config() {
    local -a gap_entries=()
    local default_gap=30

    while IFS='|' read -r name res is_retina; do
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

        gap_entries+=("{ monitor.\"$pattern\" = $gap }")
        log "Monitor: $name ($res) -> gap: $gap (pattern: $pattern)"

        # Use largest gap as default
        if (( gap > default_gap )); then
            default_gap=$gap
        fi
    done < <(get_monitors_config)

    # Build final config string
    if (( ${#gap_entries[@]} == 0 )); then
        echo "$default_gap"
    elif (( ${#gap_entries[@]} == 1 )); then
        # Single monitor - just use the value
        local single_gap="${gap_entries[0]}"
        single_gap="${single_gap#*= }"
        single_gap="${single_gap% \}}"
        echo "$single_gap"
    else
        # Multiple monitors - use array format
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
    system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Resolution:" | sort | md5 | cut -c1-8
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

    mv "$tmp_file" "$AEROSPACE_CONFIG"
}

# Main
main() {
    local force="${1:-}"

    # Check for changes
    local fingerprint
    fingerprint=$(get_fingerprint)

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

    # Notify
    if command -v osascript &> /dev/null; then
        osascript -e "display notification \"Display profile updated\" with title \"AeroSpace\"" 2>/dev/null || true
    fi
}

main "$@"
