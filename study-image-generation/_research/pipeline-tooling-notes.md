# Pipeline-Tooling — Raw Research Notes

Date: 2026-06-22. Target HW: M4 (likely M4 Pro), 48 GB unified memory, macOS.
User rule: for each image in a FOLDER, isolate character(s), composite onto solid BLACK background.
This is segmentation/matting + compositing, NOT diffusion. Section 02 owns method; Section 03 owns generative catalog. This file owns THE pipeline + one-command install.

## rembg (headline recommendation for the segmentation path)
- GitHub danielgatis/rembg. CLI + Python lib + HTTP server + Docker.
- Install: `pip install "rembg[cpu,cli]"` (CPU) / `[gpu,cli]` (CUDA only) / `[rocm,cli]`. No Apple-GPU extra — default uses onnxruntime CPU on Mac.
- Single image: `rembg i in.png out.png` ; omit out → `in.out.png`.
- Folder/batch: `rembg p input_dir output_dir` ; watch mode `rembg p -w input_dir output_dir`.
- Model flag: `rembg i -m birefnet-general in.png out.png`.
- Models: u2net, u2netp, u2net_human_seg, u2net_cloth_seg, silueta, isnet-general-use, **isnet-anime**, sam, **birefnet-general**, birefnet-general-lite, birefnet-portrait, birefnet-dis, birefnet-hrsod, birefnet-cod, birefnet-massive, bria-rmbg.
- Output: `-om` mask only, `-a` alpha matting (+ `-ae` erode etc). NO native "composite on solid color bg" flag → rembg returns RGBA cutout; we composite onto black ourselves with Pillow (`Image.new("RGBA",size,(0,0,0,255))` + `alpha_composite`).
- Models auto-download to `~/.u2net/` on first use.
- BiRefNet models slowest (~9-20s/img on CPU) but SOTA edges (hair, fine detail). isnet-anime best for anime/illustration characters (very relevant: wallpapers are often anime/game art).
- Apple Silicon accel: rembg ships onnxruntime CPU EP by default; no MPS. Community route = swap in `onnxruntime-silicon` (cansik) or `onnxruntime-coreml` wheels to get CoreML/ANE EP. Issue #556 = MPS feature request. CoreML EP needs macOS 10.15+. In practice CPU on M4 Pro is already only a few seconds/image for isnet; BiRefNet benefits most from accel.

## BiRefNet / RMBG-2.0 via transformers+PyTorch (MPS) — higher-quality alt path
- briaai/RMBG-2.0 on HF = BiRefNet architecture, outputs single-channel 8-bit alpha matte. `AutoModelForImageSegmentation.from_pretrained('briaai/RMBG-2.0', trust_remote_code=True)`. NOTE RMBG-2.0 license = non-commercial / Bria license — flag for the user.
- ZhengPeng7/BiRefNet original repo = Apache-ish, has many checkpoints (general, portrait, DIS, HRSOD, COD, matting). Use this to avoid RMBG license issues.
- Standard pipeline: resize 1024x1024, normalize ImageNet mean/std, `mask = model(x)[-1].sigmoid().cpu()`, resize to orig, `image.putalpha(mask)`.
- Model card example hardcodes `cuda`; on Mac swap to `mps` (`torch.device("mps")`). Works on MPS; trust_remote_code custom code is plain PyTorch ops → MPS-compatible. ~3.45 GB VRAM at 1024 on a 4090 → trivially fits 48 GB unified. 17 FPS on 4090; on M4 Pro expect ~1-4 s/img (MPS), CPU much slower.
- transformers MPS path benefits from `torch.set_float32_matmul_precision('high')` and fp16/bf16 cast where supported. MPS has occasional op gaps → set `PYTORCH_ENABLE_MPS_FALLBACK=1`.

## ComfyUI (generative + node-based batch) — optional variant
- comfy-cli (Comfy-Org/comfy-cli). Install: `pip install comfy-cli` then `comfy --skip-prompt install --m-series` (Apple Silicon MPS). Default install path `~/Documents/comfy/ComfyUI`.
- Every ComfyUI instance is a REST+WebSocket API server (JSON over HTTP). Headless: `comfy launch -- --listen` then POST workflow JSON to `/prompt`.
- Batch over folder: "Load Image Batch" node (custom packs, e.g. WAS Node Suite / ComfyUI-Batch-Process Zar4X) loads from a directory by index+pattern; queue N times. For segmentation use ComfyUI BiRefNet / RMBG nodes (ComfyUI_BiRefNet_ll RembgByBiRefNet) → then composite-on-color node.
- Heavyweight for a fixed rule; justified only if user also wants generative regen (FLUX/SDXL). Macs run ComfyUI on MPS but slower than CUDA.

## Draw Things — Mac-native generative, now has CLI
- draw-things-cli = reboot of gRPCServerCLI. Install `brew install drawthingsai/draw-things/draw-things-cli`. `draw-things-cli generate --model ... --prompt ...`. Auto model downloads, shell completion, terminal image output.
- JavaScript Scripting System (REPL + batch) for automation. gRPC server mode for offload.
- Best-in-class Mac generative UX; but it's a generative tool, not a folder-segmentation tool. Mention only for generative variant.

## mflux — FLUX on MLX (Apple-native generative) — Section 03 territory
- filipstrand/mflux. Install via uv: `uv tool install mflux` → `mflux-generate`, `mflux-save`, `mflux-info`. 3/4/6/8-bit quant. `--low-ram` flag. Native MLX = best Apple-Silicon generative speed/mem. Catalog in Section 03; not used for the segmentation rule.

## Other tools (brief)
- DiffusionBee: easy Mac GUI for SD; GUI-only, no folder-rule batch CLI → not suitable.
- InvokeAI: full app + API; heavy; generative; not a folder-segment one-liner.
- SD-WebUI / Forge on Mac: runs via MPS but fiddly; generative; not for this rule.
- ImageMagick: user already uses it (wallpapers_treatment.sh). Good for the final composite/format/rename step, but cannot segment by itself.

## Prereqs on macOS Apple Silicon
- Xcode Command Line Tools: `xcode-select --install`.
- Homebrew (user has it).
- Python: recommend `uv` (`brew install uv`) for isolated, fast tool installs; `uv tool install` / `uv venv`. Conda also fine. Python 3.11/3.12 sweet spot for onnxruntime + torch.
- For rembg path: a venv + `uv pip install "rembg[cpu,cli]" pillow`.
- For BiRefNet/MPS path: `uv pip install torch torchvision transformers pillow timm einops kornia` (timm/einops/kornia needed by BiRefNet custom code).

## Decision
- HEADLINE = rembg CLI + a tiny Pillow composite-on-black wrapper, model `isnet-anime` (anime/illustration wallpapers) or `birefnet-general` (photoreal/highest quality). One `uv tool` install + one script that loops the folder.
- POWER OPTION = BiRefNet via transformers on MPS for max edge quality on hair/fine detail, GPU-accelerated.
- GENERATIVE VARIANT = ComfyUI (BiRefNet node + composite) or mflux/Draw Things, only if creative regeneration wanted.

## Sources
- https://github.com/danielgatis/rembg
- https://pypi.org/project/rembg/
- https://huggingface.co/briaai/RMBG-2.0
- https://github.com/zhengpeng7/birefnet
- https://dev.to/om_prakash_3311f8a4576605/birefnet-vs-rembg-vs-u2net-which-background-removal-model-actually-works-in-production-4830
- https://github.com/cansik/onnxruntime-silicon
- https://github.com/xaviviro/onnxruntime-coreml
- https://gist.github.com/fathonix/3b9bda262226ac8842338d65ae505673
- https://github.com/danielgatis/rembg/issues/556
- https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html
- https://github.com/Comfy-Org/comfy-cli
- https://docs.comfy.org/installation/desktop/macos
- https://www.apatero.com/blog/batch-process-1000-images-comfyui-guide-2025
- https://github.com/Zar4X/ComfyUI-Batch-Process
- https://releases.drawthings.ai/p/draw-things-cli-local-media-generation
- https://wiki.drawthings.ai/wiki/Scripting_Basics
- https://github.com/filipstrand/mflux
- https://huggingface.co/docs/diffusers/en/optimization/mps
