#!/bin/bash

set -e

echo "🔧 Instalando comando 'exec_cliente' no sistema..."

DIR_LIB=/var/lib/sctunnel_client



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

################################################################
# ARP-SCAN INSTALL
print_header "ARP-SCAN INSTALL"
bash "${DIR_LIB}/setup_arp_scan_sem_pedir_senha.sh"
print_footer


################################################################
# EXEC_CLIENTE
print_header "EXEC_CLIENTE INSTALL"
EXEC_CLIENTE_PATH="/usr/local/bin/exec_cliente"
sudo tee "$EXEC_CLIENTE_PATH" > /dev/null <<'EOF'
#!/bin/bash
bash ${DIR_LIB}/trocar_cliente.sh "$1"
EOF
sudo chmod +x "$EXEC_CLIENTE_PATH"
echo "✅ Comando 'exec_cliente' instalado com sucesso!"
echo ""
echo "📢 Agora você pode usar: exec_cliente <cliente_id>"
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
    echo 'sxx'
    REMOVE_CRONS=true
  fi
done


################################################################
# REMOVE_CRONS
if $REMOVE_CRONS; then
  print_header "CRONS REMOVE"
  if [[ -f "$CRONPATH" ]]; then
    sudo rm -f "$CRONPATH"
    echo "🗑️  Cron job removido: $CRONPATH"
  else
    echo "ℹ️  Nenhum cron job para remover em: $CRONPATH"
  fi
  print_footer
fi


################################################################
# INSTALL_CRONS
if $INSTALL_CRONS; then
  print_header "CRONS INSTALL"
  echo "🕒 Instalando cron jobs..."
  sudo tee "$CRONPATH" > /dev/null <<EOF
@reboot root /bin/bash -c 'cd ${DIR_LIB} && ./exec.sh >> logs/cron.txt 2>&1'
*/1 * * * * root /bin/bash -c 'cd ${DIR_LIB} && ./exec.sh >> logs/cron.txt 2>&1'
*/30 * * * * root /usr/bin/systemctl restart NetworkManager >> ${DIR_LIB}/logs/rede.log 2>&1
EOF
  sudo chmod 644 "$CRONPATH"
  sudo chown root:root "$CRONPATH"
  echo "✅ Cron jobs instalados com sucesso em:"
  echo "$CRONPATH"
  print_footer
fi



################################################################
# INSTALL_CRON
print_header "Adiconando Permissoes..."
sudo mkdir -p "$DIR_LIB/logs"
sudo touch "$DIR_LIB/logs/cron.txt"
sudo chmod 666 "$DIR_LIB/logs/cron.txt"
sudo chmod 777 "$DIR_LIB/logs"
sudo chmod +x "$DIR_LIB/exec.sh"


print_header "Fim"
