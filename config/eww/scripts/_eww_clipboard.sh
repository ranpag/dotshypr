#!/usr/bin/env bash

LOCK_FILE="/tmp/eww-clipboard-watch.lock"

function watch_clip() {
    if [ -f "$LOCK_FILE" ] && kill -0 "$(cat $LOCK_FILE)" 2>/dev/null; then
        exit 1
    fi

    echo $$ > "$LOCK_FILE"

    cleanup() {
        rm -f "$LOCK_FILE"
        exit 0
    }
    trap cleanup SIGTERM SIGINT

    wl-paste --watch bash -c '
        cliphist store

        CLIP_JSON=$(~/.config/eww/scripts/_eww_clipboard.sh)
        eww update clipboard_items="$CLIP_JSON"
    '

    rm -f "$LOCK_FILE"
}


function get_clip() {
    IMAGE_EXTENSIONS="^(png|jpg|jpeg|gif|webp|bmp|svg)$"
    DUMMY_PATH="/usr/share/icons/hicolor/48x48/mimetypes/text-x-generic.png"
    MAX_PREVIEW=60

    text_items="[]"
    file_items="[]"

    while IFS=$'\t' read -r id content; do
        if [[ "$content" == file://* ]]; then
            path="${content#file://}"
            ext="${path##*.}"
            if [[ "${ext,,}" =~ $IMAGE_EXTENSIONS ]]; then
                preview="$path"
            else
                preview="$DUMMY_PATH"
            fi
            file_items=$(echo "$file_items" | jq --argjson id "$id" --arg preview "$preview" \
                '. += [{"id": $id, "preview": $preview}]')
        else
            preview="${content:0:$MAX_PREVIEW}"
            text_items=$(echo "$text_items" | jq --argjson id "$id" --arg preview "$preview" \
                '. += [{"id": $id, "preview": $preview}]')
        fi
    done < <(cliphist list)

    if [ ! -f "$LOCK_FILE" ] || ! kill -0 "$(cat $LOCK_FILE)" 2>/dev/null; then
        watch_clip &
    fi

    file_items=$(echo "$file_items" | jq '[to_entries | group_by(.key / 2 | floor) | map(map(.value))][]')

    jq -n \
        --argjson text "$text_items" \
        --argjson file "$file_items" \
        '[{"type":"text","data":$text},{"type":"file","data":$file}]'
}

get_clip