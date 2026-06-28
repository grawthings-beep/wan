#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
COMFYUI_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
MODEL_PROFILE="${MODEL_PROFILE:-gguf}"
COMFYUI_HOST="${COMFYUI_HOST:-0.0.0.0}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
INSTALL_CUSTOM_NODES="${INSTALL_CUSTOM_NODES:-1}"
DOWNLOAD_MODELS="${DOWNLOAD_MODELS:-0}"
INSTALL_QWENVL_GGUF_DEPS="${INSTALL_QWENVL_GGUF_DEPS:-0}"
INSTALL_SYSTEM_DEPS="${INSTALL_SYSTEM_DEPS:-1}"
START_RUNPOD_SERVICES="${START_RUNPOD_SERVICES:-0}"

echo "Repo: ${REPO_DIR}"
echo "ComfyUI: ${COMFYUI_DIR}"
echo "Model profile: ${MODEL_PROFILE}"

if [ "${START_RUNPOD_SERVICES}" = "1" ] && [ -x /start.sh ]; then
  echo "Starting base RunPod services from /start.sh"
  /start.sh &
fi

if [ "${INSTALL_SYSTEM_DEPS}" != "0" ] && command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates git ffmpeg libgl1 libglib2.0-0
  rm -rf /var/lib/apt/lists/*
fi

if [ ! -d "${COMFYUI_DIR}/.git" ]; then
  git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
else
  git -C "${COMFYUI_DIR}" pull --ff-only || true
fi

"${PYTHON_BIN}" -m pip install --upgrade pip
"${PYTHON_BIN}" -m pip install -r "${COMFYUI_DIR}/requirements.txt"

if [ "${INSTALL_CUSTOM_NODES}" != "0" ]; then
  "${PYTHON_BIN}" "${REPO_DIR}/scripts/install_custom_nodes.py" --comfyui-path "${COMFYUI_DIR}"
fi

if [ "${INSTALL_QWENVL_GGUF_DEPS}" = "1" ]; then
  "${PYTHON_BIN}" -m pip install --upgrade --force-reinstall --no-cache-dir \
    "llama-cpp-python @ git+https://github.com/JamePeng/llama-cpp-python.git"
fi

mkdir -p "${COMFYUI_DIR}/user/default/workflows"
cp "${REPO_DIR}/workflows/WAN2.2-I2V-AutoPrompt-Story.json" \
  "${COMFYUI_DIR}/user/default/workflows/WAN2.2-I2V-AutoPrompt-Story.json"

if [ "${DOWNLOAD_MODELS}" != "0" ]; then
  "${PYTHON_BIN}" "${REPO_DIR}/scripts/download_hf_models.py" \
    --comfyui-path "${COMFYUI_DIR}" \
    --profile "${MODEL_PROFILE}"
fi

echo "Starting ComfyUI on ${COMFYUI_HOST}:${COMFYUI_PORT}"
# shellcheck disable=SC2086
exec "${PYTHON_BIN}" "${COMFYUI_DIR}/main.py" --listen "${COMFYUI_HOST}" --port "${COMFYUI_PORT}" ${COMFYUI_ARGS:-}
