#!/bin/bash

DIR=/var/lib/sctunnel_client
ENVIROM=$1
PORTARIA_SERVER_SALT="$2"
CLIENTE_ID="$3"

config_json_path="$DIR/config.json"

# Verifica se argumentos foram passados
if [ -z "$ENVIROM" ] || [ -z "$PORTARIA_SERVER_SALT" ] || [ -z "$CLIENTE_ID" ]; then
  echo "❗ Uso: $0 <ENV> <TOKEN> <CLIENTE_ID>"
  exit 1
fi

# Permissão
sudo chown -R "$(whoami)" "$DIR"

# Copia o config base
cp "$DIR/config-sample-${ENVIROM}.json" "$config_json_path"

if [ ! -f "$config_json_path" ]; then
  echo "❌ Arquivo $config_json_path não encontrado."
  exit 1
fi



# Atualiza o token
sed -i "s/\"token\": *\"[^\"]*\"/\"token\": \"$PORTARIA_SERVER_SALT\"/" "$config_json_path"

# Atualiza cliente_id
# sed -i "s/\"cliente_id\": *[0-9]\+/\"cliente_id\": $CLIENTE_ID/" "$config_json_path"

# Exibe config (se tiver jq)
echo "✅ Configuração atualizada:"
if command -v jq >/dev/null; then
  jq . "$config_json_path"
else
  cat "$config_json_path"
fi

# Instala cron jobs
bash "$DIR/install.sh" --install_crons
exec_cliente "$CLIENTE_ID"
