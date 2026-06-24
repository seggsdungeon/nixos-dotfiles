#!/usr/bin/env bash
WALLPAPER="/home/user/Pictures/wallpapers/frieren/hut_in_woods.png"

# kill any existing instance, start fresh
pkill hyprpaper
sleep 0.5
hyprpaper &

# wait for the IPC socket to be ready, then set via IPC
sleep 1.5
hyprctl hyprpaper preload "$WALLPAPER"
hyprctl hyprpaper wallpaper "eDP-1,$WALLPAPER"
