#!/bin/bash

# Resolve o interpretador Python disponível, em ordem de preferência
if [ -x /usr/bin/python3.10 ]; then
  PYTHON_REAL="/usr/bin/python3.10"
elif [ -x /usr/bin/python3 ]; then
  PYTHON_REAL="/usr/bin/python3"
elif [ -x /usr/bin/python3.8 ]; then
  PYTHON_REAL="/usr/bin/python3.8"
else
  echo "❌ Nenhum interpretador Python compatível encontrado em /usr/bin" >&2
  exit 1
fi

export PYTHON_REAL
