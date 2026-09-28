# Build settings for the coopzr-comfyui-forge-neo image.
# Print the resolved config with: docker buildx bake --print

# --- Image identity ---------------------------------------------------------

variable "REGISTRY" {
    default = "ghcr.io"
}

variable "REGISTRY_USER" {
    default = "coopzr"
}

variable "APP" {
    default = "coopzr-comfyui-forge-neo"
}

# Bump this for every new image you publish (see README, "Maintaining it").
variable "RELEASE" {
    default = "1.0.1"
}

# --- Pins: the only versions fixed on purpose -------------------------------
# Everything else installs at its latest version at build time.

# Platform: the Ubuntu base image.
variable "UBUNTU_VERSION" {
    default = "24.04"
}

# Must match torch's cu130 build. Runpod hosts need NVIDIA driver 580 or newer.
variable "CUDA_VERSION_DASH" {
    default = "13-0"
}

# Forge Neo is tested on Python 3.13.
variable "PYTHON_VERSION" {
    default = "3.13"
}

# Forge Neo's exact pins (modules/launch_utils.py), shared by both apps.
variable "TORCH_VERSION" {
    default = "2.13.0+cu130"
}

variable "TORCHVISION_VERSION" {
    default = "0.28.0+cu130"
}

# Forge Neo has no release tags, so pin a full commit SHA on the `neo` branch.
variable "FORGE_COMMIT" {
    default = "3a3dea7ff781f525dd227c0f6f9ed2790ad00a35"
}

# The released ComfyUI version (a git tag).
variable "COMFYUI_VERSION" {
    default = "v0.37.0"
}

# --- Target -----------------------------------------------------------------

target "default" {
    dockerfile = "Dockerfile"
    tags = [
        "${REGISTRY}/${REGISTRY_USER}/${APP}:${RELEASE}",
        "${REGISTRY}/${REGISTRY_USER}/${APP}:latest",
    ]
    labels = {
        "org.opencontainers.image.source" = "https://github.com/coopzr/coopzr-comfyui-forge-neo"
    }
    args = {
        RELEASE             = "${RELEASE}"
        UBUNTU_VERSION      = "${UBUNTU_VERSION}"
        CUDA_VERSION_DASH   = "${CUDA_VERSION_DASH}"
        PYTHON_VERSION      = "${PYTHON_VERSION}"
        TORCH_VERSION       = "${TORCH_VERSION}"
        TORCHVISION_VERSION = "${TORCHVISION_VERSION}"
        # Not a pin: the PyTorch wheel index for the CUDA version above.
        TORCH_INDEX         = "https://download.pytorch.org/whl/cu130"
        FORGE_COMMIT        = "${FORGE_COMMIT}"
        COMFYUI_VERSION     = "${COMFYUI_VERSION}"
    }
}
