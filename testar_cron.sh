#!/bin/bash

DIR_LIB=/var/lib/sctunnel_client

FILE_LOG=$DIR_LIB/logs/cron.txt

/bin/bash -c "cd $DIR_LIB && ./exec.sh >> $FILE_LOG 2>&1"




cat $FILE_LOG

echo "----------------------------------------------------------"
echo "Esse foi o resultado do cronjob executado"
echo "Resultado aqui"
echo "cat $FILE_LOG"
echo "----------------------------------------------------------"
echo
