#!/bin/bash

# exec_install_linux_python.sh

set -e
DIR_LIB="$(cd "$(dirname "$0")" && pwd)"


source "$DIR_LIB/env.sh"



#################################
# python sem sudo
if command -v setcap >/dev/null; then
    # PYTHON_REAL=$(readlink -f "$(command -v "$pybin")")
    # PYTHON_REAL=$(readlink -f "$(which python3.10)")
    echo "[INFO] Configurando permissões para $PYTHON_REAL usar raw sockets..."
    sudo setcap cap_net_raw+eip "$PYTHON_REAL"

    if getcap "$PYTHON_REAL" | grep -q cap_net_raw; then
      echo "[OK] Permissão cap_net_raw aplicada com sucesso em $PYTHON_REAL"
    else
      echo "[ERRO] Falha ao aplicar cap_net_raw em $PYTHON_REAL"
      echo "       Verifique se você está usando um interpretador do sistema e não de uma venv."
      exit 1
    fi

  # PYTHON_REAL=$(readlink -f "$(which python3)")
  # # PYTHON_REAL=$(readlink -f "$(command -v python3)")
  # # PYTHON_REAL="/usr/bin/python3"
  # echo "[INFO] Configurando permissões para Python usar raw sockets..."
  # sudo setcap cap_net_raw+eip "$PYTHON_REAL"

  # # Verifica se a permissão foi aplicada com sucesso
  # if getcap "$PYTHON_REAL" | grep -q cap_net_raw; then
  #   echo "[OK] Permissão cap_net_raw aplicada com sucesso em $PYTHON_REAL"
  # else
  #   echo "[ERRO] Falha ao aplicar cap_net_raw em $PYTHON_REAL"
  #   echo "       Verifique se você está usando um Python do sistema e não de uma venv."
  #   exit 1
  # fi
else
  echo "[ERRO] 'setcap' não encontrado. Scapy pode não funcionar sem sudo." >&2
  exit 1
fi
#################################

# Corrige permissões e dependências do sistema de sugestões (opcional, mas limpa logs)
# sudo chmod +x /usr/lib/cnf-update-db 2>/dev/null || true
# sudo apt install --reinstall -y python3-apt || true


echo "[INFO] Instalando dependências de sistema no Linux..."
sudo apt update
sudo apt install -y build-essential python3-dev libffi-dev libpcap-dev

