#!/bin/bash


DIR_LIB=$(dirname "$0")
ENVIROM=$1
CLIENTE_ID="$2"
PORTARIA_SERVER_SALT="$3"

config_json_path="$DIR_LIB/config.json"

# Verifica se argumentos foram passados
if [ -z "$ENVIROM" ] || [ -z "$PORTARIA_SERVER_SALT" ] || [ -z "$CLIENTE_ID" ]; then
  echo "❗ Uso: $0 <ENV> <TOKEN> <CLIENTE_ID>"
  exit 1
fi

# Permissão
sudo chown -R "$(whoami)" "$DIR_LIB"

# Copia o config base
cp "$DIR_LIB/config-sample-${ENVIROM}.json" "$config_json_path"

if [ ! -f "$config_json_path" ]; then
  echo "❌ Arquivo $config_json_path não encontrado."
  exit 1
fi



# Atualiza o token
sed -i "s/\"token\": *\"[^\"]*\"/\"token\": \"$PORTARIA_SERVER_SALT\"/" "$config_json_path"

# Atualiza cliente_id
sed -i "s/\"cliente_id\": *[0-9]\+/\"cliente_id\": $CLIENTE_ID/" "$config_json_path"

# Exibe config (se tiver jq)
echo "✅ Configuração atualizada:"
if command -v jq >/dev/null; then
  jq . "$config_json_path"
else
  cat "$config_json_path"
fi
