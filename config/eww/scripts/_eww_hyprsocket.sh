#!/usr/bin/env bash

ws=$(hyprctl activeworkspace -j | jq -r '.name')
title=$(hyprctl activewindow -j | jq -r '.title')

printf '{"current_workspace": "%s", "focused_window_title": "%s"}\n' "$ws" "$title"
sh ~/.config/eww/scripts/_eww_hyprclients.sh --sync

socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - |
    stdbuf -o0 awk -F '>>|,' -e '
        /^activewindow>>/   { title = $3; print_json(); next }
        /^workspace>>/      { ws = $2; print_json(); next }
        /^openwindow>>/     { system("sh ~/.config/eww/scripts/_eww_hyprclients.sh --open " $2 " " $3); next }
        /^closewindow>>/    { system("sh ~/.config/eww/scripts/_eww_hyprclients.sh --close " $2); next }
        /^movewindowv2>>/     { system("sh ~/.config/eww/scripts/_eww_hyprclients.sh --move " $2 " " $3); next }
        /^createworkspacev2>>/     { system("sh ~/.config/eww/scripts/_eww_hyprclients.sh --create-ws " $2 " " $3); next }
        /^destroyworkspacev2>>/     { system("sh ~/.config/eww/scripts/_eww_hyprclients.sh --destroy-ws " $2); next }

        function print_json() {
            printf "{\"current_workspace\": \"%s\", \"focused_window_title\": \"%s\"}\n", ws, title
        }
    '