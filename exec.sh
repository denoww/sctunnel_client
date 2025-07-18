#!/bin/bash

PYTHON_REAL="/usr/bin/python3.10"
DIR_LIB="$(cd "$(dirname "$0")" && pwd)"

source "$DIR_LIB/get_config.sh"

tipo_script=$(get_config "sc_server.tipo_script")
echo "tipo_script: $tipo_script"

# Atualiza firmware sempre
bash "${DIR_LIB}/update_firmware.sh"


garantir_cap_net_raw() {
  echo "[INFO] Verificando permissões de cap_net_raw para $PYTHON_REAL..."

  if ! command -v setcap >/dev/null; then
    echo "[ERRO] 'setcap' não encontrado. Instale o pacote libcap2-bin." >&2
    exit 1
  fi

  echo "[INFO] Aplicando cap_net_raw com sudo..."
  sudo setcap cap_net_raw+eip "$PYTHON_REAL"

  if getcap "$PYTHON_REAL" | grep -q cap_net_raw; then
    echo "[OK] Permissão cap_net_raw aplicada com sucesso em $PYTHON_REAL"
  else
    echo "[ERRO] Falha ao aplicar cap_net_raw em $PYTHON_REAL"
    echo "       Verifique se você está usando um interpretador do sistema e não de uma venv."
    exit 1
  fi
}


# Escolhe qual tunnels rodar
if [ "$tipo_script" = "python" ]; then
  garantir_cap_net_raw

  echo "[INFO] Usando Python: $PYTHON_REAL"
  "$PYTHON_REAL" "${DIR_LIB}/exec_tunnels.py"

else
  bash "${DIR_LIB}/exec_tunnels.sh"
fi
