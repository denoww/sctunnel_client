#!/bin/bash

set -e

DIR_LIB="$(cd "$(dirname "$0")" && pwd)"
source "$DIR_LIB/env.sh"

echo "[INFO] Atualizando pip..."
# python -m pip install --upgrade pip
# python3 -m pip install --upgrade pip
"$PYTHON_REAL" -m pip install --upgrade pip


# Linux: instala dependências e permite uso de raw socket sem sudo
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "[INFO] Detecção de SO: Linux"
  bash exec_install_linux_python.sh
fi

# Windows: exibe instrução para instalar o Npcap manualmente
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
  echo "O firewall do Windows não deve bloquear o SSH (outbound: porta 22)"
  echo "[INFO] Detecção de SO: Windows"
  echo "[INFO] Instale o Npcap manualmente, se ainda não o fez:"
  echo "       https://nmap.org/npcap/"
fi

# Reinstala cffi e cryptography forçadamente para garantir _cffi_backend
echo "[INFO] Reinstalando cffi e cryptography..."
pip install --force-reinstall --upgrade cffi cryptography

# Instala requisitos do projeto
echo "[INFO] Instalando requirements.txt..."
pip install -r requirements.txt
