#!/bin/bash
# Upload v2/dist/install.sh to the sctunnel_server EC2.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SRC="$HERE/dist/install.sh"
UNINSTALL_SRC="$HERE/installer/uninstall.sh"
PEM="${SCTUNNEL_PEM:-$HOME/scTunnel.pem}"
EC2_USER="${EC2_USER:-ubuntu}"
EC2_HOST="${EC2_HOST:-sctunnel1.seucondominio.com.br}"

[[ -r "$INSTALL_SRC"   ]] || { echo "ERRO: $INSTALL_SRC não existe — rode v2/build.sh primeiro" >&2; exit 1; }
[[ -r "$UNINSTALL_SRC" ]] || { echo "ERRO: $UNINSTALL_SRC não existe" >&2; exit 1; }
[[ -r "$PEM" ]] || { echo "ERRO: PEM não encontrado em $PEM" >&2; exit 1; }

upload_one() {
  local src="$1" name="$2"
  local tmp="/tmp/sctunnel_${name}_$$.sh"
  echo "[upload] $name ($(wc -c <"$src") bytes) -> $EC2_USER@$EC2_HOST:/var/www/sctunnel/$name"
  scp -q -i "$PEM" -o StrictHostKeyChecking=accept-new "$src" "$EC2_USER@$EC2_HOST:$tmp"
  ssh -i "$PEM" -o StrictHostKeyChecking=accept-new "$EC2_USER@$EC2_HOST" \
    "sudo install -m 644 -o root -g root '$tmp' '/var/www/sctunnel/$name' && rm -f '$tmp'"
  local code=$(curl -s -o /tmp/sctunnel_check.$$ -w '%{http_code}' "https://$EC2_HOST/$name" || true)
  local size=$(wc -c < /tmp/sctunnel_check.$$ 2>/dev/null || echo 0)
  rm -f /tmp/sctunnel_check.$$
  echo "[upload]   HTTP $code — $size bytes pelo HTTPS"
  [[ "$code" == "200" ]] || { echo "ERRO: $name não acessível via HTTPS" >&2; return 1; }
}

upload_one "$INSTALL_SRC"   install.sh
upload_one "$UNINSTALL_SRC" uninstall.sh

echo
echo "[upload] OK"
echo
echo "Comandos prontos:"
echo "  curl -fsSL https://$EC2_HOST/install.sh   | sudo bash -s -- <cliente_id>"
echo "  curl -fsSL https://$EC2_HOST/uninstall.sh | sudo bash"
