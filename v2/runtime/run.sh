#!/bin/bash
# /opt/sctunnel/run.sh — entrypoint used by cron and set_cliente.
set -e
cd /opt/sctunnel
exec /opt/sctunnel/venv/bin/python /opt/sctunnel/tunnels.py
