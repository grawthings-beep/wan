# WAN 2.2 I2V AutoPrompt Story Workflow

Wan 2.2 image-to-video story workflow for ComfyUI, with FP8/GGUF model paths, Qwen3-VL autoprompt subgraphs, optional MMAudio, upscaling, color matching, and RIFE interpolation.

This repo keeps the workflow lightweight: model weights, generated videos, and local ComfyUI outputs are intentionally not included.

## Content Notice

The original workflow and default model names are intended for adult/NSFW use. Use it only for lawful content involving consenting adults, and follow the licenses and terms for ComfyUI, the custom nodes, and all model providers.

## Repository Layout

- `workflows/WAN2.2-I2V-AutoPrompt-Story.json` - original ComfyUI workflow JSON from the ZIP.
- `docs/dependencies.md` - custom node list, model placement, and workflow notes.
- `manifests/custom_nodes.json` - machine-readable custom node manifest.
- `manifests/models.json` - model filename, target folder, and source URL manifest.
- `scripts/download-hf-models.ps1` - optional helper for Hugging Face direct-download files.

## Quick Start

1. Install ComfyUI and the custom nodes listed in `docs/dependencies.md`.
2. Download the model files listed in `manifests/models.json`.
3. Put the files in the target folders shown in the manifest.
4. Open ComfyUI and load `workflows/WAN2.2-I2V-AutoPrompt-Story.json`.
5. Select the FP8 or GGUF path in the `FP8 / GGUF` group, then choose the target duration group.

For the Hugging Face files that have direct URLs, you can use:

```powershell
pwsh .\scripts\download-hf-models.ps1 -ComfyUIPath "C:\path\to\ComfyUI" -Profile gguf
```

The Civitai diffusion models usually require manual download or account/auth handling, so the helper script lists them but does not download them.

## Workflow Defaults

- Default GGUF text encoder: `umt5-xxl-encoder-Q8_0.gguf`
- Default FP8 text encoder: `nsfw_wan_umt5-xxl_fp8_scaled.safetensors`
- Default VAE: `wan_2.1_vae.safetensors`
- Default upscaler: `2xLexicaRRDBNet.pth`
- Qwen3-VL 20s timeline setting: `max_tokens` 2048 or higher, context length 16384 or higher.

## Publishing

Before pushing this to GitHub, decide on a license. If you are not the original author of the workflow, keep `NOTICE.md` and link back to upstream authors/model pages rather than redistributing model files.
