#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
MODEL_PROFILE="${MODEL_PROFILE:-gguf}"
COMFYUI_HOST="${COMFYUI_HOST:-${LISTEN:-0.0.0.0}}"
COMFYUI_PORT="${COMFYUI_PORT:-${PORT:-8188}}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace/comfyui}"
MODEL_ROOT="${MODEL_ROOT:-${WORKSPACE_DIR}}"
COMFYUI_WORKFLOW_DIR="${COMFYUI_WORKFLOW_DIR:-}"
INSTALL_CUSTOM_NODES="${INSTALL_CUSTOM_NODES:-1}"
DOWNLOAD_MODELS="${DOWNLOAD_MODELS:-0}"
INSTALL_QWENVL_GGUF_DEPS="${INSTALL_QWENVL_GGUF_DEPS:-0}"
INSTALL_SYSTEM_DEPS="${INSTALL_SYSTEM_DEPS:-1}"
START_RUNPOD_SERVICES="${START_RUNPOD_SERVICES:-0}"

echo "Repo: ${REPO_DIR}"
echo "Workspace: ${WORKSPACE_DIR}"
echo "Model root: ${MODEL_ROOT}"
echo "Model profile: ${MODEL_PROFILE}"

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python || command -v python3 || true)"
fi

if [ -z "${PYTHON_BIN}" ]; then
  echo "ERROR: neither python nor python3 was found in PATH." >&2
  exit 2
fi

find_comfyui_dir() {
  if [ -n "${COMFYUI_DIR:-}" ] && [ -f "${COMFYUI_DIR}/main.py" ]; then
    printf '%s\n' "${COMFYUI_DIR}"
    return 0
  fi

  for candidate in \
    /opt/ComfyUI \
    /workspace/ComfyUI \
    /workspace/comfyui \
    /comfyui \
    /ComfyUI \
    /app/ComfyUI; do
    if [ -f "${candidate}/main.py" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

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

if COMFYUI_DIR="$(find_comfyui_dir)"; then
  echo "ComfyUI: ${COMFYUI_DIR}"
elif [ -n "${COMFYUI_DIR:-}" ]; then
  echo "Installing ComfyUI into ${COMFYUI_DIR}"
  git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
else
  COMFYUI_DIR="/workspace/ComfyUI"
  echo "Installing ComfyUI into ${COMFYUI_DIR}"
  git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
fi

if [ -d "${COMFYUI_DIR}/.git" ] && [ "${UPDATE_COMFYUI:-0}" = "1" ]; then
  git -C "${COMFYUI_DIR}" pull --ff-only || true
fi

"${PYTHON_BIN}" -m pip install --upgrade pip
if [ "${INSTALL_COMFYUI_REQUIREMENTS:-0}" = "1" ] && [ -f "${COMFYUI_DIR}/requirements.txt" ]; then
  "${PYTHON_BIN}" -m pip install -r "${COMFYUI_DIR}/requirements.txt"
fi

if [ "${INSTALL_CUSTOM_NODES}" != "0" ]; then
  "${PYTHON_BIN}" "${REPO_DIR}/scripts/install_custom_nodes.py" --comfyui-path "${COMFYUI_DIR}"
fi

if [ "${INSTALL_QWENVL_GGUF_DEPS}" = "1" ]; then
  "${PYTHON_BIN}" -m pip install --upgrade --force-reinstall --no-cache-dir \
    "llama-cpp-python @ git+https://github.com/JamePeng/llama-cpp-python.git"
fi

mkdir -p "${WORKSPACE_DIR}/input" \
         "${WORKSPACE_DIR}/output" \
         "${MODEL_ROOT}/models/checkpoints" \
         "${MODEL_ROOT}/models/clip" \
         "${MODEL_ROOT}/models/clip_vision" \
         "${MODEL_ROOT}/models/configs" \
         "${MODEL_ROOT}/models/controlnet" \
         "${MODEL_ROOT}/models/diffusion_models" \
         "${MODEL_ROOT}/models/embeddings" \
         "${MODEL_ROOT}/models/loras" \
         "${MODEL_ROOT}/models/mmaudio" \
         "${MODEL_ROOT}/models/text_encoders" \
         "${MODEL_ROOT}/models/unet" \
         "${MODEL_ROOT}/models/upscale_models" \
         "${MODEL_ROOT}/models/vae"

cat > "${COMFYUI_DIR}/extra_model_paths.yaml" <<YAML
workspace:
  base_path: ${MODEL_ROOT}
  checkpoints: models/checkpoints/
  clip: models/clip/
  clip_vision: models/clip_vision/
  configs: models/configs/
  controlnet: models/controlnet/
  diffusion_models: models/diffusion_models/
  embeddings: models/embeddings/
  loras: models/loras/
  text_encoders: models/text_encoders/
  unet: models/unet/
  upscale_models: models/upscale_models/
  vae: models/vae/
YAML

COMFYUI_WORKFLOW_DIR="${COMFYUI_WORKFLOW_DIR:-${COMFYUI_DIR}/user/default/workflows}"
mkdir -p "${COMFYUI_WORKFLOW_DIR}"
cp "${REPO_DIR}/workflows/WAN2.2-I2V-AutoPrompt-Story.json" \
  "${COMFYUI_WORKFLOW_DIR}/WAN2.2-I2V-AutoPrompt-Story.json"

if [ "${DOWNLOAD_MODELS}" != "0" ]; then
  "${PYTHON_BIN}" "${REPO_DIR}/scripts/download_hf_models.py" \
    --root "${MODEL_ROOT}" \
    --profile "${MODEL_PROFILE}"
fi

echo "Starting ComfyUI on ${COMFYUI_HOST}:${COMFYUI_PORT}"
# shellcheck disable=SC2086
exec "${PYTHON_BIN}" "${COMFYUI_DIR}/main.py" \
  --listen "${COMFYUI_HOST}" \
  --port "${COMFYUI_PORT}" \
  --input-directory "${WORKSPACE_DIR}/input" \
  --output-directory "${WORKSPACE_DIR}/output" \
  ${COMFYUI_ARGS:-}
