#!/usr/bin/env bash
# Starts Forge Neo in the background on 127.0.0.1:3001 (nginx serves it on 3000).
# Its launch arguments come from webui.settings.sh and /workspace/forge_args.txt.
echo "FORGE: starting, log: /workspace/logs/forge.log"
cd /workspace/sd-webui-forge-neo || exit 1
nohup ./webui.sh -f > /workspace/logs/forge.log 2>&1 &
