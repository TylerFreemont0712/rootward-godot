#!/usr/bin/env bash
# Installs the "Rootward (Godot)" launcher in the app menu and on the Desktop, pointing at this checkout.
# Run it again after moving the repo. It leaves the old game's Rootward launcher alone.
# Right-click the icon for "Open in the Godot editor".
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
chmod +x "$root/scripts/play.sh"
apps="$HOME/.local/share/applications"
mkdir -p "$apps"
entry="$apps/rootward-godot.desktop"
cat > "$entry" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Rootward (Godot)
GenericName=Programming Roguelike
Comment=Play Rootward, the Godot rewrite: every spell is real code
Exec=$root/scripts/play.sh
Path=$root
Icon=$root/game/assets/brand/icon-256.png
Terminal=false
StartupNotify=true
Categories=Game;
Keywords=rootward;roguelike;programming;coding;godot;
Actions=Editor;

[Desktop Action Editor]
Name=Open in the Godot editor
Exec=$root/scripts/play.sh --editor
EOF
chmod +x "$entry"
desktop="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
if [ -d "$desktop" ]; then
	cp "$entry" "$desktop/rootward-godot.desktop"
	chmod +x "$desktop/rootward-godot.desktop"
	# Desktops that ask before running a launcher (GNOME, Nemo) accept one marked as trusted.
	gio set "$desktop/rootward-godot.desktop" metadata::trusted true 2>/dev/null || true
fi
update-desktop-database "$apps" 2>/dev/null || true
echo "Installed: $entry${desktop:+ and $desktop/rootward-godot.desktop}"
