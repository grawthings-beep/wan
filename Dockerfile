# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=runpod/comfyui:latest
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    INSTALL_SYSTEM_DEPS=0 \
    INSTALL_CUSTOM_NODES=0 \
    DOWNLOAD_MODELS=1 \
    MODEL_PROFILE=gguf \
    WORKSPACE_DIR=/workspace/comfyui \
    MODEL_ROOT=/workspace/comfyui \
    LISTEN=0.0.0.0 \
    PORT=8188 \
    COMFYUI_CORS_HEADER=*

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        aria2 \
        ca-certificates \
        curl \
        ffmpeg \
        git \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY manifests/ /opt/wan/manifests/
COPY scripts/ /opt/wan/scripts/
COPY runpod/ /opt/wan/runpod/
COPY workflows/ /opt/wan/workflows/

RUN chmod +x /opt/wan/runpod/start.sh \
    && python_bin="$(command -v python || command -v python3)" \
    && "${python_bin}" /opt/wan/scripts/install_custom_nodes.py \
       --custom-nodes-dir /opt/wan/custom_nodes

EXPOSE 8188

ENTRYPOINT []
CMD ["/opt/wan/runpod/start.sh"]
