



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

# SC_KNOWN_HOSTS="/home/orangepi/.ssh/known_hosts"

echo ''
echo '=================================================================================='
echo "CLIENTE_ID $CLIENTE_ID Sincronizando equipamentos ($(date))"
echo '=================================================================================='
echo ''

is_blank() {
  [ -z "$1" ] || [ "$1" = "null" ]
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

  ###############################
  ###############################
  # get_ip_by_mac precisa de sudo
  # arrumar o tunnel para não pedir senha
  ###############################
  if is_blank "$device_host"; then
    for MAC in "$MAC1" "$MAC2"; do
      if ! is_blank "$MAC"; then
        device_host=$(get_ip_by_mac "$MAC")
        if ! is_blank "$device_host"; then
          echo "encontrado $device_host via $MAC: $device_host"
          break
        fi
      fi
    done
  fi
  ###############################
  ###############################
  ###############################




  if is_blank "$device_host"; then
    echo "❌ device #$codigo sem ip/host. Verifique se os MACs estão corretos ou disponíveis na rede ou cadastre o ip:porta dele no sistema."
    return 1
  fi


  # Se device_host não tem porta explícita após o host/IP
  if ! [[ "$device_host" =~ :[0-9]+$ ]]; then
    if is_blank "$port"; then
      port=80
    fi
    device_host="${device_host}:${port}"
  fi


  tunnel_me=$(getDevice $device '.tunnel_me')

  echo
  echo "========================================================================================="
  echo "========================================================================================="
  echo "========================================================================================="
  echo "device"
  echo $device
  echo

  if [ "$tunnel_me" != null ]; then

    if [ "$tunnel_me" = false ]; then
      disconnect_old_tunnel "$device" "$device_host"
    fi

    if [ "$tunnel_me" = true ]; then
      reconnect_tunnel "$device" "$device_host"
    fi

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

  ssh -N -o ServerAliveInterval=20 -i "$SC_TUNNEL_PEM_FILE" -oStrictHostKeyChecking=no -oUserKnownHostsFile=/tmp/ssh_known_hosts_temp -R $tunnel_porta:$device_host $SC_TUNNEL_USER@$SC_TUNNEL_ADDRESS > /dev/null &
  pid=$!
  salvar_conexao_arquivo "$pid" "$device_host" "$tunnel_porta"

  echo
  echo "Definindo novo endereço de #$codigo no ERP"
  echo "----------------------------------------------------------------"
  echo "${device_host} -> ${tunnel_address}"
  echo "----------------------------------------------------------------"

  update_no_erp "$device" "$tunnel_address"
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

montar_erp_url() {
  path=$1
  codigos_query=""

  if [[ -n "${EQUIPAMENTO_CODIGOS:-}" ]] && echo "$EQUIPAMENTO_CODIGOS" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
    codigos_query=$(echo "$EQUIPAMENTO_CODIGOS" | jq -r '.[]' | while read -r codigo; do
      printf "&codigos[]=%s" "$codigo"
    done)
  fi



  base_url="$HOST/portarias/${path}.json?token=$TOKEN&cliente_id=$CLIENTE_ID&tunnel_macaddres=$(meusMacAddress)"
  echo "${base_url}${codigos_query}"
}


meusMacAddress(){
  ip link | awk '/ether/ {print $2}' | paste -sd,
}

updateDevices() {
  update_firmware
  # arrumar_erro_host_identification_changed

  # echo "EQUIPAMENTO_CODIGOS"
  # echo $EQUIPAMENTO_CODIGOS

  echo
  echo "========================================"
  echo "meus macs addres"
  echo $(meusMacAddress)
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
  local mac=$1
  echo $(bash buscar_ip_pelo_mac.sh "$mac")
}


update_no_erp(){
  device=$1
  tunnel_address=$2

  device_id=$(getDevice $device '.id')
  update_url=$(montar_erp_url 'update_tunnel_devices')


  JSON_PAYLOAD="{\"id\":\"$device_id\",\"tunnel_address\":\"$tunnel_address\",\"cliente_id\":\"$CLIENTE_ID\"}"

  echo
  echo "📡 Update ERP em $update_url:"
  echo "$JSON_PAYLOAD"

  curl -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$update_url" &> /dev/null


}

garantir_conexao_do_device(){
  # Garantir conexão

  device=$1
  device_host=$2
  device_codigo=$(getDevice $device '.codigo')

  linha=$(grep "device_host:$device_host" "$CONEXOES_FILE")
  tunnel_porta=$(echo "$linha" | sed -n 's/.*tunnel_porta:\([^§]*\).*/\1/p')
  pid=$(echo "$linha" | sed -n 's/.*pid:\([^§]*\).*/\1/p')

  tunnel_address="${SC_TUNNEL_ADDRESS}:${tunnel_porta}"


  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "Tunnel ativo de #$device_codigo - $device_host - $tunnel_address - PID $pid"
  else
    echo "Caiu Tunnel de #$device_codigo - $device_host - $tunnel_address - PID $pid"

    reconnect_tunnel "$device" "$device_host"
  fi

}

update_firmware(){
  echo "Atualizando firmware..."
  cd /var/lib/sctunnel_client && git pull
}

# arrumar_erro_host_identification_changed(){
#   echo "ini - arrumar_erro_host_identification_changed em $SC_TUNNEL_ADDRESS EM $SC_KNOWN_HOSTS"
#   ssh-keygen -f "$SC_KNOWN_HOSTS" -R "$SC_TUNNEL_ADDRESS"
#   echo "fim - arrumar_erro_host_identification_changed"
# }




remover_conexao_arquivo(){
  device_host=$1
  device_host_regex=$(echo "$device_host" | sed 's/\./\\./g')
  sed -i "/device_host:$device_host_regex/d" "$CONEXOES_FILE"
  # procurar e remover
}

salvar_conexao_arquivo(){
  pid=$1
  device_host=$2
  tunnel_porta=$3
  echo "pid:${pid}§§§§device_host:${device_host}§§§§tunnel_porta:${tunnel_porta}" >> $CONEXOES_FILE
}

# salvar_conexao(){
#   pid=$1
#   device_host=$2
#   tipo=$3
#   device_id=$4
#   tunnel_porta=$5
#   CONEXOES_FILE="${DIR}/conexoes.txt"
#   echo "pid:${pid}§§§§device_host:${device_host}§§§§tipo:${tipo}§§§§device_id:${device_id}§§§§tunnel_porta:${tunnel_porta}" >> $CONEXOES_FILE
# }

disconnect_old_tunnel(){
  device=$1
  device_host=$2

  codigo=$(getDevice $device '.codigo')


  echo "Removendo tunnel antigo de #$codigo $device_host"


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
  remover_conexao_arquivo $device_host

}

updateDevices





echo
echo '=================================================================================='
echo "FIM ($(date))"
echo '=================================================================================='
echo
