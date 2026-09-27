#!/usr/bin/env bash
# forge stage: Forge Neo at FORGE_COMMIT, with its own venv in /venv.
# pre_start.sh copies both to /workspace on first boot.
set -euo pipefail
export PIP_NO_CACHE_DIR=1

git clone --branch neo https://github.com/Haoming02/sd-webui-forge-classic.git /sd-webui-forge-neo
cd /sd-webui-forge-neo
git checkout "${FORGE_COMMIT}"

# --system-site-packages reuses the image's torch instead of a second copy.
python3 -m venv --system-site-packages /venv
# shellcheck disable=SC1091
source /venv/bin/activate

pip install -r requirements.txt

# Forge's own installer: gradio and the built-in extensions' packages.
# There's no GPU at build time, so skip its CUDA check.
python -c "from launch import prepare_environment; prepare_environment()" --skip-torch-cuda-test

rm -rf tmp
