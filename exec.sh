
#!/bin/bash

DIR=$(dirname "$0")
update_firmware(){
  echo "Atualizando firmware..."
  git config --global --add safe.directory "$DIR" 2>/dev/null || true
  cd "$DIR" && git pull
}
update_firmware
bash exec_tunnels.sh


