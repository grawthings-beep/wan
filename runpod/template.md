# RunPod Template Settings

Create a Pod template in RunPod with the settings below.

## Basic

| Field | Value |
| --- | --- |
| Template name | `wan-comfyui` |
| Template type | Pod |
| Docker image | `ghcr.io/grawthings-beep/wan:cuda12.8` |
| Container disk | `40 GB` minimum, `80 GB` safer |
| Volume mount path | `/workspace` |
| Network volume | `200 GB` or larger if keeping models |

This GHCR image is built by GitHub Actions from this repository. It bakes ComfyUI startup glue, the workflow, and custom nodes into the image so a Pod does not reinstall everything on each start.

## Exposed Ports

| Type | Port |
| --- | --- |
| HTTP | `8188` |

ComfyUI starts on `0.0.0.0:8188`, so RunPod's HTTP service for port `8188` opens the UI.

## Docker Command / Start Command

Leave this blank.

The image already has:

```text
CMD ["/opt/wan/runpod/start.sh"]
```

If RunPod cannot pull the GHCR image, make the package public in GitHub Packages or add registry authentication.

Current practical choices:

1. Recommended: make the GHCR package public.
   - Open `https://github.com/grawthings-beep/wan/pkgs/container/wan`
   - Package settings
   - Change visibility
   - Public
2. Private image: use `Select registry authentication` in the RunPod template.
   - Registry: `ghcr.io`
   - Username: `grawthings-beep`
   - Password/token: a GitHub PAT with `read:packages`

Without one of those, RunPod will fail before the container starts because GHCR denies anonymous pulls.

## Environment Variables

| Name | Value |
| --- | --- |
| `MODEL_PROFILE` | `gguf` |
| `DOWNLOAD_MODELS` | `1` |
| `MODEL_DOWNLOAD_JOBS` | `4` |
| `ARIA2_CONNECTIONS` | `16` |
| `ARIA2_SPLITS` | `16` |
| `INSTALL_CUSTOM_NODES` | `0` |
| `USE_BAKED_CUSTOM_NODES` | `1` |
| `INSTALL_SYSTEM_DEPS` | `0` |
| `INSTALL_QWENVL_GGUF_DEPS` | `0` |
| `START_RUNPOD_SERVICES` | `0` |
| `UPGRADE_PIP` | `0` |
| `WORKSPACE_DIR` | `/workspace/comfyui` |
| `MODEL_ROOT` | `/workspace/comfyui` |
| `LISTEN` | `0.0.0.0` |
| `PORT` | `8188` |
| `COMFYUI_ARGS` | `--reserve-vram 3` |
| `CIVITAI_TOKEN` | `{{ RUNPOD_SECRET_CIVITAI_TOKEN }}` |
| `HF_TOKEN` | `{{ RUNPOD_SECRET_HF_TOKEN }}` |

Keep `INSTALL_QWENVL_GGUF_DEPS=0` for the default template. Turn it on only if you specifically need the QwenVL GGUF path and are ready for a slower first boot because it builds a custom `llama-cpp-python`.

Keep `INSTALL_CUSTOM_NODES=0` for speed. The image already bakes the custom nodes into `/opt/wan/custom_nodes`; startup copies them into the detected ComfyUI directory.

## Model Storage

The template downloads direct Hugging Face URLs and Civitai model-version URLs from `manifests/models.json`.

Set `CIVITAI_TOKEN` through a RunPod Secret. Without it, the default GGUF/FP8 Wan diffusion downloads will fail early instead of saving an HTML login/error page as a model file.

Set `HF_TOKEN` through a RunPod Secret too. The added `uwgm/nikke-loras` LoRA URLs reject anonymous requests, so the default `gguf`/`fp8` profiles need `HF_TOKEN`.

Downloads use `aria2c` when available:

- `MODEL_DOWNLOAD_JOBS=4` downloads several files at once.
- `ARIA2_CONNECTIONS=16` and `ARIA2_SPLITS=16` split each large file.

For GGUF, downloads are written to:

```text
/workspace/comfyui/models/unet
```

- `wan22EnhancedNSFWSVICamera_nsfwV2Q8High.gguf`
- `wan22EnhancedNSFWSVICamera_nsfwV2Q8Low.gguf`

For FP8, downloads are written to:

```text
/workspace/comfyui/models/diffusion_models
```

- `wan22EnhancedNSFWSVICamera_nsfwV2FP8H.safetensors`
- `wan22EnhancedNSFWSVICamera_nsfwV2FP8L.safetensors`

The added LoRAs are written to:

```text
/workspace/comfyui/models/loras
```

- `NSFW-22-H-e8 (1).safetensors`
- `NSFW-22-L-e8 (1).safetensors`

QwenVL GGUF files for `MODEL_PROFILE=qwen` are written under:

```text
/workspace/comfyui/models/LLM/GGUF
```

The startup script now downloads those files automatically when the matching profile is selected. Use a network volume so completed downloads are reused by future pods.

## GPU Guidance

Start with 24 GB VRAM as a practical floor for testing. For long Wan 2.2 I2V runs, 48 GB or larger is much more comfortable, especially with upscaling, interpolation, MMAudio, or Qwen autoprompt enabled.
