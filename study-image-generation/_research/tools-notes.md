# Tools / Pipelines to Run Image Models Locally on Apple Silicon — Raw Research Notes

**Topic owner deliverable.** Date: 2026-06-23.
**Hardware assumed throughout:** Apple MacBook Pro, M4 Pro, 64 GB unified memory, macOS.

> Scope: macOS apps + pipelines for local image generation, each rated for Apple-Silicon support quality, features, ease, and licensing; then a concrete copy-paste install path (Draw Things = easy native; ComfyUI via comfy-cli/uv = power; mflux = FLUX on MLX), plus how/where to get models.

---

## 0. Key Apple-Silicon background (applies to everything below)

- Two acceleration backends matter on Mac:
  - **MPS (Metal Performance Shaders)** — PyTorch's Apple GPU backend. Used by ComfyUI, InvokeAI, A1111/Forge/reForge, Fooocus, SwarmUI, DiffusionBee. Works automatically from PyTorch 2.0+; no special build needed, but **ComfyUI/Forge run best on PyTorch nightly** for latest MPS fixes. Slower than NVIDIA CUDA on equivalent tier.
  - **MLX** — Apple's own array framework; used by **mflux** and (partly) Draw Things. Generally faster and lower-overhead than PyTorch-MPS for the same model.
  - **ANE (Apple Neural Engine) + NAX** — Draw Things uniquely targets ANE hybrid inference modes (M5/A19 default to ANE+NAX hybrid; M4/A18 get 8-bit "S" mode up to ~2x speedup).
- **Common MPS caveats / gotchas:**
  - Some ops are unimplemented on MPS → need `PYTORCH_ENABLE_MPS_FALLBACK=1` (falls back to CPU for those ops, slower).
  - `PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.8` often set to avoid OOM/allocator issues.
  - FP8 weights are poorly supported on MPS (an open area; GGUF/workarounds needed) — affects FLUX fp8 checkpoints in ComfyUI.
  - Forge requires **macOS 14+** for BFloat16 MPS support.
  - Open PyTorch issue: MPS "built but not available" on macOS 26 (Tahoe) with PyTorch 2.9.1 / 2.10 nightly — version-matching pain is real. (pytorch/pytorch#167679)
- **Speed reality check (M4 Pro / Mac Mini M4 Pro, 1024×1024):**
  - FLUX.1-dev, ~20 steps, Q6_K, ComfyUI (PyTorch-MPS): **~50–90 s/image**.
  - SDXL, 25 steps, ComfyUI: **~20–40 s/image**.
  - DiffusionBee (older pipeline): **~1–2 min/image**.
  - Draw Things claimed **~20%+ faster than ComfyUI** on identical hardware (vendor/3rd-party claim, qualitative).
  - mflux FLUX dev ~19–20 s on M4 Max/M3 Max (note: Max tier, not Pro) — see mflux table below.

---

## 1. Tool-by-tool

### Draw Things (NATIVE, recommended easy option)
- **What:** Native macOS/iOS/iPadOS app. Free on the App Store. Optimized for Apple Silicon (ANE + MPS + MLX hybrid).
- **Apple-Silicon quality:** Best-in-class. M5/A19 default ANE+NAX hybrid; M4/A18 8-bit "S" mode ~2x speedup. Claimed ~20%+ faster than ComfyUI MPS.
- **Models:** SD 1.5, SDXL, FLUX.1, FLUX.2, Qwen Image, Z Image, Wan 2.2, LTX (video), ERNIE Image. Built-in model downloader.
- **Features:** LoRA (incl. **on-device LoRA training** for FLUX.2 klein 4B/9B, Z Image, Qwen Image), full ControlNet (stackable: Depth+Canny+Color simultaneously), inpaint/outpaint, pose editing, infinite canvas, upscaling.
- **Ease:** Easiest of all — GUI app, one-click model download. iOS 15.4+/macOS 12.4+.
- **Free vs paid:** **Core app fully free** (local gen, downloads, infinite canvas, on-device LoRA training, offline). Optional **Draw Things+ = $8.99/mo** for cloud compute (NVIDIA servers), Bring-Your-Own-LoRA cloud upload (20 GB / 10 GB R2 storage), Privacy Pass, compute boosts. A free Community tier gives limited cloud "lab hours."
- **Install:** App Store (`id6444050820`) or https://drawthings.ai/downloads/

### ComfyUI (POWER option, node-based)
- **What:** Node/graph-based pipeline builder. Free, open-source (GPL-3.0). PyTorch-MPS backend on Mac.
- **Apple-Silicon quality:** Good but PyTorch-MPS — slower than NVIDIA; best on PyTorch nightly. FP8 FLUX checkpoints are problematic on MPS (need workarounds/GGUF). MLX is NOT the default backend (community MLX custom nodes exist but are niche).
- **Models:** Everything — SD1.5/SDXL/SD3.5, FLUX.1/.2, Qwen, video models, etc. via safetensors/GGUF/diffusion_models.
- **Features:** Maximal — LoRA, ControlNet, inpaint, upscaling, any workflow; ComfyUI-Manager for custom nodes. Steepest learning curve.
- **Ease:** Power-user. comfy-cli or Comfy Desktop launcher ease the install.
- **Install:** `pip install comfy-cli` → `comfy install` → `comfy launch`. Or Comfy Desktop app. (Full commands in §2.)
- **Model paths:** `ComfyUI/models/checkpoints/`, `.../loras/`, `.../vae/`, `.../controlnet/`, `.../diffusion_models/`, `.../text_encoders/`. Custom paths via `extra_model_paths.yaml`.

### mflux (MLX FLUX CLI — recommended FLUX-on-MLX option)
- **What:** MLX-native implementation of SoTA generative image models. CLI + Python API. **MIT license**. Current version **0.18.0** (2026-06-07).
- **Apple-Silicon quality:** Excellent — MLX-native, built for Apple Silicon only. Faster/leaner than PyTorch-MPS.
- **Models (per repo table):** Z-Image (6B), FLUX.2 (4B/9B), Ideogram 4 (9B), ERNIE-Image (8B), FIBO (8B), SeedVR2 upscaling (3B/7B), Qwen Image (20B), Depth Pro, FLUX.1 (12B, "legacy, decent quality").
- **Features:** Quantization 3/4/6/8-bit; multi-LoRA (`--lora-paths`/`--lora-scales`, library lookup); ControlNet (Canny/depth), FLUX.1 "Kontext" edit model, upscaling via ControlNet/SeedVR2; metadata export. **No GUI** (CLI only; can pair with a coding agent for the many flags).
- **Memory footprint (FLUX schnell/dev model size on disk/RAM, from mflux 0.7.0 docs):**
  | Quantization | Size |
  |---|---|
  | 3-bit | 7.52 GB |
  | 4-bit | 9.61 GB |
  | 6-bit | 13.81 GB |
  | 8-bit | 18.01 GB |
  | Original (bf16) | 33.73 GB |
- **Speed (from mflux benchmark table; FLUX, incl cold-start I/O):** M2 Ultra <15 s; M4 Max (128 GB) ~19 s; M3 Max ~20 s; M1 Pro (32 GB) ~160 s (8-bit, 512×512). NOTE: no explicit M4 **Pro** number in the table — M4 Pro likely between M3 Max and M1 Pro depending on quant. On 64 GB M4 Pro, 8-bit (18 GB) fits comfortably; bf16 original (33.7 GB) also fits but is slower.
- **Install:** `uv tool install --upgrade mflux` (Python 3.12). Models auto-download from HuggingFace on first run. (Full commands in §2.)

### DiffusionBee
- **What:** Free, dead-simple native Mac GUI app. Apple Silicon (M1–M5) + Intel.
- **Apple-Silicon quality:** Works, but older/slower pipeline (~1–2 min/image FLUX-class; ~30 s SD1.5 on 8 GB M1 Air). arm64-only FLUX support.
- **Models:** SD 1.5, SDXL, FLUX (FLUX support from **v2.5.3+**, arm64 + macOS 13+). Built-in model downloader.
- **Features:** Inpaint, outpaint, model browser. Limited ControlNet/LoRA depth vs ComfyUI/Draw Things. Easiest after Draw Things but less capable/slower.
- **Free vs paid:** Free.
- **Install:** https://diffusionbee.com/download (.dmg).

### InvokeAI
- **What:** Pro creative web UI with Photoshop-style canvas. Open-source (Apache-2.0 core) + commercial offering. PyTorch-MPS on Mac.
- **Apple-Silicon quality:** Supported via MPS; slower than CUDA; improved FLUX-on-MPS recently.
- **Models:** SD1.5, SDXL, FLUX.1 (needs ~10 GB+), FLUX.2 Klein family incl. quantized (down to ~6 GB-class). Model Manager for checkpoints/LoRAs/TI/ControlNet.
- **Features:** Strong — ControlNet (depth/edge/pose), LoRA, inpaint/outpaint/compositing, unified canvas. Mid learning curve.
- **Free vs paid:** Free self-host (Community); paid hosted/Pro tiers exist.
- **Install:** Download launcher → pick dir → auto Python env → WebUI at `http://localhost:9090`, first model ~4–7 GB.

### Automatic1111 (stable-diffusion-webui)
- **What:** The classic SD WebUI. Free, GPL-ish/AGPL. PyTorch-MPS on Mac.
- **Apple-Silicon quality:** Works via MPS but slowest of the tabbed UIs; largely superseded by Forge/reForge for Mac perf. No native FLUX (extensions only).
- **Features:** Huge extension ecosystem, LoRA, ControlNet (via ext), inpaint, upscaling, hires fix.
- **Install:** Homebrew deps + clone + `./webui.sh` (Apple Silicon wiki).

### Forge / reForge
- **What:** Performance-focused A1111 forks. Forge = memory-efficient attention + native FLUX dev/schnell, SD3.5; **30–60% faster than A1111**, lower VRAM. **reForge** = current recommended (Forge perf + up-to-date A1111 features).
- **Apple-Silicon quality:** Works via MPS, slower than NVIDIA; **requires macOS 14+** (BFloat16 MPS). For best Mac perf the consensus is "use Draw Things; use Forge for tabbed-UI/extension compatibility."
- **Features:** Native FLUX, LoRA, ControlNet, inpaint, upscaling, extensions.
- **Install:** Homebrew + clone repo + run setup script (like A1111).

### Fooocus
- **What:** Simplified "Midjourney-like" SDXL UI by lllyasviel. **GPL-3.0**.
- **Status:** **Limited LTS — bug fixes only, no new features.** Last release **v2.5.5 (2024-08-12)**. **SDXL only — no FLUX, no plans for new architectures.**
- **Apple-Silicon quality:** M1/M2 MPS supported but **experimental** and ~9x slower than an NVIDIA RTX 3xxx.
- **Features:** Auto-prompting, inpaint/outpaint, built-in styles; LoRA; abstracts away most knobs. Easy but dated.
- **Install:** conda env + PyTorch nightly + `pip install -r requirements_versions.txt`. WARNING: many fake "Fooocus" sites — only `github.com/lllyasviel/Fooocus` is official.

### SwarmUI (formerly StableSwarmUI)
- **What:** Modular web UI that **uses ComfyUI as its backend** while exposing an easy front-end + power tools. By mcmonkeyprojects. MIT.
- **Apple-Silicon quality:** **M-series only** (no Intel). Uses ComfyUI/PyTorch-MPS underneath; `launch-macos.sh` sets `PYTORCH_ENABLE_MPS_FALLBACK=1`.
- **Requirements:** .NET (via Homebrew) + Python **3.10/3.11/3.12** (NOT 3.13).
- **Features:** Inherits ComfyUI capabilities (FLUX/SDXL/etc., LoRA, ControlNet, upscaling) with friendlier UI; can drop into raw ComfyUI graph.
- **Install:** `brew install dotnet` → clone repo → `./launch-macos.sh` → follow browser setup.

---

## 2. CONCRETE RECOMMENDED INSTALL PATH (copy-paste)

### A) Easy native — Draw Things
1. App Store → search "Draw Things" (or open `https://apps.apple.com/us/app/draw-things-offline-ai-art/id6444050820`) → Get.
   Or download from `https://drawthings.ai/downloads/`.
2. Launch → on first run pick & download a model (e.g. SDXL, FLUX.1, FLUX.2) — stored locally, offline.
3. Optional: Draw Things+ ($8.99/mo) only if you want cloud compute / cloud LoRA upload. Not needed for local use.

### B) Power — ComfyUI via comfy-cli (uv-backed)
```bash
# 1. Install uv (fast Python tool/pkg manager) if not present
brew install uv

# 2. Install comfy-cli in an isolated tool env
uv tool install comfy-cli           # or: pipx install comfy-cli  / pip install comfy-cli

# 3. Install ComfyUI (use --fast-deps to resolve deps with uv)
comfy install --fast-deps
#   optional explicit location:
#   comfy --workspace=~/ComfyUI install --fast-deps

# 4. Launch (Apple Silicon: enable CPU fallback for unimplemented MPS ops)
export PYTORCH_ENABLE_MPS_FALLBACK=1
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.8
comfy launch
#   if generations look wrong/slow on nightly PyTorch, try:
#   comfy launch -- --force-fp16
```
Notes:
- comfy-cli creates a `.venv` inside the workspace; `comfy launch` uses the right Python.
- For best MPS perf, ComfyUI recommends PyTorch **nightly** (comfy-cli normally handles a working torch; if you hit MPS bugs, reinstall torch nightly inside the workspace venv).
- Install custom nodes: `comfy node install <name>` (e.g. `comfy node install comfyui-impact-pack`); update all: `comfy node update all`.

**Where models go (ComfyUI):**
```
ComfyUI/models/checkpoints/        # SD/SDXL/all-in-one + FLUX fp8 all-in-one checkpoints
ComfyUI/models/diffusion_models/   # standalone flux1-dev.safetensors (UNet/transformer)
ComfyUI/models/loras/
ComfyUI/models/vae/                # e.g. FLUX ae.safetensors
ComfyUI/models/text_encoders/      # clip_l.safetensors, t5xxl_fp16.safetensors (FLUX)
ComfyUI/models/controlnet/
```
Custom/shared library: edit `ComfyUI/extra_model_paths.yaml`.

### C) FLUX on MLX — mflux
```bash
# 1. uv (if not already)
brew install uv

# 2. Install mflux (Python 3.12). Add hf_transfer for faster HF downloads.
uv tool install -p 3.12 --upgrade mflux --with hf_transfer

# 3. Generate (FLUX schnell, fast 2-step, 8-bit quant)
mflux-generate --model schnell --prompt "a red fox in snow" --steps 2 --seed 2 --quantize 8

# 4. FLUX dev (higher quality, more steps) + LoRA
mflux-generate --model dev --prompt "..." --steps 20 -q 8 \
  --lora-paths my_style.safetensors --lora-scales 1.0

# Multiple LoRAs:
mflux-generate --lora-paths a.safetensors b.safetensors --lora-scales 0.8 0.4
```
- First run auto-downloads weights from HuggingFace (FLUX.1-dev is gated — accept license + `huggingface-cli login` first).
- On 64 GB M4 Pro: 8-bit FLUX (~18 GB) is the sweet spot; 4-bit (~9.6 GB) faster/lighter; bf16 original (~33.7 GB) fits but slowest.

### Getting models (general)
- **Hugging Face:** `pip install -U "huggingface_hub[cli]"` → `huggingface-cli login` (for gated repos like `black-forest-labs/FLUX.1-dev`) → `huggingface-cli download black-forest-labs/FLUX.1-dev`. mflux pulls automatically; for ComfyUI download specific files into the right `models/` subfolder.
- **ComfyUI built-in downloader:** `comfy model download --url <URL> [--relative-path models/checkpoints]`; CivitAI token: `comfy model download --url <URL> --set-civitai-api-token <TOKEN>`.
- **Civitai:** download `.safetensors` (checkpoints → `models/checkpoints/`, LoRAs → `models/loras/`). "All-in-one" FLUX checkpoints (VAE+text encoder merged) go in `checkpoints/`, not `unet/diffusion_models/`.

---

## 3. Comparison table (Apple Silicon focus)

| Tool | Backend | AS quality | UI / ease | LoRA | ControlNet | Inpaint | Upscale | LoRA training | FLUX | Free/Paid | License | Install |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Draw Things | ANE+MPS+MLX | Best | Native GUI, easiest | ✅ | ✅ (stackable) | ✅ | ✅ | ✅ on-device | ✅ .1/.2 | Free (+$8.99/mo cloud) | proprietary (free) | App Store |
| ComfyUI | PyTorch-MPS | Good (nightly) | Node graph, hard | ✅ | ✅ | ✅ | ✅ | via nodes | ✅ | Free | GPL-3.0 | comfy-cli/uv |
| mflux | MLX | Excellent | CLI only | ✅ multi | ✅ Canny/depth+Kontext | ✅ | ✅ (SeedVR2/CN) | (training tooling growing) | ✅ .1/.2 | Free | MIT | uv tool install |
| DiffusionBee | PyTorch-MPS | OK, slower | Native GUI, easy | limited | limited | ✅ | basic | ❌ | ✅ (2.5.3+, arm64) | Free | — | .dmg |
| InvokeAI | PyTorch-MPS | Good | Web canvas, mid | ✅ | ✅ | ✅ | ✅ | (workflows) | ✅ .1/.2 Klein | Free + paid hosted | Apache-2.0 | launcher |
| A1111 | PyTorch-MPS | Works, slowest | Web tabs, mid | ✅ | ext | ✅ | ✅ | ext | ext only | Free | AGPL-3.0 | clone+webui.sh |
| Forge/reForge | PyTorch-MPS | Works (macOS14+) | Web tabs | ✅ | ✅ | ✅ | ✅ | ext | ✅ native | Free | AGPL-3.0 | clone+script |
| Fooocus | PyTorch-MPS | Experimental, slow | Simple GUI | ✅ | built-in | ✅ | ✅ | ❌ | ❌ SDXL only | Free | GPL-3.0 | conda+pip |
| SwarmUI | ComfyUI/MPS | M-series only | Web, easy+power | ✅ | ✅ | ✅ | ✅ | via Comfy | ✅ | Free | MIT | .NET+launch-macos.sh |

---

## 4. Conflicting / uncertain data (be honest)

- **mflux M4 Pro speed:** The published mflux benchmark table lists M2 Ultra, M4 **Max**, M3 **Max**, M1 Pro — but **not M4 Pro specifically**. The ~19–20 s figures are Max-tier; M4 Pro will be slower. Don't quote 19 s for M4 Pro.
- **Draw Things "20%+ faster than ComfyUI":** comes from a vendor-aligned review (heyuan110) + Draw Things marketing; **qualitative, not a controlled side-by-side**. Treat as directional.
- **FLUX 50 s / image on M4 Pro 24 GB:** from heyuan110 review (Q6_K, 20 steps, ComfyUI). Plausible but single-source; range given was 50–90 s.
- **mflux memory table** (7.52/9.61/13.81/18.01/33.73 GB) is from mflux **0.7.0** docs — these are FLUX model footprints; newer models (FLUX.2 4B/9B, Z-Image 6B, Qwen 20B) differ. Verify per-model.
- **InvokeAI FLUX VRAM numbers** ("10 GB+", "6 GB quantized") are NVIDIA-framed VRAM; on Mac unified memory the practical floor differs. Directional only.
- **Forge/reForge install on Mac:** search results describe it generically ("clone + setup script"); exact `webui.sh` flags for reForge on Apple Silicon not pinned to a primary source here.

---

## 5. Source URLs (every citation)

Draw Things:
- https://apps.apple.com/us/app/draw-things-offline-ai-art/id6444050820
- https://drawthings.ai/downloads/
- https://drawthings.ai/pricing/
- https://wiki.drawthings.ai/wiki/Cloud_Compute
- https://wiki.drawthings.ai/wiki/Bring_Your_Own_LoRA_BYOL
- https://releases.drawthings.ai/p/introducing-boost-a-new-way-for-flexible
- https://www.heyuan110.com/posts/ai/2026-02-15-draw-things-ultimate-guide/
- https://gigazine.net/gsc_news/en/20251017-draw-things-image-generation-iphone-macos/
- https://www.tooljunction.io/ai-tools/draw-things

ComfyUI / comfy-cli:
- https://docs.comfy.org/installation/desktop/macos
- https://docs.comfy.org/installation/manual_install
- https://github.com/Comfy-Org/comfy-cli
- https://github.com/Comfy-Org/comfy-cli/blob/main/README.md
- https://comfyui-wiki.com/en/install/install-comfyui/comfy-cli
- https://pypi.org/project/comfy-cli/
- https://comfyui.org/en/install-comfyui-on-m3-macbook-pro
- https://atlassc.net/2025/01/15/installing-comfyui-on-macos-with-apple-silicon
- https://github.com/Comfy-Org/ComfyUI/discussions/13273 (FP8 MPS workaround)
- https://comfyui-wiki.com/en/tutorial/advanced/image/flux/flux-1-dev-t2i
- https://docs.comfy.org/tutorials/flux/flux-1-text-to-image
- https://huggingface.co/Comfy-Org/flux1-dev

mflux:
- https://github.com/filipstrand/mflux
- https://pypi.org/project/mflux/
- https://pypi.org/project/mflux/0.7.0/ (memory + speed tables)
- https://github.com/filipstrand/mflux/releases
- https://willschenk.com/howto/2025/running_flux_locally_on_a_mac/

DiffusionBee:
- https://diffusionbee.com/download
- https://skywork.ai/skypage/en/DiffusionBee-in-2025...

InvokeAI:
- https://invoke.ai/
- https://github.com/invoke-ai/InvokeAI/releases
- https://offlinecreator.com/tool/invokeai
- https://russmckendrick.medium.com/installing-and-running-invokeai-on-macos-8b26e09d0b75

A1111 / Forge / reForge:
- https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Installation-on-Apple-Silicon
- https://github.com/AUTOMATIC1111/stable-diffusion-webui/discussions/7453
- https://localaimaster.com/blog/sd-forge-guide
- https://stable-diffusion-art.com/sd-forge-install/

Fooocus:
- https://github.com/lllyasviel/Fooocus
- https://www.torolabs.com/installing-fooocus-on-an-apple-silicon-mac/
- https://docs.gymdreams8.com/mac_fooocus.html

SwarmUI:
- https://github.com/mcmonkeyprojects/SwarmUI
- https://deepwiki.com/mcmonkeyprojects/SwarmUI/1.1-installation-and-setup

Apple Silicon / MPS background + benchmarks:
- https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/
- https://contracollective.com/blog/m4-m5-pro-local-ai-inference-mlx-2026
- https://github.com/pytorch/pytorch/issues/167679 (MPS unavailable macOS 26/Tahoe)
- https://docs.pytorch.org/serve/hardware_support/apple_silicon_support.html
- https://medium.com/@michael.hannecke/apple-mps-beginners-guide-...
