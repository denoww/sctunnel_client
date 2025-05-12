#!/bin/bash
DIR_LIB="$(cd "$(dirname "$0")" && pwd)"
bash "${DIR_LIB}/update_firmware.sh"
bash "${DIR_LIB}/exec_install.sh" "$@"
