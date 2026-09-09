#!/bin/bash
#
# Mullvad IP Toggle - automatic Mullvad VPN location/IP rotation
#
# Features:
#   - Choose which region(s) to rotate through: European Union / United
#     States / Brazil - regions can be combined into a single pool
#   - Choose the rotation interval: 25s, 35s, 45s, 60s, 120s
#   - Saves your last configuration and offers to reuse it
#   - "Smart" reconnection that waits for the real handshake instead of a
#     fixed delay, minimizing connection downtime
#   - Automatic retry if the handshake fails
#   - Optional public IP check on every rotation (requires curl)
#   - Desktop notification on every location change (requires notify-send)
#   - Logs every rotation to a file
#   - Full country/city names instead of codes
#   - Updates the terminal window title (visible in the taskbar)
#   - Keyboard control: 'q' quits, 'a' skips ahead to the next rotation
#   - Automatically restores the default configuration on exit

LOG_FILE="$HOME/mullvad_ip_toggle.log"
CONFIG_FILE="$HOME/.mullvad_ip_toggle.conf"

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------
if ! command -v mullvad >/dev/null 2>&1; then
    echo "[Error] The 'mullvad' command was not found."
    echo "Install the Mullvad VPN app and make sure its CLI is in your PATH."
    read -rp "Press ENTER to exit..."
    exit 1
fi

HAS_NOTIFY=0
command -v notify-send >/dev/null 2>&1 && HAS_NOTIFY=1

HAS_CURL=0
command -v curl >/dev/null 2>&1 && HAS_CURL=1

# ---------------------------------------------------------------------------
# Location lists per region
# ---------------------------------------------------------------------------
EU_COUNTRIES=(at be bg hr cy cz dk ee fi fr de gr hu ie it lv lt lu mt nl pl pt ro sk si es se)
US_LOCATIONS=("us nyc" "us lax" "us mia" "us chi" "us dal" "us sea" "us atl" "us den" "us hou" "us slc")
BR_LOCATIONS=("br sao")

# ---------------------------------------------------------------------------
# Full display names (instead of raw codes)
# ---------------------------------------------------------------------------
declare -A COUNTRY_NAME=(
    [at]="Austria" [be]="Belgium" [bg]="Bulgaria" [hr]="Croatia" [cy]="Cyprus"
    [cz]="Czechia" [dk]="Denmark" [ee]="Estonia" [fi]="Finland" [fr]="France"
    [de]="Germany" [gr]="Greece" [hu]="Hungary" [ie]="Ireland" [it]="Italy"
    [lv]="Latvia" [lt]="Lithuania" [lu]="Luxembourg" [mt]="Malta" [nl]="Netherlands"
    [pl]="Poland" [pt]="Portugal" [ro]="Romania" [sk]="Slovakia" [si]="Slovenia"
    [es]="Spain" [se]="Sweden" [us]="United States" [br]="Brazil"
)

declare -A CITY_NAME=(
    [nyc]="New York" [lax]="Los Angeles" [mia]="Miami" [chi]="Chicago"
    [dal]="Dallas" [sea]="Seattle" [atl]="Atlanta" [den]="Denver"
    [hou]="Houston" [slc]="Salt Lake City" [sao]="São Paulo"
)

# Human-readable description of a location code. Automatically detects
# whether it's "country only" (one word, e.g. EU) or "country city"
# (two words, e.g. US/Brazil), which allows combining different regions
# in the same pool without confusion.
describe_location() {
    local code="$1"
    if [[ "$code" == *" "* ]]; then
        local country_code="${code%% *}"
        local city_code="${code##* }"
        echo "${CITY_NAME[$city_code]:-$city_code}, ${COUNTRY_NAME[$country_code]:-$country_code}"
    else
        echo "${COUNTRY_NAME[$code]:-$code}"
    fi
}

# ---------------------------------------------------------------------------
# Builds the location pool from a list of options (1, 2, 3)
# ---------------------------------------------------------------------------
build_locations() {
    local options="$1"
    LOCATIONS=()
    SELECTED_REGION_NAMES=()
    for opt in $options; do
        case "$opt" in
            1) LOCATIONS+=("${EU_COUNTRIES[@]}"); SELECTED_REGION_NAMES+=("European Union") ;;
            2) LOCATIONS+=("${US_LOCATIONS[@]}"); SELECTED_REGION_NAMES+=("United States") ;;
            3) LOCATIONS+=("${BR_LOCATIONS[@]}"); SELECTED_REGION_NAMES+=("Brazil") ;;
        esac
    done
}

# Joins the selected region names with " + " (IFS only uses a single
# character, so it can't be used directly with a 3-character separator)
join_region_names() {
    local result=""
    local name
    for name in "${SELECTED_REGION_NAMES[@]}"; do
        if [ -z "$result" ]; then
            result="$name"
        else
            result="$result + $name"
        fi
    done
    echo "$result"
}

# ---------------------------------------------------------------------------
# Configuration: load/save the last choice
# ---------------------------------------------------------------------------
REGION_OPTION=""

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

use_saved_config=0
if [ -n "$LAST_REGION" ] && [ -n "$LAST_INTERVAL" ]; then
    build_locations "$LAST_REGION"
    echo "========================================="
    echo "        MULLVAD IP TOGGLE"
    echo "========================================="
    echo "Last saved configuration:"
    printf '  Region(s): %s\n' "$(join_region_names)"
    echo "  Interval: ${LAST_INTERVAL}s"
    echo "-----------------------------------------"
    read -rp "Use this configuration? [Y/n]: " answer
    case "$answer" in
        n|N) use_saved_config=0 ;;
        *) use_saved_config=1 ;;
    esac
fi

if [ "$use_saved_config" -eq 1 ]; then
    REGION_OPTION="$LAST_REGION"
    INTERVAL="$LAST_INTERVAL"
    REGION_NAME=$(join_region_names)
else
    # -----------------------------------------------------------------------
    # Interactive menu
    # -----------------------------------------------------------------------
    echo "========================================="
    echo "        MULLVAD IP TOGGLE"
    echo "========================================="
    echo "Choose the region(s) to rotate through:"
    echo "  1) European Union"
    echo "  2) United States (different cities)"
    echo "  3) Brazil (same location, server rotation)"
    echo ""
    echo "You can combine several, separated by spaces (e.g. 1 3)"
    echo "-----------------------------------------"
    read -rp "Option(s): " REGION_OPTION

    build_locations "$REGION_OPTION"
    if [ "${#LOCATIONS[@]}" -eq 0 ]; then
        echo "Invalid option. Exiting."
        exit 1
    fi
    REGION_NAME=$(join_region_names)

    echo ""
    echo "Choose the interval between rotations:"
    echo "  1) 25 seconds"
    echo "  2) 35 seconds"
    echo "  3) 45 seconds"
    echo "  4) 60 seconds"
    echo "  5) 120 seconds"
    echo "-----------------------------------------"
    read -rp "Option [1-5]: " time_option

    case "$time_option" in
        1) INTERVAL=25 ;;
        2) INTERVAL=35 ;;
        3) INTERVAL=45 ;;
        4) INTERVAL=60 ;;
        5) INTERVAL=120 ;;
        *)
            echo "Invalid option. Exiting."
            exit 1
            ;;
    esac

    # Save this choice for next time
    {
        echo "LAST_REGION=\"$REGION_OPTION\""
        echo "LAST_INTERVAL=\"$INTERVAL\""
    } > "$CONFIG_FILE"
fi

# Maximum time to wait for the handshake (should not exceed the interval)
HANDSHAKE_TIMEOUT=15
# Number of reconnection attempts before giving up and moving on anyway
MAX_RECONNECT_ATTEMPTS=2

# ---------------------------------------------------------------------------
# Waits N seconds, but checks at every instant whether the user pressed
# a key:
#   'q' -> quit (this replaces CTRL+C, which on some systems is remapped
#          to the "copy" shortcut and never reaches the script as a signal)
#   'a' -> skip ahead to the next rotation right away, without waiting
# Returns: 0 = time elapsed normally | 1 = quit | 2 = skip ahead
# ---------------------------------------------------------------------------
wait_with_exit(){
    local duration="$1"
    local key
    if read -rsn 1 -t "$duration" key; then
        case "$key" in
            q|Q) return 1 ;;
            a|A) return 2 ;;
        esac
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Waits for the actual VPN reconnection instead of a fixed sleep
# ---------------------------------------------------------------------------
wait_for_reconnection() {
    local elapsed=0
    local result
    while [ "$elapsed" -lt "$HANDSHAKE_TIMEOUT" ]; do
        if mullvad status 2>/dev/null | grep -qi "connected"; then
            return 0
        fi
        wait_with_exit 0.5
        result=$?
        if [ "$result" -eq 1 ]; then
            cleanup
        fi
        elapsed=$((elapsed + 1))
    done
    return 1
}

# ---------------------------------------------------------------------------
# Tries to reconnect, with automatic retries if the handshake fails
# ---------------------------------------------------------------------------
reconnect_with_retries() {
    local attempt=1
    while [ "$attempt" -le "$MAX_RECONNECT_ATTEMPTS" ]; do
        mullvad reconnect > /dev/null 2>&1
        if wait_for_reconnection; then
            echo "[Mullvad] Reconnected successfully (attempt $attempt)."
            return 0
        fi
        echo "[Mullvad] Warning: handshake failed on attempt $attempt."
        attempt=$((attempt + 1))
    done
    echo "[Mullvad] Moving on anyway after $MAX_RECONNECT_ATTEMPTS attempts."
    return 1
}

# ---------------------------------------------------------------------------
# Shows a countdown timer until the next rotation
# ---------------------------------------------------------------------------
countdown() {
    local remaining=$1
    local result
    while [ "$remaining" -gt 0 ]; do
        printf "\rNext rotation in: %02d:%02d  ('q' quit | 'a' skip ahead) " $((remaining / 60)) $((remaining % 60))
        wait_with_exit 1
        result=$?
        if [ "$result" -eq 1 ]; then
            cleanup
        elif [ "$result" -eq 2 ]; then
            printf "\rSkipping ahead to the next location...                     \n"
            return 0
        fi
        remaining=$((remaining - 1))
    done
    printf "\rRotating to the next location...                          \n"
}

# ---------------------------------------------------------------------------
# Cleanup on exit
# ---------------------------------------------------------------------------
cleanup() {
    echo -e "\n\n\n[Mullvad] Stopping automatic IP rotation..."
    echo "[Mullvad] Restoring default configuration (any)..."
    mullvad relay set location any > /dev/null 2>&1
    echo "[Mullvad] Rotation stopped. Bye!"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rotation stopped by the user." >> "$LOG_FILE"
    exit 0
}
trap cleanup SIGINT SIGTERM

# ---------------------------------------------------------------------------
# Start rotating
# ---------------------------------------------------------------------------
echo ""
echo "========================================="
echo "   MULLVAD IP TOGGLE STARTED"
echo "   Region(s): $REGION_NAME"
echo "   Interval: ${INTERVAL}s"
echo "   Log: $LOG_FILE"
echo "   'q' to quit | 'a' to skip ahead to the next rotation"
if [ "$HAS_NOTIFY" -eq 0 ]; then
    echo "   (notify-send not found - desktop notifications disabled)"
fi
if [ "$HAS_CURL" -eq 0 ]; then
    echo "   (curl not found - public IP check disabled)"
fi
echo "========================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rotation started - Region(s): $REGION_NAME, Interval: ${INTERVAL}s" >> "$LOG_FILE"
echo -ne "\033]0;Mullvad: starting...\007"

while true; do
    chosen_location=${LOCATIONS[$RANDOM % ${#LOCATIONS[@]}]}
    location_description=$(describe_location "$chosen_location")

    echo -e "\n========================================="
    echo "[Mullvad] Switching location to: $location_description"

    # Updates the terminal window title (shown in the Cinnamon taskbar)
    echo -ne "\033]0;Mullvad: ${location_description}\007"

    # Deliberately unquoted: if chosen_location is "us nyc", it should
    # split into two separate arguments (country and city). For the EU,
    # a single word, the behavior stays the same.
    mullvad relay set location $chosen_location > /dev/null 2>&1

    reconnect_with_retries

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Location changed to: $chosen_location" >> "$LOG_FILE"

    # "--location" has been deprecated; "-v" (verbose) shows the visible location
    mullvad status -v

    # Optional public IP check
    if [ "$HAS_CURL" -eq 1 ]; then
        current_ip=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null)
        if [ -n "$current_ip" ]; then
            echo "[Mullvad] Current public IP: $current_ip"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Public IP: $current_ip" >> "$LOG_FILE"
        else
            echo "[Mullvad] Could not confirm the public IP (no response)."
        fi
    fi

    # Optional desktop notification
    if [ "$HAS_NOTIFY" -eq 1 ]; then
        notify-send -t 4000 "Mullvad IP Toggle" "Location changed to: $location_description" 2>/dev/null
    fi

    echo "========================================="

    countdown "$INTERVAL"
done
