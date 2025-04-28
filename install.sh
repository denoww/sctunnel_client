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
