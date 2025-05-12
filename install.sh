#!/bin/bash
DIR_LIB=$(dirname "$0")
bash "${DIR_LIB}/update_firmware.sh"
bash "${DIR_LIB}/exec_install.sh" "$@"
