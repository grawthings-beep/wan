# Dependencies

This document is generated from the workflow metadata and embedded notes. Install custom nodes through ComfyUI-Manager where possible; the GitHub URLs are included for manual installs.

## Custom Nodes

Run manual installs from `ComfyUI/custom_nodes`.

| Purpose | Repo | Node types seen in workflow |
| --- | --- | --- |
| GGUF loaders | `https://github.com/city96/ComfyUI-GGUF.git` | `CLIPLoaderGGUF`, `UnetLoaderGGUF` |
| rgthree utilities | `https://github.com/rgthree/rgthree-comfy.git` | `Power Lora Loader (rgthree)`, `Fast Groups Bypasser (rgthree)`, `Seed (rgthree)` |
| Video combine/select | `https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git` | `VHS_VideoCombine`, `VHS_SelectImages` |
| KJ nodes | `https://github.com/kijai/ComfyUI-KJNodes.git` | `ColorMatch`, `ImageBatchMulti`, `PathchSageAttentionKJ`, constants |
| Easy Use preview nodes | `https://github.com/yolain/ComfyUI-Easy-Use.git` | `easy showAnything` |
| mxToolkit sliders | `https://github.com/Smirnov75/ComfyUI-mxToolkit.git` | `mxSlider` |
| Upscaler TensorRT | `https://github.com/yuvraj108c/ComfyUI-Upscaler-Tensorrt.git` | `LoadUpscalerTensorrtModel`, `UpscalerTensorrt` |
| ComfyUI selectors | `https://github.com/ComfyAssets/ComfyUI_Selectors.git` | `SamplerSelector`, `SchedulerSelector` |
| VFI / RIFE | `https://github.com/GACLove/ComfyUI-VFI.git` | `RIFEInterpolation` |
| Find perfect resolution | `https://github.com/ashtar1984/comfyui-find-perfect-resolution.git` | `FindPerfectResolution` |
| QwenVL autoprompt nodes | `https://github.com/huchukato/ComfyUI-QwenVL-Mod.git` | `AILab_QwenVL_Advanced`, `AILab_QwenVL_GGUF_Advanced`, `StorySplitNode`, `VRAMCleanup` |
| RIFE TensorRT auto | `https://github.com/huchukato/ComfyUI-RIFE-TensorRT-Auto.git` | `AutoLoadRifeTensorrtModel`, `AutoRifeTensorrt` |
| MMAudio | `https://github.com/kijai/ComfyUI-MMAudio.git` | `MMAudioModelLoader`, `MMAudioFeatureUtilsLoader`, `MMAudioSampler` |
| WAS Node Suite | `https://github.com/ltdrdata/was-node-suite-comfyui.git` | `Text Concatenate` |
| Painter I2V | `https://github.com/princepainter/ComfyUI-PainterI2V.git` | `PainterI2V` |
| Painter Long Video | `https://github.com/princepainter/ComfyUI-PainterLongVideo.git` | `PainterLongVideo` |
| WanMoe sampler | `https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git` | `WanMoeKSamplerAdvanced` |

Example:

```powershell
cd C:\path\to\ComfyUI\custom_nodes
git clone https://github.com/city96/ComfyUI-GGUF.git
git clone https://github.com/huchukato/ComfyUI-QwenVL-Mod.git
git clone https://github.com/kijai/ComfyUI-MMAudio.git
```

After installing custom nodes, restart ComfyUI and install any Python requirements requested by each node repository.

## Qwen3-VL GGUF Extra

The embedded workflow note says the Qwen3-VL GGUF mode needs a modified `llama-cpp-python` build.

```powershell
cd C:\path\to\ComfyUI
.\venv\Scripts\Activate.ps1
pip install --upgrade --force-reinstall --no-cache-dir "llama-cpp-python @ git+https://github.com/JamePeng/llama-cpp-python.git"
```

If this build fails, check the QwenVL-Mod repository for the current Windows/CUDA build instructions.

## Model Placement

Use `manifests/models.json` as the source of truth. Common target folders:

The bundled RunPod workflow disables the TensorRT upscaler path by default. Some CUDA/driver/TensorRT combinations fail while building the upscaler engine with `CUDA initialization failure with error: 35`; the active path uses ComfyUI's core `UpscaleModelLoader` and `ImageUpscaleWithModel` nodes with `2xLexicaRRDBNet.pth` instead.

| Model type | Target folder under ComfyUI |
| --- | --- |
| Core FP8 diffusion models | `models/diffusion_models` |
| GGUF diffusion models | `models/unet` or the folder expected by `ComfyUI-GGUF` |
| Text encoders | `models/text_encoders` |
| VAE | `models/vae` |
| LoRAs | `models/loras` |
| Upscale models | `models/upscale_models` |
| QwenVL GGUF files | `models/LLM/GGUF` |
| QwenVL HF snapshots | `models/LLM/Qwen-VL` |
| MMAudio files | `models/mmaudio` |
| VFI/RIFE files | folder expected by `ComfyUI-VFI` |

If a loader dropdown cannot see a file, refresh ComfyUI and check the custom node's documented model folder. Some custom nodes changed folders between versions.

## Workflow Groups

- `QWEN3-VL AUTOPROMPT` - builds timeline prompts from the input image.
- `GGUFF` / `FP8` - model loading paths. The group title has the original spelling.
- `VIDEO2 10SEC`, `VIDEO3 15SEC`, `VIDEO4 20SEC` - long-video continuation sections.
- `30FPS`, `60FPS`, `MMAUDIO`, `MMAUDIO 24FPS`, `MMAUDIO 50FPS` - output and interpolation variants.
- `UPSCALE`, `UPSCALE TENSORRT`, `COLOR MATCH` - post-processing groups.
- `LIGHTX2V LORAS` - optional LoRA hooks. LoRA files are listed in `manifests/models.json`, not bundled in git.

## Useful Defaults

| Setting | Default / recommendation |
| --- | --- |
| Qwen timeline `max_tokens` for 20s | 2048 or higher |
| Qwen timeline context | 16384 or higher |
| Qwen 5s prompt `max_tokens` | 1024 or higher |
| Motion amplitude | 1.15 recommended |
| Motion frames | 5 |
| Color match strength | Start near 0.01 to 0.05; increase only for strong drift |
