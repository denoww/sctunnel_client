#!/bin/bash

DIR_LIB="$(cd "$(dirname "$0")" && pwd)"

source "$DIR_LIB/get_config.sh"

tipo_script=$(get_config "sc_server.tipo_script")
echo "tipo_script: $tipo_script"

# Atualiza firmware sempre
bash "${DIR_LIB}/update_firmware.sh"

# Escolhe qual tunnels rodar
if [ "$tipo_script" = "python" ]; then
  python3 "${DIR_LIB}/exec_tunnels.py"
else
  bash "${DIR_LIB}/exec_tunnels.sh"
fi
