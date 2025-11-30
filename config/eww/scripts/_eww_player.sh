#!/usr/bin/env bash

escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    echo "$s"
}

PLAYER_ART_DEFAULT_DIR="assets/images/player"
PLAYER_ICON_DEFAULT="󰎇 "
PLAYER_ART_DEFAULT="$PLAYER_ART_DEFAULT_DIR/default.png"

get_metadata_json() {
    local player_status="$(playerctl status)"
    local url="${3:-"$(playerctl metadata xesam:url)"}"

    if [[ $player_status = "Playing" || $player_status = "Paused" ]] || [[ -n $url ]]; then
        local artist="${1:-"$(playerctl metadata artist)"}"
        local title="${2:-"$(playerctl metadata title)"}"
        local art_url="${4:-"$(playerctl metadata mpris:artUrl)"}"
        local icon=""
        local art_default="$PLAYER_ART_DEFAULT"

        if [[ $url =~ youtube ]]; then
            icon='<span color=\"#FF0000\"></span>'
            art_default="$PLAYER_ART_DEFAULT_DIR/youtube.svg"
        elif [[ $url =~ spotify ]]; then
            icon='<span color=\"#1ED760\"></span>'
            art_default="$PLAYER_ART_DEFAULT_DIR/spotify.svg"
        elif [[ $url =~ soundcloud ]]; then
            icon='<span color=\"#F37422\">󰓀</span>'
            art_default="$PLAYER_ART_DEFAULT_DIR/soundcloud.svg"
        fi

        artist="$(escape "$artist")"
        title="$(escape "$title")"
        icon="${icon:-$PLAYER_ICON_DEFAULT}"
        art_url="${art_url:-$art_default}"

        printf '{"icon": "%s", "artist": "%s", "title": "%s", "art_url": "%s", "url": "%s", "status": "%s"}\n' \
            "$icon" "$artist" "$title" "$art_url" "$url" "$player_status"        
    else
        printf '{"icon":"%s","empty":"No media playing right now","art_url":"%s"}\n' \
            "$PLAYER_ICON_DEFAULT" "$PLAYER_ART_DEFAULT"
    fi
}

get_metadata_json

playerctl --follow metadata \
  --format '{{artist}}{{title}}{{xesam:url}}{{mpris:artUrl}}' |
while IFS='' read -r artist title url art_url; do
    get_metadata_json "$artist" "$title" "$url" "$art_url"
done