#!/bin/bash

# Verifica se o usuário passou o MAC como argumento
if [ -z "$1" ]; then
  echo "❗ Use: $0 <MAC_ADDRESS>" >&2
  exit 1
fi

TARGET_MAC=$(echo "$1" | tr '[:upper:]' '[:lower:]')

# Detecta a interface com IP na rede 192.168.*
read -r IFACE IP <<< $(ip -o -4 addr show | awk '$4 ~ /^192\.168\./ {print $2, $4; exit}')

# Se não encontrou, exibe erro
if [ -z "$IFACE" ]; then
  echo "❌ Nenhuma interface na rede 192.168.* encontrada." >&2
  exit 2
fi

# Calcula o /24 baseado no IP
SUBNET=$(echo "$IP" | sed 's/\.[0-9]\+\/[0-9]\+$/\.0\/24/')

# Executa arp-scan e extrai apenas o IP do MAC correspondente
FOUND_IP=$(sudo arp-scan --interface="$IFACE" "$SUBNET" | awk -v mac="$TARGET_MAC" 'tolower($2) == mac {print $1}')

if [ -n "$FOUND_IP" ]; then
  echo "$FOUND_IP"
  exit 0
else
  echo "false"
  exit 1
fi
