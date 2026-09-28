#!/usr/bin/env bash
# Run by start.sh on every boot: copies the apps to /workspace when the image
# is new to this volume, creates missing folders and files, starts the apps.
set -uo pipefail

VERSION_FILE=/workspace/.coopzr-comfyui-forge-neo-version
MODELS=/workspace/ComfyUI/models

# --- 1. Sync -----------------------------------------------------------------
# rsync -rlptD is -a without owner/group, which network volumes can refuse.
# Runpod volumes are slow per file, not per byte, and the apps are ~80,000
# small files, so the four copies run at the same time.
sync_apps() {
    local start=$SECONDS failed=0 pid
    local pids=()
    echo "SYNC: copying the apps to /workspace, this can take 15-20 minutes on first boot..."
    mkdir -p /workspace/venvs/forge-neo /workspace/sd-webui-forge-neo /workspace/ComfyUI/venv
    rsync -rlptD /venv/ /workspace/venvs/forge-neo/ & pids+=($!)
    rsync -rlptD /sd-webui-forge-neo/ /workspace/sd-webui-forge-neo/ & pids+=($!)
    rsync -rlptD --exclude=/venv/ /ComfyUI/ /workspace/ComfyUI/ & pids+=($!)
    rsync -rlptD /ComfyUI/venv/ /workspace/ComfyUI/venv/ & pids+=($!)
    for pid in "${pids[@]}"; do
        wait "$pid" || failed=1
    done
    if ((failed)) || ! {
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

# ComfyUI-Manager installs with uv by default, but uv ignores PIP_CONSTRAINT
# and can't see the image's torch, so a custom node needing torch would pull
# in a second, newer torch. pip respects both.
MANAGER_CFG=/workspace/ComfyUI/user/__manager/config.ini
if [[ ! -f $MANAGER_CFG ]]; then
    mkdir -p "$(dirname "$MANAGER_CFG")"
    printf '[default]\nuse_uv = False\n' > "$MANAGER_CFG"
fi

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
