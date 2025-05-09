#!/bin/bash

set -e

echo "🔧 Instalando comando 'exec_cliente' no sistema..."

DIR_LIB=/var/lib/sctunnel_client



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

# arp-scan
print_header "ARP-SCAN INSTALL"

bash "${DIR_LIB}/setup_arp_scan_sem_pedir_senha.sh"
print_footer

# Define o EXEC_CLIENTE_PATH do comando
print_header "EXEC_CLIENTE INSTALL"

EXEC_CLIENTE_PATH="/usr/local/bin/exec_cliente"

# Cria o script do comando
sudo tee "$EXEC_CLIENTE_PATH" > /dev/null <<'EOF'
#!/bin/bash
bash ${DIR_LIB}/trocar_cliente.sh "$1"
EOF

# Dá permissão de execução
sudo chmod +x "$EXEC_CLIENTE_PATH"

echo "✅ Comando 'exec_cliente' instalado com sucesso!"
echo ""
echo "📢 Agora você pode usar: exec_cliente <cliente_id>"
print_footer

# Verifica se --install_crons está entre os argumentos
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


if $INSTALL_CRONS; then
  print_header "CRONS INSTALL"
  echo "🕒 Instalando cron jobs..."
  sudo tee "$CRONPATH" > /dev/null <<EOF
@reboot root bash ${DIR_LIB}/exec.sh >> ${DIR_LIB}/logs/cron.txt 2>&1
*/1 * * * * root bash ${DIR_LIB}/exec.sh >> ${DIR_LIB}/logs/cron.txt 2>&1
*/30 * * * * root /usr/bin/systemctl restart NetworkManager >> ${DIR_LIB}/logs/rede.log 2>&1
EOF

  sudo chmod 644 "$CRONPATH"
  sudo chown root:root "$CRONPATH"

  echo "✅ Cron jobs instalados com sucesso em:"
  echo "$CRONPATH"
  print_footer
fi

