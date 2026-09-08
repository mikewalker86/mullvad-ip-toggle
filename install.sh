#!/bin/bash
#
# Instalador do Mullvad IP Toggle
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/mikewalker86/mullvad-ip-toggle/main/install.sh | bash
#
set -e

REPO_RAW="https://raw.githubusercontent.com/mikewalker86/mullvad-ip-toggle/main"
INSTALL_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
COMANDO="mullvad-ip-toggle"

echo "========================================="
echo "   Instalador - Mullvad IP Toggle"
echo "========================================="

if ! command -v mullvad >/dev/null 2>&1; then
    echo "[Aviso] O CLI da Mullvad ('mullvad') não foi encontrado neste sistema."
    echo "        Instala a app da Mullvad VPN antes de usar este programa."
fi

mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR"

echo "A descarregar o script principal..."
curl -fsSL "$REPO_RAW/mullvad_ip_toggle.sh" -o "$INSTALL_DIR/$COMANDO"
chmod +x "$INSTALL_DIR/$COMANDO"

echo "A instalar o atalho de aplicações..."
curl -fsSL "$REPO_RAW/mullvad-ip-toggle.desktop" -o "$DESKTOP_DIR/mullvad-ip-toggle.desktop"
# Substitui o marcador pelo caminho real onde o script ficou instalado
sed -i "s|__EXEC_PATH__|$INSTALL_DIR/$COMANDO|g" "$DESKTOP_DIR/mullvad-ip-toggle.desktop"
chmod +x "$DESKTOP_DIR/mullvad-ip-toggle.desktop"

# Tenta também colocar um atalho na pasta do Ambiente de Trabalho, se existir
# (o nome da pasta varia consoante o idioma do sistema)
for pasta_desktop in "$HOME/Desktop" "$HOME/Secretária" "$HOME/Área de Trabalho" "$HOME/Escritorio"; do
    if [ -d "$pasta_desktop" ]; then
        cp "$DESKTOP_DIR/mullvad-ip-toggle.desktop" "$pasta_desktop/"
        chmod +x "$pasta_desktop/mullvad-ip-toggle.desktop"
        # Marca como "confiável" no Nemo/Nautilus, quando possível
        gio set "$pasta_desktop/mullvad-ip-toggle.desktop" metadata::trusted true 2>/dev/null || true
    fi
done

echo ""
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "-----------------------------------------------------------"
    echo "Aviso: $INSTALL_DIR ainda não está no teu PATH."
    echo "Adiciona esta linha ao teu ~/.bashrc (ou ~/.zshrc) e reinicia o terminal:"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "-----------------------------------------------------------"
fi

echo ""
echo "========================================="
echo "   Instalação concluída!"
echo "========================================="
echo "Podes correr o programa de duas formas:"
echo "  1) Escrevendo 'mullvad-ip-toggle' num terminal"
echo "  2) Procurando 'Mullvad IP Toggle' no menu de aplicações"
echo "     (ou pelo ícone no Ambiente de Trabalho, se foi criado)"
