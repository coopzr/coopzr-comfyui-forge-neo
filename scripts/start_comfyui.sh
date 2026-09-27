#!/usr/bin/env bash
# Starts ComfyUI in the background on 127.0.0.1:3021 (nginx serves it on 3020).
# Extra launch arguments come from /workspace/comfyui_args.txt.
echo "COMFYUI: starting, log: /workspace/logs/comfyui.log"
cd /workspace/ComfyUI || exit 1
# shellcheck disable=SC1091
source venv/bin/activate

args=()
if [[ -f /workspace/comfyui_args.txt ]]; then
    while IFS= read -r line; do
        [[ $line =~ ^[[:space:]]*# ]] && continue
        read -ra words <<< "$line"
        args+=("${words[@]}")
    done < /workspace/comfyui_args.txt
fi

nohup python main.py --listen 127.0.0.1 --port 3021 --enable-manager "${args[@]}" \
    > /workspace/logs/comfyui.log 2>&1 &
