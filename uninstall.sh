#!/bin/bash
#
# Mullvad IP Toggle uninstaller
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mikewalker86/mullvad-ip-toggle/main/uninstall.sh | bash
#
INSTALL_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
COMMAND_NAME="mullvad-ip-toggle"

rm -f "$INSTALL_DIR/$COMMAND_NAME"
rm -f "$DESKTOP_DIR/mullvad-ip-toggle.desktop"

for desktop_folder in "$HOME/Desktop" "$HOME/Secretária" "$HOME/Área de Trabalho" "$HOME/Escritorio"; do
    rm -f "$desktop_folder/mullvad-ip-toggle.desktop"
done

echo "Mullvad IP Toggle has been uninstalled."
echo "Note: the configuration file (~/.mullvad_ip_toggle.conf) and the log"
echo "(~/mullvad_ip_toggle.log) were kept. To remove them as well:"
echo "  rm -f ~/.mullvad_ip_toggle.conf ~/mullvad_ip_toggle.log"
