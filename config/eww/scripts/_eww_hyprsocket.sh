#!/usr/bin/env bash

ws_id="$(hyprctl activeworkspace -j | jq -r '.id')"
ws_name="$(hyprctl activeworkspace -j | jq -r '.name')"
win_title="$(hyprctl activewindow -j | jq -r '.title')"

printf '{"current_workspace_id": %d, "current_workspace_name": "%s", "focused_window_title": "%s"}\n' \
    "$ws_id" "$ws_name" "$win_title"

socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - |
    stdbuf -o0 awk -F '>>|,' -e '
        /^activewindow>>/   { win_title = $3; print_json(); next }
        /^workspacev2>>/    { ws_id = $2; ws_name = $3; print_json(); next }
        /^openwindow>>/ && $4 != "" { system("sh ~/.config/eww/scripts/_eww_hyprclients.sh --open " $2 " " $4); next }
        /^closewindow>>/    { system("sh ~/.config/eww/scripts/_eww_hyprclients.sh --close " $2); next }

        function print_json() {
            printf "{\"current_workspace_id\": %d, \"current_workspace_name\": \"%s\", \"focused_window_title\": \"%s\"}\n", ws_id, ws_name, win_title
        }
    '