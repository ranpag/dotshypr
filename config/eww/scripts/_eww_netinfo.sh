#!/usr/bin/env bash

# --- Airplane mode --- | icon will replace all
is_airplane_active=false
airplane_icon="󱢂"
if ! rfkill list | grep -q "Soft blocked: no"; then
    is_airplane_active=true
    airplane_icon="󰀝"
fi


# --- Ethernet --- | icon will replace wifi if connected
is_eth_connected=false
eth_icon="󰌙"
if nmcli -t -f TYPE,STATE device | grep -q "^ethernet:connected$"; then
    is_eth_connected=true
    eth_icon="󰌘"
fi


# --- WiFi --- | icon always show
wifi_state="unavailable"
wifi_icon="󰤭"
wifi_device="wlan0"
ssid=""
if rfkill list wifi | grep -q "Soft blocked: no" && [[ $is_airplane_active == "false" ]]; then
    state="$(nmcli -t -f TYPE,STATE device | grep '^wifi:')"
    if [[ $state == "wifi:connected" ]]; then
        wifi_state="connected"
        wifi_signal=$(nmcli -t -f IN-USE,SIGNAL dev wifi list | grep '^\*' | cut -d':' -f2)
        data=$(nmcli -t -f ACTIVE,SSID,DEVICE dev wifi | grep '^yes:')
        ssid=$(echo "$data" | cut -d':' -f2)
        wifi_device=$(echo "$data" | cut -d':' -f3)

        if   [[ $wifi_signal -ge 80 ]]; then
            wifi_icon="󰤨"
        elif [[ $wifi_signal -ge 60 ]]; then
            wifi_icon="󰤥"
        elif [[ $wifi_signal -ge 40 ]]; then
            wifi_icon="󰤢"
        elif [[ $wifi_signal -ge 20 ]]; then
            wifi_icon="󰤟"
        else
            wifi_icon="󰤯"
        fi
    elif [[ $state == "wifi:connecting" ]]; then
        wifi_state="connecting"
        wifi_icon="󰤯"
    elif [[ $state == "wifi:disconnected" ]]; then
        wifi_state="disconnected"
        wifi_icon="󰤯"
        nmcli d wifi rescan
    fi
fi


# --- Bluetooth --- | icon always show
is_bluetooth_daemon_active=false
is_bluetooth_connected=false
connected_device=""
bluetooth_icon="󰂲"
if rfkill list bluetooth | grep -q "Soft blocked: no" && [[  $is_airplane_active == "false" ]]; then
    if systemctl status bluetooth &>/dev/null; then
        is_bluetooth_daemon_active=true
        bluetooth_icon="󰂯"

        if bluetoothctl show | grep -q "Powered: yes"; then
            device_line=$(bluetoothctl devices Connected | head -n 1)

            if [ -n "$device_line" ]; then
                is_bluetooth_connected=true
                connected_device=$(echo "$device_line" | cut -d' ' -f3-)
                bluetooth_icon="󰂱"
            fi
        fi
    fi
fi


# --- VPN (WireGuard only) --- | show if connected
is_vpn_active=false
vpn_interface=""
vpn_icon="󰦞"
if nmcli -t -f TYPE,STATE device | grep -q "^wireguard:connected"; then
    is_vpn_active=true
    vpn_interface="$(nmcli -t -f TYPE,CONNECTION device | grep wireguard | cut -d':' -f2)"
    vpn_icon="󰒘"
fi


# --- Output JSON for Eww ---
printf '{
    "wifi_state": "%s",
    "wifi_icon": "%s",
    "wifi_device": "%s",
    "ssid": "%s",
    "is_bluetooth_daemon_active": %s,
    "is_bluetooth_connected": %s,
    "bluetooth_icon": "%s",
    "connected_device": "%s",
    "is_vpn_active": %s,
    "vpn_icon": "%s",
    "vpn_interface": "%s",
    "is_eth_connected": %s,
    "eth_icon": "%s",
    "is_airplane_active": "%s",
    "airplane_icon": "%s"
}\n' \
    "$wifi_state" \
    "$wifi_icon" \
    "$wifi_device" \
    "$ssid" \
    "$is_bluetooth_daemon_active" \
    "$is_bluetooth_connected" \
    "$bluetooth_icon" \
    "$connected_device" \
    "$is_vpn_active" \
    "$vpn_icon" \
    "$vpn_interface" \
    "$is_eth_connected" \
    "$eth_icon" \
    "$is_airplane_active" \
    "$airplane_icon" | jq -c '.'
