#!/bin/bash

set -e

echo
echo "📦 Verificando e instalando arp-scan..."
# sudo apt-get update -y
sudo apt-get install -y arp-scan

# Detecta o binário real do arp-scan
ARP_SCAN_BIN="/usr/sbin/arp-scan"
ARP_SCAN_INSTALDO="ARP_SCAN_INSTALDO.txt"

# Aplica setcap para permitir rodar sem sudo
echo "🔧 Aplicando permissões com setcap..."
sudo setcap cap_net_raw,cap_net_admin=eip "$ARP_SCAN_BIN"

# Verifica se deu certo
if getcap "$ARP_SCAN_BIN" | grep -q "cap_net_admin,cap_net_raw+eip"; then
  echo "✅ Permissões aplicadas com sucesso."
else
  echo "❌ Falha ao aplicar permissões com setcap." >&2
  exit 1
fi

# Detecta a melhor interface com IP local na faixa 192.168.*
echo "🌐 Detectando interface de rede ativa (192.168.*)..."
# read -r IFACE IP <<< "$(ip -o -4 addr show | awk '$4 ~ /^192\.168\./ {print $2, $4; exit}')"

read -r IFACE IP <<< $(ip route get 1.1.1.1 | awk '{print $5, $7; exit}')


if [ -z "$IFACE" ]; then
  echo "❌ Nenhuma interface  detectada." >&2
  exit 1
fi

echo "✅ Interface detectada: $IFACE ($IP)"

# Testa a varredura
echo "🔍 Iniciando varredura com arp-scan..."
$ARP_SCAN_BIN --interface="$IFACE" 192.168.0.0/24

# Marca como instalado
touch "$ARP_SCAN_INSTALDO"
echo "✅ Script concluído. Você já pode usar arp-scan diretamente, sem sudo."
