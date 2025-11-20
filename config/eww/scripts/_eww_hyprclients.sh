#!/usr/bin/env bash

ICON_THEME="$GTK_ICON_THEME"

if [[ -z  $ICON_THEME ]]; then
    ICON_THEME="$(gsettings get org.gnome.desktop.interface icon-theme)"
    ICON_THEME="${ICON_THEME//\'/}"
fi

if [[ -z  $ICON_THEME ]]; then
    ICON_THEME="$(grep "gtk-icon-theme-name" ~/.config/gtk-3.0/settings.ini)"
    ICON_THEME="${ICON_THEME##*=}"
fi

DESKTOP_DIR=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
)
ICONS_DIR=(
    "$HOME/.local/share/icons/$ICON_THEME"
    "/usr/share/icons/$ICON_THEME"
    "/usr/share/icons"
)
FALLBACK_ICON_PATH_XWAYLAND="assets/images/x11.svg"
FALLBACK_ICON_PATH_WAYLAND="assets/images/wayland.svg"

# $1 app_class, $2 is_xwayland
find_icon_path() {
    local xwayland="$2"
    local search_names="${1,,}"
    search_names="${search_names// /-}"

    local desktop_file=""
    for dir in "${DESKTOP_DIR[@]}"; do
        if [[ -f "$dir/${search_names}.desktop" ]]; then
            desktop_file="$dir/${search_names}.desktop"
            break
        fi
    done

    local icon_val=""
    if [[ -n $desktop_file ]]; then

        while IFS='=' read -r key value; do
            [[ $key == "Icon" ]] && icon_val="$value" && break
        done < "$desktop_file"

        if [[ -n $icon_val ]]; then
            if [[ $icon_val == /* && -f $icon_val ]]; then
                echo "$icon_val"
                return
            fi
        fi
    fi

    icon_val="${icon_val:-$search_names}"
    for icon_dir in "${ICONS_DIR[@]}"; do
        if [[ -d $icon_dir ]]; then
            for ext in svg png xpm jpg jpeg; do
                local icon_path_found="$(find -L $icon_dir -name "*$icon_val*.$ext" 2>/dev/null)"
                local icon_path="${icon_path_found%%$'\n'*}"

                if [[ -f "$icon_path" ]]; then
                    echo "$icon_path"
                    return
                fi
            done
        fi
    done

    if [[ $xwayland == "false" ]]; then
        echo "$FALLBACK_ICON_PATH_WAYLAND"
        return
    fi

    echo "$FALLBACK_ICON_PATH_XWAYLAND"
}

get_clients() {
    eww get clients
}

update_clients() {
    eww update clients="$1"
}

# $1 address $2 class
open_window() {
    local address="0x$1"
    local class="$2"

    [[ -z $class ]] && return

    local current_clients=$(get_clients)

    local new_client=$(hyprctl clients -j | jq -c \
        --arg address "$address" \
        '
            .[] | select(.address == $address) | 
            {address, class, title, pid, hidden, xwayland}
        '
    )

    [[ -z $new_client ]] && return 1

    local is_xwayland="$(jq -r '.xwayland' <<<"$new_client")"
    local icon_path="$(find_icon_path  "$class" "$is_xwayland")"
    new_client="$(jq --arg icon "$icon_path" '. + {icon_path: $icon}' <<<"$new_client")"

    local new_clients="$(jq -c --argjson client "$new_client" '. += [$client]' <<<"$current_clients")"

    update_clients "$new_clients"
}

# $1 address
close_window() {
    local address="0x$1"
    local current_clients=$(get_clients)

    [[ -z $1 ]] && return 1

    local new_clients=$(echo "$current_clients" | jq -c \
        --arg address "$address" \
        '. |= map(select(.address != $address))'
    )

    update_clients "$new_clients"
}

sync_window() {
    local clients_json
    clients_json="$(hyprctl clients -j)"

    local output="["
    local class is_xwayland icon_path

    while IFS= read -r client; do
        class="$(jq -r '.class' <<<"$client")"
        is_xwayland="$(jq -r '.xwayland' <<<"$client")"

        icon_path="$(find_icon_path "$class" "$is_xwayland")"
        client="$(jq --arg icon "$icon_path" '. + {icon_path: $icon}' <<<"$client")"

        output+="$client,"
    done < <(jq -c '.[] | {address, class, title, pid, hidden, xwayland}' <<<"$clients_json")

    output="${output%,}]"

    echo "$output" | jq -c .
}

OPT=$1; shift
case "$OPT" in
    --sync)         sync_window;;
    --open)         open_window "$@";;
    --close)        close_window "$@";;
esac