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

echo "Repo: ${REPO_DIR}"
echo "ComfyUI: ${COMFYUI_DIR}"
echo "Model profile: ${MODEL_PROFILE}"

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
