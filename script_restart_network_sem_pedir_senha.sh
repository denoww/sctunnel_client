#!/bin/bash
set -e

echo
echo "🔁 Instalando dependências e configurando restart do NetworkManager sem senha..."

# Caminhos
DIR_LIB="/var/lib/sctunnel_client"
NM_SCRIPT_PATH="${DIR_LIB}/restart_network.sh"
SUDOERS_FILE="/etc/sudoers.d/restart_networkmanager_orangepi"

# Cria script que reinicia o NetworkManager
echo "📄 Criando script de reinício em: $NM_SCRIPT_PATH"
sudo tee "$NM_SCRIPT_PATH" > /dev/null <<'EOF'
#!/bin/bash
exec sudo /usr/bin/systemctl restart NetworkManager
EOF

# Permissão de execução
sudo chmod +x "$NM_SCRIPT_PATH"

# Cria regra sudoers para permitir executar sem senha
echo "🔐 Configurando sudoers para permitir restart sem senha..."
echo "orangepi ALL=NOPASSWD: /usr/bin/systemctl restart NetworkManager" | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 440 "$SUDOERS_FILE"

# Testa execução
echo
echo "🧪 Testando reinício com: $NM_SCRIPT_PATH"
bash "$NM_SCRIPT_PATH"

echo
echo "✅ Tudo pronto! Agora você pode reiniciar o NetworkManager via:"
echo "   bash $NM_SCRIPT_PATH"
