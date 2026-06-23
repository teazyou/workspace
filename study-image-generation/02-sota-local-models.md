# 02 — SOTA Local-Runnable Generative Models

This file is the **model catalog** for the study: which state-of-the-art text-to-image models you can actually run locally on a 64GB M4 Pro Mac in mid-2026, how they compare on quality / speed / memory / license, and which to pick for a given goal. It defers *how to install and run* each one to [03 — Tools & Install](./03-tools-and-install.md), and *which are practical to fine-tune* to [04 — Customization & LoRA](./04-customization-and-lora.md). For the underlying "can this hardware even do it" question, see [01 — Feasibility](./01-feasibility.md).

> **Hardware context.** Speeds and footprints below assume the study machine: MacBook Pro, M4 Pro, **64GB unified memory**. That 64GB is generous for this class — it clears the ~32GB ceiling that most general guides warn about (they assume 24GB Macs), so several "won't fit" models here are actually *runnable, if slow*. The hard limit on a Mac is **memory bandwidth** (~273 GB/s, roughly 1/4 of an RTX 4090), not capacity, so expect tens of seconds to a few minutes per image — never the "sub-second" figures you see quoted (those are H800 / 4090 GPU numbers).

---

## At-a-glance catalog

| Model | Params | Quality tier | License | Commercial? | Local fit on 64GB M4 Pro |
|---|---|---|---|---|---|
| **FLUX.2 [dev]** | 32B (+24B Mistral 3.1 text enc) | Flagship | FLUX.2 Non-Commercial | No | Runs (FP8/GGUF), slow — 1–3 min/img |
| **FLUX.2 [klein] 4B** | 4B | High, fast | **Apache 2.0** | **Yes** | Great — ~13GB, ~4 steps |
| FLUX.2 [klein] 9B | 9B | High, fast | FLUX.2 Non-Commercial | No | Good, ~4 steps |
| FLUX.1 [dev] | 12B | High | FLUX.1-dev Non-Commercial | No | Great — best Mac tooling |
| FLUX.1 [schnell] | 12B | Good, 4-step | **Apache 2.0** | **Yes** | Great, fast |
| **Qwen-Image** / -2512 | 20B MMDiT (+Qwen2.5-VL) | Top (esp. text) | **Apache 2.0** | **Yes** | Runs well (6/8-bit), FP16 fits |
| **Z-Image Turbo** | 6B | High, 8-step | **Apache 2.0** | **Yes** | Excellent — fits 16GB, ~60–80s |
| Z-Image Base | 6B | High (30–50 step) | **Apache 2.0** | **Yes** | Excellent — best fine-tune base |
| SD 3.5 Large / Turbo | 8B | High | Stability Community | Yes (<$1M rev) | Great |
| SD 3.5 Medium | 2.5B | Mid | Stability Community | Yes (<$1M rev) | Great, small |
| SDXL 1.0 (+Lightning/Hyper/Turbo) | 3.5B | Mid (huge ecosystem) | CreativeML OpenRAIL-M | **Yes (no rev cap)** | Trivial — fastest mature option |
| **HiDream-I1** | 17B | Top-tier | **MIT** | **Yes** | Runs (nf4 ~16GB / fp8) |
| Sana | 0.6B / 1.6B | Mid, ultra-fast | Apache 2.0 (code)* | Yes (code) | Trivial — tiny |
| Lumina-Image 2.0 | ~2.6B | Mid-high | Apache 2.0 | Yes | Trivial |
| Chroma | ~8.9B (de-distilled FLUX.1-schnell) | High | Apache 2.0* | Yes | Good — GGUF ~8–12GB |

\* See *Uncertainties* at the end: Sana's per-checkpoint *weights* license and Chroma's exact param count / license nuance need primary-card verification.

---

## FLUX.2 family (Black Forest Labs) — the 2026 flagship

### FLUX.2 [dev]
The current open-weights **quality leader**. A **32B-parameter** rectified-flow transformer paired with a **Mistral Small 3.1 (24B) multimodal encoder**, which gives it markedly better long / complex prompt adherence than FLUX.1's older T5+CLIP stack. Released **2025-11-25**.

- **License: FLUX.2 Non-Commercial License** — open weights but **commercial use is not permitted**; the commercial route is the FLUX.2 Pro API or a separate paid license.
- **Footprint:** Full BF16 is large — the official Diffusers writeup notes running the transformer + encoder together without offloading needs **>80GB VRAM** (~62GB with CPU offloading); the commonly cited **~64GB** total is the BF16 transformer+encoder bracket. On the study's 64GB Mac, full BF16 un-offloaded is **not** realistic; **FP8 (~32–35GB)** is comfortable, and **GGUF Q4_K_S (~19GB transformer)** or **NF4 (~18–20GB)** are the practical choices.
- **Apple Silicon path:** MPS via Diffusers, a native **Swift-MLX port** (`VincentGourbin/flux-2-swift-mlx`), and GGUF builds (city96, unsloth). See [03](./03-tools-and-install.md).
- **Speed (M4 Pro):** roughly **1–3 minutes per 1024px image** quantized. Honest verdict: *runs, but slow* — a "produce, then walk away" model, not an interactive one. Real 64GB-M4-Pro numbers are still scarce, so treat this as an estimate.

### FLUX.2 [klein] — BFL's fast tier (released 2026-01-15)
Step-distilled to **~4 inference steps**. Two sizes with a **crucial license asymmetry**:

- **FLUX.2 [klein] 4B — Apache 2.0, ~13GB.** *Confirmed* commercial-use-OK on its HF card. This is **the single best permissive, fast, modern option** — fast enough to be interactive on the M4 Pro, supports image-to-image and multi-reference, and effectively replaces the old FLUX.1 [schnell] role.
- **FLUX.2 [klein] 9B — FLUX.2 Non-Commercial License** (uses an 8B Qwen3 text embedder). Higher quality than 4B but **not commercial-usable**.

### FLUX.1 [dev] / [schnell] — prior gen, still the best-supported FLUX on Mac
Both **12B**. Still highly relevant because their **Apple-Silicon tooling is the most mature** of any FLUX:

- **[dev]** — FLUX.1-dev Non-Commercial, ~28 steps, top quality of the pair. Reference: **~50s/image** at 1024px in Draw Things; **50–90s** in ComfyUI (Q6_K, 20 steps) on a 24GB M4 Pro.
- **[schnell]** — **Apache 2.0**, 4-step distilled, ~7× faster, slightly lower quality. The commercial-safe FLUX.1 choice.
- Runs via **MFLUX** (line-by-line MLX port), **DiffusionKit** (Swift CoreML/MLX), GGUF (Q4/Q8 ~7–12GB), and MPS — all detailed in [03](./03-tools-and-install.md). FLUX.1-dev also has an enormous LoRA ecosystem ([04](./04-customization-and-lora.md)), though its license blocks commercial use.

---

## Qwen-Image (Alibaba Tongyi) — the commercial-safe quality pick

A **20B MMDiT** image foundation model with a frozen **Qwen2.5-VL** feature extractor, under **Apache 2.0** — full commercial use. *(Verified: the official blog and HF card both confirm "20B MMDiT" and Apache 2.0; an early "~57B" snippet is unsupported and wrong.)*

- **What it's best at:** complex, **multilingual text rendering** (English + Chinese to near-commercial standard) — the strongest open model for posters, UI mockups, signage, and anything with legible in-image text. Claims #1 across several public benchmarks (GenEval, DPG).
- **Checkpoints:** the base **Qwen-Image** plus refreshed **Qwen-Image-2512** (richer faces / environments). Naming is muddy — a separately marketed "Qwen-Image-2.0 / 7B native-2K" line is also referenced, and exact quality/footprint deltas between checkpoints on the M4 Pro are **not firmly established**; start with **Qwen-Image-2512** and compare.
- **Footprint (Draw Things variants):** **6-bit ~11GB / 8-bit ~16GB / FP16 ~30GB** peak runtime memory (disk: ~16/20/40GB). On 64GB, **even FP16 fits**; 6-bit or 8-bit are the comfortable defaults.
- **Speed (M4 Pro):** tens of seconds to a couple of minutes depending on steps/precision.

**Bottom line: for the best *commercially licensed* quality, Qwen-Image-2512 is the top pick** — it beats the non-commercial FLUX.2 [dev] on license freedom while staying in the same quality conversation, especially for text.

---

## Z-Image (Alibaba Tongyi) — the efficiency story

A **6B** model on a Scalable Single-Stream DiT (S3-DiT) architecture — the standout *quality-per-GB* option of late 2025 / early 2026.

- **Z-Image Turbo** (released 2025-11-26) — *Confirmed:* **Apache 2.0**, **fits comfortably within 16GB**, distilled to **8 effective steps** (its code sets `num_inference_steps=9`, yielding 8 DiT forwards). At launch it ranked #1 among open-source models on Artificial Analysis.
- **Z-Image Base** (released 2026-01-28) — non-distilled raw checkpoint, needs **30–50 steps (CFG 3–5)** but has a higher artistic ceiling. **Apache 2.0**, and the **best Z-Image variant for LoRA / ControlNet fine-tuning** (Draw Things supports Z-Image LoRA training — see [04](./04-customization-and-lora.md)).
- **Speed (M4 Pro):** *Confirmed* ~**60–80s/image** at 1024px (Turbo, ComfyUI MPS) on a 24GB Mac. Caveat: Mac numbers vary *wildly* by tool — ~14s has been reported on an optimized M2 Max, ~160s on an M1 Max. Treat all Z-Image Mac timings as rough; the 64GB M4 Pro should land near the faster end.

**Best quality/speed balance on this hardware.** Apache-licensed, fits with room to spare, and fast enough for comfortable iteration.

---

## Stable Diffusion 3.5 / SDXL (Stability AI) — the best-supported families

| Variant | Params | Steps | License notes |
|---|---|---|---|
| SD 3.5 Large | 8B | ~28 | Stability Community — free commercial **under $1M/yr** revenue |
| SD 3.5 Large Turbo | 8B | **4** (ADD, guidance 0) | same |
| SD 3.5 Medium | 2.5B | ~28 | same |
| SDXL 1.0 | 3.5B | ~25 | **CreativeML OpenRAIL-M — no revenue cap** |
| SDXL Turbo / Lightning / Hyper-SD | 3.5B | **1–8** | OpenRAIL-M base; distill licenses vary |

- **SDXL is the workhorse:** small (~6–7GB), trivially fast on the M4 Pro (**~20–40s** at 1024px, 25 steps, ComfyUI MPS — *confirmed*; SD 3.5 Turbo hits ~2s at 512px in Draw Things), and the **largest LoRA / ControlNet / IP-Adapter ecosystem** by far. Its OpenRAIL-M license has **no revenue cap**, making it more commercial-friendly than SD 3.5.
- **Few-step distillations:** for SDXL, **Lightning** (adversarial + progressive distill) and **Hyper-SD** (trajectory-segmented consistency + human feedback) generally **beat Turbo** on quality at the same low step count; older **LCM** is the weakest. Use these when you want near-instant SDXL output.
- **Apple-Silicon support is the deepest here:** Apple ships official **CoreML** (`apple/ml-stable-diffusion`) *and* native **MLX** (`mlx-examples`) implementations, plus Draw Things, DiffusionBee, and MPS. Details in [03](./03-tools-and-install.md).

---

## Notable newcomers

- **HiDream-I1 (17B, MoE DiT) — MIT license.** Released 2025-04-07 with **Full / Dev (28-step) / Fast (16-step)** variants. **MIT is the most permissive license of any top-tier model here** — fully commercial, no caps, no RAIL clauses. Runs on 64GB via **nf4 (~16GB)**, fp8, or GGUF in ComfyUI. The pick when you want top-tier quality **and** maximal license freedom.
- **Sana (NVIDIA, 0.6B / 1.6B).** Linear-attention DiT, ~20× smaller than FLUX-12B, **ultra-fast and ultra-light** (<4GB), 4K-capable at 1.6B. Quality is below the 8B+ flagships — best for fast iteration or weak hardware. **Code is Apache 2.0**, but *individual weight checkpoints may carry a different license* — verify per file before commercial use.
- **Lumina-Image 2.0 (~2.6B, Apache 2.0).** Small, strong at illustration / concept understanding, commercially safe.
- **Chroma (~8.9B, Apache 2.0).** A community **de-distilled / retrained FLUX.1-[schnell]** base, popular as a **permissive Flux-style fine-tune base** (GGUF ~8–12GB, ComfyUI on MPS). Exact param count and license nuance are **lower-confidence** here — confirm on its HF card before relying on it.

---

## Apple-Silicon caveats (be honest)

- **MPS has gaps.** PyTorch's Metal backend occasionally falls back to CPU for unimplemented ops (sometimes needing `PYTORCH_ENABLE_MPS_FALLBACK=1`), and not every Diffusers feature behaves identically to CUDA.
- **MLX vs GGUF.** Native **MLX** is ~15–40% faster throughput on the same Apple hardware but is Apple-only (no Linux/cloud fallback). **GGUF** is cross-platform with a bigger ecosystem. A *mature, native MLX* path is firmly established for FLUX (MFLUX/DiffusionKit) and SD/SDXL; for **Qwen-Image and Z-Image, the optimized path is mainly Draw Things' Metal implementation** rather than a standalone MLX port — verify current status before committing.
- **Draw Things is the most optimized Mac app** (Metal FlashAttention, ANE support on M4, ~20% faster than ComfyUI MPS) and has first-class support for FLUX.2 klein, Qwen-Image, Z-Image, SD/SDXL, plus on-device LoRA training. See [03](./03-tools-and-install.md).

---

## Tiered recommendations (M4 Pro, 64GB)

- **Best absolute quality:** **FLUX.2 [dev]** (32B) — but *non-commercial* and slow (1–3 min/img). For top quality **with a commercial license**, choose **Qwen-Image-2512** (20B, Apache) or **HiDream-I1** (17B, MIT) instead.
- **Best quality/speed balance:** **Z-Image Turbo** (6B, Apache, 8 steps, fits 16GB) or **FLUX.2 [klein] 4B** (Apache, ~4 steps, ~13GB).
- **Fastest:** **FLUX.2 [klein] 4B/9B**, **Z-Image Turbo**, and **SDXL Turbo / Lightning / Hyper-SD** (1–4 steps, seconds on Mac); ultra-light: **Sana 0.6B**.
- **Most permissive license:** **HiDream-I1 (MIT)** first, then the Apache 2.0 group — Qwen-Image, Z-Image, FLUX.1-schnell, FLUX.2-klein-4B, Sana (code), Lumina-2, Chroma — and SDXL (OpenRAIL-M, no revenue cap). **Avoid for commercial work:** FLUX.2-dev, FLUX.2-klein-9B, FLUX.1-dev.
- **Best base for fine-tuning** (full treatment in [04](./04-customization-and-lora.md)): **Z-Image Base** (non-distilled, Apache, Draw Things LoRA training) and **SDXL** (largest ecosystem); **Chroma** for permissive Flux-style fine-tunes.

---

## Uncertainties to flag

1. **Qwen-Image checkpoint choice** — base vs 2512 vs the marketed "2.0 / 7B" line; relative quality/footprint on M4 Pro not firmly benchmarked. Start with **2512**.
2. **FLUX.2 real Mac speeds** — most published numbers are 24GB Macs or NVIDIA GPUs; true 64GB-M4-Pro figures for [dev] and [klein] are still thin.
3. **Sana weights license** — code is Apache 2.0; per-checkpoint weight licenses may differ.
4. **Chroma** — exact ~8.9B param count and precise license/status need primary HF-card verification.
5. **Native MLX (not just MPS/GGUF) for Qwen-Image / Z-Image** — uncertain whether a mature standalone MLX path exists beyond Draw Things' Metal backend.
