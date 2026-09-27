#!/usr/bin/env bash
# Run by start.sh on every boot: copies the apps to /workspace when the image
# is new to this volume, creates missing folders and files, starts the apps.
set -uo pipefail

VERSION_FILE=/workspace/.coopzr-comfyui-forge-neo-version
MODELS=/workspace/ComfyUI/models

# --- 1. Sync -----------------------------------------------------------------
# rsync -rlptD is -a without owner/group, which network volumes can refuse.
sync_apps() {
    local start=$SECONDS
    echo "SYNC: copying the apps to /workspace, this takes a few minutes on first boot..."
    mkdir -p /workspace/venvs
    if ! {
        rsync -rlptD /venv/ /workspace/venvs/forge-neo/ &&
            rsync -rlptD /sd-webui-forge-neo/ /workspace/sd-webui-forge-neo/ &&
            rsync -rlptD /ComfyUI/ /workspace/ComfyUI/ &&
            /fix_venv.sh /venv /workspace/venvs/forge-neo &&
            /fix_venv.sh /ComfyUI/venv /workspace/ComfyUI/venv
    }; then
        echo "SYNC: FAILED. It will be retried on the next boot."
        return 1
    fi
    echo "$TEMPLATE_VERSION" > "$VERSION_FILE"
    echo "SYNC: done in $((SECONDS - start)) seconds"
}

existing="$(cat "$VERSION_FILE" 2>/dev/null || echo 0.0.0)"
echo "SYNC: image version $TEMPLATE_VERSION, volume version $existing"

if [[ -n ${DISABLE_SYNC:-} ]]; then
    echo "SYNC: DISABLE_SYNC is set, skipping"
elif [[ $existing == "$TEMPLATE_VERSION" ]]; then
    echo "SYNC: volume is up to date, skipping"
elif [[ "$(printf '%s\n' "$existing" "$TEMPLATE_VERSION" | sort -V | tail -n 1)" == "$TEMPLATE_VERSION" ]]; then
    sync_apps
else
    echo "SYNC: volume has a newer version than this image, skipping"
fi

# --- 2. Create what's missing ------------------------------------------------
mkdir -p /workspace/logs
for dir in checkpoints diffusion_models text_encoders clip vae loras controlnet upscale_models embeddings; do
    mkdir -p "$MODELS/$dir"
done

if [[ ! -f /workspace/forge_args.txt ]]; then
    cat > /workspace/forge_args.txt <<'EOF'
# Extra Forge Neo launch arguments. Lines starting with # are ignored.
# After editing, run: restart forge
# Example:
# --cuda-malloc
EOF
fi

if [[ ! -f /workspace/comfyui_args.txt ]]; then
    cat > /workspace/comfyui_args.txt <<'EOF'
# Extra ComfyUI launch arguments. Lines starting with # are ignored.
# After editing, run: restart comfyui
# Example:
# --preview-method auto
EOF
fi

# --- 3. Start the apps -------------------------------------------------------
if [[ -n ${DISABLE_AUTOLAUNCH:-} ]]; then
    echo "DISABLE_AUTOLAUNCH is set, not starting the apps."
    echo "Start them with: restart forge, restart comfyui, or restart all"
else
    /start_forge.sh
    /start_comfyui.sh
fi
