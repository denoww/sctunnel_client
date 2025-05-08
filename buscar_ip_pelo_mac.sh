#!/bin/bash

MAC=$1
ARP_SCAN_INSTALDO="ARP_SCAN_INSTALDO.txt"
echo "🔍 Procurando IP pelo MAC $MAC" >&2

# Verifica se o marcador de instalação existe
RED='\033[31m'
NC='\033[0m'
if [ ! -f "$ARP_SCAN_INSTALDO" ]; then

  echo -e "${RED}==================================================================${NC}" >&2
  echo -e "${RED}❌ arp-scan não está instalado.${NC}" >&2
  echo -e "${RED}Instale com 'bash /var/lib/sctunnel_client/install.sh'${NC}" >&2
  echo -e "${RED}==================================================================${NC}" >&2

  exit 1
fi

ARP_SCAN_PATH=$(command -v arp-scan)
# Verifica se o comando foi encontrado
if [ -z "$ARP_SCAN_PATH" ]; then
  echo -e "${RED}Comando 'arp-scan' não encontrado no PATH. '.${NC}" >&2
  echo -e "${RED}Faça 'bash /var/lib/sctunnel_client/install.sh' ${NC}" >&2
  echo -e "${RED}ou ${NC}" >&2
  echo -e "${RED}Faça 'sudo apt install arp-scan' ${NC}" >&2
  exit 1
fi



# Verifica se o usuário passou o MAC como argumento
if [ -z "$1" ]; then
  echo "❗ Use: $0 <MAC_ADDRESS>" >&2
  exit 1
fi

TARGET_MAC=$(echo "$MAC" | tr '[:upper:]' '[:lower:]')

# Detecta a interface e IP principal (default route)
read -r IFACE IP <<< $(ip route get 1.1.1.1 | awk '{print $5, $7; exit}')


# Se não encontrou interface
if [ -z "$IFACE" ]; then
  echo "❌ Nenhuma interface detectada." >&2
  exit 2
fi

# Calcula subnet /24
SUBNET=$(echo "$IP" | sed 's/\.[0-9]\+$/\.0\/24/')

# Mostra comando a ser executado
echo "🖥️  Executando: sudo /usr/sbin/arp-scan --interface=$IFACE $SUBNET" >&2

# Executa arp-scan e procura o IP do MAC
FOUND_IP=$(sudo /usr/sbin/arp-scan --interface="$IFACE" "$SUBNET" | awk -v mac="$TARGET_MAC" 'tolower($2) == mac {print $1}')

# Saída final
if [ -n "$FOUND_IP" ]; then
  echo "$FOUND_IP"
  exit 0
else
  # retorna vazio
  exit 1
fi
