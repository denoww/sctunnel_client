#!/bin/bash

set -e

echo "🔧 Instalando comando 'exec_cliente' no sistema..."

# Define o destino do comando
DESTINO="/usr/local/bin/exec_cliente"

# Cria o script do comando
sudo tee "$DESTINO" > /dev/null <<'EOF'
#!/bin/bash
bash /var/lib/sctunnel_client/trocar_cliente.sh "$1"
EOF

# Dá permissão de execução
sudo chmod +x "$DESTINO"

echo "✅ Comando 'exec_cliente' instalado com sucesso!"
echo ""
echo "📢 Agora você pode usar: exec_cliente <cliente_id>"

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
  if [[ -f "$CRONPATH" ]]; then
    sudo rm -f "$CRONPATH"
    echo "🗑️  Cron job removido: $CRONPATH"
  else
    echo "ℹ️  Nenhum cron job para remover em: $CRONPATH"
  fi
fi


if $INSTALL_CRONS; then
  echo "🕒 Instalando cron jobs..."
  sudo tee "$CRONPATH" > /dev/null <<EOF
@reboot root bash /var/lib/sctunnel_client/exec.sh >> /var/lib/sctunnel_client/log_cron.txt 2>&1
*/1 * * * * root bash /var/lib/sctunnel_client/exec.sh >> /var/lib/sctunnel_client/log_cron.txt 2>&1
*/30 * * * * root /usr/bin/systemctl restart NetworkManager >> /var/lib/sctunnel_client/rede.log 2>&1
EOF

  sudo chmod 644 "$CRONPATH"
  sudo chown root:root "$CRONPATH"

  echo "✅ Cron jobs instalados com sucesso em:"
  echo "$CRONPATH"
fi
