function get_config {
  config=$(jq -r '' "config.json")
  echo $config | jq '.'$1''
}

HOST=$(get_config "sc_server.host" | tr -d '"')
TOKEN=$(get_config "sc_server.token" | tr -d '"')
CLIENTE_ID=$(get_config "sc_server.cliente_id" | tr -d '"')

function montar_cameras {
  camera=$2
  stream_obj=$1

  camera_params=$(echo ''$stream_obj' '$camera'' | jq -s add)

  camera_url=$(echo $camera_params | jq -c '.url')
  # camera_url="rtsp://admin:ds171118@0.tcp.sa.ngrok.io:13408/cam/realmonitor?channel=5&subtype=1"

  # regex="(.*)://(.*):(.*)@(.*):(.*)/cam/realmonitor\?channel\=(.*)&subtype=(.*)"
  regex="(.*)://(.*):(.*)@(.*):([[:digit:]]+)/(.*)"

  if [[ $camera_url =~ $regex ]]; then
    camera_params=$(echo $camera_params | jq '.stream_channel_id = .id' )
    camera_params=$(echo $camera_params | jq --arg v "${BASH_REMATCH[2]}" '.camera_user = $v' )
    camera_params=$(echo $camera_params | jq --arg v "${BASH_REMATCH[3]}" '.camera_user_pass = $v' )
    camera_params=$(echo $camera_params | jq --arg v "${BASH_REMATCH[4]}" '.camera_adress_ip = $v' )
    camera_params=$(echo $camera_params | jq --arg v "${BASH_REMATCH[5]}" '.camera_adress_porta = $v' )
    # camera_params=$(echo $camera_params | jq --arg v "${BASH_REMATCH[6]}" '.camera_channel = $v' )
    camera_params=$(echo $camera_params | jq --arg v "$(echo ${BASH_REMATCH[6]} | tr -d '"')" '.camera_adress_url_controller = $v' )

    camera_address=$(echo $camera_params | jq -c '.camera_adress_ip' | tr -d '"')
    # camera_address="192.168.1.108"
    # camera_address="0.tcp.sa.ngrok.io"

    # regex="([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])"
    regex="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"

    if [[ $camera_address =~ $regex ]]; then
      # se for IP, vamos compartilhar as informacoes via tcp próprio ou com ngrok

      camera_url=$(bash app/get-custom-rtsp-camera.sh "$camera_params" 2>/dev/null)

      camera_params=$(echo $camera_params | jq --arg v "$camera_url" '.url = $v' )
    else
      exit
    fi
  else
    exit
  fi

  echo "$camera_params"
}

function montar_streamns {
  resp=()

  URL="$HOST/portarias/cameras_streams.json?token=$TOKEN&cliente_id=$CLIENTE_ID"
  sc_streamns=$(curl -s $URL 2>&1 | jq -c '.streams?')

  readarray -t list < <(echo $sc_streamns | jq -c '.[]')
  for stream in "${list[@]}"; do
    stream_obj=$(echo "$stream" | jq 'del(.cameras)')

    resp_cameras=()

    readarray -t cameras < <(echo $stream | jq -c '.cameras[] | select(.url != null)')
    for camera in "${cameras[@]}"; do
      camera_params=$(montar_cameras "$stream_obj" "$camera")
      if [[ ! $camera_params ]]; then
        continue
      fi

      camera_id=$(echo $camera_params | jq '.stream_channel_id' | tr -d '"')
      camera_url=$(echo $camera_params | jq '.url' | tr -d '"')
      if [[ ! $camera_url ]]; then
        continue
      fi

      camera_obj="{\"id\":$camera_id, \"url\":\"$camera_url\"}"
      resp_cameras+=($camera_obj)
    done

    stream_id=$(echo $stream | jq '.stream_id' | tr -d '"')
    resp_cameras=$(echo "${resp_cameras[@]}" | jq -s '.')

    stream_obj="{\"stream_id\":\"$stream_id\",\"cameras\":$resp_cameras}"

    resp+=($stream_obj)

  done

  echo $(echo "${resp[@]}" | jq -s '.')
}

echo $(montar_streamns)
