#!/bin/bash

# Verifica se foi passado um argumento
if [ -z "$1" ]; then
  echo "Uso: bash trocar_cliente.sh <novo_cliente_id>"
  exit 1
fi

NOVO_CLIENTE_ID=$1

# Pega o diretório onde o script está
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define o caminho completo do config.json
CONFIG_FILE="$SCRIPT_DIR/config.json"

# Verifica se o arquivo existe
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Erro: Arquivo $CONFIG_FILE não encontrado."
  exit 1
fi


# Faz a substituição do cliente_id no JSON usando jq
# jq --argjson id "$NOVO_CLIENTE_ID" '.sc_server.cliente_id = $id' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson id "$NOVO_CLIENTE_ID" '.sc_server.cliente_id = $id' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv -f "${CONFIG_FILE}.tmp" "$CONFIG_FILE"


echo "cliente_id atualizado para $NOVO_CLIENTE_ID em $CONFIG_FILE"

bash /var/lib/sctunnel_client/exec.sh
