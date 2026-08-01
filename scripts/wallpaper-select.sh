#!/usr/bin/env bash
# ~/.config/hypr/scripts/wallpaper-select.sh
# Rofi wallpaper picker with HiDPI-aware thumbnails -> swww -> matugen (dark).
# Adapted from JaKooLit/Hyprland-Dots WallpaperSelect.sh, stripped to image-only.

WALL_DIR="$HOME/Pictures/wallpapers"

# Kill any stale rofi instance before opening a new one
if pidof rofi > /dev/null; then
    pkill rofi
fi

# --- HiDPI-aware icon sizing ---
# Pull the focused monitor's width and scale factor, size icons at ~11% of
# width adjusted for scale, so the grid looks right on any monitor you're on.
focused_monitor_json=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true)')
mon_width=$(echo "$focused_monitor_json" | jq -r '.width')
mon_scale=$(echo "$focused_monitor_json" | jq -r '.scale')

icon_size=$(awk -v w="$mon_width" -v s="$mon_scale" 'BEGIN { printf "%d", (w * 0.11) / s }')

rofi_override="element-icon{size:${icon_size}px;} listview{columns:4; lines:3;} window{width:60%;}"

# --- Build the menu ---
menu() {
    for img in "$WALL_DIR"/*.jpg "$WALL_DIR"/*.jpeg "$WALL_DIR"/*.png "$WALL_DIR"/*.webp; do
        [ -e "$img" ] || continue
        name="$(basename "$img")"
        echo -en "${name}\0icon\x1fthumbnail://${img}\n"
    done
}

selected_name=$(menu | rofi -dmenu -show-icons -i \
    -p "Wallpaper" \
    -theme-str "$rofi_override")

[ -z "$selected_name" ] && exit 0

selected_path="$WALL_DIR/$selected_name"

# --- Apply wallpaper ---
# NOTE: swww was archived and replaced by awww on Arch as of late 2025/early
# 2026 (see earlier note). Confirm which one `pacman -Ss swww` resolves to on
# your system before relying on this — command syntax may differ slightly.
awww img "$selected_path" \
    --transition-type grow \
    --transition-duration 1.2 \
    --transition-fps 60

# --- Regenerate system-wide theme (forced dark), triggers all post_hooks ---
matugen image "$selected_path" --prefer darkness

echo "$selected_path" > "$HOME/.cache/current_wallpaper"
