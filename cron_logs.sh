#!/bin/bash

DIR_LIB="$(cd "$(dirname "$0")" && pwd)"


FILE_LOG=$DIR_LIB/logs/cron.txt

tail -n 500 "$FILE_LOG"

echo "----------------------------------------------------------"
echo "Esse foi o resultado do cronjob executado"
echo "Resultado aqui"
echo "tail -n 500 $FILE_LOG"
echo "----------------------------------------------------------"
echo
