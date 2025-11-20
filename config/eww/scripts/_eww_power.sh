#!/usr/bin/env bash

source scripts/__var.sh

battery_paths=()
while IFS= read -r line; do
    case "$line" in
        */battery_*) battery_paths+=("$line") ;;
    esac
done < <(upower -e)

total_percentage=0
count=0
overall_state="discharging"
time_to_full="N/A"

for battery in "${battery_paths[@]}"; do
    info=$(upower -i "$battery")

    pct=""
    state_local=""
    ttf_local=""

    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"

        case "$line" in
            percentage:*)
                value=${line#percentage:}
                value=${value%%\%*}
                value=${value//[!0-9]/}
                pct="$value"
                ;;
            state:*)
                state_local=${line#state:}
                state_local=${state_local//[[:space:]]/}
                ;;
            "time to full"*)
                ttf_local=${line#time to full:}
                ttf_local=${ttf_local#"${ttf_local%%[![:space:]]*}"} 
                ;;
        esac
    done <<< "$info"

    if [[ -n $pct ]]; then
        total_percentage=$((total_percentage + pct))
        count=$((count + 1))
    fi

    if [[ $state_local == "charging" ]]; then
        overall_state="charging"
        [[ -n $ttf_local ]] && time_to_full="$ttf_local"
    fi
done

if (( count > 0 )); then
    percentage=$((total_percentage / count))
else
    percentage=0
fi

if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    mode=$(<"/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
else
    mode="unknown"
fi

if [[ $overall_state == "charging" ]]; then
    bat_icon="<span color=\\\"$success\\\">󰂄</span>"
else
    case $percentage in
        [0-9])   bat_icon="<span color=\\\"$error\\\">󰂃</span>" ;;
        1[0-9])  bat_icon="<span color=\\\"$error\\\">󰁺</span>" ;;
        2[0-9])  bat_icon="<span color=\\\"$error\\\">󰁻</span>" ;;
        3[0-9])  bat_icon="<span color=\\\"$warning\\\">󰁼</span>" ;;
        4[0-9])  bat_icon="<span color=\\\"$warning\\\">󰁽</span>" ;;
        5[0-9])  bat_icon="<span color=\\\"$warning\\\">󰁾</span>" ;;
        6[0-9])  bat_icon="<span color=\\\"$success\\\">󰁿</span>" ;;
        7[0-9])  bat_icon="<span color=\\\"$success\\\">󰂀</span>" ;;
        8[0-9])  bat_icon="<span color=\\\"$success\\\">󰂁</span>" ;;
        9[0-9])  bat_icon="<span color=\\\"$success\\\">󰂂</span>" ;;
        100)     bat_icon="<span color=\\\"$success\\\">󰁹</span>" ;;
        *)       bat_icon="󱉝" ;;
    esac
fi

case $mode in
    performance) mode_icon="<span color=\\\"$error\\\"></span>" ;;
    powersave)   mode_icon="<span color=\\\"$success\\\">󰌪</span>" ;;
    *)           mode_icon="" ;;
esac

has_battery=false
[[ $count > 0 ]] && has_battery=true

printf '{"has_battery": %s, "bat_icon": "%s", "mode_icon": "%s", "percentage": %d, "state": "%s", "time_to_full": "%s", "mode": "%s"}\n' \
    "$has_battery" "$bat_icon" "$mode_icon" "$percentage" "$overall_state" "$time_to_full" "$mode"
