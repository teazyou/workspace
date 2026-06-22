# Annex: LoRA & Fine-Tuning on Apple Silicon (and why it's mostly irrelevant to your task)

**Bottom line up front:** You explicitly asked for "the best local image AI I can get" and a LoRA annex, so here it is — but read this first. **LoRA fine-tuning does nothing for your stated goal.** Your rule (isolate the character, composite onto solid black) is a *segmentation/matting* problem solved by an alpha-mask model (see [Section 02](02-the-task-method.md)). A LoRA fine-tunes a *generative* diffusion model's style or subject — it changes what the model *paints*, not how cleanly a subject is cut out. If isolation accuracy is poor on a specific art style, the correct fix is to **fine-tune a segmentation model (e.g. BiRefNet), not train a LoRA** — a different discipline covered at the end. The rest of this annex is for the *separate_ future case where you want to generate or creatively repaint content. For that: on a 48 GB M4, **SDXL and FLUX.1 LoRA training is realistic via Draw Things or mflux; FLUX.2/Qwen LoRA is borderline-to-broken on Mac — rent a cloud GPU for those.** And before training anything, try the **no-training** options (IP-Adapter / ControlNet), which often achieve the intent in minutes.

---

## 1. The relevance caveat (read this or skip the annex)

| Your goal | What it needs | Does LoRA help? |
|---|---|---|
| Character on solid black background | Alpha mask (segmentation/matting) → composite | **No.** Zero effect on mask quality. |
| Generate *new* art in a specific style | Style LoRA on a diffusion model | Yes — but this is a different goal. |
| Generate a *specific recurring character* | Subject LoRA / DreamBooth | Yes — different goal. |
| Improve cut-out accuracy on one art style | Fine-tune a *segmentation* model on labeled mattes | A LoRA is the wrong tool; see [§7](#7-the-actually-relevant-training-fine-tuning-a-segmentation-model). |

LoRA, DreamBooth, and textual inversion are all techniques for teaching a **generative** model a concept. Your pipeline (Section 02) never generates pixels — it masks and composites. So nothing in sections 1–6 below changes your wallpaper output. Keep that framing.

---

## 2. Feasibility on a 48 GB M4 (verdict table)

The chip variant matters. 48 GB points to an **M4 Pro** (~16–20 GPU cores, ~273 GB/s memory bandwidth); it *could* be an **M4 Max** (~32–40 cores, ~410–546 GB/s, roughly 2× throughput). Both are far below a datacenter A100/H100. Treat all Mac time estimates as "M4 Pro slow / M4 Max ~2× faster," and remember every figure below is for *generative* LoRA training, not your task.

| Training target | On 48 GB M4? | Tool | Reality |
|---|---|---|---|
| **SDXL LoRA** | Realistic | Draw Things (easiest), kohya_ss (fiddly) | Hours, not minutes. Works. |
| **FLUX.1 [dev] LoRA** | Realistic (quantized) | Draw Things, mflux | Slow (~seconds–tens of seconds/step). 48 GB is enough with quant. |
| **FLUX.2 / Qwen / Klein LoRA** | Borderline → often broken | ai-toolkit (CUDA-first) | 48 GB is tight; MPS convergence failures reported. **Use cloud.** |
| **Full fine-tune / DreamBooth (full weights)** | No (FLUX-scale) | — | Out of scope on Mac; rent a GPU. |

**Key Apple-Silicon gaps vs CUDA:**
- **`bitsandbytes` 4-bit quant is CUDA-only.** The big memory win (cuts FLUX LoRA peak ~60 GB → ~37 GB, or under 10 GB with cached latents) **is unavailable on MPS.** This is the single biggest reason Mac training is memory-pressured.
- **No xFormers / FlashAttention CUDA kernels.** MPS uses its own attention (Draw Things ships Metal FlashAttention v2, a notable exception); generic PyTorch-on-MPS is slower per step.
- **MPS numerical instability.** Reported NaN losses with cached embeds + high LR, and fp16 OOM where the allocator over-commits (ai-toolkit issue #871).
- **Tooling is CUDA-first.** kohya_ss and ai-toolkit treat macOS as best-effort; you often need community forks.

---

## 3. Recommended Mac tools (if you do want to train generatively)

### Draw Things — best "it just works" path on Mac
Free Mac/iOS app with **built-in LoRA training on Apple Silicon** using Metal (no PyTorch/MPS breakage). Trains SDXL, SD1.5, SD3 Medium 3.5, FLUX.1 [dev], Kwai Kolors, and in 2026 added **FLUX.2 [klein] 4B/9B, Z-Image, and Qwen Image**. Built-in DreamBooth-style personalization. Metal FlashAttention v2 cuts RAM ~20–25%; the team reports it's the only efficient macOS app that both *infers and fine-tunes* FLUX.1 [dev] (11B). Benchmark: ~**9 sec/step/image @1024** for a FLUX.1 LoRA *on an M2 Ultra* — your M4 Pro will be slower, M4 Max closer. GUI-driven, so the lowest-friction option.

### mflux — MLX-native, scriptable
Line-by-line MLX port of Diffusers FLUX; runs natively on Apple Silicon (no PyTorch/MPS). **LoRA fine-tuning via DreamBooth since v0.5.0**; 2026 releases added FLUX.2 + Z-Image training adapters, local-model training, and expanded LoRA key-mapping. Config-file driven (config + image folder + captions). Best when you want a CLI you can wire into a script. (No SDXL — it's the FLUX/Z-Image line.)

### kohya_ss / sd-scripts — possible but painful
macOS support is "may vary"; Linux is the maintained target. SDXL LoRA runs but needs gradient checkpointing (speed hit), lacks the bitsandbytes/xFormers optimizations, and is materially slower per step than NVIDIA. Use only if you need its specific knobs.

### ai-toolkit (ostris) — the standard, but not on Mac
The de-facto tool for FLUX.2 / Z-Image / Qwen — **CUDA-first.** On Apple Silicon you need a fork (`hughescr/ai-toolkit` or `poyen-wu/ai-toolkit-mps`) with MPS patches (torch.amp, spawn not fork, T5 quantizer disabled, `num_workers=0`). Even then, issue **#871** documents extensive FLUX.2-dev attempts that **failed to converge** (loss oscillation, fp16 OOM, NaN with cached embeds), with no working config and no maintainer confirmation that MPS is supported. **Treat ai-toolkit-on-Mac as experimental.** Run it on a cloud GPU instead.

---

## 4. The realistic path for serious training: rent a GPU, infer locally

For anything heavier than an SDXL/FLUX.1 LoRA — and especially FLUX.2/Qwen — the honest recommendation is:

> **Rent a cloud GPU for the few hours of training, download the small LoRA file, run inference locally on the Mac (Draw Things / mflux).**

Training is the only memory- and ecosystem-hungry step; the resulting LoRA is tiny (~10–300 MB) and runs fine locally. Cloud gives you the full CUDA stack (bitsandbytes, xFormers, ai-toolkit as-designed) and finishes in minutes.

| Provider | GPU | ~Price (2026) | Notes |
|---|---|---|---|
| RunPod | A100 40GB | ~$1.29–1.39/hr | Great cost/perf for LoRA; billed by ms |
| RunPod | L40S 48GB | ~$1/hr range | 48 GB, good for FLUX.2/Qwen |
| RunPod | H100 PCIe/SXM | ~$2.65–2.89/hr | Fastest; overkill for a single LoRA |
| Replicate / fal.ai | managed | per-run | **No infra** — managed FLUX LoRA trainers; easiest |
| Google Colab | T4/A100 | free–cheap | Session limits; fine for small jobs |
| Civitai trainer | managed | credits | Click-to-train FLUX/SDXL LoRA |

A typical SDXL or FLUX.1 LoRA finishes in ~20–60 min on an A100 → roughly **$1–2 total**. FLUX.2 takes longer. This is usually cheaper and far less frustrating than fighting MPS.

---

## 5. Step outline (generative LoRA, Draw Things example)

1. **Collect a dataset.** Subject LoRA: 10–30 high-quality images, varied pose/lighting/background, consistent subject. Style LoRA: 20–100 images of the style. Use 1024 px.
2. **Caption** with a unique trigger word (Draw Things and ai-toolkit can auto-caption).
3. **Pick base model** (SDXL for speed/ecosystem; FLUX.1 [dev] for quality).
4. **Set rank 16–32, ~1000–3000 steps** (subject end of range; watch for overfitting if few images / many steps).
5. **Train.** Draw Things: GUI, runs on Metal. mflux: point a config at the image folder.
6. **Test** at several LoRA scales (0.6–1.0); iterate captions/steps if identity/style is weak.
7. **Use** the LoRA at inference (see [Section 04](04-install-guide.md) for the local inference stack).

---

## 6. No-training alternatives (try these before any LoRA)

These often achieve the *generative* intent without training at all — relevant only if you later want generation, still not for the black-bg task.

| Technique | What it does | When to use |
|---|---|---|
| **IP-Adapter** | Feed a reference image: "make it look like this subject/style," no training | Quick style/subject transfer; orders of magnitude cheaper than fine-tuning |
| **IP-Adapter-FaceID** | Consistent identity across contexts | Reuse a face/character without a LoRA |
| **ControlNet** | Structural control (pose, depth, canny, composition) | Lock layout/pose |
| **ControlNet + IP-Adapter** | Structure (ControlNet) + style (IP-Adapter) together | The common no-train combo (cf. ICAS) |

Rule of thumb: **IP-Adapter for fast, composable, no-wait results; LoRA only for long-term identity recall** of a recurring subject/style. None of these touch segmentation.

---

## 7. The actually-relevant training: fine-tuning a *segmentation* model

If your wallpapers are a specific art style (e.g. anime) and the off-the-shelf matting model from [Section 02](02-the-task-method.md) cuts out hair/edges poorly, **this** is the training you'd actually do — and it's not LoRA:

- **Discipline:** supervised image matting / dichotomous segmentation. You fine-tune a model like **BiRefNet** (or RMBG-2.0) on labeled data.
- **Data:** pairs of `RGB image → ground-truth alpha matte` (RGBA). This is the expensive part — you need accurate masks, not just images.
- **Precedent — ToonOut (2025):** fine-tuned BiRefNet on **1,228 annotated anime images**, lifting pixel accuracy **95.3% → 99.5%** on anime characters (complex hair, transparency, stylized edges). Code/weights/dataset open-sourced (`MatteoKartoon/BiRefNet`; dataset `joelseytre/toonout`).
- **Off-the-shelf shortcut:** for anime, try **`isnet-anime`** (rembg) before training anything — it's purpose-built and may remove the need entirely.
- **Feasibility on Mac:** BiRefNet fine-tuning is far lighter than diffusion LoRA and is plausible on a 48 GB M4, but — like all PyTorch-on-MPS — expect slower steps than CUDA; a short cloud rental is again the path of least resistance.

This is the only "training" that would improve your stated black-background pipeline. A diffusion LoRA would not.

---

## Sources
- mflux: https://github.com/filipstrand/mflux • https://github.com/filipstrand/mflux/releases
- Draw Things LoRA training: https://wiki.drawthings.ai/wiki/LoRA_Training
- Draw Things engineering (fine-tuning / Metal FlashAttention v2): https://engineering.drawthings.ai/p/draw-things-democratizes-local-large-model-fine-tuning-on-iphone-ipad-and-mac-2ceb60b5b462 • https://engineering.drawthings.ai/p/metal-flashattention-2-0-pushing-forward-on-device-inference-training-on-apple-silicon-fe8aac1ab23c
- Draw Things 2026 review: https://www.heyuan110.com/posts/ai/2026-02-15-draw-things-ultimate-guide/
- ai-toolkit: https://github.com/ostris/ai-toolkit • MPS issue #871: https://github.com/ostris/ai-toolkit/issues/871 • MPS fork: https://github.com/poyen-wu/ai-toolkit-mps • hughescr fork: https://github.com/hughescr/ai-toolkit
- Mac FLUX training: https://huggingface.co/blog/AlekseyCalvin/mac-flux-training
- kohya_ss: https://github.com/bmaltais/kohya_ss • M1 issue: https://github.com/bmaltais/kohya_ss/issues/1248 • sd-scripts: https://github.com/kohya-ss/sd-scripts
- LoRA training guide 2026 (VRAM): https://sanj.dev/post/lora-training-2025-ultimate-guide/
- FLUX QLoRA on consumer HW: https://huggingface.co/blog/flux-qlora
- RunPod pricing: https://www.runpod.io/pricing • GPU pricing 2026: https://www.spheron.network/blog/gpu-cloud-pricing-comparison-2026/
- ToonOut (segmentation fine-tune): https://arxiv.org/html/2509.06839v1 • dataset: https://huggingface.co/datasets/joelseytre/toonout
- BiRefNet: https://github.com/zhengpeng7/birefnet • RMBG-2.0: https://huggingface.co/briaai/RMBG-2.0 • ComfyUI-RMBG: https://github.com/1038lab/ComfyUI-RMBG
- IP-Adapter: https://huggingface.co/docs/diffusers/using-diffusers/ip_adapter • ICAS: https://arxiv.org/html/2504.13224v1
- MLX fine-tuning guide: https://insiderllm.com/guides/fine-tuning-mac-lora-mlx/
