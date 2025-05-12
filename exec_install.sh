#!/bin/bash

set -e
DIR_LIB=$(dirname "$0")
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


################################################################
# CRONS
INSTALL_CRONS=false
REMOVE_CRONS=false
CRONPATH="/etc/cron.d/sctunnel"
for arg in "$@"; do
  if [[ "$arg" == "--install_crons" ]]; then
    INSTALL_CRONS=true
  fi
  if [[ "$arg" == "--remove_crons" ]]; then
    REMOVE_CRONS=true
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
*/30 * * * * /bin/bash -c '/usr/bin/systemctl restart NetworkManager >> ${DIR_LIB}/logs/rede.txt 2>&1'
0 */6 * * * /bin/bash -c '[ -f ${DIR_LIB}/logs/cron.txt ] && tail -n 500 ${DIR_LIB}/logs/cron.txt > /tmp/cron.tmp && mv /tmp/cron.tmp ${DIR_LIB}/logs/cron.txt'
0 */6 * * * /bin/bash -c '[ -f ${DIR_LIB}/logs/rede.txt ] && tail -n 500 ${DIR_LIB}/logs/rede.txt > /tmp/rede.tmp && mv /tmp/rede.tmp ${DIR_LIB}/logs/rede.txt'
EOF
)


  # Salva crons atuais em um tmp e remove linhas antigas
  TMP_CRON=$(mktemp)
  crontab -l 2>/dev/null | grep -v 'sctunnel_client' > "$TMP_CRON" || true

  # Adiciona os novos crons
  echo "$CRON_CONTENT" >> "$TMP_CRON"

  # Instala a nova versão
  crontab "$TMP_CRON"
  rm "$TMP_CRON"

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
print_header "ADICONANDO PERMISSOES"
sudo mkdir -p "$DIR_LIB/logs"
sudo touch "$DIR_LIB/logs/cron.txt"
sudo chmod 666 "$DIR_LIB/logs/cron.txt"
sudo chmod 400 "$DIR_LIB/scTunnel.pem"
sudo chmod 777 "$DIR_LIB/logs"
sudo chmod 777 "$DIR_LIB/config.json"
sudo chmod +x "$DIR_LIB/exec.sh"
sudo chmod +x "$DIR_LIB/exec_tunnels.sh"



################################################################
# ARP-SCAN INSTALL
print_header "ARP-SCAN INSTALL"
bash "${DIR_LIB}/script_arp_scan_sem_pedir_senha.sh"
print_footer




print_header "Fim"
