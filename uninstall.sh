#!/bin/bash
#
# Desinstalador do Mullvad IP Toggle
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/mikewalker86/mullvad-ip-toggle/main/uninstall.sh | bash
#
INSTALL_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
COMANDO="mullvad-ip-toggle"

rm -f "$INSTALL_DIR/$COMANDO"
rm -f "$DESKTOP_DIR/mullvad-ip-toggle.desktop"

for pasta_desktop in "$HOME/Desktop" "$HOME/Secretária" "$HOME/Área de Trabalho" "$HOME/Escritorio"; do
    rm -f "$pasta_desktop/mullvad-ip-toggle.desktop"
done

echo "Mullvad IP Toggle foi desinstalado."
echo "Nota: o ficheiro de configuração (~/.mullvad_ip_toggle.conf) e o log"
echo "(~/mullvad_ip_toggle.log) foram mantidos. Para os apagar também:"
echo "  rm -f ~/.mullvad_ip_toggle.conf ~/mullvad_ip_toggle.log"
