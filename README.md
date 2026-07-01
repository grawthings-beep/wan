# WAN 2.2 I2V AutoPrompt Story Workflow

Wan 2.2 image-to-video story workflow for ComfyUI, with FP8/GGUF model paths, Qwen3-VL autoprompt subgraphs, optional MMAudio, upscaling, color matching, and RIFE interpolation.

This repo is set up for launching ComfyUI on RunPod and generating with the bundled workflow. GitHub Actions builds a reusable GHCR image so Pod startup does not reinstall ComfyUI custom nodes every time.

## Content Notice

The original workflow and default model names are intended for adult/NSFW use. Use it only for lawful content involving consenting adults, and follow the licenses and terms for ComfyUI, the custom nodes, and all model providers.

## Repository Layout

- `workflows/WAN2.2-I2V-AutoPrompt-Story.json` - original ComfyUI workflow JSON from the ZIP.
- `docs/dependencies.md` - custom node list, model placement, and workflow notes.
- `manifests/custom_nodes.json` - machine-readable custom node manifest.
- `manifests/models.json` - model filename, target folder, and source URL manifest.
- `runpod/start.sh` - RunPod bootstrap script for ComfyUI, custom nodes, workflow placement, and launch.
- `runpod/README.md` - RunPod usage guide.
- `runpod/template.md` - exact RunPod Pod Template settings.
- `runpod/template.json` - machine-readable copy of the template settings.
- `runpod/template.env.example` - environment variables for the template.
- `Dockerfile` - builds the RunPod/ComfyUI image published to GHCR.
- `scripts/install_custom_nodes.py` - installs custom nodes from the manifest.
- `scripts/audit_workflow_manifest.py` - checks that workflow model and custom-node references are covered by the manifests.
- `scripts/download_hf_models.py` - fast cross-platform downloader for Hugging Face and Civitai model URLs.
- `scripts/download-hf-models.ps1` - optional Windows helper for manifest model downloads.

## RunPod Quick Start

Use this image in the RunPod Template:

```text
ghcr.io/grawthings-beep/wan:cuda12.8
```

Leave the Template start command blank and expose HTTP port `8188`.

Keep `COMFYUI_CORS_HEADER=*` in the template. This prevents ComfyUI from rejecting RunPod proxy browser requests with HTTP 403 when the proxied host and browser origin differ.

If RunPod cannot pull the image, make the GHCR package public or configure RunPod registry authentication for `ghcr.io`.

Set these RunPod secrets/environment variables for model downloads:

```text
CIVITAI_TOKEN={{ RUNPOD_SECRET_CIVITAI_TOKEN }}
HF_TOKEN={{ RUNPOD_SECRET_HF_TOKEN }}
MODEL_DOWNLOAD_JOBS=4
ARIA2_CONNECTIONS=16
ARIA2_SPLITS=16
```

The default Civitai Wan GGUF/FP8 model files are downloaded automatically when `CIVITAI_TOKEN` is configured.
The added `NSFW-22-H-e8 (1).safetensors` and `NSFW-22-L-e8 (1).safetensors` LoRAs require `HF_TOKEN` because their Hugging Face URLs reject anonymous requests.

The image is built by `.github/workflows/build-ghcr.yml` and pushed as:

```text
ghcr.io/grawthings-beep/wan:cuda12.8
ghcr.io/grawthings-beep/wan:latest
```

Manual fallback from a generic GPU pod terminal:

```bash
cd /workspace
git clone https://github.com/grawthings-beep/wan.git
cd wan
MODEL_PROFILE=gguf DOWNLOAD_MODELS=1 bash runpod/start.sh
```

Open the RunPod HTTP service for port `8188`.

The script clones/updates ComfyUI in `/workspace/ComfyUI`, installs custom nodes from `manifests/custom_nodes.json`, copies the workflow into ComfyUI's user workflow folder, optionally downloads Hugging Face and Civitai model URLs, and starts ComfyUI on `0.0.0.0:8188`.

See `runpod/README.md` for model placement and environment variables.
Use `runpod/template.md` when creating the RunPod Pod Template.

## Local ComfyUI Quick Start

1. Install ComfyUI and the custom nodes listed in `docs/dependencies.md`.
2. Download the model files listed in `manifests/models.json`.
3. Put the files in the target folders shown in the manifest.
4. Open ComfyUI and load `workflows/WAN2.2-I2V-AutoPrompt-Story.json`.
5. Select the FP8 or GGUF path in the `FP8 / GGUF` group, then choose the target duration group.

For local/manual model download, use the Python downloader:

```bash
CIVITAI_TOKEN=... python scripts/download_hf_models.py --comfyui-path /workspace/ComfyUI --profile gguf
```

It downloads several files in parallel and uses `aria2c` when available. The PowerShell helper is kept as a Windows convenience:

```powershell
pwsh .\scripts\download-hf-models.ps1 -ComfyUIPath "C:\path\to\ComfyUI" -Profile gguf
```

The default Civitai diffusion models require `CIVITAI_TOKEN`, and the added Hugging Face LoRAs require `HF_TOKEN`; without the needed token, the downloader exits early instead of saving an HTML login/error page as a model file.

## Workflow Defaults

- Default GGUF text encoder: `umt5-xxl-encoder-Q8_0.gguf`
- Default FP8 text encoder: `nsfw_wan_umt5-xxl_fp8_scaled.safetensors`
- Default VAE: `wan_2.1_vae.safetensors`
- Default upscaler: `2xLexicaRRDBNet.pth`
- Qwen3-VL 20s timeline setting: `max_tokens` 2048 or higher, context length 16384 or higher.

## Publishing

Before pushing this to GitHub, decide on a license. If you are not the original author of the workflow, keep `NOTICE.md` and link back to upstream authors/model pages rather than redistributing model files.
