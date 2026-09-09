#!/bin/bash
#
# Mullvad IP Toggle installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mikewalker86/mullvad-ip-toggle/main/install.sh | bash
#
set -e

REPO_RAW="https://raw.githubusercontent.com/mikewalker86/mullvad-ip-toggle/main"
INSTALL_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
COMMAND_NAME="mullvad-ip-toggle"

echo "========================================="
echo "   Mullvad IP Toggle - Installer"
echo "========================================="

if ! command -v mullvad >/dev/null 2>&1; then
    echo "[Warning] The Mullvad CLI ('mullvad') was not found on this system."
    echo "          Install the Mullvad VPN app before using this program."
fi

mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR"

echo "Downloading the main script..."
curl -fsSL "$REPO_RAW/mullvad_ip_toggle.sh" -o "$INSTALL_DIR/$COMMAND_NAME"
chmod +x "$INSTALL_DIR/$COMMAND_NAME"

echo "Installing the application launcher..."
curl -fsSL "$REPO_RAW/mullvad-ip-toggle.desktop" -o "$DESKTOP_DIR/mullvad-ip-toggle.desktop"
# Replaces the placeholder with the actual install path
sed -i "s|__EXEC_PATH__|$INSTALL_DIR/$COMMAND_NAME|g" "$DESKTOP_DIR/mullvad-ip-toggle.desktop"
chmod +x "$DESKTOP_DIR/mullvad-ip-toggle.desktop"

# Also tries to place a shortcut on the Desktop folder, if it exists
# (the folder name varies depending on the system's language)
for desktop_folder in "$HOME/Desktop" "$HOME/Secretária" "$HOME/Área de Trabalho" "$HOME/Escritorio"; do
    if [ -d "$desktop_folder" ]; then
        cp "$DESKTOP_DIR/mullvad-ip-toggle.desktop" "$desktop_folder/"
        chmod +x "$desktop_folder/mullvad-ip-toggle.desktop"
        # Marks the file as "trusted" on Nemo/Nautilus, when possible
        gio set "$desktop_folder/mullvad-ip-toggle.desktop" metadata::trusted true 2>/dev/null || true
    fi
done

echo ""
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "-----------------------------------------------------------"
    echo "Warning: $INSTALL_DIR is not yet in your PATH."
    echo "Add this line to your ~/.bashrc (or ~/.zshrc) and restart your terminal:"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "-----------------------------------------------------------"
fi

echo ""
echo "========================================="
echo "   Installation complete!"
echo "========================================="
echo "You can run the program in two ways:"
echo "  1) Typing 'mullvad-ip-toggle' in a terminal"
echo "  2) Searching for 'Mullvad IP Toggle' in your applications menu"
echo "     (or the Desktop icon, if one was created)"
