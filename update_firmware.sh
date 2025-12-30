#!/bin/bash
# update_firmware.sh

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

update_firmware(){
  echo "Atualizando firmware..."

  git config --global --add safe.directory "$DIR" 2>/dev/null || true

  cd "$DIR"

  echo "[INFO] Descartando alterações locais (arquivos versionados)..."
  git reset --hard HEAD

  echo "[INFO] Limpando arquivos/pastas não rastreados (NÃO remove gitignored)..."
  git clean -fd

  # --ff-only evita merge automático (se precisar, dá pra trocar por git pull --rebase).
  echo "[INFO] Fazendo pull..."
  git pull --ff-only
}

update_firmware



# #!/bin/bash
# DIR=$(dirname "$0")
# update_firmware(){
#   echo "Atualizando firmware..."
#   git config --global --add safe.directory "$DIR" 2>/dev/null || true
#   cd "$DIR" && git pull
# }
# update_firmware

