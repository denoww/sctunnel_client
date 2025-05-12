#!/bin/bash
set -e

echo
echo "🧹 Removendo serviço e timer de reinício de rede..."

# Caminhos
DIR_LIB="$(cd "$(dirname "$0")" && pwd)"
NM_SCRIPT_PATH="${DIR_LIB}/restart_network.sh"
SERVICE_FILE="/etc/systemd/system/restart-network.service"
TIMER_FILE="/etc/systemd/system/restart-network.timer"
SUDOERS_FILE="/etc/sudoers.d/restart_networkmanager_$(whoami)"

# Para o timer se estiver ativo
echo "⛔ Parando e desabilitando timer..."
sudo systemctl disable --now restart-network.timer || true
sudo systemctl stop restart-network.service || true

# Remove arquivos
echo "🗑️ Removendo arquivos:"
sudo rm -f "$SERVICE_FILE"
sudo rm -f "$TIMER_FILE"
sudo rm -f "$NM_SCRIPT_PATH"
sudo rm -f "$SUDOERS_FILE"

# Recarrega systemd
sudo systemctl daemon-reload

echo
echo "✅ Remoção concluída. O sistema não reiniciará mais a rede automaticamente."
