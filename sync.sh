#!/usr/bin/env bash
cp /etc/nixos/configuration.nix ~/dotfiles/
cp ~/.config/hypr/hyprland.conf ~/dotfiles/.config/hypr/
cp ~/.config/hypr/hyprpaper.conf ~/dotfiles/.config/hypr/
cp ~/.config/hypr/set-wallpaper.sh ~/dotfiles/.config/hypr/
cp ~/.config/waybar/config.jsonc ~/dotfiles/.config/waybar/
cp ~/.config/waybar/modules.jsonc ~/dotfiles/.config/waybar/
cp ~/.config/waybar/style.css ~/dotfiles/.config/waybar/
cd ~/dotfiles
git add .
git commit -m "sync $(date +%Y-%m-%d)"
git push
