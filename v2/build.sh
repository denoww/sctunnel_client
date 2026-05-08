#!/bin/bash
# Build sctunnel v2 install.sh on rodrigo's machine.
# Reads:
#   $HOME/scTunnel.pem
#   $HOME/.sctunnel/token  (or $SCTUNNEL_TOKEN env var)
# Writes:
#   v2/dist/install.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
RUNTIME="$HERE/runtime"
TEMPLATE="$HERE/installer/template.sh"
DIST="$HERE/dist"
OUT="$DIST/install.sh"

PEM="${SCTUNNEL_PEM:-$HOME/scTunnel.pem}"
TOKEN_FILE="${SCTUNNEL_TOKEN_FILE:-$HOME/.sctunnel/token}"

# config — mantém alinhado com o que o sample-prod usa
SC_SERVER_HOST="${SC_SERVER_HOST:-https://www.seucondominio.com.br}"
SC_TUNNEL_HOST="${SC_TUNNEL_HOST:-sctunnel1.seucondominio.com.br}"
SC_TUNNEL_USER="${SC_TUNNEL_USER:-ubuntu}"

[[ -r "$PEM" ]] || { echo "ERRO: PEM não encontrado em $PEM" >&2; exit 1; }

if [[ -n "${SCTUNNEL_TOKEN:-}" ]]; then
  TOKEN="$SCTUNNEL_TOKEN"
elif [[ -r "$TOKEN_FILE" ]]; then
  TOKEN=$(<"$TOKEN_FILE")
else
  echo "ERRO: defina \$SCTUNNEL_TOKEN ou crie $TOKEN_FILE" >&2
  exit 1
fi
TOKEN=$(printf '%s' "$TOKEN" | tr -d '\r\n')
[[ -n "$TOKEN" ]] || { echo "ERRO: token vazio" >&2; exit 1; }

mkdir -p "$DIST"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# bundle: runtime/ + scTunnel.pem
mkdir -p "$TMP/bundle/runtime"
cp -f "$RUNTIME"/*.py "$RUNTIME"/*.sh "$TMP/bundle/runtime/"
cp -f "$PEM" "$TMP/bundle/scTunnel.pem"
chmod 600 "$TMP/bundle/scTunnel.pem"

# tar + base64 (one line)
( cd "$TMP/bundle" && tar -czf "$TMP/payload.tar.gz" . )
base64 -w0 < "$TMP/payload.tar.gz" > "$TMP/payload.b64"
echo >> "$TMP/payload.b64"  # trailing newline

VERSION=$(date -u +%Y%m%d-%H%M%S)
SIZE=$(wc -c < "$TMP/payload.tar.gz")
echo "[build] payload size: $SIZE bytes — version: $VERSION"

# render template (handle special chars in TOKEN safely via env+awk)
export SC_SERVER_HOST SC_TUNNEL_HOST SC_TUNNEL_USER TOKEN VERSION
awk '
  { line=$0
    gsub(/@@SC_SERVER_HOST@@/, ENVIRON["SC_SERVER_HOST"], line)
    gsub(/@@SC_TUNNEL_HOST@@/, ENVIRON["SC_TUNNEL_HOST"], line)
    gsub(/@@SC_TUNNEL_USER@@/, ENVIRON["SC_TUNNEL_USER"], line)
    gsub(/@@SC_TOKEN@@/,       ENVIRON["TOKEN"],          line)
    gsub(/@@BUILD_VERSION@@/,  ENVIRON["VERSION"],        line)
    print line
  }
' "$TEMPLATE" > "$OUT"

cat "$TMP/payload.b64" >> "$OUT"
chmod 644 "$OUT"

# sanity check: payload marker present and parseable
PAYLOAD_LINE=$(awk '/^__PAYLOAD_BELOW__$/{print NR+1; exit 0}' "$OUT") || true
if [[ -z "$PAYLOAD_LINE" ]]; then
  echo "ERRO: marker __PAYLOAD_BELOW__ ausente no install.sh" >&2
  exit 1
fi
TEST_DIR=$(mktemp -d)
tail -n +"$PAYLOAD_LINE" "$OUT" | base64 -d | tar -tzf - >/dev/null
tail -n +"$PAYLOAD_LINE" "$OUT" | base64 -d | tar -xzf - -C "$TEST_DIR"
[[ -f "$TEST_DIR/scTunnel.pem" ]] || { echo "ERRO: PEM ausente no payload" >&2; exit 1; }
[[ -f "$TEST_DIR/runtime/tunnels.py" ]] || { echo "ERRO: tunnels.py ausente" >&2; exit 1; }
rm -rf "$TEST_DIR"

bash -n "$OUT" && echo "[build] sintaxe do install.sh ok"

OUT_SIZE=$(wc -c < "$OUT")
echo "[build] OK -> $OUT  ($OUT_SIZE bytes)"
