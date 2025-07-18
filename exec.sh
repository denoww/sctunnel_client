#!/bin/bash

PYTHON_REAL="/usr/bin/python3.8"

DIR_LIB="$(cd "$(dirname "$0")" && pwd)"

source "$DIR_LIB/get_config.sh"

tipo_script=$(get_config "sc_server.tipo_script")
echo "tipo_script: $tipo_script"

# Atualiza firmware sempre
bash "${DIR_LIB}/update_firmware.sh"

# Escolhe qual tunnels rodar
if [ "$tipo_script" = "python" ]; then
  # python3 "${DIR_LIB}/exec_tunnels.py"
  # python "${DIR_LIB}/exec_tunnels.py"
  # if command -v python3 &>/dev/null; then
  #   echo "rodando com $ python3"
  #   python3 "${DIR_LIB}/exec_tunnels.py"
  # elif command -v python &>/dev/null; then
  #   echo "rodando com $ python"
  #   python "${DIR_LIB}/exec_tunnels.py"
  # else
  #   echo "Erro: Python não encontrado." >&2
  #   exit 1
  # fi

  # PYTHON_REAL="/usr/bin/python3.10"
  # PYTHON_REAL=$(readlink -f "$(which python3.10)")
  DIR_LIB="$(dirname "$0")"

  echo "[INFO] Usando Python: $PYTHON_REAL"
  "$PYTHON_REAL" "${DIR_LIB}/exec_tunnels.py"

else
  bash "${DIR_LIB}/exec_tunnels.sh"
fi
