# Sourced by Forge Neo's webui.sh on every start.
export VENV_DIR="/workspace/venvs/forge-neo"

# Models live in ComfyUI's folder so both apps share one copy.
# No --listen: Forge binds to 127.0.0.1 and is only reachable through nginx.
COMFY_MODELS=/workspace/ComfyUI/models
export COMMANDLINE_ARGS="--port 3001 \
  --forge-ref-comfy-home /workspace/ComfyUI \
  --esrgan-models-path $COMFY_MODELS/upscale_models \
  --embeddings-dir $COMFY_MODELS/embeddings \
  $(grep -v '^\s*#' /workspace/forge_args.txt 2>/dev/null | tr '\n' ' ')"
