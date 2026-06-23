# SOTA Local-Runnable Generative Models — Raw Research Notes

> Topic: catalog of SOTA text-to-image models runnable LOCALLY on Apple Silicon (M4 Pro, 64GB unified memory, macOS).
> Date of research: 2026-06-23. Field moves fast; all facts web-verified below with URLs.
> Hardware target: MacBook Pro M4 Pro, 64GB unified memory. NOTE: 64GB is generous for this class — it clears the usual <32GB ceiling that blocks full FLUX, so the FP16/BF16 footprints below are mostly *runnable* (if slow) rather than crash-inducing.

---

## TL;DR catalog (mid-2026)

| Model | Params | Quality tier | License | Commercial? | Apple-Silicon path | Approx footprint (quantized) |
|---|---|---|---|---|---|---|
| FLUX.2 [dev] | 32B (+24B Mistral text enc) | Top / flagship | FLUX.2 Non-Commercial | NO (open weights) | MPS (Diffusers), native Swift-MLX port, GGUF | Q4 GGUF ~19GB transformer; FP16 ~64GB total |
| FLUX.2 [klein] 4B | 4B | High, fast | Apache 2.0 | YES | MPS, ComfyUI GGUF, Draw Things | ~13GB VRAM |
| FLUX.2 [klein] 9B | 9B | High, very fast (4 steps) | FLUX.2-dev Non-Commercial | NO | MPS, Draw Things, GGUF | larger; sub-second on GPU |
| FLUX.1 [dev] | 12B | High | FLUX.1-dev Non-Commercial | NO | MFLUX (MLX), DiffusionKit, MPS, GGUF | Q4/Q8 GGUF ~7–12GB |
| FLUX.1 [schnell] | 12B | Good, 4-step | Apache 2.0 | YES | MFLUX (MLX), DiffusionKit, MPS | ~7–12GB GGUF |
| Qwen-Image / -2512 | 20B MMDiT (+Qwen2.5-VL) | Top (text rendering) | Apache 2.0 | YES | Draw Things, MPS (Diffusers), qwen-image-mps | 6-bit ~11GB / 8-bit ~16GB / FP16 ~30GB |
| Z-Image Turbo | 6B | High, 8-step | Apache 2.0 | YES | MPS, ComfyUI, Draw Things | fits 16GB; ~60-80s on M4 Pro |
| Z-Image Base | 6B | High (30-50 step) | Apache 2.0 | YES | same as Turbo | fits 16GB |
| SD 3.5 Large | 8B | High | Stability Community License | YES (<$1M rev) | CoreML (apple/ml-stable-diffusion), MPS, Draw Things | ~8-16GB quantized |
| SD 3.5 Large Turbo | 8B | High, 4-step (ADD) | Stability Community License | YES (<$1M rev) | CoreML, MPS, Draw Things | ~8-16GB |
| SD 3.5 Medium | 2.5B | Mid | Stability Community License | YES (<$1M rev) | CoreML, MPS | ~5GB |
| SDXL 1.0 | 3.5B | Mid (mature ecosystem) | CreativeML OpenRAIL-M | YES (no rev cap) | CoreML, MLX (mlx-examples), Draw Things, MPS | ~6-7GB |
| SDXL Turbo/Lightning/Hyper | 3.5B | Mid, 1-8 step | OpenRAIL-M (+ distill licenses vary) | mostly YES | CoreML, MLX, Draw Things | ~6-7GB |
| HiDream-I1 | 17B | Top-tier (benchmarks) | MIT | YES | MPS, GGUF/fp8/nf4 (ComfyUI) | nf4 ~16GB; fp8 larger |
| Sana (0.6B / 1.6B) | 0.6B / 1.6B | Mid, ULTRA fast | Apache 2.0 (code; weights vary) | YES (code) | MPS; tiny | <4GB |
| Lumina-Image 2.0 | ~2.6B | Mid-high | Apache 2.0 | YES | MPS | small |
| Chroma | ~8.9B (FLUX.1-schnell base, de-distilled) | High, uncensored | Apache 2.0 | YES | MPS, GGUF, ComfyUI | GGUF ~8-12GB |

---

## FLUX.2 family (Black Forest Labs) — the 2026 flagship

### FLUX.2 [dev]
- **32 billion parameters** (transformer). Released **2025-11-25**.
- Text encoder: **Mistral Small 3.1 (24B)** multimodal VLM encoder — much better long/complex-prompt handling than FLUX.1's T5+CLIP.
- License: **FLUX.2 Non-Commercial License** — commercial use NOT allowed for open weights; commercial route is the FLUX.2 Pro API or a separate commercial license.
- Footprint: FP16 ~**64GB** total (32B transformer + 24B encoder); FP8 ~**32-35GB**; NF4 ~**18-20GB**; GGUF **Q4_K_S ~19GB** transformer.
- Recommended steps: ~28 (50 in full examples).
- Apple Silicon: official code comment says "switch to 'mps' for apple devices." Native **Swift-MLX** port exists: `github.com/VincentGourbin/flux-2-swift-mlx`. Also GGUF via city96 + unsloth.
- On M4 Pro: expect **1-3 minutes/image** with GGUF/quantized at 32GB+. 64GB makes FP8 comfortable. Slow but runnable.
- Sources: https://huggingface.co/black-forest-labs/FLUX.2-dev ; https://github.com/black-forest-labs/flux2 ; https://huggingface.co/black-forest-labs/FLUX.2-dev/blob/main/LICENSE.txt ; https://huggingface.co/unsloth/FLUX.2-dev-GGUF ; https://huggingface.co/city96/FLUX.2-dev-gguf ; https://github.com/VincentGourbin/flux-2-swift-mlx ; https://www.spheron.network/blog/deploy-flux2-gpu-cloud-production-guide/

### FLUX.2 [klein] — released 2026-01-15 (BFL's fastest)
- Two sizes: **4B** and **9B**. Both **step-distilled to ~4 inference steps** for sub-second generation on GPU.
- **klein 4B**: **Apache 2.0** (commercial OK). ~**13GB VRAM**. Runs on RTX 3090/4070-class; great on M4 Pro. Supports image-to-image + multi-reference.
- **klein 9B**: **FLUX.2-dev Non-Commercial License** (NOT commercial). Uses an 8B Qwen3 text embedder. Single + multi-reference.
- *NOTE the license asymmetry: 4B = Apache, 9B = non-commercial. This makes klein 4B one of the best permissive fast options.*
- klein replaces the older FLUX.1 [schnell] role.
- Sources: https://huggingface.co/black-forest-labs/FLUX.2-klein-4B ; https://www.apatero.com/blog/flux-2-klein-apache-license-commercial-use ; https://docs.jarvislabs.ai/tutorials/running-flux2-klein ; https://localaimaster.com/blog/flux-2-local-setup-guide

### FLUX.1 [dev] / [schnell] — prior gen, still very relevant on Mac
- Both **12B** parameters.
- **[dev]**: FLUX.1-dev Non-Commercial license (guidance-distilled, 28 steps, top quality of the pair). NO commercial.
- **[schnell]**: **Apache 2.0** (commercial OK), distilled to **4 steps**, ~7x faster, slightly lower quality.
- Apple Silicon: best-supported of all FLUX on Mac. **MFLUX (MacFLUX)** = line-by-line MLX port of Diffusers FLUX (`github` mflux). **DiffusionKit** (argmaxinc) = Swift + CoreML/MLX on-device. Also GGUF (Q4/Q8 ~7-12GB) and plain MPS.
- M4 Pro (24GB) reference: ~**50s/image** at 1024² for Flux Dev in Draw Things; ComfyUI MPS ~50-90s (Q6_K, 20 steps); DiffusionBee ~6 min (slow). 64GB will be faster/more headroom.
- Sources: https://huggingface.co/black-forest-labs/FLUX.1-dev ; https://github.com/black-forest-labs/flux/blob/main/model_licenses/LICENSE-FLUX1-schnell ; https://github.com/argmaxinc/DiffusionKit ; https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/

---

## Qwen-Image (Alibaba Tongyi)
- **20B MMDiT** image foundation model + **Qwen2.5-VL** (frozen) for text/image feature extraction.
- License: **Apache 2.0** — full commercial use. (One early search result said "~57B"; that conflicts with all official sources — see Conflicts.)
- **Qwen-Image-2512** = refreshed checkpoint (richer faces, better environment vs the Aug release). A separate "Qwen-Image-2.0 / 7B native-2K" line is also referenced in marketing pages.
- SOTA at complex multilingual **text rendering** (English + Chinese to commercial standard); claims #1 on 9 public benchmarks (GenEval, DPG).
- Apple Silicon: first-class in **Draw Things** (variants: FP16 ~30GiB / 8-bit ~16GiB / 6-bit ~11GiB peak runtime VRAM; disk 40GB BF16 / 20GB 8-bit / 16GB 6-bit). Also `qwen-image-mps` (ivanfioravanti) and `qwen-image-macos` (zsxkib, w/ Lightning LoRA 4-8 step). Runs on Apple devices from past ~5 years.
- M4 Pro 64GB: 6-bit/8-bit comfortable; FP16 fits. Expect tens of seconds to a couple minutes depending on steps.
- Sources: https://github.com/QwenLM/Qwen-Image ; https://qwenlm.github.io/blog/qwen-image/ ; https://huggingface.co/Qwen/Qwen-Image-2512 ; https://releases.drawthings.ai/p/introducing-qwen-image-support ; https://wiki.drawthings.ai/wiki/Qwen_Image ; https://github.com/ivanfioravanti/qwen-image-mps ; https://github.com/zsxkib/qwen-image-macos

---

## Z-Image (Alibaba Tongyi) — the efficiency story of late 2025/early 2026
- **6B parameters**, **Scalable Single-Stream DiT (S3-DiT)** architecture (text + visual-semantic + VAE tokens concatenated into one stream).
- **Z-Image Turbo**: released **2025-11-26/27**. **Apache 2.0** (commercial OK). Distilled, **8 NFEs** (~8 DiT forwards; example uses num_inference_steps=9). Fits **16GB** VRAM. Sub-second on H800; ranks #1 among open-source on Artificial Analysis at launch, ~#8 overall vs proprietary.
- **Z-Image Base**: released **2026-01-28**, non-distilled raw checkpoint. Needs **30-50 steps (CFG 3-5)** but higher artistic ceiling. Best Z-Image variant for **LoRA / ControlNet fine-tuning**. Apache 2.0.
- **Z-Image Edit**: image-editing variant.
- Apple Silicon: MPS device option; runs in **ComfyUI** and **Draw Things** (Draw Things supports Z-Image LoRA training). One-click community launchers exist.
- M4 Pro 24GB reference: Turbo ~**60-80s/image** at 1024² (ComfyUI). Reported ~14s on M2 Max with optimized setups — Apple-Silicon numbers vary a lot by tool. 64GB M4 Pro should be comfortable and likely faster.
- Sources: https://huggingface.co/Tongyi-MAI/Z-Image-Turbo ; https://huggingface.co/Tongyi-MAI/Z-Image ; https://github.com/Tongyi-MAI/Z-Image ; https://comfyui-wiki.com/en/news/2025-11-27-alibaba-z-image-turbo-release ; https://comfyui-wiki.com/en/news/2026-01-28-alibaba-z-image-base-release ; https://www.rundiffusion.com/z-image ; https://z-image.me/en/blog/How_to_Use_Z-Image_on_Mac_en

---

## Stable Diffusion 3.5 / SDXL (Stability AI)
- **SD 3.5 Large**: **8B** params, MMDiT. **SD 3.5 Large Turbo**: 8B + **Adversarial Diffusion Distillation (ADD)**, **4 steps**, guidance_scale=0.0. **SD 3.5 Medium**: **2.5B**.
- License: **Stability AI Community License** — free commercial for orgs under **$1M/yr revenue**; above that requires Enterprise license. (More restrictive than SDXL.)
- **SDXL 1.0**: **3.5B**. License: **CreativeML OpenRAIL-M** (permissive, NO revenue cap) — still the most license-friendly of the Stability line.
- SDXL distillations: **Turbo** (adversarial distill, 1-4 step), **Lightning** (adversarial + progressive distill, generally higher quality than Turbo), **Hyper-SD** (trajectory-segmented consistency + human feedback, accurate few-step), **LCM** (older, lower quality). Trade: fewer steps = much faster but reduced fine detail / diversity. Lightning & Hyper > Turbo > LCM in typical quality.
- Apple Silicon: **best-supported family**. Apple's official **apple/ml-stable-diffusion** (CoreML), **mlx-examples** stable diffusion (native MLX), Draw Things, DiffusionBee, MPS. SDXL is small and fast on M4 Pro.
- M4 Pro 24GB reference: SDXL 1024² ~**20-40s** (ComfyUI MPS, 25 steps), ~1-2 min in DiffusionBee; SD 3.5 Turbo 512² ~**2s** in Draw Things. SD 1.5 512² ~5-10s. 64GB trivially handles all.
- Sources: https://stability.ai/news-updates/introducing-stable-diffusion-3-5 ; https://huggingface.co/stabilityai/stable-diffusion-3.5-medium ; https://huggingface.co/stabilityai/stable-diffusion-3.5-large-turbo ; https://github.com/apple/ml-stable-diffusion ; https://www.felixsanz.dev/articles/sdxl-lightning-quick-look-and-comparison ; https://stable-diffusion-art.com/hyper-sdxl/ ; https://www.baseten.co/blog/comparing-few-step-image-generation-models/

---

## Notable newcomers

### HiDream-I1 (HiDream-ai)
- **17B params**, sparse Mixture-of-Experts Diffusion Transformer (MoE DiT). Released **2025-04-07**.
- License: **MIT** — fully permissive incl. commercial. (One of the most permissive of any top-tier model.)
- Variants: **Full**, **Dev** (28 steps), **Fast** (16 steps). Strong on benchmarks (claimed SOTA at launch).
- Apple Silicon: ComfyUI with fp8 / **GGUF** / **nf4** quant (nf4 ~16GB); MPS. Large but feasible on 64GB.
- Sources: https://github.com/HiDream-ai/HiDream-I1 ; https://huggingface.co/HiDream-ai/HiDream-I1-Full ; https://arxiv.org/html/2505.22705v1 ; https://comfyui-wiki.com/en/tutorial/advanced/image/hidream/i1-t2i

### Sana (NVIDIA NVlabs)
- **0.6B and 1.6B** linear-attention DiT. ~20x smaller than Flux-12B, >100x throughput. 4K-capable (1.6B).
- License: **code Apache 2.0** (relicensed 2025-01-11). Weights license should be confirmed per-checkpoint.
- Ultra-fast, ultra-light — great for fast iteration / weak hardware. Quality below the 8B+ flagships.
- Sources: https://github.com/NVlabs/Sana ; https://nvlabs.github.io/Sana/ ; https://github.com/NVlabs/Sana/blob/main/LICENSE

### Lumina-Image 2.0
- ~2.6B. **Apache 2.0**. Strong at illustration / concept understanding. Apache makes it commercially safe.
- Sources: https://www.singleapi.net/2025/02/11/lumina-image-2-0/

### Chroma
- ~**8.9B**, a **de-distilled / retrained FLUX.1-[schnell]** base, **Apache 2.0**, fully open + uncensored, community-trained. Popular as a permissive fine-tune base. GGUF available; runs in ComfyUI on MPS.
- (Lower-confidence on exact param count — verify on its HF card.)

---

## Apple-Silicon caveats (be honest)
- **MPS (PyTorch Metal) has gaps**: some ops fall back to CPU or are unimplemented, occasionally causing slowdowns or needing `PYTORCH_ENABLE_MPS_FALLBACK=1`. Not all Diffusers features work identically to CUDA.
- **MLX vs GGUF**: MLX is ~15-40% faster throughput on the same Apple hardware but is Apple-only (no Linux/cloud fallback). GGUF is cross-platform with a bigger ecosystem. (contracollective, famstack benchmarks.)
- **Speed vs NVIDIA**: M4 Pro memory bandwidth ~273 GB/s — about **1/4 of an RTX 4090** and **half the M4 Max**. Capacity (64GB) is huge, but bandwidth bounds diffusion speed. Expect tens of seconds (SDXL/Z-Image-Turbo) to minutes (FLUX.2/Qwen-Image full) per image. "Sub-second" claims are H800/4090 numbers, NOT Mac.
- **Draw Things** is the most optimized Mac app (SwiftUI + Metal FlashAttention, ANE support for M4 + 8-bit S models, up to ~2x speedup; ~20% faster than ComfyUI MPS). Strong choice for FLUX.2 klein, Z-Image, Qwen-Image, plus LoRA training.
- **64GB advantage**: clears the <32GB ceiling that the general guides warn about (which assume 24GB Macs). FP8 FLUX.2 and FP16 Qwen-Image both fit.
- Sources: https://contracollective.com/blog/gguf-vs-mlx-quantization-formats-apple-silicon-2026 ; https://famstack.dev/guides/mlx-vs-gguf-apple-silicon/ ; https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/

---

## Tiered recommendations (M4 Pro, 64GB)

- **Best overall quality**: **FLUX.2 [dev]** (32B) for max fidelity/prompt-handling — but non-commercial. Close rivals with commercial licenses: **Qwen-Image-2512** (20B, Apache) and **HiDream-I1** (17B, MIT).
- **Best quality/speed balance**: **Z-Image Turbo** (6B, Apache, 8 steps, fits 16GB) or **FLUX.2 [klein] 4B** (Apache, 4 steps, ~13GB).
- **Fastest**: **FLUX.2 [klein] 4B/9B** and **Z-Image Turbo**; ultra-light: **Sana 0.6B**, **SDXL Turbo/Lightning** (1-4 step, seconds on Mac).
- **Most permissive license**: **HiDream-I1 (MIT)**, then Apache 2.0 group: **Qwen-Image, Z-Image, FLUX.1-schnell, FLUX.2-klein-4B, Sana, Lumina-2, Chroma, SDXL (OpenRAIL-M, no rev cap)**. Avoid for commercial: FLUX.2-dev, FLUX.2-klein-9B, FLUX.1-dev.
- **Best base for fine-tuning**: **Z-Image Base** (non-distilled, Apache, Draw Things LoRA training) and **SDXL** (largest LoRA/ControlNet ecosystem). FLUX.1-dev has a huge LoRA ecosystem but non-commercial. **Chroma** (Apache, de-distilled FLUX) for permissive Flux-style fine-tuning.

---

## Conflicts / uncertainty to flag
1. **Qwen-Image param count**: one search snippet claimed "~57B"; all official/primary sources say **20B MMDiT** (+ frozen Qwen2.5-VL encoder, which inflates total disk). Treating 20B as correct. Also a separate "Qwen-Image-2.0 / 7B" marketing line exists — version naming is muddy; verify which checkpoint.
2. **Z-Image Mac speed**: 14s (M2 Max) vs 60-80s (M4 Pro ComfyUI) — huge spread, entirely tool/precision dependent. Treat Mac speed numbers as rough.
3. **Chroma exact params (~8.9B) and licensing nuance** — lower confidence; verify on HF.
4. **Sana weights license** — code is Apache 2.0; individual weight checkpoints may differ. Verify per file.
5. FLUX.2-dev FP16 "~64GB" total figure comes from secondary blogs (Spheron/botmonster), not the official card — directionally right but verify.
