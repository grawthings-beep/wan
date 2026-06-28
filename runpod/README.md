# RunPod Usage

This repo is intended to bootstrap a RunPod GPU pod for ComfyUI generation with the bundled Wan 2.2 I2V workflow.

For reusable RunPod template fields, use `runpod/template.md`.

## Pod Setup

Use the GHCR image built from this repo:

```text
ghcr.io/grawthings-beep/wan:cuda12.8
```

This avoids reinstalling ComfyUI custom nodes on every Pod start.

If RunPod cannot pull the image, make the GHCR package public at:

```text
https://github.com/grawthings-beep/wan/pkgs/container/wan
```

or configure RunPod registry authentication for `ghcr.io` with a GitHub token that has `read:packages`.

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
| `WORKSPACE_DIR` | `/workspace/comfyui` | Persistent input/output root. |
| `MODEL_ROOT` | `/workspace/comfyui` | Persistent ComfyUI model root. |
| `MODEL_PROFILE` | `gguf` | Model manifest profile: `gguf`, `fp8`, `mmaudio`, `optional`, or `all`. |
| `DOWNLOAD_MODELS` | `0` | Set to `1` to download Hugging Face and Civitai model URLs. |
| `MODEL_DOWNLOAD_JOBS` | `4` | Number of model files to download in parallel. |
| `ARIA2_CONNECTIONS` | `16` | Connections per file when `aria2c` is available. |
| `ARIA2_SPLITS` | `16` | Splits per file when `aria2c` is available. |
| `INSTALL_CUSTOM_NODES` | `0` in the GHCR image | Set to `1` only when using a raw base image. |
| `USE_BAKED_CUSTOM_NODES` | `1` | Copy baked custom nodes from the image into ComfyUI at startup. |
| `INSTALL_QWENVL_GGUF_DEPS` | `0` | Set to `1` to install the QwenVL GGUF `llama-cpp-python` fork. |
| `CIVITAI_TOKEN` | unset | Required for the default Civitai Wan model downloads. Use a RunPod Secret. |
| `HF_TOKEN` | unset | Optional for Hugging Face gated/private files. Use a RunPod Secret. |
| `COMFYUI_ARGS` | empty | Extra args passed to `main.py`. |

## Civitai Models

The default Wan diffusion models in this workflow point to Civitai model versions. The startup script downloads them automatically through the Civitai API when `CIVITAI_TOKEN` is set.

For the default GGUF path, files are downloaded under `/workspace/comfyui/models/unet` unless your installed `ComfyUI-GGUF` version documents a different folder:

- `wan22EnhancedNSFWSVICamera_nsfwV2Q8High.gguf`
- `wan22EnhancedNSFWSVICamera_nsfwV2Q8Low.gguf`

For the default FP8 path, files are downloaded under `/workspace/comfyui/models/diffusion_models`:

- `wan22EnhancedNSFWSVICamera_nsfwV2FP8H.safetensors`
- `wan22EnhancedNSFWSVICamera_nsfwV2FP8L.safetensors`

## MMAudio

To include the MMAudio direct-download files:

```bash
MODEL_PROFILE=mmaudio DOWNLOAD_MODELS=1 bash runpod/start.sh
```

You can also download every manifest entry, including Civitai files when `CIVITAI_TOKEN` is set:

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
ComfyUI's user workflow folder inside the image.
```

If ComfyUI does not show it automatically, load the JSON manually from the repo checkout.
