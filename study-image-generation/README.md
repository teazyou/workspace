# Local Image Generation on an M4 Pro / 64GB Mac — Study Index

This study answers, end to end, whether and how you can do **good local (offline) image generation** on the target machine — an **Apple MacBook Pro, M4 Pro chip, 64GB unified memory, macOS** (mid-2026). It covers the hardware feasibility and its ceilings, the best state-of-the-art open-weights models you can actually run here, the apps and exact install commands to run them, how to customize/specialize a model (LoRA and every sibling technique, plus the local-vs-cloud training line), a practical annex for generating anime / video-game / "sketchy-but-SFW" illustration wallpapers, and a final annex for **editing an existing image** into a plain-black-background wallpaper (isolate a character, keep named objects, recolor one, black out the rest) — so the study covers both **generating from scratch** and **editing pixels you already have**. It is scoped to **local** generation — where a cloud GPU is the honest answer (video, 32B-class training), it says so. As a deliberate alternative to running locally, a final **cloud-API** annex shows how to do the same edit on hosted frontier APIs (**Google Gemini / OpenAI / xAI Grok**, plus the top-3 alternatives), confirms each can do prompt-plus-image editing at 1080p, tiers the quality, and **prices 100 edits per provider in VND** — so you can weigh the offline pipeline against a pay-per-edit API.

---

## Executive verdict

**Yes — the M4 Pro / 64GB is a genuinely good local *image*-generation machine.** Its 64GB of unified memory gives ~48GB of GPU-addressable RAM, enough to run essentially every current open-weights image model — including **FLUX.1-dev (12B) at full fp16**, which most 16–24GB NVIDIA cards cannot do without offloading or quantizing. The trade-off is speed, not capability: per-image generation is roughly **3–10× slower than an RTX 4090** (memory-bandwidth bound at ~273 GB/s), but firmly in "usable" territory for stills. Two hard ceilings: local **video** generation is *not* practical here (use a rented cloud GPU), and **FP8 quantization does not work on Apple Silicon/MPS** (use GGUF, MLX quant, or fp16/bf16 instead).

**Single recommended stack:** **Draw Things** (free, native Mac app, fastest local option, the only one with built-in on-device LoRA training) running **Z-Image Turbo** (6B, Apache 2.0, 8 steps) for fast everyday work, or **FLUX.1-dev** when you want top FLUX quality. For the best *commercially licensed* quality, swap in **Qwen-Image-2512** (20B, Apache 2.0).

---

## TL;DR — recommended setup

- **Tool (everyday + LoRA training):** **Draw Things** — free on the Mac App Store (`id6444050820`) or from `https://drawthings.ai/downloads/`. On the M4, enable the 8-bit "S" mode for ~2× speedup. Free Edition covers local generation and on-device LoRA training; no paid tier is required for local use.
- **Tool (scripted, lean, fast FLUX on Apple MLX):** **mflux** (MIT, CLI) — `uv tool install -p 3.12 --upgrade mflux --with hf_transfer`.
- **Tool (power / any model / custom workflows):** **ComfyUI** via `comfy-cli`.
- **Models to start with:**
  - **Z-Image Turbo** (6B, Apache 2.0) — best quality/speed balance, fits with room to spare.
  - **FLUX.1-dev** (12B) — best-supported FLUX on Mac, top quality (non-commercial license).
  - **Qwen-Image-2512** (20B, Apache 2.0) — best *commercial-licensed* quality, strongest in-image text.
  - **SDXL** (3.5B, OpenRAIL-M, no revenue cap) — fastest mature option, largest LoRA/ControlNet ecosystem; the right base for anime wallpapers.
- **Where to get them:** Hugging Face (gated repos like FLUX.1-dev need `huggingface-cli login` + license acceptance), Civitai for community checkpoints/LoRAs, or Draw Things' in-app model browser. mflux auto-downloads on first run.
- **Editing an existing image (not generating one)** is a *different* job: it is **segmentation/compositing first, generation second** — isolate what you keep, composite over true `#000000`, and only let a model touch the pixels that must change. See [`06-annex-image-editing.md`](./06-annex-image-editing.md).
- **Prefer a hosted API over your own GPU?** The same edit runs on **Gemini / OpenAI / Grok** (or FLUX.1 Kontext / Qwen / Stability) for cents per image — **FLUX.1 Kontext [pro]** is the recommended default (~105,280 ₫/100). See [`07-annex-api-image-generation.md`](./07-annex-api-image-generation.md).

> **Exact copy-paste install commands, model-folder layout, and download steps are in [`03-tools-and-install.md`](./03-tools-and-install.md).**

---

## How to read this study

Each file owns a distinct set of questions. Use this table to route a question to the right file.

| File | Owns these questions — route here for… |
|---|---|
| [`01-feasibility.md`](./01-feasibility.md) | **Can this machine do good local image generation, and where are the ceilings?** The hardware verdict; why 64GB / unified memory matters (~48GB GPU-addressable); the **no-FP8-on-Apple-Silicon** caveat; realistic seconds-per-image; the backends (MPS / MLX / CoreML / Draw Things); **possibilities & limitations** (runs great / runs slow / needs a cloud GPU); and **why local video needs a cloud GPU**. |
| [`02-sota-local-models.md`](./02-sota-local-models.md) | **What is the best local solution and what are my model options?** The full catalog of SOTA open-weights text-to-image models runnable here — FLUX.2 (dev/klein), FLUX.1 (dev/schnell), Qwen-Image, Z-Image, SD 3.5 / SDXL, HiDream-I1, Sana, Lumina-2, Chroma — with quality / speed / memory-footprint / **license & commercial-use** comparisons and tiered "which to pick" recommendations. Also home of the **instruction-edit models** (FLUX.1 Kontext, Qwen-Image-Edit-2509) that annex 06 builds on. |
| [`03-tools-and-install.md`](./03-tools-and-install.md) | **How do I install and run it?** The apps/pipelines (Draw Things, ComfyUI, mflux, DiffusionBee, InvokeAI, A1111, Forge/reForge, Fooocus, SwarmUI) rated for Mac support, plus **exact copy-paste install commands** for the three recommended paths and **where/how to fetch model weights** (Hugging Face, ComfyUI downloader, Civitai) and which folders they go in. |
| [`04-customization-and-lora.md`](./04-customization-and-lora.md) | **What is a LoRA, what does training one need, and what other ways can I specialize a model?** LoRA theory (low-rank ΔW, rank/alpha, file sizes) and **what training one requires** (captioned dataset, captioning stack, trainers, the Apple-Silicon fp16-NaN precision footgun); every sibling method (DreamBooth, textual inversion, full fine-tune, checkpoint merge, ControlNet, IP-Adapter, hypernetworks); the **local-vs-cloud training line** and rates; and licensing for selling outputs/LoRAs. |
| [`05-annex-wallpaper-generation.md`](./05-annex-wallpaper-generation.md) | **Generate a NEW game / anime / "sketchy-SFW" wallpaper from a prompt.** Why **SDXL** (not FLUX/Qwen) for anime; the checkpoint ecosystem (Illustrious / NoobAI / Pony V6 / Animagine); per-family prompting conventions and quality/rating tags; wallpaper resolutions, native buckets & upscalers (4x-UltraSharp, SUPIR); a batch workflow; **keeping "sketchy" stylization strictly SFW**; and the ethics/legal guardrails (no minors, no real-person likeness, per-model licenses). *Contrast with 06: this file makes a brand-new image; 06 edits one you already have.* |
| [`06-annex-image-editing.md`](./06-annex-image-editing.md) | **EDIT an image you ALREADY have into a plain-black-background wallpaper — LOCALLY (offline, free).** The canonical task — *isolate a character, keep named objects (yoga rope, flower), recolor one of them (flower → red), and replace the entire background with true `#000000`*. Owns the **three routes**: **A** one-shot generative instruction edit (FLUX.1 Kontext [dev] non-commercial / Qwen-Image-Edit-2509 Apache-2.0); **B** deterministic **SAM 3 / 3.1** text-prompt masks → composite over black → LAB recolor (pixel-faithful, free); and the recommended **C** hybrid (Route-B black-out + a small masked flower inpaint for natural shading). Plus the black-key finish, GGUF sizes, the **BRIA RMBG non-commercial trap**, SAM-3-on-Apple-Silicon (triton/transformers/ComfyUI) caveats, and upscaling. *Contrast with 05: 05 = generate new from scratch; 06 = edit existing pixels. For the same edit via a CLOUD API instead, see 07.* |
| [`07-annex-api-image-generation.md`](./07-annex-api-image-generation.md) | **Do the SAME edit via a CLOUD API instead of locally — priced per 100 images in VND.** The cloud counterpart to 01–06 (and especially 06): *prompt + ~1080p input → edited 1080p plain-black wallpaper* on a hosted service. Owns: **how to call Gemini / OpenAI / xAI Grok** (model ids, edit-vs-generate endpoints, minimal snippets); whether each can do **prompt + input-image editing at 1080p** (all three can — **none is text-to-image only**, Grok included); the **top-3 alternatives** (FLUX.1 Kontext, fal.ai Qwen-Image-Edit, Stability AI); **quality equivalence** (tiered, not equal); and **how much 100 such edits cost per provider in VND** (1 USD = 26,320 ₫, 2026-06-23) — default **FLUX.1 Kontext [pro] ≈ 105,280 ₫/100**, cheapest **Gemini 2.5 Flash batch ≈ 51,324 ₫/100**, priciest **OpenAI gpt-image-2 ≈ 539,560 ₫/100**. Ends with a privacy/cost local-vs-API trade-off. *Contrast with 06: 06 = local & offline; 07 = cloud API & pay-per-edit.* |

---

## Hardware assumptions

- **Machine:** Apple MacBook Pro, **M4 Pro** chip, **64GB unified memory**, macOS (study reflects mid-2026 software).
- **GPU-addressable memory:** ~48GB out of the box (Metal's ~75% `recommendedMaxWorkingSetSize` on >36GB Macs); raisable via `sysctl iogpu.wired_limit_mb` but leave 8–16GB for macOS to avoid swap.
- **Memory bandwidth:** ~273 GB/s — fixed regardless of capacity, and the dominant limit on per-image speed (~1/4 of an RTX 4090's ~1008 GB/s).
- **Power:** plug in for sustained work; macOS throttles GPU clocks on battery.
- Speed figures throughout are **directional** (third-party 2025–2026 blogs/benchmarks, often on different chips or a 24GB Mac Mini), not controlled lab results — measure your own config.

## Caveats & limitations

- **No FP8 on Apple Silicon/MPS.** FP8 checkpoints fail or fall back to CPU. Use **GGUF** (Q8 ~13GB, Q6_K ~10GB, Q4 ~6–8GB for FLUX-class), MLX-native 4/8-bit, or plain fp16/bf16. This dictates which checkpoints you download.
- **Slower than NVIDIA.** ~3–10× slower per image than a 4090 for FLUX-class; FLUX.1-dev is ~50–90s/image at 1024px. The Mac's edge is capacity (big models, multiple resident models, large overnight batches), not throughput.
- **Local video is not practical.** LTX-Video is the *most* feasible but still rough; Wan 2.2 / HunyuanVideo are impractical (~hour-plus per short clip). Use a cloud GPU.
- **MPS has gaps.** Occasional unimplemented ops need `PYTORCH_ENABLE_MPS_FALLBACK=1` (slow CPU fallback); MPS is still beta.
- **fp16 training is broken on MPS** (GradScaler unimplemented → NaN loss). Train in **fp32 or bf16** (bf16 *is* supported on Apple Silicon + macOS 14+). Heavy training (FLUX.2-dev 32B, Qwen-Image 20B, full fine-tunes) needs a cloud GPU (~$0.30–1.40/hr; a small FLUX LoRA ≈ $0.50–3).
- **Editing an existing image is segmentation/compositing first, generation second.** To preserve a subject and get a *true* `#000000` background, don't paste the whole instruction into a generative editor (it redraws the canvas and rarely yields clean black) — segment what you keep, composite over a literal black canvas, and only let a model touch the pixels that must change. SAM 3's official repo is **CUDA/triton-only**; on Apple Silicon use the **transformers** or **ComfyUI** path. Watch the **BRIA RMBG (CC BY-NC) non-commercial trap** for cutouts. See [`06-annex-image-editing.md`](./06-annex-image-editing.md).
- **Cloud-API prices drift, and APIs send your image to a third party.** The per-100-edit VND figures in annex 07 are mid-2026 snapshots at 1 USD = 26,320 ₫ (2026-06-23) — re-check each provider's pricing page before budgeting, and note that any API path means your **input image and prompt leave your Mac** (a privacy trade-off the fully-local pipeline in 01–06 avoids). See [`07-annex-api-image-generation.md`](./07-annex-api-image-generation.md).
- **Several figures are unconfirmed for the M4 Pro specifically** — much published data is from M2 Max / M2 Ultra / 24GB Mac Mini; the files flag these as estimates throughout. (No clean primary M4-Pro-64GB benchmark exists for Kontext/Qwen edits or SAM 3.1 either — treat annex 06's seconds figures as estimates.)
- **Licensing matters for commercial use.** FLUX.1-dev, FLUX.2-dev, FLUX.2-klein-9B, and **FLUX.1 Kontext [dev]** are **non-commercial** (Kontext's *outputs*, however, are commercially usable). For commercial work prefer Apache 2.0 (Qwen-Image, **Qwen-Image-Edit-2509**, Z-Image, FLUX.1-schnell, FLUX.2-klein-4B), MIT (HiDream-I1), or SDXL (OpenRAIL-M, no revenue cap). The **SAM License** (annex 06) permits commercial use with no MAU cap. Paid-API outputs (annex 07) are generally commercial-OK — confirm each provider's terms.

---

## Contradictions found across the files and how they were reconciled

The seven files are mutually consistent — no genuine contradictions remained to reconcile. The shared numbers and claims line up across them, and where they could superficially appear to disagree, each file already self-corrects in the same direction:

- **FLUX.1-dev speed** is quoted consistently as **~50s in Draw Things / 50–90s in ComfyUI (Q6_K, 20 steps)** on a 24GB M4 Pro in files 01, 02, and 03, all explicitly flagging the figure as a single 24GB-Mac-Mini benchmark, not a 64GB-M4-Pro number. File 06 reuses the same caveat for Kontext edits, noting no Kontext-on-M4-Pro figure exists.
- **Z-Image Turbo speed** — file 02's "~60–80s/image at 1024px" and file 01's "expect ~15–30s+ at 512px, well over two minutes at 1024px" are *not* in conflict: both explicitly note Mac timings vary wildly by tool/resolution and that the widely-quoted single-digit-second figures are NVIDIA (4090/4070), not Apple Silicon.
- **Draw Things "~20% / up to 40% faster than ComfyUI"** appears in 01, 02, 03, and 05, and every instance flags the same caveat — it comes from secondary reviews, not a controlled benchmark, so treat it as a defensible floor.
- **The "4B" naming** is explicitly disambiguated in both 02 and 04: **4B is a FLUX.2 [klein] size (Apache 2.0), not a "dev" model**; FLUX.2 [dev] is 32B and non-commercial.
- **SDXL speed (~20–40s at 1024px/25 steps, ComfyUI MPS)** matches between 02, 03, and 05.
- **The no-FP8-on-MPS and FP32-VAE caveats** are stated identically in 01 and 06 — annex 06 simply applies them to the editor/inpaint models rather than txt2img.
- **The FLUX.1 Kontext / Qwen-Image-Edit editors** appear in 02 (local catalog), 06 (local edit routes), and 07 (the same models hosted as APIs) — consistent: 06 runs them on your Mac, 07 calls them in the cloud at a flat per-image price.

If a future reader spots an apparent mismatch, it will almost always be a **best-case vs typical** figure or a **different chip** (M2 Max / M2 Ultra / 24GB Mac Mini / M1 Max vs the 64GB M4 Pro target) — each file labels these inline.
