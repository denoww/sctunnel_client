CHECK="do while"

while [[ ! -z $CHECK ]]; do
  _random=$(od -An -N2 -i /dev/random)
  PORT=$(( ( _random % 58000 )  + 1026 ))
  CHECK=$(sudo netstat -ap | grep $PORT)
done

echo $PORT
