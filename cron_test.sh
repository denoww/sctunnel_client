#!/bin/bash

DIR_LIB="$(cd "$(dirname "$0")" && pwd)"


FILE_LOG=$DIR_LIB/logs/cron.txt

/bin/bash -c "cd $DIR_LIB && ./exec.sh >> $FILE_LOG 2>&1"

bash "${DIR_LIB}/cron_logs.sh"


