# Build args come from docker-bake.hcl.
ARG UBUNTU_VERSION=24.04

# ---------------------------------------------------------------------------
# base: Ubuntu, Python, CUDA build tools, torch, Jupyter and small tools
# ---------------------------------------------------------------------------
FROM ubuntu:${UBUNTU_VERSION} AS base

ARG CUDA_VERSION_DASH
ARG PYTHON_VERSION
ARG TORCH_VERSION
ARG TORCHVISION_VERSION
ARG TORCH_INDEX

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV PIP_BREAK_SYSTEM_PACKAGES=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PIP_EXTRA_INDEX_URL=${TORCH_INDEX} \
    PIP_CONSTRAINT=/opt/constraints.txt \
    PYTHONUNBUFFERED=1 \
    TZ=Etc/UTC \
    HF_HOME=/workspace/.cache/huggingface \
    PATH=/usr/local/cuda/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64

COPY --chmod=755 build/base.sh /base.sh
RUN /base.sh && rm /base.sh

# ---------------------------------------------------------------------------
# forge: Forge Neo in /sd-webui-forge-neo, venv in /venv
# ---------------------------------------------------------------------------
FROM base AS forge

ARG FORGE_COMMIT

COPY --chmod=755 build/install_forge.sh /install_forge.sh
RUN /install_forge.sh && rm /install_forge.sh
COPY forge/webui.settings.sh /sd-webui-forge-neo/webui.settings.sh

# ---------------------------------------------------------------------------
# comfyui: ComfyUI and ComfyUI-Manager in /ComfyUI, venv in /ComfyUI/venv
# ---------------------------------------------------------------------------
FROM forge AS comfyui

ARG COMFYUI_VERSION

COPY --chmod=755 build/install_comfyui.sh /install_comfyui.sh
RUN /install_comfyui.sh && rm /install_comfyui.sh

# ---------------------------------------------------------------------------
# final: nginx, runtime scripts and the entry point
# ---------------------------------------------------------------------------
FROM comfyui AS final

ARG RELEASE
ENV TEMPLATE_VERSION=${RELEASE}

COPY nginx/nginx.conf nginx/proxy.conf /etc/nginx/
COPY nginx/502.html /usr/share/nginx/html/502.html
COPY --chmod=755 scripts/ /
RUN mv /restart.sh /usr/local/bin/restart && \
    rm -f /etc/ssh/ssh_host_*

CMD ["/start.sh"]
