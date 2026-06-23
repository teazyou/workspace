# Customization & LoRA: Specializing Image Models

This file answers **how you teach an image model something new** — a person, an art style, a concept, or fine structural control — and which of those methods are realistic on a 64GB M4 Pro versus which need a rented cloud GPU. It owns LoRA end to end (theory + training) and every sibling technique (DreamBooth, textual inversion, full fine-tune, checkpoint merge, ControlNet, IP-Adapter, hypernetworks), plus the local-vs-cloud training verdict and the licensing that governs selling what you make. For the models themselves see [./02-sota-local-models.md](./02-sota-local-models.md); for the apps that run/train them see [./03-tools-and-install.md](./03-tools-and-install.md).

> Hardware throughout: **MacBook Pro, M4 Pro, 64GB unified memory, macOS.** Figures are mid-2026; the field moves fast — treat version numbers and cloud prices as point-in-time.

---

## 1. What a LoRA actually is

LoRA (**Low-Rank Adaptation**) freezes the entire base model and learns a small **low-rank delta** alongside the existing linear/attention layers. Rather than updating a weight matrix `W`, it learns `ΔW = B·A`, where `A` and `B` are skinny matrices of **rank `r`**. Only `A` and `B` train; `W` stays frozen. At inference the effective weight is:

```
W_effective = W + (α / r) · B · A
```

- **Rank `r`** (a.k.a. "network dim") sets capacity. Small (4–8) = lighter, smaller file, less expressive; large (32–64+) = more expressive but bigger and more prone to overfitting. Typical SDXL subject LoRA: **rank 8–32**. Draw Things defaults to **network dim 8**.
- **Alpha `α`** scales the update; the `α/r` ratio is the effective strength. Common heuristic: **`α = r`** or `α = r/2`.
- **Why files are tiny.** You store only `A` and `B`, not the multi-GB checkpoint. SD1.5/SDXL LoRAs run **~2–200 MB**; FLUX LoRAs are typically tens to a couple hundred MB. The base model loads separately and the LoRA is applied on top.
- **LyCORIS variants** — LoCon (adds conv layers), LoHa, LoKr, **DoRA** — extend *where/how* the low-rank update applies. Out of strict scope but worth knowing the names.

**Same mechanism, three uses** (it's the dataset and captioning that differ, not the math):

| Type | Dataset | Captioning strategy |
|---|---|---|
| **Subject** (one person/object) | ~10–30 images, varied angles/lighting | Unique trigger token; caption *everything except* the subject so the trigger absorbs its identity |
| **Style** (an aesthetic) | ~50–200+ images | Caption the *content*, not the style, so the style binds to the trigger |
| **Concept** (pose/lighting/composition) | ~20–100 images | Caption the surrounding context |

---

## 2. What it takes to train one

You need a **small captioned dataset** + a **trainer**. The modern (2026) captioning stack:

- **WD14 Tagger v3** (SmilingWolf) — DeepDanbooru-style booru tags; the de-facto standard tagger, strongest on anime/illustration but used broadly.
- **Florence-2** (Microsoft) — natural-language descriptions: composition, lighting, scene. The common workflow pairs **Florence-2 (natural language) + WD14 (tags) + a trigger token**, often automated in a ComfyUI node graph.
- **BLIP/BLIP-2** are older NL captioners; **JoyCaption** is a newer VLM option.
- **Trigger word** — a unique token (`ohwx`, `sks`, or a custom string) prepended to every caption; it becomes the activation key.

### Trainers

| Tool | Best for | Apple Silicon? |
|---|---|---|
| **Draw Things** | SDXL + FLUX.1/FLUX.2 on-device, GUI | **Yes — native Metal, the easiest Mac path** |
| **mflux** | FLUX.1/FLUX.2 LoRA, MLX-native | **Yes — built for Apple Silicon (MLX)** |
| **SimpleTuner** (bghira) | General diffusion fine-tune | **Yes** — `pip install simpletuner[apple]` |
| **OneTrainer** (Nerogar) | One-stop UI, SD/SDXL/LoRA | **Yes** — Apple Silicon out of the box |
| **ai-toolkit** (Ostris) | Primary FLUX/FLUX.2 trainer | MPS only via community fork ([hughescr/ai-toolkit](https://github.com/hughescr/ai-toolkit)); fiddly |
| **kohya_ss / sd-scripts** | Most-used trainer overall | **CUDA-first** — not the recommended Mac path |

Match the LoRA to the base model you'll *generate* with — **a LoRA is not portable across base architectures** (an SDXL LoRA won't load on FLUX).

---

## 3. The Apple-Silicon footgun: precision

This is the #1 reason non-Draw-Things training fails on Mac. On the **MPS** backend, PyTorch AMP's `GradScaler` is **not implemented**, so **fp16 gradients underflow to zero and the loss goes NaN**. You cannot train in fp16 on MPS.

The correct framing (per the corrected verdict): **avoid fp16; use fp32 or bf16.** bf16 *is* supported on Apple Silicon (M-series) with macOS 14+ in recent PyTorch and needs no gradient scaling — its wider exponent range avoids the underflow. So the choice on the M4 Pro is **fp32 or bf16, not fp32-only**. (The "bf16 blocked at the hardware level" claim in some blogs applies to Intel/AMD Macs, not Apple Silicon.) Set `--mixed_precision='no'` (fp32) or bf16; for the ai-toolkit MPS fork also set `num_workers=0`, `PYTORCH_ENABLE_MPS_FALLBACK=1`, and disable the T5 quantizer.

Draw Things sidesteps all of this with a native Metal pipeline (8-bit quantized base, FP16 main net, **FP32 LoRA net**), which is why it's the cleanest path.

---

## 4. Feasibility on the M4 Pro / 64GB

### SDXL LoRA — runs great locally ✅

**Draw Things (native Metal) is the recommended path for local SDXL LoRA training.** Concrete vendor figures (Draw Things engineering blog, **M2 Ultra**):

- SDXL (3.5B) fine-tune peak memory **~10.3 GiB** — comfortably within 64GB.
- **~14 minutes for 500 steps at 512×512**; effective LoRAs in "as few as 500 steps."

> **Caveat:** these are **M2 Ultra** numbers from a vendor source. The M4 Pro has far fewer GPU cores, so **wall-clock time will be substantially longer** — plan for minutes-to-low-tens-of-minutes for a small SDXL subject LoRA, not the M2 Ultra time. No M4-Pro-specific benchmark has been published; treat this as an extrapolation worth verifying hands-on. The memory figure is also config-specific (512×512, this rank/batch).

Community kohya/diffusers-on-MPS reports vary wildly (one "10 min/step," another "~4 sec/step") — purely configuration-dependent, and the precision footgun above is usually the cause. Draw Things' native path avoids most of it.

### FLUX.1 LoRA — runs, but heavier ⚠️

- **mflux (MLX)** trains FLUX.1 LoRA/DreamBooth natively (since **v0.5.0**), with 4-bit/8-bit quant and `--low-ram` to avoid swapping. Best native FLUX-training route on Mac. **Exact M4 Pro time/memory is not published** — needs a hands-on benchmark.
- **Draw Things** trains FLUX.1 [dev] LoRAs on-device (Metal FlashAttention 2.0 added an experimental backward pass). Reported **~9 sec/step per image at 1024×1024 on M2 Ultra** — again **M2 Ultra; the M4 Pro will be markedly slower**, and FLUX.1 [dev] is ~11–12B params, so this is heavy work. Draw Things also added LoRA training/export for **FLUX.2 [klein] 4B/9B**.
- **ai-toolkit on MPS** works via the hughescr fork but is fiddly; the author warns it is "very unlikely to work on Mac systems with low unified memory" — 64GB helps, but expect 3–5× slower than NVIDIA.

### Needs a cloud GPU ☁️

- **FLUX.2 [dev] (32B)** full-quality LoRA, **Qwen-Image (20B)** heavy LoRA, **DreamBooth full fine-tunes**, and **full checkpoint fine-tunes**.
- FLUX.2 [dev] is a **32B** flow-matching transformer; full precision wants **~80GB VRAM** (FP8 ~32GB). For ai-toolkit dev LoRA training, guides cite **24GB minimum / 80GB recommended**.

**Rough cloud rates (mid-2026 — RunPod fixed, Vast.ai is a dynamic marketplace, so verify at deploy time):**

| Service | GPU | Approx rate |
|---|---|---|
| RunPod | H100 PCIe | ~$2.89/hr |
| RunPod | A100 PCIe | ~$1.39/hr |
| RunPod | RTX 4090 (community) | ~$0.34/hr |
| Vast.ai | RTX 4090 | ~$0.31/hr (dynamic) |
| Vast.ai | A100 80GB | ~$0.67/hr (dynamic) |

A typical FLUX LoRA job (24GB GPU, ~10–30 images, under ~40 min) costs roughly **$0.50–$3** of GPU time on a 4090/A100. Full fine-tunes and 32B models cost more (multi-hour on 80GB).

---

## 5. Every other customization method

| Method | What it's for | Output size | Local on M4 Pro/64GB? |
|---|---|---|---|
| **LoRA** | Subject/style/concept adaptation (above) | Few MB–~200 MB | **Yes** (SDXL easy; FLUX heavier) |
| **Textual inversion** | Optimizes only the text embedding of a new token; freezes the U-Net. Tiny, low control | A few **KB** | **Yes — cheapest/lightest to train locally** |
| **Checkpoint merging** | Weighted average of two+ existing checkpoints. **No training** | Full checkpoint | **Yes** — it's weight arithmetic (supermerger, ComfyUI, kohya merge) |
| **ControlNet** | Structural conditioning (edge/depth/pose/scribble/segmentation maps) | ~1–2.5 GB/model | **Using: yes** (Draw Things/ComfyUI/mflux Canny+depth). **Training a new one: cloud** |
| **IP-Adapter** | Image-prompt: a reference image as visual prompt via decoupled cross-attention. Variants: FaceID, InstantID | ~10s–100s MB | **Using: yes, no training needed** |
| **DreamBooth** | Few-shot subject baked into the weights; highest single-subject fidelity but single-purpose | Full checkpoint (multi-GB) | **Marginal** — SDXL heavy; FLUX/large = cloud. (mflux's "DreamBooth technique" actually outputs a LoRA, not a full fine-tune) |
| **Full fine-tuning** | Update all/most weights to build a new base checkpoint | Full checkpoint | **No — cloud/data-center GPU** |
| **Hypernetworks** | Auxiliary net modifying attention; **largely superseded by LoRA** | ~80–200 MB | Yes but **deprecated** — almost nobody trains new ones |

**Quick decision guide:**
- One person/object, portable → **LoRA** (or **textual inversion** for the lightest touch).
- Exact pose/structure/composition → **ControlNet** (inference).
- "Make it look like *this* reference image," zero training → **IP-Adapter**.
- Abstract concept, minimal data → **textual inversion**.
- Brand-new base knowledge → **full fine-tune** (cloud).
- Combine existing models' looks, no training → **checkpoint merge**.

---

## 6. Licensing — can you sell what you make?

The base model's license flows down to your output and your LoRA. If you intend to **sell** generated images or LoRAs, pick an Apache-2.0 base.

| Model | License | Commercial use |
|---|---|---|
| FLUX.1 [schnell] | Apache-2.0 | ✅ |
| FLUX.2 [klein] **4B** | Apache-2.0 | ✅ |
| Qwen-Image | Apache-2.0 | ✅ |
| SDXL | CreativeML **OpenRAIL++-M** | ✅ (with use restrictions) |
| FLUX.1 [dev] | FLUX.1 [dev] Non-Commercial License v1.1.1 | ❌ Non-commercial |
| FLUX.2 [klein] **9B** | FLUX.2-dev Non-Commercial | ❌ Non-commercial |
| FLUX.2 [dev] **32B** | FLUX.2-dev Non-Commercial | ❌ Non-commercial |

> Note: **4B is a FLUX.2 [klein] size, not a "dev" model.** FLUX.2 [dev] is 32B. The commercially-friendly local-training sweet spot is therefore **SDXL** (OpenRAIL++-M) or **FLUX.2 [klein] 4B** / **Qwen-Image** (Apache-2.0).

---

## 7. Practical bottom line

- **SDXL LoRA → train it locally**, via **Draw Things** (easiest) or OneTrainer/SimpleTuner. ~10 GiB peak; fits the M4 Pro easily; expect tens of minutes (not the M2 Ultra 14 min). Avoid fp16 — use fp32 or bf16.
- **FLUX.1 / FLUX.2 [klein] LoRA → possible locally** via **mflux** or Draw Things, but slow and not yet benchmarked on M4 Pro. Workable for patient, small jobs.
- **FLUX.2 [dev] 32B / Qwen-Image / DreamBooth full / full fine-tunes → rent a cloud GPU.** A 24GB 4090 or A100 at ~$0.30–1.40/hr turns a FLUX LoRA into a **~$0.50–$3** job.
- **No training at all?** Reach for **IP-Adapter** (reference-image transfer) or **ControlNet** (structural control) — both run locally at inference and cover a surprising amount of "customization" without ever training.

**Open questions** (honestly flagged): no M4-Pro-specific training benchmark exists (all numbers are M2 Ultra); mflux's exact FLUX LoRA memory/time on Apple Silicon is unpublished; how much quality a local FLUX.2 [klein] 4B LoRA loses vs a cloud FLUX.2 [dev] 32B / FLUX.1 [dev] LoRA is untested; and live cloud prices (especially Vast.ai's marketplace) shift constantly.
