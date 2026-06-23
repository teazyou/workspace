# 03 — Tools & Install Guide

This file is the practical core of the study: it surveys the apps and pipelines that actually run image-generation models on Apple Silicon, rates each for Mac support / ease / features / license, and then gives **exact, copy-paste install commands** for the three recommended paths — Draw Things (easy native), ComfyUI (power), and mflux (FLUX on MLX) — plus how and where to fetch model weights. For *which model to pick* see [`./02-sota-local-models.md`](./02-sota-local-models.md); for *can my Mac run it at all* see [`./01-feasibility.md`](./01-feasibility.md); for *training your own LoRA* see [`./04-customization-and-lora.md`](./04-customization-and-lora.md).

Hardware assumed throughout: **MacBook Pro, M4 Pro, 64 GB unified memory, macOS** (mid-2026).

---

## TL;DR recommendation

- **Want it to just work, no terminal?** → **Draw Things** (free, App Store, fastest native option, only app with built-in on-device LoRA training). Start here.
- **Want maximum control / every model / custom workflows?** → **ComfyUI** via `comfy-cli`.
- **Want the leanest, fastest FLUX path via Apple's MLX, scripted from the CLI?** → **mflux**.

Everything else (DiffusionBee, InvokeAI, A1111, Forge/reForge, Fooocus, SwarmUI) is situational and covered below.

---

## Apple-Silicon background (applies to all tools)

Three acceleration backends matter on a Mac:

- **MPS (Metal Performance Shaders)** — PyTorch's Apple-GPU backend. Used by ComfyUI, InvokeAI, A1111, Forge/reForge, Fooocus, SwarmUI, DiffusionBee. Works automatically from PyTorch 2.0+, but the diffusion UIs run best on **PyTorch nightly** for the latest MPS fixes. Slower than equivalent-tier NVIDIA CUDA.
- **MLX** — Apple's own array framework, used by **mflux** (and partly by Draw Things). Generally leaner and faster than PyTorch-MPS for the same model.
- **ANE (Apple Neural Engine) + NAX** — **Draw Things** uniquely targets ANE hybrid inference. M5/A19 default to an ANE+NAX hybrid; **M4/A18 get an 8-bit "S" mode worth roughly a 2× speedup**.

Common MPS gotchas you will hit:

- Some ops are unimplemented on MPS → set `PYTORCH_ENABLE_MPS_FALLBACK=1` (falls back to CPU for those ops, slower but correct).
- `PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.8` is commonly set to dodge allocator/OOM issues.
- **FP8 weights are poorly supported on MPS** — this directly affects FLUX fp8 all-in-one checkpoints in ComfyUI; GGUF or higher-precision weights are the workaround. The current state of native fp8-on-MPS support is unsettled, so prefer GGUF / bf16 / quantized-MLX on Mac.
- **Forge/reForge (and ComfyUI) require macOS 14+** for BFloat16 on MPS — this is a PyTorch/MPS floor, not unique to Forge.

### Speed reality check

| Workload (1024×1024) | Tool / backend | Time per image |
|---|---|---|
| FLUX.1-dev, 20 steps, Q6_K | ComfyUI (PyTorch-MPS), Mac Mini **M4 Pro 24 GB** | **~50–90 s** |
| SDXL, 25 steps | ComfyUI (PyTorch-MPS), M4 Pro | ~20–40 s |
| FLUX-class | DiffusionBee (older pipeline) | ~1–2 min |
| FLUX, 8-bit | mflux on **M4/M3 Max** (not Pro) | ~19–20 s |

> **Caveats:** the ~50–90 s FLUX figure is a single third-party blog benchmark (heyuan110) on a **24 GB** Mac Mini at Q6_K — a 64 GB M4 Pro with a different quant/backend will differ. The ~19–20 s mflux numbers are **Max-tier** chips; **no published mflux benchmark exists for the M4 Pro specifically**, so the real seconds-per-image on a 64 GB M4 Pro at 8-bit is unverified and must be measured. Treat all of these as directional, and see [`./01-feasibility.md`](./01-feasibility.md) for the fuller speed discussion.

---

## Tool comparison (Apple-Silicon focus)

| Tool | Backend | AS quality | UI / ease | LoRA train | ControlNet | FLUX | License | Cost |
|---|---|---|---|---|---|---|---|---|
| **Draw Things** | ANE+MPS+MLX | **Best** | Native GUI, easiest | ✅ on-device | ✅ stackable | ✅ .1/.2 | proprietary (free) | Free (+$8.99/mo cloud add-on) |
| **ComfyUI** | PyTorch-MPS | Good (nightly) | Node graph, hard | via nodes | ✅ | ✅ | GPL-3.0 | Free |
| **mflux** | MLX | Excellent | CLI only | growing | ✅ Canny/depth+Kontext | ✅ .1/.2 | MIT | Free |
| DiffusionBee | PyTorch-MPS | OK, slower | Native GUI, easy | ❌ | limited | ✅ (v2.5.3+) | free | Free |
| InvokeAI | PyTorch-MPS | Good | Web canvas, mid | (workflows) | ✅ | ✅ .1/.2 Klein | Apache-2.0 | Free self-host + paid hosted |
| A1111 | PyTorch-MPS | Works, **slowest** | Web tabs, mid | ext | ext | ext only | AGPL-3.0 | Free |
| Forge / reForge | PyTorch-MPS | Works (macOS 14+) | Web tabs | ext | ✅ | ✅ native | AGPL-3.0 | Free |
| Fooocus | PyTorch-MPS | Experimental, slow | Simple GUI | ✅ | built-in | ❌ SDXL only | GPL-3.0 | Free |
| SwarmUI | ComfyUI/MPS | M-series only | Web, easy+power | via Comfy | ✅ | ✅ | MIT | Free |

**Runs great locally:** Draw Things, mflux. **Runs but slower:** ComfyUI, InvokeAI, DiffusionBee, Forge/reForge, SwarmUI. **Runs but barely worth it:** A1111 (slowest tabbed UI), Fooocus (experimental MPS, ~9× slower than an RTX 3xxx, SDXL-only and frozen).

### Notes per tool

- **Draw Things** (native, *recommended easy*) — Free on the Mac App Store (`id6444050820`). Supports SD 1.5/SDXL/FLUX.1/FLUX.2/Qwen-Image/Z-Image/Wan 2.2/LTX. Fully stackable ControlNet (Depth + Canny + Color together), inpaint/outpaint, upscaling, and the **only** app here with built-in **on-device LoRA training** (FLUX.2 klein 4B/9B, Z-Image, Qwen-Image). Directionally **~20%+ faster than ComfyUI/PyTorch-MPS** on the same hardware (native Swift + Metal FlashAttention) — but this magnitude comes from secondary reviews, not a controlled benchmark, so treat it as a defensible floor rather than a precise number.
- **ComfyUI** (*recommended power*) — Node/graph pipeline builder, GPL-3.0, runs everything (SD/SDXL/SD3.5/FLUX.1/.2/Qwen/video). Steepest learning curve; best on PyTorch nightly; FP8 FLUX checkpoints are the weak spot on MPS (use GGUF). MLX custom nodes exist but are niche — **the default PyTorch-MPS backend is still the recommendation**; the MLX-node maturity question is unresolved.
- **mflux** (*recommended FLUX-on-MLX*) — MIT-licensed, **v0.18.0 (2026-06-07)**, MLX-native CLI. Quantization 3/4/6/8-bit, multi-LoRA, ControlNet (Canny/depth), FLUX "Kontext" edit, SeedVR2 upscaling. No GUI — pairs well with a coding agent for the many flags.
- **DiffusionBee** — Dead-simple native `.dmg` GUI; FLUX support from v2.5.3+ (arm64, macOS 13+). Easiest after Draw Things but older/slower (~1–2 min/image) and shallow on LoRA/ControlNet.
- **InvokeAI** — Apache-2.0 community core with a Photoshop-style unified canvas, Model Manager, WebUI on `:9090`. Strong ControlNet/inpaint/compositing; supports FLUX.1 and FLUX.2 Klein (incl. quantized). Free self-host; paid hosted/Pro tiers also exist (the exact free-vs-paid boundary for the hosted tiers was not fully resolved here — the self-hosted Community edition is free).
- **Forge / reForge** — Performance A1111 forks; Forge is ~30–60% faster than A1111 with native FLUX dev/schnell and SD3.5. **reForge is the currently recommended fork.** Requires macOS 14+. Exact Apple-Silicon install flags aren't pinned to a primary source (generic "clone + setup script").
- **A1111** — The classic WebUI; works via MPS but is the slowest tabbed UI and has no native FLUX. Largely superseded by reForge on Mac.
- **Fooocus** — Simplified SDXL-only UI, GPL-3.0, **in bug-fix-only LTS** (last release v2.5.5, 2024-08-12, with no plans for new architectures). MPS is experimental and ~9× slower than an RTX 3xxx. Only `github.com/lllyasviel/Fooocus` is official (many fake clone sites exist).
- **SwarmUI** — MIT front-end that drives a **ComfyUI backend**; M-series only; needs .NET + Python 3.10/3.11/3.12 (not 3.13). Friendly UI with a drop-into-raw-graph escape hatch.

---

## Install — A) Easy native: Draw Things

1. Open the Mac App Store, search **"Draw Things"** (or open `https://apps.apple.com/us/app/draw-things-offline-ai-art/id6444050820`) → **Get**. Or grab the build from `https://drawthings.ai/downloads/`.
2. Launch → on first run pick and download a model (e.g. SDXL, FLUX.1, FLUX.2). Weights are stored locally and run fully offline.
3. (Optional) On an M4, enable the **8-bit "S" mode** for the ~2× speedup.

**Free vs paid (corrected):** the **Free Edition** is free for local generation **and includes on-device LoRA training**. **Basic Cloud Compute is also free** via the Community tier. **Draw Things+ ($8.99/mo)** only unlocks *higher* cloud-compute limits, an on-demand compute boost, Privacy Pass, and **BYOL** (using your own LoRAs with Cloud Compute) — it does **not** gate cloud compute itself. Nothing about local use requires a paid tier.

---

## Install — B) Power: ComfyUI via comfy-cli (uv-backed)

Requires Python 3.10+ (`comfy-cli` manages its own venv).

```bash
# 1. Install uv (fast Python tool/pkg manager) if not present
brew install uv

# 2. Install comfy-cli in an isolated tool env
uv tool install comfy-cli            # or: pipx install comfy-cli  /  pip install comfy-cli

# 3. Install ComfyUI (use --fast-deps to resolve deps with uv)
comfy install --fast-deps
#    optional explicit location:
#    comfy --workspace=~/ComfyUI install --fast-deps

# 4. Launch (Apple Silicon: enable CPU fallback for unimplemented MPS ops)
export PYTORCH_ENABLE_MPS_FALLBACK=1
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.8
comfy launch
#    if generations look wrong/slow on nightly PyTorch, try:
#    comfy launch -- --force-fp16
```

Notes:

- `comfy install` creates a `.venv` inside the workspace; `comfy launch` uses the right Python automatically.
- For best MPS perf, ComfyUI recommends **PyTorch nightly**. comfy-cli normally installs a working torch; if you hit MPS bugs, reinstall torch nightly inside the workspace venv.
- Custom nodes: `comfy node install <name>` (e.g. `comfy node install comfyui-impact-pack`); update all with `comfy node update all`.

**Where models go (ComfyUI):**

```
ComfyUI/models/checkpoints/        # SD/SDXL + FLUX fp8 all-in-one checkpoints
ComfyUI/models/diffusion_models/   # standalone flux1-dev.safetensors (UNet/transformer)
ComfyUI/models/loras/
ComfyUI/models/vae/                # e.g. FLUX ae.safetensors
ComfyUI/models/text_encoders/      # clip_l.safetensors, t5xxl_fp16.safetensors (FLUX)
ComfyUI/models/controlnet/
```

To share an existing model library, edit `ComfyUI/extra_model_paths.yaml`.

---

## Install — C) FLUX on MLX: mflux

```bash
# 1. uv (if not already)
brew install uv

# 2. Install mflux (Python 3.12). Add hf_transfer for faster HF downloads.
uv tool install -p 3.12 --upgrade mflux --with hf_transfer

# 3. Generate (FLUX schnell, fast 2-step, 8-bit quant)
mflux-generate --model schnell --prompt "a red fox in snow" --steps 2 --seed 2 -q 8

# 4. FLUX dev (higher quality, more steps) + LoRA
mflux-generate --model dev --prompt "..." --steps 20 -q 8 \
  --lora-paths my_style.safetensors --lora-scales 1.0

# Multiple LoRAs:
mflux-generate --lora-paths a.safetensors b.safetensors --lora-scales 0.8 0.4
```

- `-q` is the shorthand for quantization (3/4/6/8-bit). mflux 0.18.0 also ships model-specific commands, e.g. `mflux-generate-z-image-turbo ... -q 8`.
- First run auto-downloads weights from Hugging Face. **FLUX.1-dev is gated** — accept the license and `huggingface-cli login` first (see below).

**FLUX.1 schnell/dev memory footprint by quantization** (from mflux 0.7.0 docs — these are **model/disk sizes**, FLUX.1-specific, not peak RAM, and the current 0.18.0 README no longer publishes the table; FLUX.2 / Z-Image / Qwen differ):

| Quantization | Size | Fits in 64 GB? |
|---|---|---|
| 3-bit | 7.52 GB | ✅ |
| 4-bit | 9.61 GB | ✅ (lighter/faster) |
| 6-bit | 13.81 GB | ✅ |
| **8-bit** | **18.01 GB** | ✅ **sweet spot** |
| Original (bf16) | 33.73 GB | ✅ (fits, slowest) |

On a 64 GB M4 Pro, **8-bit (~18 GB) is the recommended sweet spot**; 4-bit is faster and lighter; the bf16 original (~33.7 GB) fits but is the slowest.

---

## Getting models (general)

**Hugging Face** (gated repos like FLUX.1-dev need a login + accepted license):

```bash
pip install -U "huggingface_hub[cli]"
huggingface-cli login
huggingface-cli download black-forest-labs/FLUX.1-dev   # accept the license on the model page first
```

**ComfyUI built-in downloader** (handles placement via `--relative-path`; Civitai needs a token):

```bash
comfy model download --url <URL> --relative-path models/checkpoints
comfy model download --url <URL> --set-civitai-api-token <TOKEN>
```

**Civitai** — download `.safetensors` manually and drop them in the right folder:

- All-in-one / fp8 checkpoints → `models/checkpoints/`
- Standalone flux1-dev transformer → `models/diffusion_models/`
- LoRAs → `models/loras/`
- VAE → `models/vae/`
- FLUX text encoders (`clip_l`, `t5xxl`) → `models/text_encoders/`

mflux downloads everything automatically on first run; Draw Things has a built-in in-app model browser.

---

## Bottom line

For a 64 GB M4 Pro the pragmatic stack is: **Draw Things for everyday generation and on-device LoRA training**, **mflux when you want scripted, lean, fast FLUX from the terminal**, and **ComfyUI when you need a custom multi-stage workflow or a model nobody else supports yet**. All three are free for local use; the rest of the field is either slower, frozen, or a friendlier wrapper around the same MPS/ComfyUI engines. Apple Silicon is fully *functional* for local image generation — just meaningfully slower than NVIDIA, with fp8-on-MPS the main rough edge to route around.
