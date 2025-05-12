#!/bin/bash
set -e

echo
echo "🔁 Instalando dependências e configurando restart do NetworkManager sem senha..."

# Caminhos
DIR_LIB="$(cd "$(dirname "$0")" && pwd)"
NM_SCRIPT_PATH="${DIR_LIB}/restart_network.sh"
SUDOERS_FILE="/etc/sudoers.d/restart_networkmanager_$(whoami)"

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
echo "$(whoami) ALL=NOPASSWD: /usr/bin/systemctl restart NetworkManager" | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 440 "$SUDOERS_FILE"

# Testa execução e derruba a sessão
echo
echo "🧪 Testando reinício com: $NM_SCRIPT_PATH (a sessão deve ser encerrada)"
exec bash "$NM_SCRIPT_PATH"

# (Nunca será alcançado por causa do exec)
echo
echo "✅ Tudo pronto! Agora você pode reiniciar o NetworkManager via:"
echo "   bash $NM_SCRIPT_PATH"
