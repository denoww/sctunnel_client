#!/bin/bash
set -e

RESTART_INTERVAL_MIN=1  # intervalo em minutos

echo
echo "🔁 Instalando serviço systemd para reiniciar o NetworkManager a cada $RESTART_INTERVAL_MIN minutos..."

# Caminhos
DIR_LIB="$(cd "$(dirname "$0")" && pwd)"
NM_SCRIPT_PATH="${DIR_LIB}/restart_network.sh"
SERVICE_FILE="/etc/systemd/system/restart-network.service"
TIMER_FILE="/etc/systemd/system/restart-network.timer"
SUDOERS_FILE="/etc/sudoers.d/restart_networkmanager_$(whoami)"

# Cria o script de reinício manual
echo "📄 Criando script auxiliar: $NM_SCRIPT_PATH"
sudo tee "$NM_SCRIPT_PATH" > /dev/null <<EOF
#!/bin/bash
echo "\$(date) - reiniciando rede via systemd" >> ${DIR_LIB}/logs/rede.txt
/usr/bin/systemctl restart NetworkManager
EOF

sudo chmod +x "$NM_SCRIPT_PATH"

# Garante permissão sudo sem senha
echo "🔐 Configurando sudoers para permitir restart sem senha..."
echo "$(whoami) ALL=NOPASSWD: /usr/bin/systemctl restart NetworkManager" | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 440 "$SUDOERS_FILE"

# Cria o serviço systemd como root (sem User=)
echo "🛠️ Criando unidade systemd: $SERVICE_FILE"
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Reiniciar NetworkManager

[Service]
Type=oneshot
ExecStart=${NM_SCRIPT_PATH}
EOF

# Cria o timer com variável
echo "⏱️ Criando timer systemd: $TIMER_FILE"
sudo tee "$TIMER_FILE" > /dev/null <<EOF
[Unit]
Description=Executa reinício de rede a cada ${RESTART_INTERVAL_MIN} minutos

[Timer]
OnBootSec=1min
OnUnitActiveSec=${RESTART_INTERVAL_MIN}min
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
