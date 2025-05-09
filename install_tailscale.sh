#!/bin/bash

set -e

# 🔧 CONFIGURE AQUI
AUTH_KEY="tskey-auth-ksTZgQHeh511CNTRL-ros7ts9GrUgbfako241zUgDsXGGr9bu8L"
TAG="tag:infra"

MAC=$(ip link | awk '/ether/ {print $2; exit}' | tr -d ':')
HOSTNAME="tunnel$MAC"
# HOSTNAME=$(hostname)

echo "📦 Instalando Tailscale (se necessário)..."
if ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# echo "🔄 Resetando estado anterior (caso exista)..."
# sudo tailscale down || true
# sudo tailscale logout || true
# sudo tailscale up --reset || true

echo "🔐 Conectando com hostname '$HOSTNAME' e tag '$TAG'..."


if ! sudo tailscale up --authkey="$AUTH_KEY" --advertise-tags="$TAG" --hostname="$HOSTNAME" --accept-dns=false; then
  echo -e "\n❌ ERRO: Falha na autenticação. Possíveis causas:"
  echo "  - Auth key inválida ou expirada"
  echo "  - TAG não permitida no ACL"
  echo "  - HOSTNAME em uso ou mal formatado"
  echo -e "\n🧪 Verifique manualmente com:\n  tailscale status"
  exit 1
fi

echo -e "\n✅ Dispositivo conectado com sucesso!"
tailscale ip
tailscale status
