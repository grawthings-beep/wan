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

## Environment Variables

| Name | Value |
| --- | --- |
| `MODEL_PROFILE` | `gguf` |
| `DOWNLOAD_MODELS` | `1` |
| `INSTALL_CUSTOM_NODES` | `0` |
| `USE_BAKED_CUSTOM_NODES` | `1` |
| `INSTALL_SYSTEM_DEPS` | `0` |
| `INSTALL_QWENVL_GGUF_DEPS` | `0` |
| `START_RUNPOD_SERVICES` | `0` |
| `WORKSPACE_DIR` | `/workspace/comfyui` |
| `MODEL_ROOT` | `/workspace/comfyui` |
| `LISTEN` | `0.0.0.0` |
| `PORT` | `8188` |
| `COMFYUI_ARGS` | `--reserve-vram 3` |

Keep `INSTALL_QWENVL_GGUF_DEPS=0` for the default template. Turn it on only if you specifically need the QwenVL GGUF path and are ready for a slower first boot because it builds a custom `llama-cpp-python`.

Keep `INSTALL_CUSTOM_NODES=0` for speed. The image already bakes the custom nodes into `/opt/wan/custom_nodes`; startup copies them into the detected ComfyUI directory.

## Model Storage

The template can download direct Hugging Face URLs from `manifests/models.json`, but the default Wan diffusion models point to Civitai pages and still need manual placement.

For GGUF, place these in:

```text
/workspace/comfyui/models/unet
```

- `wan22EnhancedNSFWSVICamera_nsfwV2Q8High.gguf`
- `wan22EnhancedNSFWSVICamera_nsfwV2Q8Low.gguf`

For FP8, place these in:

```text
/workspace/comfyui/models/diffusion_models
```

- `wan22EnhancedNSFWSVICamera_nsfwV2FP8H.safetensors`
- `wan22EnhancedNSFWSVICamera_nsfwV2FP8L.safetensors`

Use a network volume if you do not want to redownload models for every pod.

## GPU Guidance

Start with 24 GB VRAM as a practical floor for testing. For long Wan 2.2 I2V runs, 48 GB or larger is much more comfortable, especially with upscaling, interpolation, MMAudio, or Qwen autoprompt enabled.
