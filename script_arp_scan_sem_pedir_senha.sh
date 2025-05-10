#!/bin/bash
set -e

echo
echo "📦 Verificando e instalando arp-scan..."
sudo apt-get install -y arp-scan libcap2-bin

DIR_LIB="/var/lib/sctunnel_client"
ARP_SCAN_INSTALDO="${DIR_LIB}/ARP_SCAN_INSTALADO.txt"

# Detecta o binário real do arp-scan
# ARP_SCAN_PATH=$(command -v arp-scan)
ARP_SCAN_PATH=$(which arp-scan 2>/dev/null)

if [ -z "$ARP_SCAN_PATH" ]; then
  echo "❌ arp-scan não encontrado após instalação." >&2
  exit 1
fi

# Aplica setcap para rodar sem sudo
echo "🔧 Aplicando permissões com setcap..."
sudo setcap cap_net_raw,cap_net_admin=eip "$ARP_SCAN_PATH"

# Verifica se deu certo
# Verifica se deu certo
if getcap "$ARP_SCAN_PATH" | grep -q "cap_net_admin,cap_net_raw+eip"; then
  echo "✅ Permissões aplicadas com sucesso."
else
  echo "⚠️ Permissões não confirmadas via getcap, mas setcap foi executado. Continuando..."
fi

# if getcap "$ARP_SCAN_PATH" | grep -q "cap_net_admin,cap_net_raw+eip"; then
#   echo "✅ Permissões aplicadas com sucesso."
# else
#   echo "❌ Falha ao aplicar permissões com setcap." >&2
#   exit 1
# fi

# Detecta a melhor interface com IP local na rota padrão
echo "🌐 Detectando interface de rede ativa..."
read -r IFACE IP <<< "$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5, $7; exit}')"

if [ -z "$IFACE" ] || [ -z "$IP" ]; then
  echo "❌ Nenhuma interface de rede detectada." >&2
  exit 1
fi

echo "✅ Interface detectada: $IFACE ($IP)"
SUBNET=$(echo "$IP" | sed 's/\.[0-9]\+$/\.0\/24/')

# Testa a varredura
echo "🔍 Iniciando varredura com arp-scan em $SUBNET..."
$ARP_SCAN_PATH --interface="$IFACE" "$SUBNET"

# Marca como instalado
touch "$ARP_SCAN_INSTALDO"
echo "✅ Script concluído. Você já pode usar arp-scan diretamente, sem sudo."
