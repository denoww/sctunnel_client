#!/bin/bash
set -e

echo
echo "🔁 Instalando serviço systemd para reiniciar o NetworkManager a cada 30 minutos..."

# Caminhos
DIR_LIB="$(cd "$(dirname "$0")" && pwd)"
NM_SCRIPT_PATH="${DIR_LIB}/restart_network.sh"
SERVICE_FILE="/etc/systemd/system/restart-network.service"
TIMER_FILE="/etc/systemd/system/restart-network.timer"

# Cria o script de reinício manual
echo "📄 Criando script auxiliar: $NM_SCRIPT_PATH"
sudo tee "$NM_SCRIPT_PATH" > /dev/null <<'EOF'
#!/bin/bash
echo "$(date) - reiniciando rede via systemd" >> /var/lib/sctunnel_client/logs/rede.txt
/usr/bin/systemctl restart NetworkManager
EOF

sudo chmod +x "$NM_SCRIPT_PATH"

# Cria o serviço systemd
echo "🛠️ Criando unidade systemd: $SERVICE_FILE"
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Reiniciar NetworkManager

[Service]
Type=oneshot
ExecStart=${NM_SCRIPT_PATH}
EOF

# Cria o timer
echo "⏱️ Criando timer systemd: $TIMER_FILE"
sudo tee "$TIMER_FILE" > /dev/null <<EOF
[Unit]
Description=Executa reinício de rede a cada 30 minutos

[Timer]
OnBootSec=1min
OnUnitActiveSec=30min
Unit=restart-network.service

[Install]
WantedBy=timers.target
EOF

# Recarrega o systemd e ativa o timer
echo "🔄 Ativando serviço e timer..."
sudo systemctl daemon-reload
sudo systemctl enable --now restart-network.timer

echo
echo "✅ Tudo pronto!"
echo "📋 Status atual do timer:"
systemctl list-timers --all | grep restart-network || true

echo
echo "🧪 Para testar manualmente:"
echo "   sudo systemctl start restart-network.service"
echo
echo "🔍 Log será salvo em: ${DIR_LIB}/logs/rede.txt"
