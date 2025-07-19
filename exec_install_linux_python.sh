#!/bin/bash

# exec_install_linux_python.sh

set -e
DIR_LIB="$(cd "$(dirname "$0")" && pwd)"


source "$DIR_LIB/env.sh"



#################################
# python sem sudo
bash cap_net_raw.sh
#################################

# Corrige permissões e dependências do sistema de sugestões (opcional, mas limpa logs)
# sudo chmod +x /usr/lib/cnf-update-db 2>/dev/null || true
# sudo apt install --reinstall -y python3-apt || true


echo "[INFO] Instalando dependências de sistema no Linux..."
sudo apt update
sudo apt install -y build-essential python3-dev libffi-dev libpcap-dev

