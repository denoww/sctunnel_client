#!/bin/bash
echo "$(date) - reiniciando rede via systemd (nmcli)" >> /home/rodrigo/workspace/sctunnel_client/logs/rede.txt
sudo /usr/bin/nmcli networking off
sleep 2
sudo /usr/bin/nmcli networking on
