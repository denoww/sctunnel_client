config=$(jq -r '' "config.json")

function montar_cameras {
  cameras=$2
  equipamento_obj=$1

  readarray -t list < <(echo $cameras | jq -c '.[]')

  resp=()
  for camera in "${list[@]}"; do
    camera_params=$(echo ''$equipamento_obj' '$camera'' | jq -s add)
    camera_url=$(bash app/get-custom-rtsp-camera.sh "$camera_params" 2>/dev/null)

    camera_id=$(echo $camera | jq '.stream_channel_id' | tr -d '"')

    camera_obj="{\"id\":$camera_id, \"url\":\"$camera_url\"}"
    resp+=($camera_obj)
  done
  echo $(echo "${resp[@]}" | jq -s '.')
}

function montar_streamns {
  resp=()

  readarray -t list < <(echo $config | jq -c '.equipamentos[]?')
  for equipamento in "${list[@]}"; do
    equipamento_obj=$(echo "$equipamento" | jq 'del(.cameras)')

    cameras=$(echo "$equipamento" | jq '.cameras')
    cameras_obj=$(montar_cameras "$equipamento_obj" "$cameras")

    stream_id=$(echo $equipamento_obj | jq '.stream_id' | tr -d '"')

    stream_obj="{\"stream_id\":\"$stream_id\",\"cameras\":$cameras_obj}"

    resp+=($stream_obj)
  done
  echo $(echo "${resp[@]}" | jq -s '.')
}

echo $(montar_streamns)
