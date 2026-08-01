#!/usr/bin/env bash
# Reads AMD GPU usage + temp from sysfs (amdgpu driver, card0 assumed).
# Adjust CARD if your GPU isn't card0 — check with: ls /sys/class/drm/ | grep card
CARD="card1"
BUSY_PATH="/sys/class/drm/${CARD}/device/gpu_busy_percent"
HWMON_BASE="/sys/class/drm/${CARD}/device/hwmon"

usage=$(cat "$BUSY_PATH" 2>/dev/null || echo "0")

# find the hwmon temp1_input under this card (numbered dir varies)
#temp_path=$(find "$HWMON_BASE" -maxdepth 1 -name "hwmon*" 2>/dev/null | head -1)
temp_path="${HWMON_BASE}/hwmon2/"
if [ -n "$temp_path" ] && [ -f "$temp_path/temp1_input" ]; then
    temp_raw=$(cat "$temp_path/temp1_input")
    temp=$((temp_raw / 1000))
else
    temp="?"
fi

echo "{\"text\": \"${usage}% ${temp}°C\", \"tooltip\": \"GPU: ${usage}% busy, ${temp}°C\"}"
