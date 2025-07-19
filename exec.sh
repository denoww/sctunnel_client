#!/bin/bash

# exec.sh
DIR_LIB="$(cd "$(dirname "$0")" && pwd)"
source "$DIR_LIB/env.sh"



source "$DIR_LIB/get_config.sh"

tipo_script=$(get_config "sc_server.tipo_script")
echo "tipo_script: $tipo_script"

# Atualiza firmware sempre
bash "${DIR_LIB}/update_firmware.sh"



# Escolhe qual tunnels rodar
if [ "$tipo_script" = "python" ]; then
  # garantir_cap_net_raw

  echo "[INFO] Usando Python: $PYTHON_REAL"
  "$PYTHON_REAL" "${DIR_LIB}/exec_tunnels.py"

else
  bash "${DIR_LIB}/exec_tunnels.sh"
fi
