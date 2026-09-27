#!/usr/bin/env bash
# Installed as /usr/local/bin/restart.
# Usage: restart <forge|comfyui|all>

usage() {
    echo "Usage: restart <forge|comfyui|all>"
    exit 1
}

restart_app() {
    local name=$1 port=$2 script=$3

    echo "Stopping $name (port $port)..."
    fuser -k "$port/tcp" > /dev/null 2>&1
    for _ in {1..10}; do
        fuser -s "$port/tcp" 2> /dev/null || break
        sleep 1
    done
    if fuser -s "$port/tcp" 2> /dev/null; then
        echo "Warning: port $port is still in use."
    fi

    "$script"
}

[[ $# -eq 1 ]] || usage

case "$1" in
    forge) restart_app forge 3001 /start_forge.sh ;;
    comfyui) restart_app comfyui 3021 /start_comfyui.sh ;;
    all)
        restart_app forge 3001 /start_forge.sh
        restart_app comfyui 3021 /start_comfyui.sh
        ;;
    *) usage ;;
esac
