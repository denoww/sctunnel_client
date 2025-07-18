#!/bin/bash


DIR_LIB="$(cd "$(dirname "$0")" && pwd)"
ENVIROM=$1
cliente_id="$2"
token="$3"
tipo_script="$4"

config_json_path="$DIR_LIB/config.json"

# Verifica se argumentos foram passados
if [ -z "$ENVIROM" ] || [ -z "$token" ] || [ -z "$cliente_id" ] || [ -z "$tipo_script" ]; then
  echo "❗ Uso: $0 <ENV> <TOKEN> <cliente_id>"
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



declare -a keys=("token" "tipo_script" "cliente_id")
declare -a values=("$token" "$tipo_script" "$cliente_id")

# ======================================
# Loop geral
# ======================================

for i in "${!keys[@]}"; do
  key="${keys[$i]}"
  value="${values[$i]}"

  echo "🔧 Atualizando $key => $value"

  if grep -q "\"$key\":" "$config_json_path"; then
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      sed -i "/\"sc_server\": {/,/}/s/\"$key\": *[0-9]\+/\"$key\": $value/" "$config_json_path"
    else
      sed -i "/\"sc_server\": {/,/}/s/\"$key\": *\"[^\"]*\"/\"$key\": \"$value\"/" "$config_json_path"
    fi
  else
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      sed -i "/\"sc_server\": {/,/}/s/}/  , \"$key\": $value\n  }/" "$config_json_path"
    else
      sed -i "/\"sc_server\": {/,/}/s/}/  , \"$key\": \"$value\"\n  }/" "$config_json_path"
    fi
  fi
done



# Exibe config (se tiver jq)
echo "✅ Configuração atualizada:"
if command -v jq >/dev/null; then
  jq . "$config_json_path"
else
  cat "$config_json_path"
fi

bash "$DIR_LIB/trocar_cliente.sh" "$cliente_id"
