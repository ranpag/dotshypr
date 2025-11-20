#!/usr/bin/env bash

max=$(brightnessctl m)
print_brightness() {
    cur=$(brightnessctl g)
    printf '{"screen": %d}\n' "$((cur * 100 / max))"
}

print_brightness

exec inotifywait -m -q -e close_write /sys/class/backlight/* \
    --format '%e' |
while read -r _; do
    print_brightness
done