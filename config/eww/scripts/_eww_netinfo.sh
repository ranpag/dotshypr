#!/usr/bin/env bash

declare -A rfkill_devices
actual_devices_count=0
blocked_devices_count=0

while read -r type device soft hard; do
    ((actual_devices_count++))
    [[ $soft == "blocked" || $hard == "blocked" ]] && ((blocked_devices_count++))

    is_blocked="blocked"
    [[ $soft == "unblocked" && $hard == "unblocked" ]] && is_blocked="unblocked"

    rfkill_devices["${type}_${device}"]="$is_blocked"
done < <(rfkill -r -n -o TYPE,DEVICE,SOFT,HARD)


declare -A network_status
(( actual_devices_count == blocked_devices_count )) && network_status["plane_mode"]=true

while IFS=':' read -r type state device; do
    case "$type:$state" in
        ethernet:connected*)  network_status["eth"]=true ;;
        wifi:connected*)      network_status["wifi"]="connected" ;;
        wifi:connecting*)     network_status["wifi"]="connecting";;
        wireguard:connected*) 
            network_status["vpn"]=true 
            network_status["vpn_device"]="$device" 
            ;;
        *) continue ;;
    esac
done < <(nmcli -t -f TYPE,STATE,DEVICE d)


declare -A wifi_connection

if [[ ${network_status["plane_mode"]} != "true" ]]; then

    for key in "${!rfkill_devices[@]}"; do
        [[ $key == wlan_* || $key == wifi_* ]] || continue
        wifi_state="${rfkill_devices[$key]}"
    done

    wifi_state="${wifi_state:-'blocked'}"

    if [[ $wifi_state == "blocked" ]]; then
        wifi_connection["active"]=false
        wifi_connection["state"]="blocked"
        wifi_connection["icon"]="󰤭"
    elif [[ ${network_status["wifi"]} =~ ^connect ]]; then
        while IFS=':' read -r active device ssid signal bars security; do
            [[ $active != "yes" ]] && continue

            wifi_connection["active"]=true
            wifi_connection["state"]="${network_status["wifi"]}"
            wifi_connection["device"]="$device"
            wifi_connection["ssid"]="$ssid"
            wifi_connection["signal"]=$signal
            wifi_connection["bars"]="$bars"
            wifi_connection["security"]="$security"

            if   (( signal >= 80 )); then
                wifi_connection["icon"]="󰤨"
            elif (( signal >= 60 )); then
                wifi_connection["icon"]="󰤥"
            elif (( signal >= 40 )); then
                wifi_connection["icon"]="󰤢"
            elif (( signal >= 20 )); then
                wifi_connection["icon"]="󰤟"
            else
                wifi_connection["icon"]="󰤯"
            fi

        done < <(nmcli -t -f ACTIVE,DEVICE,SSID,SIGNAL,BARS,SECURITY d wifi)
    else
        wifi_connection["active"]=true
        wifi_connection["state"]="disconnect"
        wifi_connection["icon"]="󰤯"
    fi
fi


declare -A bluetooth_connection

if [[ ${network_status["plane_mode"]} != "true" ]] && systemctl is-active --quiet bluetooth; then
    
    for key in "${!rfkill_devices[@]}"; do
        [[ $key == bluetooth_* ]] || continue
        bt_state="${rfkill_devices[$key]}"
    done

    bt_state="${bt_state:-'blocked'}"

    if [[ $bt_state == "blocked" ]]; then
        bluetooth_connection["active"]=false
        bluetooth_connection["state"]="blocked"
        bluetooth_connection["icon"]="󰂲"
    else
        bluetooth_connection["active"]=true
        bt_output=$(bluetoothctl devices Connected 2>/dev/null)

        if [[ -n $bt_output ]]; then
            first_line="${bt_output%%$'\n'*}"

            read -r _ mac name_rest <<<"$first_line"
            device_name="${first_line#* * }"

            bluetooth_connection["state"]="connected"
            bluetooth_connection["device_mac"]="$mac"
            bluetooth_connection["device_name"]="$device_name"
            bluetooth_connection["icon"]="󰂱"
        else
            bluetooth_connection["state"]="disconnected"
            bluetooth_connection["icon"]="󰂯"
        fi
    fi
fi

printf '{
    "wifi_active": %s,
    "wifi_state": "%s",
    "wifi_device": "%s",
    "wifi_ssid": "%s",
    "wifi_signal": "%s",
    "wifi_bars": "%s",
    "wifi_security": "%s",
    "wifi_icon": "%s",
    "bluetooth_active": %s,
    "bluetooth_state": "%s",
    "bluetooth_device_mac": "%s",
    "bluetooth_device_name": "%s",
    "bluetooth_icon": "%s",
    "vpn_active": %s,
    "vpn_device": "%s",
    "vpn_icon": "%s",
    "eth_active": %s,
    "eth_icon": "%s",
    "airplane_active": %s,
    "airplane_icon": "%s"
}\n' \
    "${wifi_connection["active"]:-false}" \
    "${wifi_connection["state"]}" \
    "${wifi_connection["device"]}" \
    "${wifi_connection["ssid"]}" \
    "${wifi_connection["signal"]}" \
    "${wifi_connection["bars"]}" \
    "${wifi_connection["security"]}" \
    "${wifi_connection["icon"]}" \
    "${bluetooth_connection["active"]:-false}" \
    "${bluetooth_connection["state"]}" \
    "${bluetooth_connection["device_mac"]}" \
    "${bluetooth_connection["device_name"]}" \
    "${bluetooth_connection["icon"]}" \
    "${network_status["vpn"]:-false}" \
    "${network_status["vpn_device"]}" \
    "$([[ ${network_status["vpn"]} ]] && echo '󰒘' || echo '󰦞')" \
    "${network_status["eth"]:-false}" \
    "$([[ ${network_status["eth"]} ]] && echo '󰌘' || echo '󰌙')" \
    "${network_status["plane_mode"]:-false}" \
    "$([[ ${network_status["plane_mode"]} ]] && echo '󰀝' || echo '󱢂')" | jq -c .
