

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


# readarray -t list < <(echo $devices | jq -c '.[]')
# for devices in "${list[@]}"; do

#   stream_obj=$(echo "$devices" | jq 'del(.devices)')

#   devices=$(echo "$devices" | jq '.devices')
#   echo $devices | jq -c '.[] | select(.url != null)' | while read camera; do
#     camera_params=$(echo ''$stream_obj' '$camera'' | jq -s add)
#     # bash app/sync-devices.sh "$camera_params"
#   done

# done

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



  base_url="$HOST/portarias/${path}.json?token=$TOKEN&cliente_id=$CLIENTE_ID"
  echo "${base_url}${codigos_query}"
}



updateDevices() {
  update_firmware
  # arrumar_erro_host_identification_changed

  # echo "EQUIPAMENTO_CODIGOS"
  # echo $EQUIPAMENTO_CODIGOS


  echo "Procurando equipamentos para fazer tunnel..."
  get_url=$(montar_erp_url 'get_tunnel_devices')
  echo "Url: $get_url"

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
      update_tunnel $device
    done
  fi

}


update_tunnel(){
  device=$1
  getDevice() {
    echo ${device} | jq -r ${1}
  }

  device_id=$(getDevice '.id')
  device_codigo=$(getDevice '.codigo')
  # port=$(getDevice '.port')
  # ip=$(getDevice '.ip')
  device_host=$(getDevice '.host')
  tunnel_me=$(getDevice '.tunnel_me')
  tipo=$(getDevice '.tipo')
  tunnel_me=$(getDevice '.tunnel_me')

  # if [ -n $address ]; then

  #   protocol=$(echo $address | cut -d : -f 1)
  #   ip=$(echo $address | cut -d : -f 2)
  #   ip=${ip#*//} # sem http ou https ou //
  #   port=$(echo $address | cut -d : -f 3)
  #   if [ -z $port ]; then
  #     port=80 # se não tiver port usa a 80
  #   fi
  # fi
  # device_host="${ip}:${port}"

  # address_with_protocol=$tunnel_address

  # if [ -n $protocol ]; then
  #   address_with_protocol="${protocol}://${address_with_protocol}"
  # fi



  echo
  echo "¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨"
  if [ "$tunnel_me" != null ]; then

    if [ "$tunnel_me" = false ]; then
      disconnect_old_tunnel $device_host
    fi

    if [ "$tunnel_me" = true ]; then
      disconnect_old_tunnel $device_host
      connect_tunnel $device_host
    fi

    update_no_erp $device_id $tipo $tunnel_address

  else
    garantir_conexao_do_device "$device_host" "$device_id" "$tipo" "$tunnel_address" "$device_codigo"
  fi
  echo "¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨"
  echo

}

update_no_erp(){
  device_id=$1
  tipo=$2
  tunnel_address=$3
  update_url=$(montar_erp_url 'update_tunnel_devices')
  curl -X POST -H "Content-Type: application/json" -d '{"id": "'$device_id'", "tipo": "'$tipo'", "tunnel_address": "'$tunnel_address'", "cliente_id": "'$CLIENTE_ID'"}' $update_url &> /dev/null
}

garantir_conexao_do_device(){
  # Garantir conexão
  device_host="$1"
  device_id="$2"
  tipo="$3"
  tunnel_address="$4"
  device_codigo="$5"


  linha=$(grep "device_host:$device_host" $CONEXOES_FILE)
  # echo $linha

  pid=$(echo "$linha" | sed 's/pid:\([^§]\+\).*/\1/')

  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "Tunnel ativo de #$device_codigo - $device_host - PID $pid"
  else
    echo "Caiu Tunnel de #$device_codigo - $device_host - PID $pid"

    disconnect_old_tunnel $device_host
    connect_tunnel $device_host
    update_no_erp $device_id $tipo $tunnel_address
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

connect_tunnel(){
  device_host=$1
  tunnel_porta=$(find_tunnel_port)
  tunnel_address="${SC_TUNNEL_ADDRESS}:${tunnel_porta}"

  ssh -N -o ServerAliveInterval=20 -i "$SC_TUNNEL_PEM_FILE" -oStrictHostKeyChecking=no -oUserKnownHostsFile=/tmp/ssh_known_hosts_temp -R $tunnel_porta:$device_host $SC_TUNNEL_USER@$SC_TUNNEL_ADDRESS > /dev/null &
  pid=$!
  salvar_conexao_arquivo $pid $device_host $tunnel_porta
  echo
  echo "Definindo novo endereço de #$device_id no erp"
  echo "${device_host} -> ${tunnel_address}"
}

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
  device_host=$1
  echo "Removendo tunnel antigo de $device_host"


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
