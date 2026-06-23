# Model Customization: LoRA & Every Other Specialization Method — Research Notes

> Topic owner notes for the image-generation study. Hardware context throughout: **Apple MacBook Pro, M4 Pro, 64GB unified memory, macOS.** Date: 2026-06-23.
> All facts below were web-verified in June 2026. Where sources conflict or numbers are soft, it is flagged inline. Field moves fast — treat version numbers and prices as "as-of mid-2026."

---

## 1. LoRA from first principles

**What it is.** LoRA (Low-Rank Adaptation) freezes the full base model and injects small trainable low-rank decomposition matrices alongside the existing linear (and attention) layers. Instead of updating a weight matrix `W` directly, it learns `ΔW = B·A`, where `A` and `B` are skinny matrices of rank `r`. Only `A` and `B` are trained; `W` is frozen. This cuts trainable parameters by >90% vs full fine-tuning.

- **Rank (`r` / "network dim/dimension").** Controls the capacity/size of the adaptation. Small rank (4–8) = lighter, faster, smaller file, less expressive. Large rank (32–64+) = more expressive, bigger file, more overfitting risk. Typical SDXL subject LoRA: 8–32. Draw Things default network dimension is **8**.
- **Alpha (`α`).** A scaling factor on the LoRA update. At inference the effective weight is `W + (α/r)·B·A` (the `α/r` ratio sets the strength). Stabilizes training as rank grows. Common heuristic: `α = r` or `α = r/2` (e.g. rank 64 / alpha 32).
- **Why the file is only a few MB.** You only store `A` and `B` (the low-rank deltas), not the full multi-GB checkpoint. An SD1.5/SDXL LoRA is typically ~2–200 MB depending on rank and which layers are targeted; a FLUX LoRA is commonly tens to a couple hundred MB. The base model stays separate and is loaded at inference, with the LoRA merged/applied on top.
- **Variants (LyCORIS family).** LoCon (applies to conv layers too), LoHa, LoKr, DoRA, etc. — extend where/how the low-rank update is applied. Out of strict scope but worth one line.

**Subject vs style vs concept LoRA (same mechanism, different dataset/captioning):**
- **Subject LoRA** — one specific person/character/object. ~10–30 images, a unique trigger token, captions that describe everything *except* the subject (so the trigger absorbs the subject identity).
- **Style LoRA** — an art style/aesthetic. 50–200+ images, captions describe content (not style), so the style binds to the trigger/whole-LoRA.
- **Concept LoRA** — a pose, composition, lighting, clothing, or abstract concept not well-represented in the base model.

Sources:
- https://huggingface.co/docs/diffusers/training/lora
- https://www.sandgarden.com/learn/lora-low-rank-adaptation
- https://www.mindstudio.ai/blog/what-is-sdxl-lora-custom-styles
- https://yuchen20.github.io/posts/low-rank-adaptation/
- https://github.com/cloneofsimo/lora (original SD LoRA impl)
- https://engineering.drawthings.ai/p/draw-things-democratizes-local-large-model-fine-tuning-on-iphone-ipad-and-mac-2ceb60b5b462 (network dim 8 default)

---

## 2. What it takes to TRAIN a LoRA

### Dataset size (rules of thumb, 2025–2026)
- Subject: **≈10–30 images** (some say as few as 5–15 for FLUX). Varied angles/lighting/backgrounds.
- Style: **≈50–200+ images**.
- Concept: varies, often 20–100.

### Captioning tooling
- **WD14 Tagger (v3, by SmilingWolf)** — DeepDanbooru-style booru tag lists; the de-facto standard tagger, strongest for anime/illustration but used broadly. Outputs thousands of discrete tags (character, clothing, hair/eye color, etc.). Described as "the standard captioning tool in 2026."
- **BLIP / BLIP-2** — natural-language caption generation (older, simpler).
- **Florence-2 (Microsoft)** — unified vision model; produces natural-language descriptions, composition, lighting. Common modern workflow = **Florence-2 (natural language) + WD14 (tags) + trigger token injection**, often automated in a ComfyUI node graph.
- **JoyCaption** — popular newer VLM captioner mentioned in community workflows.
- Trigger word: a unique token (e.g. `ohwx`, `sks`, or a custom string) prepended to captions; it becomes the activation key for the LoRA.

### Base-model choice (what you train the LoRA *on top of*)
- **SD 1.5** — tiny, fastest to train, lowest quality ceiling. Still trained for legacy.
- **SDXL (~3.5B UNet / ~6.6B total)** — the workhorse for local Apple-Silicon training; best speed/quality/feasibility tradeoff on Mac.
- **FLUX.1 [dev]** (12B, non-commercial license) — much higher quality but heavy; FLUX.1 [schnell] is Apache-2.0.
- **FLUX.2 [klein]** (4B / 9B) and **FLUX.2 [dev]** (32B) — newest; klein-4B is Apache-2.0 and small enough for consumer training, dev-32B is data-center class.
- **Qwen-Image** (20B, Apache-2.0) — strong prompt understanding, commercially permissive.
- Match the LoRA's base model to the base model you'll generate with — a LoRA is not portable across base architectures.

### Trainer tools
| Tool | Repo / link | Notes | Apple Silicon? |
|---|---|---|---|
| **kohya_ss / sd-scripts** | github.com/bmaltais/kohya_ss, github.com/kohya-ss/sd-scripts | Most widely used; Gradio GUI; SD1.5/SDXL/FLUX.1/FLUX.2. Fused backward pass (v0.9+, Jan 2025), LoRA+. | CUDA-first; community got it running on M1 with heavy caveats (Issue #1248). Not the recommended Mac path. |
| **ai-toolkit (Ostris)** | github.com/ostris/ai-toolkit | Primary FLUX/FLUX.2 trainer; YAML configs (`train_lora_flux_24gb.yaml`); also "AI-Studio" UI. | Runs on MPS via a community fork (hughescr/ai-toolkit) with `num_workers=0`, `PYTORCH_ENABLE_MPS_FALLBACK=1`, T5 quantizer off, torch.amp. "Unlikely to work on low unified memory." |
| **mflux (MLX native)** | github.com/filipstrand/mflux | MLX/Apple-Silicon-native FLUX + many models; LoRA *training* via DreamBooth technique since **v0.5.0**; 4-bit/8-bit quant; `--low-ram`. FLUX.2 / Z-Image training adapters added. | **Yes — built for Apple Silicon (MLX).** Best-aligned native option. |
| **SimpleTuner (bghira)** | github.com/bghira/SimpleTuner | General diffusion fine-tune kit (image/video/audio). | **Yes** — `pip install simpletuner[apple]` (M1–M4). Was historically CUDA-only. |
| **OneTrainer (Nerogar)** | github.com/Nerogar/OneTrainer, onetrainer.org | One-stop UI for SD/SDXL/LoRA. | **Yes** — claims NVIDIA, AMD, **Apple Silicon out of the box**. |
| **Draw Things** | wiki.drawthings.ai/wiki/LoRA_Training, drawthings.ai | macOS/iOS app; on-device LoRA training UI. | **Yes — native Metal, the easiest Mac path.** |

Sources:
- https://github.com/bmaltais/kohya_ss , https://github.com/kohya-ss/sd-scripts
- https://github.com/ostris/ai-toolkit , https://huggingface.co/blog/AlekseyCalvin/mac-flux-training , https://github.com/hughescr/ai-toolkit
- https://github.com/filipstrand/mflux , https://github.com/filipstrand/mflux/releases
- https://github.com/bghira/SimpleTuner
- https://github.com/Nerogar/OneTrainer , https://onetrainer.org/
- https://deepwiki.com/kohya-ss/sd-scripts/10.4-automated-captioning-and-tagging
- https://www.patreon.com/posts/ultimate-auto-145972827 (Florence2 + WD14 workflow)
- https://civitai.com/articles/25066/captioning-for-lora-training-joycaption-wd14-ideas
- https://apatero.com/blog/ultimate-guide-lora-training-2025

---

## 3. Feasibility on M4 Pro / 64GB specifically

### SDXL LoRA locally on MPS — YES, feasible
- **Draw Things (native Metal)** is the cleanest path. Concrete numbers from Draw Things engineering:
  - SDXL (3.5B) fine-tune peak memory **~10.3 GiB** (well within 64GB).
  - **SDXL on M2 Ultra: ~14 minutes for 500 steps** at 512×512; effective LoRAs in "as few as 500 steps" at lr 1e-4/1e-3.
  - Implementation: 8-bit quantized base, main net FP16, LoRA net FP32, network dim 8.
  - M4 Pro (lower GPU core count than M2 Ultra) will be **slower than these M2 Ultra figures** — expect minutes-to-low-tens-of-minutes for a small SDXL subject LoRA, not the M2 Ultra time. [Estimate — no direct M4 Pro SDXL benchmark found.]
- **MPS caveat (critical):** must train in **fp32** — fp16 produces NaN/zero gradients because AMP gradient scaling is disabled on MPS. This roughly doubles memory vs fp16 and is the #1 footgun on non-Draw-Things tools.
- Community reports for kohya/diffusers on MPS are inconsistent: one M3 Max report said "10 minutes per step" (very slow/misconfigured), another said "~4 sec/step." Wide variance → configuration-dependent. Draw Things' native Metal path avoids most of this.

### FLUX.1 LoRA on Apple Silicon — feasible but heavier
- **mflux (MLX)** supports LoRA/DreamBooth training natively (since v0.5.0); 4-bit/8-bit quant + `--low-ram` to avoid swapping. Best native FLUX-training route on Mac. (Exact M4 Pro time/memory not published — needs a hands-on benchmark; flag as open question.)
- **Draw Things** also trains FLUX.1 [dev] LoRAs on-device. Metal FlashAttention 2.0 (Sept 2025) added an experimental backward pass for training. Reported **~9 sec/step per image at 1024×1024 on M2 Ultra** for FLUX.1 LoRA. M4 Pro will be slower than M2 Ultra. Draw Things also added LoRA training for **FLUX.2 [klein] 4B/9B** and LoRA export for FLUX.2.
- **ai-toolkit on MPS** works via the hughescr fork but is fiddly and "unlikely to work on low unified memory" — 64GB helps here, but expect 3–5× slower than NVIDIA.

### What realistically belongs on a rented cloud GPU
- **FLUX.2 [dev] (32B)** full-quality LoRA, **Qwen-Image (20B)** heavy LoRA, **DreamBooth full fine-tunes**, and **full checkpoint fine-tunes** → rent NVIDIA.
- FLUX.2 dev needs **80GB+ VRAM** (or aggressive quant/offload). ai-toolkit FLUX.2 dev training: 24GB minimum, **80GB recommended**.
- Services & rough rates (mid-2026, live-market, verify before quoting):
  - **RunPod** — H100 PCIe from ~$2.89/hr (some listings ~$1.50/hr 80GB), A100 PCIe ~$1.39/hr, RTX 4090 community ~$0.34/hr. https://www.runpod.io/pricing
  - **Vast.ai** — marketplace, cheapest raw: RTX 4090 ~$0.31/hr, A100 80GB ~$0.67/hr (host-dependent, no fixed rate). https://vast.ai
  - A typical FLUX LoRA job (24GB GPU, ~10–30 imgs, <40 min) costs roughly **$0.50–$3** of GPU time on a 4090/A100. Full fine-tunes / 32B models cost more (multi-hour on 80GB).

Sources:
- https://engineering.drawthings.ai/p/draw-things-democratizes-local-large-model-fine-tuning-on-iphone-ipad-and-mac-2ceb60b5b462 (SDXL 10.3GiB, 14 min/500 steps M2 Ultra)
- https://engineering.drawthings.ai/p/metal-flashattention-2-0-pushing-forward-on-device-inference-training-on-apple-silicon-fe8aac1ab23c (FLUX ~9 sec/step M2 Ultra, backward pass)
- https://github.com/filipstrand/mflux (LoRA training v0.5.0, --low-ram, 4/8-bit)
- https://huggingface.co/blog/AlekseyCalvin/mac-flux-training (MPS config tweaks, low-RAM warning)
- https://sanj.dev/post/lora-training-2025-ultimate-guide/ (VRAM tiers; HTTP403 to fetch but surfaced in search)
- https://apatero.com/blog/how-to-train-flux-2-lora-complete-fine-tuning-guide-2025 (FLUX.2 24GB min / 80GB rec)
- https://www.runpod.io/pricing , https://vast.ai , https://www.spheron.network/blog/gpu-cloud-pricing-comparison-2026/
- MPS fp32-only / NaN: https://www.reallyar.com/training-stable-diffusion-lora-on-apple-silicon-m2-mac-gpus-metal/ , https://medium.com/@haldankar.deven/lora-fine-tuning-on-apple-silicon-d000ea38453c

---

## 4. Every other customization / specialization method

| Method | What it's for | Output size / cost | Locally feasible on M4 Pro/64GB? |
|---|---|---|---|
| **LoRA** | Lightweight subject/style/concept adaptation (see above). | Few MB–~200MB. | **Yes** (SDXL easy via Draw Things; FLUX heavier via mflux). |
| **DreamBooth** | *Full* fine-tune that injects a subject into the model weights (often a few-shot subject). Highest fidelity for a specific subject but bakes into a full checkpoint, single-purpose, slow. | Full checkpoint (multi-GB). | **Marginal.** SDXL DreamBooth possible but heavy; FLUX/large = cloud. mflux uses "DreamBooth technique" but produces a LoRA adapter, not a full weight fine-tune. |
| **Textual Inversion / embeddings** | Freezes U-Net; optimizes only the text embedding of a new token to represent a concept. Tiny, fast, low control. | A few KB (just an embedding vector). | **Yes — cheapest/lightest to train locally.** |
| **Full fine-tuning** | Update all (or most) model weights on a large dataset; build a new base checkpoint. Most expensive, most capable. | Full checkpoint (multi-GB). | **No — cloud/data-center GPU.** Not realistic locally for SDXL+ at quality. |
| **Checkpoint merging** | Blend two or more existing checkpoints by weighted averaging of weights (no training). Used to mix styles/capabilities. | Full checkpoint. | **Yes** — it's arithmetic on weights, not training; runs locally (tools like supermerger, ComfyUI, kohya merge). |
| **ControlNet** | Structural conditioning at *inference* — control output structure via edge/depth/pose/scribble/segmentation maps. *Using* it is inference; *training* a new ControlNet updates a copy of the encoder (heavy). | ~1–2.5GB per ControlNet model. | **Using: yes** (Draw Things/ComfyUI/mflux Canny+depth). **Training a new one: cloud.** |
| **IP-Adapter** | Image-prompt adapter: feeds a *reference image* as a visual prompt via decoupled cross-attention (text + image features separated). Style/subject transfer without training. Variants: IP-Adapter, IP-Adapter-FaceID, InstantID. | ~10s–100s MB. | **Using: yes, locally, no training needed.** |
| **Hypernetworks (legacy)** | Small auxiliary network that predicts/modifies attention weights for a concept; largely superseded by LoRA. | ~80–200MB. | **Yes** but **deprecated** — almost nobody trains new ones in 2025–2026; mentioned for completeness. |

Quick decision guide:
- One person/object, want portability → **LoRA** (or **textual inversion** for the lightest touch).
- Exact structure/pose/composition control → **ControlNet** (inference).
- "Make it look like this reference image" with zero training → **IP-Adapter**.
- New token for an abstract concept, minimal data → **textual inversion**.
- A brand-new base model with new knowledge → **full fine-tune** (cloud).
- Combine existing models' looks with no training → **checkpoint merge**.

Sources:
- https://andyhtu.com/personalization-techniques-dreambooth-vs-lora/
- https://towardsdatascience.com/six-ways-to-control-style-and-content-in-diffusion-models/
- https://github.com/AUTOMATIC1111/stable-diffusion-webui/discussions/3850
- https://sdxlturbo.ai/blog-LoRA-vs-Dreambooth-vs-Textual-Inversion-vs-Hypernetworks-19262
- https://github.com/TheLastBen/fast-stable-diffusion/discussions/1582

---

## 5. Licenses (matters for "can I sell what I make")
- **FLUX.1 [schnell]** — Apache-2.0 (free/commercial).
- **FLUX.1 [dev]** — "FLUX.1 [dev] Non-Commercial License v1.1.1" (open weights, **non-commercial**). https://huggingface.co/black-forest-labs/FLUX.1-dev/blob/main/LICENSE.md
- **FLUX.2 [klein] 4B** — Apache-2.0. **FLUX.2 [klein] 9B** and **FLUX.2 [dev] 32B** — FLUX.2-dev Non-Commercial License. https://github.com/black-forest-labs/flux2 , https://huggingface.co/black-forest-labs/FLUX.2-klein-4B
- **Qwen-Image / Qwen-Image-Edit** — Apache-2.0 (commercially permissive). https://www.spheron.network/blog/deploy-open-source-ai-image-editing-models-gpu-cloud-2026/
- **SDXL** — CreativeML OpenRAIL++-M (permissive with use restrictions).

---

## 6. Conflicts / uncertainties flagged
1. **FLUX.2 parameter counts conflicted across sources.** Resolved: **dev = 32B**, **klein = 4B and 9B**. (mflux README's "FLUX.2 (4B & 9B)" was referring to the klein variants; one search result wrongly equated FLUX.2-dev with a 4B model.) Confirmed via BFL repo / DeepWiki.
2. **MPS SDXL step time varies wildly** in community reports ("10 min/step" vs "4 sec/step" vs Draw Things 14 min / 500 steps). Configuration- and tool-dependent; Draw Things native numbers are the most trustworthy.
3. **No published M4 Pro-specific benchmark** for FLUX or SDXL LoRA training memory/time was found — all concrete Apple-Silicon numbers are M2 Ultra (Draw Things) or unspecified. M4 Pro figures are extrapolations and should be benchmarked.
4. **Cloud GPU prices are live-market** (esp. Vast.ai). Numbers here are mid-2026 snapshots; verify at deploy time.
5. **sanj.dev 2026 LoRA guide returned HTTP 403** to direct fetch; its VRAM-tier claims came through search snippets only — lower-confidence, cross-check before quoting specific GB tiers.
