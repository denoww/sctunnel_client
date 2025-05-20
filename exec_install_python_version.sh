#!/bin/bash

set -e

# Atualiza o pip
python -m pip install --upgrade pip

# Instala dependências do sistema (apenas para Linux)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "[INFO] Instalando dependências de sistema no Linux..."
  sudo apt update
  sudo apt install -y build-essential python3-dev libffi-dev

  # usar python sem sudo
  sudo setcap cap_net_raw+eip $(readlink -f $(which python3))
fi

# Reinstala cffi e cryptography forçadamente para garantir _cffi_backend
echo "[INFO] Reinstalando cffi e cryptography..."
pip install --force-reinstall --upgrade cffi cryptography

# Instala requisitos do projeto
echo "[INFO] Instalando requirements.txt..."
pip install -r requirements.txt

