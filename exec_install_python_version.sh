#!/bin/bash

set -e

echo "[INFO] Atualizando pip..."
python -m pip install --upgrade pip

# Linux: instala dependências e permite uso de raw socket sem sudo
if [[ "$OSTYPE" == "linux-gnu"* ]]; then

  #################################
  # python sem sudo
  if command -v setcap >/dev/null; then
    # PYTHON_REAL=$(readlink -f "$(command -v python3)")
    PYTHON_REAL="/usr/bin/python3"
    echo "[INFO] Configurando permissões para Python usar raw sockets..."
    sudo setcap cap_net_raw+eip "$PYTHON_REAL"

    # Verifica se a permissão foi aplicada com sucesso
    if getcap "$PYTHON_REAL" | grep -q cap_net_raw; then
      echo "[OK] Permissão cap_net_raw aplicada com sucesso em $PYTHON_REAL"
    else
      echo "[ERRO] Falha ao aplicar cap_net_raw em $PYTHON_REAL"
      echo "       Verifique se você está usando um Python do sistema e não de uma venv."
      exit 1
    fi
  else
    echo "[ERRO] 'setcap' não encontrado. Scapy pode não funcionar sem sudo." >&2
    exit 1
  fi
  #################################


  echo "[INFO] Instalando dependências de sistema no Linux..."
  # sudo apt update
  # sudo apt install -y build-essential python3-dev libffi-dev libpcap-dev

else
  echo "[INFO] Detecção de SO: $OSTYPE. Se for Windows, instale o Npcap manualmente:"
  echo "      https://nmap.org/npcap/"
fi


# Reinstala cffi e cryptography forçadamente para garantir _cffi_backend
echo "[INFO] Reinstalando cffi e cryptography..."
pip install --force-reinstall --upgrade cffi cryptography

# Instala requisitos do projeto
echo "[INFO] Instalando requirements.txt..."
pip install -r requirements.txt

