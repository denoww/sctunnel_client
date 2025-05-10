
#!/bin/bash

# Defina o PATH para garantir que comandos como arp-scan e curl funcionem
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"


# PATH=${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}
USER=${USER:-$(whoami)}

# clear config
# new_config=$(jq -r '.' "config.json" | jq '.sc_tunnel = {}')
# echo $new_config | jq '.' > config.json


DIR=$(dirname "$0")
function get_config {
  config=$(jq -r '' "$DIR/config.json")
  echo $config | jq '.'$1''
}

HOST=$(get_config "sc_server.host" | tr -d '"')
TOKEN=$(get_config "sc_server.token" | tr -d '"')
CLIENTE_ID=$(get_config "sc_server.cliente_id" | tr -d '"')
EQUIPAMENTO_CODIGOS=$(get_config "sc_server.equipamento_codigos" | tr -d '"')


SC_TUNNEL_ADDRESS=$(get_config "sc_tunnel_server.host" | tr -d '"')
SC_TUNNEL_USER=$(get_config "sc_tunnel_server.user" | tr -d '"')
# SC_TUNNEL_PEM_FILE="$projectPath/$(get_config "sc_tunnel_server.pem_file" | tr -d '"')"
SC_TUNNEL_PEM_FILE="${DIR}/scTunnel.pem"
CONEXOES_FILE="${DIR}/conexoes.txt"


####################################################
####################################################
####################################################
####################################################
## ARPSCAP
####################################################

if [ ! -f "$CONEXOES_FILE" ]; then
  touch "$CONEXOES_FILE"
  echo "📝 Arquivo criado: $CONEXOES_FILE"
fi


# Verifica se o marcador de instalação existe
RED='\033[31m'
NC='\033[0m'

ARP_SCAN_PATH=$(which arp-scan 2>/dev/null)
# ARP_SCAN_PATH=$(command -v arp-scan)
# ARP_SCAN_PATH="/usr/bin/arp-scan"

ARP_SCAN_INSTALADO="${DIR}/ARP_SCAN_INSTALADO.txt"
if [ ! -f "$ARP_SCAN_INSTALADO" ]; then

  echo -e "${RED}==================================================================${NC}" >&2
  echo -e "${RED}❌ arp-scan não está instalado.${NC}" >&2
  echo -e "${RED}Instale com 'bash ${DIR}/install.sh'${NC}" >&2
  echo -e "${RED}==================================================================${NC}" >&2

  # exit 1
fi

# Verifica se o comando foi encontrado
if [ -z "$ARP_SCAN_PATH" ]; then
  echo -e "${RED}Comando 'arp-scan' não encontrado no PATH. '.${NC}" >&2
  echo -e "${RED}Faça 'bash ${DIR}/install.sh' ${NC}" >&2
  echo -e "${RED}ou ${NC}" >&2
  echo -e "${RED}Faça 'sudo apt install arp-scan' ${NC}" >&2
  # exit 1
fi
# Detecta a interface e IP principal (default route)
read -r INTERFACE_REDE IP_TUNNEL <<< $(ip route get 1.1.1.1 | awk '{print $5, $7; exit}')
SUBNET=$(echo "$IP_TUNNEL" | sed 's/\.[0-9]\+$/\.0\/24/')

echo "🔄 Escaneando rede com arp-scan (uma vez só)..." >&2
# ARP_SCAN_OUTPUT=$(sudo $ARP_SCAN_PATH --interface="$INTERFACE_REDE" "$SUBNET")
ARP_SCAN_OUTPUT=$($ARP_SCAN_PATH --interface="$INTERFACE_REDE" "1.1.1.2")

echo
echo "--------------------------------------------------------------"
echo "Macs de todos aparelhos da Rede"
if [ -n "$ARP_SCAN_OUTPUT" ]; then
  echo -e "\033[0;32m$ARP_SCAN_OUTPUT\033[0m"  # verde
else
  echo -e "\033[0;31mNenhum dispositivo encontrado.\033[0m"  # vermelho
fi
####################################################
####################################################
####################################################
####################################################




echo ''
echo '=================================================================================='
echo "CLIENTE_ID $CLIENTE_ID Sincronizando equipamentos ($(date))"
echo '=================================================================================='
echo ''

is_blank() {
  [ -z "$1" ] || [ "$1" = "null" ]
}

is_present() {
  [ -n "$1" ] && [ "$1" != "null" ]
}


getDevice() {
  device=$1
  echo ${device} | jq -r ${2}
}

tunel_device(){
  device=$1


  device_host=$(getDevice $device '.host')
  port=$(getDevice $device '.port')
  codigo=$(getDevice $device '.codigo')
  MAC1=$(getDevice $device '.mac_address')
  MAC2=$(getDevice $device '.mac_address_2')

  echo
  echo "========================================================================================="
  echo "========================================================================================="
  echo "========================================================================================="
  echo "device #$codigo"
  echo $device
  echo
  ###############################
  ###############################
  # get_ip_by_mac precisa de sudo
  # arrumar o tunnel para não pedir senha
  ###############################
  if is_blank "$device_host"; then
    for MAC in "$MAC1" "$MAC2"; do
      if ! is_blank "$MAC"; then
        echo "" >&2
        echo "🔍 #$codigo Procurando IP pelo MAC $MAC" >&2
        device_host=$(get_ip_by_mac "$MAC")
        if ! is_blank "$device_host"; then
          echo "✅ Encontrado device_host: $device_host via MAC: $MAC"
          break
        else
          echo "⚠️  Nenhum device_host encontrado via MAC: $MAC"
        fi
      fi
    done
  fi
  ###############################
  ###############################
  ###############################


  if is_present "$device_host" && ! [[ "$device_host" =~ :[0-9]+$ ]]; then
    if is_blank "$port"; then
      port=80
    fi
    device_host="${device_host}:${port}"
  fi


  tunnel_me=$(getDevice $device '.tunnel_me')


  if [ "$tunnel_me" = false ]; then
    disconnect_old_tunnel "$device" "$device_host"
  fi

  if [ "$tunnel_me" != null ]; then


    if is_blank "$device_host"; then
      echo "❌ device #$codigo sem ip/host. Verifique se os MACs estão corretos ou disponíveis na rede ou cadastre o ip:porta dele no sistema."
      return 1
    fi

    if [ "$tunnel_me" = true ]; then
      reconnect_tunnel "$device" "$device_host"
    fi
    update_device_tunnel_addres_no_erp "$device" "$device_host"
  else
    garantir_conexao_do_device "$device" "$device_host"
  fi




  echo "========================================================================================="
  echo "========================================================================================="
  echo "========================================================================================="
  echo

}

connect_tunnel() {
  device=$1
  device_host=$2

  codigo=$(getDevice "$device" '.codigo')

  tunnel_porta=$(find_tunnel_port)
  tunnel_address="${SC_TUNNEL_ADDRESS}:${tunnel_porta}"

  echo
  echo "🔐 Conectando túnel SSH para o dispositivo #$codigo"
  echo "📡 Comando:"
  echo "ssh -N -o ServerAliveInterval=20 -i \"$SC_TUNNEL_PEM_FILE\" -oStrictHostKeyChecking=no -oUserKnownHostsFile=/tmp/ssh_known_hosts_temp -R $tunnel_porta:$device_host $SC_TUNNEL_USER@$SC_TUNNEL_ADDRESS"
  echo

  ssh -N -o ServerAliveInterval=20 -i "$SC_TUNNEL_PEM_FILE" -oStrictHostKeyChecking=no -oUserKnownHostsFile=/tmp/ssh_known_hosts_temp -R $tunnel_porta:$device_host $SC_TUNNEL_USER@$SC_TUNNEL_ADDRESS > /dev/null 2>&1 &
  pid=$!
  salvar_conexao_arquivo "$pid" "$device" "$device_host" "$tunnel_porta"

  echo
  echo "Definindo novo endereço de #$codigo no ERP"
  echo "----------------------------------------------------------------"
  echo "${device_host} -> ${tunnel_address}"
  echo "----------------------------------------------------------------"

}

reconnect_tunnel() {
  device="$1"
  device_host="$2"
  disconnect_old_tunnel "$device" "$device_host"
  connect_tunnel "$device" "$device_host"
}

find_tunnel_port() {
  portas=$(curl -s --request GET http://${SC_TUNNEL_ADDRESS}:3020/unused_ports?qtd=1 )
  echo $portas | jq -r '.portas[0]'
}

urlencode() {
  local data
  if [[ "$#" -eq 0 ]]; then
    cat
  else
    data="$1"
  fi

  # Usa printf para codificar os caracteres
  echo -n "$data" | jq -s -R -r @uri
}

gerar_ssh_cmd() {
  local device_id=0
  local ssh_port
  ssh_port=$(extrair_campo_conexao "$device_id" "tunnel_porta")

  local ssh_cmd
  ssh_cmd="ssh -p ${ssh_port} ${USER}@${SC_TUNNEL_ADDRESS} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

  echo "$ssh_cmd"
}


montar_erp_url() {
  path=$1
  codigos_query=""

  if [[ -n "${EQUIPAMENTO_CODIGOS:-}" ]] && echo "$EQUIPAMENTO_CODIGOS" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
    codigos_query=$(echo "$EQUIPAMENTO_CODIGOS" | jq -r '.[]' | while read -r codigo; do
      printf "&codigos[]=%s" "$codigo"
    done)
  fi


  ssh_cmd=$(gerar_ssh_cmd)
  ssh_cmd_encoded=$(urlencode "$ssh_cmd")

  base_url="$HOST/portarias/${path}.json?token=$TOKEN&cliente_id=$CLIENTE_ID&tunnel_macaddres=$(macAddresDoTunnel)&ssh_cmd=${ssh_cmd_encoded}"
  echo "${base_url}${codigos_query}"
}


macAddresDoTunnel(){
  ip link | awk '/ether/ {print $2}' | paste -sd,
}

buscar_ip_na_lista_de_macs() {
  local mac="$1"
  local mac_lower=$(echo "$mac" | tr '[:upper:]' '[:lower:]')

  echo "$ARP_SCAN_OUTPUT" | awk -v mac="$mac_lower" 'tolower($2) == mac {print $1}'
}


abrir_ssh_do_tunnel(){
  host="${IP_TUNNEL}:22"
  echo "🔐 Abrindo túnel SSH na porta 22 para o device em $host"
  device="{\"id\":0,\"codigo\":\"0\",\"host\":\"$host\"}"
  tunel_device "$device"

  ssh_cmd=$(gerar_ssh_cmd)
  echo -e "##################################################################"
  echo -e "\033[0;32mAcesse essa máquina com\033[0m"
  echo -e "\033[0;32m$ssh_cmd\033[0m"
  echo -e "##################################################################"


}


updateDevices() {

  # arrumar_erro_host_identification_changed

  # echo "EQUIPAMENTO_CODIGOS"
  # echo $EQUIPAMENTO_CODIGOS

  abrir_ssh_do_tunnel



  echo
  echo "========================================"
  echo "mac address do tunnel"
  echo $(macAddresDoTunnel)
  echo "========================================"


  echo
  echo "Procurando equipamentos para fazer tunnel em"
  get_url=$(montar_erp_url "get_tunnel_devices")
  echo "$get_url"

  # Faz a requisição e guarda a resposta inteira
  response=$(curl -s "$get_url")

  # Tenta extrair a mensagem de erro, se houver
  msg=$(echo "$response" | jq -r '.msg // empty')

  if [[ "$msg" == "token inválido" ]]; then
    echo "Erro: token inválido. Arrume token com PORTARIA_SERVER_SALT em config.json."
    exit 1
  fi

  # Extrai os devices
  devices=$(echo "$response" | jq -c '.devices // empty')

  readarray -t list < <(echo $devices | jq -c '.[]')

  if [ ${#list[@]} -eq 0 ]; then
    echo "Nenhum tunnel para fazer (lista vazia)"
  else
    for device in "${list[@]}"; do
      tunel_device $device
    done
  fi

}


get_ip_by_mac() {
  local mac="$1"
  buscar_ip_na_lista_de_macs "$mac"
}


update_device_tunnel_addres_no_erp(){
  device=$1
  device_host=$2

  tunnel_address=$(get_tunnel_address "$device")
  device_id=$(getDevice $device '.id')

  # 🚫 Não prossegue se device_id for 0 ou "0"
  if [ "$device_id" = "0" ] || [ "$device_id" = 0 ]; then
    echo "⚠️  Ignorando update: device_id é 0"
    return
  fi

  update_url=$(montar_erp_url 'update_tunnel_devices')
  JSON_PAYLOAD="{\"id\":\"$device_id\",\"tunnel_address\":\"$tunnel_address\",\"cliente_id\":\"$CLIENTE_ID\"}"

  echo
  echo "📡 Update ERP em $update_url:"
  echo "$JSON_PAYLOAD"

  curl -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$update_url" &> /dev/null
}


get_device_conexao() {
  local device_id="$1"

  if [[ -z "$device_id" ]]; then
    echo "❌ Uso: get_device_conexao <device_id>" >&2
    return 1
  fi

  if [[ ! -f "$CONEXOES_FILE" ]]; then
    echo "❌ Arquivo de conexões '$CONEXOES_FILE' não encontrado." >&2
    return 1
  fi

  local linha
  linha=$(grep "device_id:$device_id" "$CONEXOES_FILE")

  if [[ -n "$linha" ]]; then
    echo "$linha"
  else
    echo "⚠️ Nenhuma conexão encontrada para device_id:$device_id" >&2
    return 1
  fi
}

extrair_campo_conexao() {
  local device_id="$1"
  local chave="$2"

  local conexao_item
  conexao_item=$(get_device_conexao "$device_id")
  if [[ -z "$conexao_item" ]]; then
    # echo "⚠️ Nenhuma conexão encontrada para device_id: $device_id" >&2
    return 1
  fi

  local valor
  valor=$(echo "$conexao_item" | sed -n "s/.*$chave:\([^§]*\).*/\1/p")

  if [[ -n "$valor" ]]; then
    echo "$valor"
  else
    echo "⚠️ Campo '$chave' não encontrado em conexão de device_id:$device_id" >&2
    return 1
  fi
}


get_tunnel_address() {
  local device="$1"

  device_id=$(getDevice "$device" '.id')


  tunnel_porta=$(extrair_campo_conexao $device_id "tunnel_porta")


  if [ -n "$tunnel_porta" ]; then
    echo "${SC_TUNNEL_ADDRESS}:${tunnel_porta}"
  else
    echo ""
    return 1
  fi
}


garantir_conexao_do_device(){
  device=$1
  device_host=$2
  device_codigo=$(getDevice "$device" '.codigo')
  device_id=$(getDevice "$device" '.id')

  pid=$(extrair_campo_conexao $device_id "pid")
  tunnel_address=$(get_tunnel_address "$device")

  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "Tunnel ativo de #$device_codigo - $device_host - $tunnel_address - PID $pid"
  else
    echo "Caiu Tunnel de #$device_codigo - $device_host - $tunnel_address - PID $pid"
    reconnect_tunnel "$device" "$device_host"
    update_device_tunnel_addres_no_erp "$device" "$device_host"
  fi
}





# update_firmware(){
#   echo "Atualizando firmware..."
#   export GIT_CONFIG_GLOBAL=/dev/null
#   git config --global --add safe.directory "$DIR"
#   cd ${DIR} && git pull
# }

# arrumar_erro_host_identification_changed(){
#   echo "ini - arrumar_erro_host_identification_changed em $SC_TUNNEL_ADDRESS EM $SC_KNOWN_HOSTS"
#   ssh-keygen -f "$SC_KNOWN_HOSTS" -R "$SC_TUNNEL_ADDRESS"
#   echo "fim - arrumar_erro_host_identification_changed"
# }




remover_conexao_arquivo(){
  device=$1
  device_id=$(getDevice "$device" '.id')
  device_host_regex=$(echo "$device_id" | sed 's/\./\\./g')
  sed -i "/device_id:$device_host_regex/d" "$CONEXOES_FILE"
  # procurar e remover
}

salvar_conexao_arquivo(){
  pid=$1
  device=$2
  device_host=$3
  tunnel_porta=$4

  device_id=$(getDevice "$device" '.id')


  echo "pid:${pid}§§§§device_id:${device_id}§§§§device_host:${device_host}§§§§tunnel_porta:${tunnel_porta}" >> $CONEXOES_FILE
}



disconnect_old_tunnel(){
  device=$1
  device_host=$2

  codigo=$(getDevice $device '.codigo')


  echo "Removendo tunnel antigo de #$codigo $device_host"
  remover_conexao_arquivo $device


  if is_present "$device_host"; then
    pids=()
    while IFS= read -r line; do
      pids+=("$line")
    done < <(ps aux | grep "$device_host $SC_TUNNEL_USER@$SC_TUNNEL_ADDRESS" | awk '{print $2}')

    # Exibir o array de PIDs
    for pid in "${pids[@]}"; do
      # $(kill -9 $pid > /dev/null &)

      if kill -0 $pid 2>/dev/null; then
        kill $pid
        echo "processo $pid encerrado"
      # else
        # echo "O processo com o PID fornecido não está em execução."
      fi
    done
  fi

}

updateDevices





echo
echo '=================================================================================='
echo "FIM ($(date))"
echo '=================================================================================='
echo
