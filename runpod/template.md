# RunPod Template Settings

Create a Pod template in RunPod with the settings below.

## Basic

| Field | Value |
| --- | --- |
| Template name | `wan-comfyui` |
| Template type | Pod |
| Docker image | `runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04` |
| Container disk | `80 GB` minimum, `120 GB` safer |
| Volume mount path | `/workspace` |
| Network volume | `200 GB` or larger if keeping models |

The image is intentionally pinned to Python 3.11, CUDA 12.8.1, and PyTorch 2.8.0 because ComfyUI and video/custom-node dependencies are more predictable on Python 3.11 than on newer Python runtimes.

## Exposed Ports

| Type | Port |
| --- | --- |
| HTTP | `8188` |

ComfyUI starts on `0.0.0.0:8188`, so RunPod's HTTP service for port `8188` opens the UI.

## Docker Command

Use this as the template start command:

```bash
bash -lc 'command -v git >/dev/null 2>&1 || (apt-get update && apt-get install -y --no-install-recommends ca-certificates git && rm -rf /var/lib/apt/lists/*); cd /workspace && if [ ! -d wan ]; then git clone https://github.com/grawthings-beep/wan.git wan; else git -C wan pull --ff-only; fi && cd wan && bash runpod/start.sh'
```

This command keeps the template generic: every pod pulls the latest `main` from this repo, then starts ComfyUI through `runpod/start.sh`.

## Environment Variables

| Name | Value |
| --- | --- |
| `MODEL_PROFILE` | `gguf` |
| `DOWNLOAD_MODELS` | `1` |
| `INSTALL_CUSTOM_NODES` | `1` |
| `INSTALL_SYSTEM_DEPS` | `1` |
| `INSTALL_QWENVL_GGUF_DEPS` | `0` |
| `START_RUNPOD_SERVICES` | `1` |
| `COMFYUI_DIR` | `/workspace/ComfyUI` |
| `COMFYUI_HOST` | `0.0.0.0` |
| `COMFYUI_PORT` | `8188` |

Keep `INSTALL_QWENVL_GGUF_DEPS=0` for the default template. Turn it on only if you specifically need the QwenVL GGUF path and are ready for a slower first boot because it builds a custom `llama-cpp-python`.

## Model Storage

The template can download direct Hugging Face URLs from `manifests/models.json`, but the default Wan diffusion models point to Civitai pages and still need manual placement.

For GGUF, place these in:

```text
/workspace/ComfyUI/models/unet
```

- `wan22EnhancedNSFWSVICamera_nsfwV2Q8High.gguf`
- `wan22EnhancedNSFWSVICamera_nsfwV2Q8Low.gguf`

For FP8, place these in:

```text
/workspace/ComfyUI/models/diffusion_models
```

- `wan22EnhancedNSFWSVICamera_nsfwV2FP8H.safetensors`
- `wan22EnhancedNSFWSVICamera_nsfwV2FP8L.safetensors`

Use a network volume if you do not want to redownload models for every pod.

## GPU Guidance

Start with 24 GB VRAM as a practical floor for testing. For long Wan 2.2 I2V runs, 48 GB or larger is much more comfortable, especially with upscaling, interpolation, MMAudio, or Qwen autoprompt enabled.
