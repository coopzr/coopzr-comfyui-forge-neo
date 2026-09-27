#!/usr/bin/env bash
# comfyui stage: ComfyUI at COMFYUI_VERSION, with ComfyUI-Manager and its own
# venv in /ComfyUI/venv. pre_start.sh copies it to /workspace on first boot.
set -euo pipefail
export PIP_NO_CACHE_DIR=1

git clone --branch "${COMFYUI_VERSION}" --depth 1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
cd /ComfyUI

# --system-site-packages reuses the image's torch instead of a second copy.
python3 -m venv --system-site-packages venv
# shellcheck disable=SC1091
source venv/bin/activate

# manager_requirements.txt is ComfyUI's official way to add ComfyUI-Manager
# (turned on with --enable-manager at launch).
pip install -r requirements.txt -r manager_requirements.txt
