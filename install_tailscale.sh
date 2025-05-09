#!/bin/bash
set -e

# ✅ Abre o link para gerar a API Key no navegador
LINK_API="https://login.tailscale.com/admin/settings/keys"
echo "🌐 Por favor, gere sua API Key em:"
echo "👉 $LINK_API"

# Tenta abrir no navegador em modo anônimo, se possível
if command -v xdg-open &>/dev/null; then
  xdg-open "$LINK_API" >/dev/null 2>&1 &
elif command -v gnome-open &>/dev/null; then
  gnome-open "$LINK_API" >/dev/null 2>&1 &
elif command -v open &>/dev/null; then
  open "$LINK_API" >/dev/null 2>&1 &
else
  echo "(🔗 Copie e cole o link acima no seu navegador)"
fi

echo
read -p "🔐 Cole aqui sua API Key gerada: " API_KEY

if [ -z "$API_KEY" ]; then
  echo "❌ API Key não informada. Abortando."
  exit 1
fi

# Habilita e instala servidor SSH
echo "🔧 Verificando SSH..."
sudo apt install -y openssh-server
sudo systemctl enable ssh --now

# Configuração do Tailscale
TAG="tag:infra"
AUTH_KEY_LIFETIME=7776000
MAC=$(ip link | awk '/ether/ {print $2; exit}' | tr -d ':')
HOSTNAME="$(hostname)-$MAC"

echo "🔑 Solicitando nova auth key via API..."
AUTH_KEY=$(curl -s -X POST https://api.tailscale.com/api/v2/tailnet/-/keys \
  -H "Authorization: Bearer $API_KEY" \
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

if ! command -v tailscale &>/dev/null; then
  echo "📦 Instalando Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

echo "🔐 Conectando com hostname '$HOSTNAME' e tag '$TAG'..."
if ! sudo tailscale up --authkey="$AUTH_KEY" --advertise-tags="$TAG" --hostname="$HOSTNAME" --accept-dns=false; then
  echo "❌ Falha na autenticação com auth key gerada pela API."
  exit 2
fi

echo "✅ Dispositivo conectado com sucesso!"
IP=$(tailscale ip -4)
FQDN=$(tailscale status | grep "$IP" | awk '{print $2".ts.net"}')

echo
echo "🧠 Acesse este dispositivo via Tailscale:"
echo "  SSH (IP):     ssh $IP"
echo "  SSH (nome):   ssh $FQDN"
echo
echo "🔍 Verifique o status com:"
echo "  tailscale status"
