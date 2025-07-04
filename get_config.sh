#!/bin/bash

DIR_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_config() {
  local key="$1"

  if [ -z "$key" ]; then
    jq -r "." "$DIR_LIB/config.json"
  else
    value=$(jq -r ".$key" "$DIR_LIB/config.json")

    # Aplica default SE for a chave tipo_script
    if [[ "$key" == "sc_server.tipo_script" ]]; then
      if [ -z "$value" ] || [ "$value" == "null" ]; then
        value="shell"
      fi
    fi

    echo "$value"
  fi
}
