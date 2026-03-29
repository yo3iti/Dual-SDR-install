#!/bin/bash
# Activate SDR virtual environment

VENV_PATH="$HOME/programare/sdr_build/venv"

if [ -d "$VENV_PATH" ]; then
    source "$VENV_PATH/bin/activate"
    echo "SDR virtual environment activated"
    echo "Python: $(which python3)"
    echo "To deactivate: type 'deactivate'"
else
    echo "ERROR: Virtual environment not found at $VENV_PATH"
    exit 1
fi
