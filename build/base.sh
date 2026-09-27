#!/usr/bin/env bash
# Base stage: system packages, Python, CUDA build tools, torch and small tools.
# Build args used: PYTHON_VERSION, CUDA_VERSION_DASH, TORCH_VERSION,
# TORCHVISION_VERSION, TORCH_INDEX (see docker-bake.hcl).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Torch pins. PIP_CONSTRAINT (set in the Dockerfile) points here, so no later
# pip install, at build time or on the pod, can swap torch out.
cat > /opt/constraints.txt <<CONSTRAINTS
torch==${TORCH_VERSION}
torchvision==${TORCHVISION_VERSION}
CONSTRAINTS

# 1. apt packages
apt-get update
apt-get install -y --no-install-recommends \
    software-properties-common \
    nginx \
    openssh-server \
    git \
    git-lfs \
    curl \
    wget \
    aria2 \
    ffmpeg \
    rsync \
    psmisc \
    libgl1 \
    libglib2.0-0t64 \
    tmux \
    htop \
    nano \
    zip \
    unzip \
    ca-certificates \
    build-essential \
    apache2-utils \
    openssl

# 2. Python from the deadsnakes PPA. Ubuntu's own python3 (3.12) stays in
# /usr/bin for system tools; ours takes over via /usr/local/bin in PATH.
add-apt-repository -y ppa:deadsnakes/ppa
apt-get install -y --no-install-recommends \
    "python${PYTHON_VERSION}" \
    "python${PYTHON_VERSION}-dev" \
    "python${PYTHON_VERSION}-venv"
ln -sf "/usr/bin/python${PYTHON_VERSION}" /usr/local/bin/python3
ln -sf "/usr/bin/python${PYTHON_VERSION}" /usr/local/bin/python
curl -fsSL https://bootstrap.pypa.io/get-pip.py | "python${PYTHON_VERSION}" - --no-cache-dir

# 3. CUDA compiler and headers, kept so extensions can compile on the pod.
curl -fsSL -o /tmp/cuda-keyring.deb \
    https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i /tmp/cuda-keyring.deb
rm /tmp/cuda-keyring.deb
apt-get update
apt-get install -y --no-install-recommends "cuda-minimal-build-${CUDA_VERSION_DASH}"
ln -sfn "/usr/local/cuda-${CUDA_VERSION_DASH/-/.}" /usr/local/cuda

# 4. Torch. The versions come from /opt/constraints.txt; torchaudio and
# torchcodec are whatever pip finds that fits.
pip install --no-cache-dir torch torchvision torchaudio torchcodec --index-url "${TORCH_INDEX}"

# 5. Tools
python3 -m venv /opt/venvs/jupyter
/opt/venvs/jupyter/bin/pip install --no-cache-dir jupyterlab ipywidgets

curl -fsSL -o /usr/local/bin/runpodctl \
    https://github.com/runpod/runpodctl/releases/latest/download/runpodctl-linux-amd64
chmod +x /usr/local/bin/runpodctl

curl -fsSL https://rclone.org/install.sh | bash

# Fail the build now, not on the pod, if something above is broken.
python3 --version
nvcc --version
python3 -c "import torch, torchvision, torchaudio, torchcodec; print('torch', torch.__version__, 'torchvision', torchvision.__version__, 'torchaudio', torchaudio.__version__)"

# 6. Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*
