#!/bin/bash
# sctunnel v2 uninstaller — standalone, no embedded payload.
#
# Usage:
#   curl -fsSL https://sctunnel1.seucondominio.com.br/uninstall.sh | sudo bash
set -euo pipefail

print_h() { printf '\n\033[1;34m== %s ==\033[0m\n' "$*"; }
ok()      { printf '\033[0;32m✔ %s\033[0m\n' "$*"; }
warn()    { printf '\033[0;33m⚠ %s\033[0m\n' "$*"; }

if [[ "$EUID" -ne 0 ]]; then
  command -v sudo >/dev/null || { echo "precisa de root ou sudo"; exit 1; }
  exec sudo bash "$0" "$@"
fi

BASE=/opt/sctunnel

print_h "sctunnel v2 uninstall"

# ── parar cron primeiro pra não disparar nova execução durante o uninstall ──
if [[ -f /etc/cron.d/sctunnel ]]; then
  rm -f /etc/cron.d/sctunnel
  ok "cron removido (/etc/cron.d/sctunnel)"
else
  warn "cron já estava ausente"
fi

# ── matar túneis SSH spawneados a partir do PEM em /opt/sctunnel ────────────
KILLED=0
for pid in $(pgrep -f 'ssh -N -o ServerAliveInterval=20.*sctunnel' 2>/dev/null || true); do
  kill -KILL "$pid" 2>/dev/null && KILLED=$((KILLED + 1)) || true
done
[[ $KILLED -gt 0 ]] && ok "$KILLED túnel(eis) SSH encerrado(s)" || warn "nenhum túnel SSH ativo"

# ── remover comando global ─────────────────────────────────────────────────
if [[ -f /usr/local/bin/set_cliente ]]; then
  rm -f /usr/local/bin/set_cliente
  ok "set_cliente removido"
fi

# ── remover diretório principal ────────────────────────────────────────────
if [[ -d "$BASE" ]]; then
  rm -rf "$BASE"
  ok "$BASE removido"
else
  warn "$BASE não existia"
fi

print_h "uninstall concluído"
echo "Para reinstalar: curl -fsSL https://sctunnel1.seucondominio.com.br/install.sh | sudo bash -s -- <cliente_id>"
