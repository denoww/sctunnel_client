#!/bin/bash

set -e
DIR_LIB="$(cd "$(dirname "$0")" && pwd)"

git config --global --add safe.directory $DIR_LIB/sctunnel_client



################################################################
# FUNCTIONS
print_header() {
  local title="$1"
  echo >&2
  echo >&2
  echo "-------------------------------------------------" >&2
  echo "$title" >&2
  echo "-------------------------------------------------" >&2
  # echo >&2
}
print_footer() {
  echo "-------------------------------------------------" >&2
}

print_header "Iniciando EXEC_INSTALL"



# HABILITAR E INSTALA SERVIDOR SSH
print_header "HABILITAR SSH"
echo "🔧 Verificando SSH..."
sudo apt install -y openssh-server
sudo systemctl enable ssh --now



################################################################
# SET_CLIENTE
print_header "SET_CLIENTE INSTALL"
EXEC_CLIENTE_PATH="/usr/local/bin/set_cliente"
sudo tee "$EXEC_CLIENTE_PATH" > /dev/null <<EOF
#!/bin/bash
bash ${DIR_LIB}/trocar_cliente.sh "\$1"
EOF

sudo chmod +x "$EXEC_CLIENTE_PATH"
echo "✅ Comando 'set_cliente' instalado com sucesso!"
echo ""
echo "📢 Agora você pode usar: set_cliente <cliente_id>"
print_footer


uninstall_network_restart_timer() {
  ################################################################
  # REMOVE_TIMER_RESTART_NETWORK INSTALL
  print_header "REMOVE_TIMER_RESTART_NETWORK"
  bash "${DIR_LIB}/remove_timer_restart_network.sh"
}


install_network_restart_timer() {
  ################################################################
  # INSTALL_TIMER_RESTART_NETWORK INSTALL
  print_header "INSTALL_TIMER_RESTART_NETWORK"
  bash "${DIR_LIB}/install_timer_restart_network.sh"
}

################################################################
# CRONS
INSTALL_CRONS=false
REMOVE_CRONS=false
CRONPATH="/etc/cron.d/sctunnel"
for arg in "$@"; do
  if [[ "$arg" == "--install_crons" ]]; then
    INSTALL_CRONS=true
    install_network_restart_timer

  fi
  if [[ "$arg" == "--remove_crons" ]]; then
    REMOVE_CRONS=true
    uninstall_network_restart_timer
  fi
done



################################################################
# REMOVE_CRONS
if $REMOVE_CRONS; then
  print_header "CRONS REMOVE"

  # Remove cron do usuário atual (crontab -r remove todos)
  if crontab -l &>/dev/null; then
    crontab -r
    echo "🗑️  Cron jobs removidos do usuário $(whoami)"
  else
    echo "ℹ️  Nenhum cron job encontrado para o usuário $(whoami)"
  fi

  # Remove também o arquivo em /etc/cron.d se existir
  if [[ -f "$CRONPATH" ]]; then
    sudo rm -f "$CRONPATH"
    echo "🗑️  Arquivo de cron removido: $CRONPATH"
  fi
  uninstall_network_restart_timer
  print_footer
fi





################################################################
# INSTALL_CRONS
if $INSTALL_CRONS; then
  print_header "CRONS INSTALL"   # Exibe cabeçalho indicando início da instalação dos crons
  echo "🕒 Instalando cron jobs..."  # Loga mensagem indicando início da instalação

  # Constrói conteúdo do cron com caminhos absolutos
  # @reboot: Executa o script exec.sh ao iniciar o sistema
  # */1 * * * *: Executa o script exec.sh a cada 1 minuto
  # */30 * * * *: Reinicia o serviço NetworkManager a cada 30 minutos
  # 0 */6 * * *: A cada 6 horas (à hora cheia), mantém apenas as últimas 500 linhas de cron.txt, se o arquivo existir
  # 0 */6 * * *: A cada 6 horas (à hora cheia), mantém apenas as últimas 500 linhas de rede.txt, se o arquivo existir

  CRON_CONTENT=$(cat <<EOF
@reboot /bin/bash -c 'cd ${DIR_LIB} && /bin/bash ./exec.sh >> ${DIR_LIB}/logs/cron.txt 2>&1'
*/1 * * * * /bin/bash -c 'cd ${DIR_LIB} && /bin/bash ./exec.sh >> ${DIR_LIB}/logs/cron.txt 2>&1'
0 */6 * * * /bin/bash -c '[ -f ${DIR_LIB}/logs/cron.txt ] && tail -n 500 ${DIR_LIB}/logs/cron.txt > /tmp/cron.tmp && mv /tmp/cron.tmp ${DIR_LIB}/logs/cron.txt'
0 */6 * * * /bin/bash -c '[ -f ${DIR_LIB}/logs/rede.txt ] && tail -n 500 ${DIR_LIB}/logs/rede.txt > /tmp/rede.tmp && mv /tmp/rede.tmp ${DIR_LIB}/logs/rede.txt'
EOF

#   CRON_CONTENT=$(cat <<EOF
# @reboot /bin/bash -c 'cd ${DIR_LIB} && /bin/bash ./exec.sh >> ${DIR_LIB}/logs/cron.txt 2>&1'
# */1 * * * * /bin/bash -c 'cd ${DIR_LIB} && /bin/bash ./exec.sh >> ${DIR_LIB}/logs/cron.txt 2>&1'
# */30 * * * * /bin/bash -c '/var/lib/sctunnel_client/restart_network.sh >> ${DIR_LIB}/logs/rede.txt 2>&1'
# 0 */6 * * * /bin/bash -c '[ -f ${DIR_LIB}/logs/cron.txt ] && tail -n 500 ${DIR_LIB}/logs/cron.txt > /tmp/cron.tmp && mv /tmp/cron.tmp ${DIR_LIB}/logs/cron.txt'
# 0 */6 * * * /bin/bash -c '[ -f ${DIR_LIB}/logs/rede.txt ] && tail -n 500 ${DIR_LIB}/logs/rede.txt > /tmp/rede.tmp && mv /tmp/rede.tmp ${DIR_LIB}/logs/rede.txt'
# EOF
)

  # Sobrescreve completamente o crontab do usuário
  echo "$CRON_CONTENT" | crontab -

  echo "✅ Cron jobs atualizados para o usuário $(whoami)"
  echo "🔎 Verifique com: crontab -l"
  echo
  echo "📋 Cron jobs instalados:"
  echo "──────────────────────────────────────────────"
  echo "$CRON_CONTENT" | sed 's/^/  • /'
  echo "──────────────────────────────────────────────"
  echo
  echo "🧪 Teste o cron manualmente com:"
  echo "bash ${DIR_LIB}/cron_test.sh"



  print_footer

fi






################################################################
# PERMISSOES
print_header "ADICIONANDO PERMISSÕES"

# Garante que diretório de logs existe
sudo mkdir -p "$DIR_LIB/logs"

# Cria arquivos de log se não existirem
sudo touch "$DIR_LIB/logs/cron.txt"
sudo touch "$DIR_LIB/logs/rede.txt"  # opcional

# Permissões para arquivos que precisam ser editados por qualquer processo (ex: cron)
sudo chmod 664 "$DIR_LIB/logs/cron.txt"
sudo chmod 664 "$DIR_LIB/logs/rede.txt"

# Permissões seguras para chave privada
sudo chmod 400 "$DIR_LIB/scTunnel.pem"

# Permissões adequadas para scripts executáveis
sudo chmod +x "$DIR_LIB/exec.sh"
sudo chmod +x "$DIR_LIB/exec_tunnels.sh"

# Permissão mais restrita e suficiente para config.json
sudo chmod 644 "$DIR_LIB/config.json"

# Ajusta ownership para o usuário atual
CURRENT_USER=$(whoami)

echo "=========================="
echo "Usuário $CURRENT_USER"
echo "=========================="

sudo chown -R "$CURRENT_USER:$CURRENT_USER" /var/lib/sctunnel_client

sudo chown -R "$CURRENT_USER:$CURRENT_USER" .git
sudo chown -R "$CURRENT_USER:$CURRENT_USER" "$DIR_LIB/logs"
sudo chown -R "$CURRENT_USER:$CURRENT_USER" "$DIR_LIB/.git"


# print_header "ADICONANDO PERMISSOES"
# sudo mkdir -p "$DIR_LIB/logs"
# sudo touch "$DIR_LIB/logs/cron.txt"
# sudo chmod 666 "$DIR_LIB/logs/cron.txt"
# sudo chmod 400 "$DIR_LIB/scTunnel.pem"
# sudo chmod 777 "$DIR_LIB/logs"
# sudo chmod 777 "$DIR_LIB/config.json"
# sudo chmod +x "$DIR_LIB/exec.sh"
# sudo chmod +x "$DIR_LIB/exec_tunnels.sh"
# sudo chown -R $(whoami):$(whoami) "$DIR_LIB/.git"
# sudo chown -R $(whoami):$(whoami) "$DIR_LI/logs"

# sudo chown -R "$USER":"$USER" "$DIR_LIB/.git"




################################################################
# ARP-SCAN INSTALL
print_header "ARP-SCAN INSTALL"
bash "${DIR_LIB}/script_arp_scan_sem_pedir_senha.sh"
print_footer





print_header "Fim"
