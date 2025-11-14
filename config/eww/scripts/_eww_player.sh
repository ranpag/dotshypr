#!/usr/bin/env bash

escape() {
    echo "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e 's/\t/\\t/g' \
        -e 's/\r/\\r/g' \
        -e 's/\n/\\n/g'
}

PLAYER_ART_DEFAULT_DIR="assets/images/player"
PLAYER_ICON_DEFAULT="󰎇 "
PLAYER_ART_DEFAULT="$PLAYER_ART_DEFAULT_DIR/default.png"

get_media_metadata_json() {
    local player_status=$(playerctl status 2>/dev/null)
    local icon=""
    local player_name=""

    if [[ $player_status = "Playing" || $player_status = "Paused" ]]; then
        local artist=$(escape "$(playerctl metadata artist)" 2>/dev/null)
        local title=$(escape "$(playerctl metadata title)" 2>/dev/null)
        local url=$(escape "$(playerctl metadata xesam:url)" 2>/dev/null)
        local artUrl=$(escape "$(playerctl metadata mpris:artUrl)" 2>/dev/null)
        player_name=$(playerctl metadata --format '{{playerName}}' 2>/dev/null)

        if echo "$url" | grep -q "youtube"; then
            icon=" "
            PLAYER_ART_DEFAULT="$PLAYER_ART_DEFAULT_DIR/youtube.svg"
        elif echo "$url" | grep -q "soundcloud"; then
            icon="󰓀 "
            PLAYER_ART_DEFAULT="$PLAYER_ART_DEFAULT_DIR/soundcloud.svg"
        else
            icon="󰎇 "
            PLAYER_ART_DEFAULT="$PLAYER_ART_DEFAULT_DIR/default.png"
        fi

        [[ -z "$artist" ]] && artist="—"
        [[ -z "$title" ]] && title=""
        [[ -z "$artUrl" ]] && artUrl="$PLAYER_ART_DEFAULT"

        printf '{"icon": "%s", "artist": "%s", "title": "%s", "artUrl": "%s", "url": "%s", "status": "%s"}' "$icon" "$artist" "$title" "$artUrl" "$url" "$player_status"
    else
        printf '{"icon": "%s", "empty": "%s", "artUrl": "%s"}' "$PLAYER_ICON_DEFAULT" "No media playing right now" "$PLAYER_ART_DEFAULT"
    fi
}

echo "$(get_media_metadata_json)"

playerctl --follow status 2>/dev/null | while read -r _; do
    echo "$(get_media_metadata_json)"
done