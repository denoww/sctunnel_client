#!/bin/bash

DIR_LIB=$(dirname "$0")


FILE_LOG=$DIR_LIB/logs/cron.txt

cat $FILE_LOG

echo "----------------------------------------------------------"
echo "Esse foi o resultado do cronjob executado"
echo "Resultado aqui"
echo "cat $FILE_LOG"
echo "----------------------------------------------------------"
echo
