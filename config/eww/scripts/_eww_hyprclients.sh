#!/usr/bin/env bash

ICON_THEME="$(echo $GTK_ICON_THEME | awk -F '=' '{printf $2}')"
ICON_THEME="${ICON_THEME:-$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")}"
ICON_THEME="${ICON_THEME:-$(grep "gtk-icon-theme-name" ~/.config/gtk-3.0/settings.ini | awk -F '=' '{printf $2}')}"

DESKTOP_DIR=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
)
ICONS_DIR=(
    "$HOME/.local/share/icons/$ICON_THEME"
    "/usr/share/icons/$ICON_THEME"
    "/usr/share/icons"
    "$HOME/.local/share/pixmaps"
    "/usr/share/pixmaps"
)
FALLBACK_ICON_PATH_XWAYLAND="assets/images/x11.svg"
FALLBACK_ICON_PATH_WAYLAND="assets/images/wayland.svg"

find_icon_path() {
    local app_class="$1"
    local xwayland="$2"
    local search_names=$(echo "$app_class" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

    for icon_dir in "${ICONS_DIR[@]}"; do
        if [[ -d "$icon_dir" ]]; then
            for ext in svg xpm png jpg jpeg; do
                icon_path_found="$(find -L $icon_dir -name "$app_class.$ext" 2>/dev/null | head -n 1)"
                if [[ -f "$icon_path_found" ]]; then
                    echo "$icon_path_found"
                    return
                fi
            done
        fi
    done

    local desktop_file=""
    for dir in "${DESKTOP_DIR[@]}"; do
        if [[ -f "$dir/${$search_names}.desktop" ]]; then
            desktop_file="$dir/${$search_names}.desktop"
            break
        elif [[ -d "$dir" ]]; then
            local match=$(grep -l "StartupWMClass=.*$app_class" "$dir"/*.desktop 2>/dev/null)
            if [[ -n "$match" ]]; then
                desktop_file="$match"
                break
            fi
        fi
    done

    if [[ -n "$desktop_file" ]]; then
        local icon_val=$(grep -m1 '^Icon=' "$desktop_file" | cut -d'=' -f2-)
        if [[ -n "$icon_val" ]]; then
            if [[ "$icon_val" == /* && -f "$icon_val" ]]; then
                echo "$icon_val"
                return
            else
                for icon_dir in "${ICONS_DIR[@]}"; do
                    if [[ -d $icon_dir ]]; then
                        for ext in svg xpm png jpg jpeg; do
                            icon_path_found="$(find -L $icon_dir -name "*$icon_val*.$ext" 2>/dev/null | head -n 1)"
                            if [[ -f "$icon_path_found" ]]; then
                                echo "$icon_path_found"
                                return
                            fi
                        done
                    fi
                done
            fi
        fi
    fi

    if [[ $xwayland == "false" ]]; then
        echo "$FALLBACK_ICON_PATH_WAYLAND"
    else
        echo "$FALLBACK_ICON_PATH_XWAYLAND"
    fi
}

get_clients() {
    eww get workspaces_clients
}

update_clients() {
    eww update workspaces_clients="$1"
}

open_window() {
    local address="0x$1"
    local ws_id=$2
    local current_clients=$(get_clients)

    local client_obj=$(hyprctl clients -j | jq -c \
        --argjson ws_id "$ws_id" \
        --arg address "$address" \
        '
            .[] | 
            select(.workspace.id == $ws_id and .address == $address) | 
            {address, class, title, initialClass, initialTitle, pid, hidden, xwayland}
        '
    )

    [[ -z "$client_obj" ]] && return 1

    local icon_path=$(find_icon_path  "$(echo "$client_obj" | jq -r .class)" "$(echo "$client_obj" | jq -r .xwayland)") 
    client_obj=$(echo "$client_obj" | jq --arg icon "$icon_path" '. + {icon_path: $icon}')

    local new_clients=$(echo "$current_clients" | jq -c \
        --argjson ws_id "$ws_id" \
        --argjson client "$client_obj" \
        '
            . |= map(
                if .ws_id == $ws_id then
                    .clients += [$client]
                else
                    .
                end
            )
        '
    )

    update_clients "$new_clients"
}

close_window() {
    local address="0x$1"
    local current_clients=$(get_clients)

    local new_clients=$(echo "$current_clients" | jq -c \
        --arg address "$address" \
        '. |= map(.clients |= map(select(.address != $address)))'
    )

    update_clients "$new_clients"
}

move_window() {
    local address="0x$1"
    local destination_ws_id=$2
    local current_clients=$(get_clients)

    local client_obj=$(echo "$current_clients" | jq -c \
        --arg address "$address" \
        '[.[] | .clients[]] | map(select(.address == $address)) | .[0]'
    )
    
    if [ -z "$client_obj" ] || [ "$client_obj" = "null" ]; then
        notify-send "Error: Client with address $address not found in EWW data."
        return 1
    fi

    local new_clients=$(echo "$current_clients" | jq -c \
        --argjson dest_ws_id "$destination_ws_id" \
        --arg address "$address" \
        --argjson client_to_move "$client_obj" \
        '
            . |= map(
                if .ws_id == $dest_ws_id then
                    .clients += [$client_to_move]
                else
                    .clients |= map(select(.address != $address))
                end
            )
        '
    )

    update_clients "$new_clients"
}

create_workspace() {
    local ws_id=$1
    local ws_name=$2
    local current_clients=$(get_clients)

    local ws="{\"ws_id\":$ws_id,\"ws_name\":\"$ws_name\",\"clients\":[]}"

    local new_clients=$(echo "$current_clients" | jq -c \
        --argjson ws "$ws" \
        '. += [$ws]'
    )

    update_clients "$new_clients"
}

destroy_workspace() {
    local ws_id=$1
    local current_clients=$(get_clients)

    local new_clients=$(echo "$current_clients" | jq -c \
        --argjson ws_id "$ws_id" \
        '. |= map(select(.ws_id != $ws_id))'
    )

    update_clients "$new_clients"
}

sync_window() {
    local clients_json=$(hyprctl clients -j)
    local workspaces=$(hyprctl workspaces -j | jq -c '.[] | {id, name}')
    local clients

    local output="["

    for ws in $(echo "$workspaces" | jq -c '.'); do
        ws_id=$(echo "$ws" | jq '.id')
        ws_name=$(echo "$ws" | jq -r '.name')

        clients=$(echo "$clients_json" | jq -c --argjson id "$ws_id" '
            map(select(.workspace.id == $id)) |
            map(select(.class and .class != "")) |
            map({
                address,
                class,
                title,
                initialClass,
                initialTitle,
                pid,
                hidden
            }) | .[:2]
        ')

        clients=$(echo "$clients" | jq -c '.[]' | while read -r client; do
            icon_path=$(find_icon_path "$(echo "$client" | jq -r '.class')")
            echo "$client" | jq --arg icon "$icon_path" '. + {icon_path: $icon}'
        done | jq -s '.')

        output+="{
            \"ws_id\": $ws_id,
            \"ws_name\": \"$ws_name\",
            \"clients\": $clients
        },"
    done

    output="${output%,}"
    output+="]"

    output=$(echo "$output" | jq -c 'sort_by(.id)')

    update_clients "$output"
}

OPT=$1; shift
case "$OPT" in
    --sync)         sync_window;;
    --poll)         sync_window; echo "true";;
    --open)         open_window "$@";; # address(window) ws_id
    --close)        close_window "$@";; # address(window)
    --move)         move_window "$@";; # address(window) dest_ws_id
    --active)       active_window "$@";; # 
    --create-ws)    create_workspace "$@";; # ws_id ws_name
    --destroy-ws)   destroy_workspace "$@";; # ws_id
    *)              notify-send -u critical "Error" "Invalid operation $OPT\n~/.config/eww/scripts/_eww_hyprclients.sh"; exit 1 ;;
esac