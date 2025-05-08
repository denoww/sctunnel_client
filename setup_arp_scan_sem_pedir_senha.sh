#!/bin/bash

# Detecta o caminho do comando arp-scan

sudo apt install arp-scan
ARP_SCAN_PATH=$(command -v arp-scan)

# Verifica se o comando foi encontrado
if [ -z "$ARP_SCAN_PATH" ]; then
  echo "❌ Comando 'arp-scan' não encontrado no PATH. Verifique se está instalado Faça sudo apt install arp-scan." >&2
  exit 1
fi

# Nome do arquivo sudoers customizado
SUDOERS_FILE="/etc/sudoers.d/arp-scan-nopasswd"
# Arquivo de confirmação
ARP_SCAN_INSTALDO="ARP_SCAN_INSTALDO.txt"

# Usuário atual
USER_NAME="$USER"

# Verifica se já está configurado
if sudo grep -q "$ARP_SCAN_PATH" "$SUDOERS_FILE" 2>/dev/null; then
  echo "✅ O sudo sem senha para arp-scan já está configurado para o usuário '$USER_NAME'."
  touch "$ARP_SCAN_INSTALDO"
  exit 0
fi

# Cria a regra no sudoers
echo "🔧 Configurando sudo sem senha para '$ARP_SCAN_PATH'..."
echo "$USER_NAME ALL=(ALL) NOPASSWD: $ARP_SCAN_PATH" | sudo tee "$SUDOERS_FILE" > /dev/null

# Verifica se foi criado com sucesso
if [ -f "$SUDOERS_FILE" ]; then
  echo "✅ Configuração concluída. Você já pode rodar:"
  echo "    sudo $ARP_SCAN_PATH ..."
  echo "👉 Sem precisar digitar a senha."
  touch "$ARP_SCAN_INSTALDO"
else
  echo "❌ Falha ao criar o arquivo sudoers." >&2
  exit 1
fi
