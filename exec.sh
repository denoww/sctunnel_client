echo ''
echo '---------------------------------------------------------------------------------'
echo '---------------------------------------------------------------------------------'
echo "Sincronizando equipamentos ($(date))"
echo '---------------------------------------------------------------------------------'
echo '---------------------------------------------------------------------------------'
echo ''

# clear config
# new_config=$(jq -r '.' "config.json" | jq '.sc_tunnel = {}')
# echo $new_config | jq '.' > config.json


function get_config {
  config=$(jq -r '' "config.json")
  echo $config | jq '.'$1''
}

HOST=$(get_config "sc_server.host" | tr -d '"')
TOKEN=$(get_config "sc_server.token" | tr -d '"')
CLIENTE_ID=$(get_config "sc_server.cliente_id" | tr -d '"')

SC_TUNNEL_ADDRESS=$(get_config "sc_tunnel_server.host" | tr -d '"')
# SC_TUNNEL_PEM_FILE="$projectPath/$(get_config "sc_tunnel_server.pem_file" | tr -d '"')"
SCRIPTPATH=$(dirname "$SCRIPT")
SC_TUNNEL_PEM_FILE="${SCRIPTPATH}/scTunnel.pem"



# readarray -t list < <(echo $devices | jq -c '.[]')
# for devices in "${list[@]}"; do

#   stream_obj=$(echo "$devices" | jq 'del(.devices)')

#   devices=$(echo "$devices" | jq '.devices')
#   echo $devices | jq -c '.[] | select(.url != null)' | while read camera; do
#     camera_params=$(echo ''$stream_obj' '$camera'' | jq -s add)
#     # bash app/sync-devices.sh "$camera_params"
#   done

# done

findTunnelPort() {
  portas=$(curl -s --request GET http://${SC_TUNNEL_ADDRESS}:3020/unused_ports?qtd=1 )
  echo $portas | jq -r '.portas[0]'
}

montarUrl(){
  path=$1
  echo "$HOST/portarias/${path}.json?token=$TOKEN&cliente_id=$CLIENTE_ID"
}

tunnelDevices() {
  echo "==========================="
  echo 'tunnelDevices'
  URL=$(montarUrl 'get_tunnel_devices')
  devices=$(curl -s $URL 2>&1 | jq -c '.devices?')

  readarray -t list < <(echo $devices | jq -c '.[]')
  for device in "${list[@]}"; do
    _jq() {
      echo ${device} | jq -r ${1}
    }

    deviceId=$(_jq '.id')

    host=$(_jq '.host')
    if [ -n $host ]; then

      protocol=$(echo $host | cut -d : -f 1)
      ip=$(echo $host | cut -d : -f 2)
      ip=${ip#*//} # sem http ou https ou //
      porta=$(echo $host | cut -d : -f 3)
      if [ -z $porta ]; then
        porta=80
      fi
    fi
    tunnelPorta=$(findTunnelPort)
    newHost="${SC_TUNNEL_ADDRESS}:${tunnelPorta}"
    hostPortaDevice="${ip}:${porta}"

    newHostToSave=$newHost

    if [ -n $protocol ]; then
      newHostToSave="${protocol}://${newHostToSave}"
    fi

    echo
    echo "¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨"
    echo "${hostPortaDevice} -> ${newHostToSave}"
    echo
    ssh -N -o ServerAliveInterval=20 -i "$SC_TUNNEL_PEM_FILE" -R $tunnelPorta:$hostPortaDevice ubuntu@$SC_TUNNEL_ADDRESS > /dev/null &


    updateHostOnErp $deviceId $newHostToSave
  done
  echo
}

updateHostOnErp(){
  deviceId=$1
  newHost=$2
  echo "Salvando equipamento $deviceId com -> $newHost"
  echo "¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨"
  echo

  url=$(montarUrl 'update_tunnel_devices')

  curl -X POST -H "Content-Type: application/json" -d '{"id": "'$deviceId'", "host": "'$newHost'", "cliente_id": "'$CLIENTE_ID'"}' $url
  echo

}


tunnelDevices


echo ''
echo '---------------------------------------------------------------------------------'
echo "OK OK OK OK OK OK OK OK OK OK OK OK OK ($(date))"
echo '---------------------------------------------------------------------------------'
echo ''
