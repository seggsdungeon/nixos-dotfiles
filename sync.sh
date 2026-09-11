#!/usr/bin/env bash
# Sync live config into ~/dotfiles and push.
# Fails loudly: a partial sync must not look like a clean one.
set -euo pipefail
USER="/home/user"
DOTS="/home/user/dotfiles"

# --- NixOS ---------------------------------------------------------------
# Trailing /. copies the *contents* of /etc/nixos, not the directory itself,
# so this picks up configuration.nix, flake.nix, flake.lock, spicetify.nix
# and hardware-configuration.nix without nesting.
cp -r /etc/nixos/. "$DOTS/"

# --- Hyprland ------------------------------------------------------------
mkdir -p "$DOTS/.config/hypr"
cp "$USER/.config/hypr/hyprland.conf" "$DOTS/.config/hypr/"

# monitors.conf / workspaces.conf are nwg-displays output — regenerated on
# any layout change. Uncomment if you want them versioned.
# cp "$USER/.config/hypr/monitors.conf"   "$DOTS/.config/hypr/"
# cp "$USER/.config/hypr/workspaces.conf" "$DOTS/.config/hypr/"

# --- nwg-displays --------------------------------------------------------
# rsync, not cp -r: `cp -r src dest` copies src *inside* dest when dest
# already exists, which is what buried .config/nwg-displays/nwg-displays/.
# Trailing slashes on BOTH paths are load-bearing for rsync.
# --delete means a profile removed locally is removed from the repo too.
mkdir -p "$DOTS/.config/nwg-displays"
rsync -a --delete "$USER/.config/nwg-displays/" "$DOTS/.config/nwg-displays/"

# --- Brain_Shell ---------------------------------------------------------
# Uncomment once these exist (post-install). Your patched hypridle.conf and
# hyprlock.conf live in a git clone, so `git pull` reverts them — copying
# them here is a stopgap until the source is pinned properly.
# mkdir -p "$DOTS/.config/Brain_Shell" "$DOTS/brain-shell-patches"
# rsync -a --delete "$USER/.config/Brain_Shell/" "$DOTS/.config/Brain_Shell/"
# cp "$USER/.local/src/Brain_Shell/src/config/hypridle.conf" "$DOTS/brain-shell-patches/"
# cp "$USER/.local/src/Brain_Shell/src/config/hyprlock.conf" "$DOTS/brain-shell-patches/"

# --- Commit --------------------------------------------------------------
cd "$DOTS"
git add -A                      # -A catches deletions anywhere in the tree

if git diff --cached --quiet; then
    echo "sync: nothing changed"
    exit 0                      # `git commit` with no staged changes exits
fi                              # non-zero, which set -e would treat as failure

git commit -m "sync $(date +%Y-%m-%d)"
git push
