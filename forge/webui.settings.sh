# Sourced by Forge Neo's webui.sh on every start.
export VENV_DIR="/workspace/venvs/forge-neo"

# webui.sh sets SD_WEBUI_RESTART without exporting it, so Forge thinks it
# can't restart and "Apply and restart UI" just quits. Exporting it here
# (webui.sh's later assignment keeps the export) makes the restart work.
export SD_WEBUI_RESTART="tmp/restart"

# Models live in ComfyUI's folder so both apps share one copy.
# No --listen: Forge binds to 127.0.0.1 and is only reachable through nginx.
COMFY_MODELS=/workspace/ComfyUI/models
export COMMANDLINE_ARGS="--port 3001 \
  --forge-ref-comfy-home /workspace/ComfyUI \
  --esrgan-models-path $COMFY_MODELS/upscale_models \
  --embeddings-dir $COMFY_MODELS/embeddings \
  $(grep -v '^\s*#' /workspace/forge_args.txt 2>/dev/null | tr '\n' ' ')"
