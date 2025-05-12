#!/bin/bash

DIR_LIB=$(dirname "$0")


FILE_LOG=$DIR_LIB/logs/cron.txt

/bin/bash -c "cd $DIR_LIB && ./exec.sh >> $FILE_LOG 2>&1"

bash "${DIR_LIB}/cron_logs.sh"


