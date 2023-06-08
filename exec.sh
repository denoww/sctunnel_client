echo ''
echo '---------------------------------------------------------------------------------'
echo '---------------------------------------------------------------------------------'
echo "Sincronizando equipamentos ($(date))"
echo '---------------------------------------------------------------------------------'
echo '---------------------------------------------------------------------------------'
echo ''

# clear config
new_config=$(jq -r '.' "config.json" | jq '.sc_tunnel = {}')
echo $new_config | jq '.' > config.json

echo 'get sc list'
sc_streamns=$(bash app/get-rtsp-sc-list.sh)
echo $sc_streamns

echo ''
echo 'get config list'
confg_streamns=$(bash app/get-rtsp-list.sh)
echo $confg_streamns

streamns=$(echo ''$sc_streamns' '$confg_streamns'' | jq -s add)

readarray -t list < <(echo $streamns | jq -c '.[]')
for stream in "${list[@]}"; do

  stream_obj=$(echo "$stream" | jq 'del(.cameras)')

  cameras=$(echo "$stream" | jq '.cameras')
  echo $cameras | jq -c '.[] | select(.url != null)' | while read camera; do
    camera_params=$(echo ''$stream_obj' '$camera'' | jq -s add)
    bash app/sync-stream.sh "$camera_params"
  done

done

echo ''
echo '---------------------------------------------------------------------------------'
echo "OK OK OK OK OK OK OK OK OK OK OK OK OK ($(date))"
echo '---------------------------------------------------------------------------------'
echo ''
