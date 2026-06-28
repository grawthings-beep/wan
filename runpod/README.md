# RunPod Usage

This repo is intended to bootstrap a RunPod GPU pod for ComfyUI generation with the bundled Wan 2.2 I2V workflow.

## Pod Setup

Use a RunPod GPU pod image that has CUDA, Python 3.10+, `git`, and `ffmpeg`. A RunPod PyTorch template is usually the fastest starting point.

Expose ComfyUI port `8188`.

## Start ComfyUI

From the RunPod terminal:

```bash
cd /workspace
git clone https://github.com/grawthings-beep/wan.git
cd wan
MODEL_PROFILE=gguf DOWNLOAD_MODELS=1 bash runpod/start.sh
```

Then open the RunPod HTTP service for port `8188`.

## Important Environment Variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `COMFYUI_DIR` | `/workspace/ComfyUI` | Where ComfyUI is cloned/updated. |
| `MODEL_PROFILE` | `gguf` | Model manifest profile: `gguf`, `fp8`, `mmaudio`, `optional`, or `all`. |
| `DOWNLOAD_MODELS` | `0` | Set to `1` to download direct Hugging Face model URLs. |
| `INSTALL_CUSTOM_NODES` | `1` | Set to `0` to skip custom node install/update. |
| `INSTALL_QWENVL_GGUF_DEPS` | `0` | Set to `1` to install the QwenVL GGUF `llama-cpp-python` fork. |
| `COMFYUI_ARGS` | empty | Extra args passed to `main.py`. |

## Civitai Models

The default Wan diffusion models in this workflow point to Civitai pages. Those usually need manual download or auth handling, so the bootstrap script does not fetch them automatically.

For the default GGUF path, place these files under `/workspace/ComfyUI/models/unet` unless your installed `ComfyUI-GGUF` version documents a different folder:

- `wan22EnhancedNSFWSVICamera_nsfwV2Q8High.gguf`
- `wan22EnhancedNSFWSVICamera_nsfwV2Q8Low.gguf`

For the default FP8 path, place these under `/workspace/ComfyUI/models/diffusion_models`:

- `wan22EnhancedNSFWSVICamera_nsfwV2FP8H.safetensors`
- `wan22EnhancedNSFWSVICamera_nsfwV2FP8L.safetensors`

## MMAudio

To include the MMAudio direct-download files:

```bash
MODEL_PROFILE=mmaudio DOWNLOAD_MODELS=1 bash runpod/start.sh
```

You can also download all direct Hugging Face files:

```bash
MODEL_PROFILE=all DOWNLOAD_MODELS=1 bash runpod/start.sh
```

## Workflow Location

The startup script copies:

```text
workflows/WAN2.2-I2V-AutoPrompt-Story.json
```

to:

```text
/workspace/ComfyUI/user/default/workflows/WAN2.2-I2V-AutoPrompt-Story.json
```

If ComfyUI does not show it automatically, load the JSON manually from the repo checkout.
