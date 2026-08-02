#!/usr/bin/env bash
#
# rofi-bt.sh — minimal Bluetooth control menu via rofi + bluetoothctl
#
# Menu shows:
#   - Power toggle (On/Off) as the first entry
#   - Every paired device, with a connected/disconnected marker
#   - Selecting a device connects it if disconnected, disconnects if connected
#
# Requires: rofi, bluez-utils (bluetoothctl)
#
# Usage: bind this script to a keypress or a Waybar module on-click.

THEME="$HOME/.config/rofi/bluetooth.rasi"

# --- helpers ------------------------------------------------------

power_state() {
    # returns "on" or "off"
    bluetoothctl show | grep -q "Powered: yes" && echo "on" || echo "off"
}

toggle_power() {
    if [[ "$(power_state)" == "on" ]]; then
        bluetoothctl power off
    else
        bluetoothctl power on
    fi
}

is_connected() {
    # $1 = device MAC
    bluetoothctl info "$1" | grep -q "Connected: yes"
}

toggle_connection() {
    # $1 = device MAC
    if is_connected "$1"; then
        bluetoothctl disconnect "$1"
    else
        bluetoothctl connect "$1"
    fi
}

# --- build menu -----------------------------------------------------

build_menu() {
    local pwr
    pwr="$(power_state)"

    if [[ "$pwr" == "on" ]]; then
        echo "󰂯  Power: On"
    else
        echo "󰂲  Power: Off"
    fi

    # Only list paired devices if powered on — bluetoothctl returns
    # nothing useful with the adapter off.
    if [[ "$pwr" == "on" ]]; then
        bluetoothctl devices Paired | while read -r _ mac name; do
            if is_connected "$mac"; then
                echo "  $name"   # nf-md-check-circle — connected
            else
                echo "  $name"   # nf-md-close-circle-outline — paired, not connected
            fi
        done
    fi
}

# --- main -------------------------------------------------------

selection=$(build_menu | rofi -dmenu -i -p "Bluetooth" -theme "$THEME")

[[ -z "$selection" ]] && exit 0

if [[ "$selection" == *"Power:"* ]]; then
    toggle_power
    exit 0
fi

# Strip the leading icon+space, look up the MAC for the chosen name
name="${selection#* }"
mac=$(bluetoothctl devices Paired | grep -F "$name" | awk '{print $2}')

[[ -n "$mac" ]] && toggle_connection "$mac"
