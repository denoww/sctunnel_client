#!/bin/bash
set -e

# 🔧 CONFIGURE AQUI
TS_API_KEY="tskey-api-kRtUj537SW11CNTRL-wS9EepzseL2rgPUYCRfnL29VzDHwXQnE"               # <- SUA API KEY DA TAILSCALE
TAG="tag:infra"
AUTH_KEY_LIFETIME=7776000              # 90 dias em segundos (máximo permitido)
MAC=$(ip link | awk '/ether/ {print $2; exit}' | tr -d ':')
HOSTNAME="$(hostname)$MAC"

# 📡 Gera nova auth key via API
echo "🔑 Solicitando nova auth key via API..."
AUTH_KEY=$(curl -s -X POST https://api.tailscale.com/api/v2/tailnet/-/keys \
  -H "Authorization: Bearer $TS_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
        \"capabilities\": {
          \"devices\": {
            \"create\": {
              \"reusable\": true,
              \"ephemeral\": false,
              \"preauthorized\": true,
              \"tags\": [\"$TAG\"]
            }
          }
        },
        \"expirationSeconds\": $AUTH_KEY_LIFETIME
      }" | jq -r .key)

if [ "$AUTH_KEY" = "null" ] || [ -z "$AUTH_KEY" ]; then
  echo "❌ Falha ao gerar auth key. Verifique a API Key e permissões."
  exit 1
fi

# 🧩 Instala o Tailscale se necessário
if ! command -v tailscale &>/dev/null; then
  echo "📦 Instalando Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# 🚀 Conecta com authkey gerada
echo "🔐 Conectando com hostname '$HOSTNAME' e tag '$TAG'..."
if ! sudo tailscale up --authkey="$AUTH_KEY" --advertise-tags="$TAG" --hostname="$HOSTNAME" --accept-dns=false; then
  echo -e "\n❌ Falha na autenticação com auth key gerada pela API."
  exit 2
fi

# ✅ Sucesso
echo -e "\n✅ Dispositivo conectado com sucesso!"
IP=$(tailscale ip -4)
FQDN=$(tailscale status | grep "$IP" | awk '{print $2".ts.net"}')

echo
echo "🧠 Acesse este dispositivo via Tailscale:"
echo "  SSH (IP):     ssh usuario@$IP"
echo "  SSH (nome):   ssh usuario@$FQDN"
echo
echo "🔍 Verifique o status com:"
echo "  tailscale status"
