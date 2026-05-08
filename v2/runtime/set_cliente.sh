#!/bin/bash
# /opt/sctunnel/set_cliente.sh — wrapper invoked by /usr/local/bin/set_cliente
set -e

if [ -z "$1" ]; then
  echo "Uso: set_cliente <cliente_id>" >&2
  exit 1
fi

NOVO_ID="$1"
BASE=/opt/sctunnel
CONFIG="$BASE/config.json"

jq --argjson id "$NOVO_ID" '.sc_server.cliente_id = $id' "$CONFIG" > "$CONFIG.tmp"
mv -f "$CONFIG.tmp" "$CONFIG"
echo "$NOVO_ID" > "$BASE/cliente.txt"

echo "cliente_id atualizado para $NOVO_ID"
exec "$BASE/run.sh"
