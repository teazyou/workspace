# SOTA Local Generative Image Models for a 48 GB Apple-Silicon Mac (2026)

**Bottom line up front.** If you want the *best* open-weight image generator you can comfortably run locally on a 48 GB M4-class Mac, the practical answer in mid-2026 is a two-horse race: **FLUX.2 [dev]** (32B, highest open quality, but heavy and non-commercial) and **Qwen-Image / Qwen-Image-2512** (20B, currently the #1-ranked open model on blind-test arenas, Apache-2.0, strong text + editing). For the best *speed-to-quality* and a clean commercial license, **Z-Image-Turbo** (6B, 8-step) and **FLUX.2 [klein] 4B** are the standouts; for the deepest *editing* toolkit (img2img, inpaint, ControlNet, IP-Adapter) on existing wallpapers, the mature **SDXL** ecosystem and **FLUX.1 [dev]** still win on tooling breadth. **Important honesty caveat that this whole study turns on:** none of these are needed for the user's stated task (isolate characters onto black) — that is a segmentation/matting job (see `02-the-task-method.md`). This catalog exists to answer the separate "best local image AI I can get" ask and to feed the LoRA annex (`05-annex-lora-training.md`). For the recommended runtime/install path see `04-install-guide.md`; for the hardware verdict see `01-feasibility.md`.

---

## How to read this on a 48 GB Mac

48 GB of unified memory is the comfortable sweet spot for local image gen on Apple Silicon: the GPU can address ~36–44 GB, which is enough to run **FLUX.1 [dev] and SDXL at full fp16**, and to run the largest models (FLUX.2 dev 32B, Qwen-Image 20B) at 4-bit/GGUF or FP8 with headroom. The 24 GB tier forces GGUF quant for FLUX; 48 GB "unlocks fp16" per Draw Things' own benchmarks.

**Chip variant changes speed, not capability.** Everything below runs on M4 / M4 Pro / M4 Max; the difference is throughput, which tracks GPU-core count and memory bandwidth:

| Chip | GPU cores | Mem bandwidth | Relative image-gen speed |
|------|-----------|---------------|--------------------------|
| M4 | 10 | ~120 GB/s | 1.0x (baseline) |
| **M4 Pro (most likely for 48 GB)** | 16–20 | ~273 GB/s | ~1.8–2.2x |
| M4 Max | 32–40 | ~410–546 GB/s | ~3.5–4x |

A 48 GB config is almost certainly an **M4 Pro** (base M4 Air/Pro cap at 24–32 GB; 48 GB is an M4 Pro option), possibly an M4 Max. Where a number below is chip-sensitive it is flagged.

---

## Ranked catalog

Ranked from "best quality you can run on 48 GB" down to lighter/faster options. Memory figures are the diffusion transformer weights at the stated precision (text encoder/VAE add a few GB more); speeds are 1024×1024 unless noted and are **M4 Pro estimates** extrapolated from cited M4-Pro-24GB and M4-Max benchmarks (see Sources).

| Rank | Model | Params | Quality tier | Mem (fp16 / 8-bit / 4-bit·GGUF·MLX) | ~Speed on M4 Pro (1024²) | License | Best use-case |
|------|-------|--------|--------------|--------------------------------------|--------------------------|---------|---------------|
| 1 (quality) | **FLUX.2 [dev]** | 32B | Frontier open | ~64GB / ~32GB / **~16–18GB (Q4)** | ~2–4 min (Q4) | **Non-commercial** (FLUX dev license) | Absolute best open T2I + single/multi-reference editing (up to 4MP, 10 refs) |
| 2 (quality) | **Qwen-Image / -2512** | 20.4B (+8.3B TE) | Frontier open; **#1 on AI Arena** | ~42GB / ~22GB (FP8) / **~17GB (4-bit)** | ~1–3 min (4-bit) | **Apache 2.0** (commercial OK) | Best photoreal + on-image text; strong instruction editing (Qwen-Image-Edit) |
| 3 | **FLUX.1 [dev]** | 12B | Excellent; deepest LoRA/ControlNet ecosystem | **~24GB (fp16, fits!)** / ~12GB / ~7–10GB (Q4–Q6) | ~40–70s (fp16); faster quantized | Non-commercial | Best all-round editing workhorse (richest LoRA/ControlNet/IP-Adapter support) |
| 4 | **FLUX.2 [klein] 9B** | 9B | Very good, retains diversity (no distillation collapse) | ~18GB / ~9GB / **~12GB (Q4 GGUF)** | ~30–60s | Non-commercial (9B) | High quality + fast; good middle ground |
| 5 | **SD 3.5 Large** | 8.1B | Good | ~18GB / **~11GB (FP8)** / — | ~40–60s | Community (free <$1M rev) | Commercial-friendly, decent quality, well-documented |
| 6 (sweet spot) | **Z-Image-Turbo** | 6B | Very good photoreal, 8-step | ~14–16GB (BF16) / **~8GB (FP8)** / ~6GB GGUF | **~10–25s** | Open / commercial-OK | **Best quality-per-second & per-GB**; bilingual text |
| 7 | **FLUX.2 [klein] 4B** | 4B | Good, sub-second class | ~8GB / ~4GB / ~4GB | ~15–35s | **Apache 2.0** | Best *commercial-clean* fast model |
| 8 | **SDXL 1.0 (+ fine-tunes)** | 3.5B | Good base; great with fine-tunes | **~7–8GB (fp16, trivial)** | **~15–30s** | OpenRAIL++ (commercial OK) | **Best editing toolkit**: ControlNet, IP-Adapter, inpaint, thousands of LoRAs |
| 9 | **SD 3.5 Medium** | 2.5B | Decent | ~9.9GB | ~20–40s | Community (free <$1M) | Lightweight commercial-friendly option |
| 10 | **PixArt-Σ** | 0.6B | Older/lighter | ~3–4GB | ~10–20s | Open | Minimal-footprint legacy option |

Notes on the table:
- **FLUX.2 [dev] at fp16 (~64 GB) will NOT fit** on 48 GB — you run it at 4-bit/Q4 (~16–18 GB), which fits comfortably. This is the one frontier model where 48 GB forces quantization.
- **Qwen-Image fp16 (~42 GB) is technically borderline** on 48 GB once you add the 8.3B text encoder and activations — run it FP8 (~22 GB) or 4-bit (~17 GB). 4-bit costs only ~3.5 points of quality (91.7 vs 95.2).
- **FLUX.1 [dev] fp16 (~24 GB) fits with room to spare** — this is the highest-quality model you can run at *full precision* on 48 GB, which is part of why it remains the default workhorse.
- **Würstchen / Stable Cascade** are omitted from the ranking: efficient but effectively superseded with little 2026 momentum. Emerging models worth watching (all surfaced via mflux/ComfyUI): **FIBO** (8B, JSON prompts), **ERNIE-Image** (8B, Baidu), **Ideogram 4** (9B, typography), **Qwen Image 2.0** (a smaller ~7B variant reportedly beating FLUX.2 on AI Arena), **LongCat-Image**, **Ovis-Image**.

---

## Top recommendations

- **Best quality overall (you'll accept slow):** **FLUX.2 [dev]** at Q4 — frontier open quality and best-in-class reference editing. Caveat: non-commercial license; ~2–4 min/image on M4 Pro (roughly halve on M4 Max).
- **Best quality with a clean license:** **Qwen-Image-2512** (Apache 2.0) at FP8/4-bit — #1 open model on blind arenas, exceptional text rendering and editing, and you can ship outputs commercially.
- **Best speed-to-quality (the daily driver):** **Z-Image-Turbo** — ~10–25s/image on M4 Pro, photorealistic, runs in ~8 GB, commercial-friendly. The model most people should start with.
- **Best full-precision model that fits at fp16:** **FLUX.1 [dev]** — still the workhorse thanks to the deepest LoRA + ControlNet + IP-Adapter ecosystem.
- **Best for editing existing wallpapers (img2img / inpaint / ControlNet / IP-Adapter):** the **SDXL** ecosystem — most mature tooling by a wide margin — or FLUX.1 [dev] if you want higher base quality.

---

## Editing capabilities (img2img / inpaint / ControlNet / IP-Adapter)

These matter if you want to *edit* existing wallpapers rather than generate from scratch.

| Model | img2img | Inpaint/Fill | ControlNet | IP-Adapter / ref-image | Notes |
|-------|---------|--------------|------------|------------------------|-------|
| **SDXL** | Yes | Yes (dedicated inpaint model) | **Full suite** (canny/depth/pose/etc.; Illustrious/NoobAI added 2025) | **Yes** incl. face variants | The richest editing ecosystem available locally |
| **FLUX.1 [dev]** | Yes | Yes (Fill) | Yes (Canny/Depth, Alimama inpaint) | Redux (ref) | Best quality with strong-but-narrower tool set |
| **FLUX.2 [dev/klein]** | Yes | Yes | Growing | **Native multi-reference (up to 10 imgs)** | Reference editing is a headline FLUX.2 feature |
| **Qwen-Image-Edit (2509/2511)** | Yes | Yes | Some | Multi-image editing | Instruction-driven editing, multilingual |
| **Z-Image-Turbo** | Yes | Partial | "Fun ControlNet" patch (reported quality issues) | Limited | Generation-first; editing tooling immature |
| **SD 3.5** | Yes | Yes | Some | Some | Less tooling than SDXL/FLUX |

**For the user's literal task** (character → black background), none of this is the right tool: you want segmentation/matting + compositing (see `02-the-task-method.md`). ControlNet/IP-Adapter are only relevant if you later want to *repaint or restyle* the isolated character.

---

## Apple-native runtimes (how these models actually run on the Mac)

The recommended runtime/install path is owned by `04-install-guide.md`; this is the capability landscape.

| Runtime | What it is | Model coverage | Editing/ControlNet | Batch-friendly | Notes |
|---------|-----------|----------------|--------------------|----------------|-------|
| **Draw Things** (free, App Store) | Polished Metal/MLX Mac+iOS app | SDXL, FLUX.1, FLUX.2 (+klein 4B/9B), Qwen-Image + Qwen-Edit 2509, Z-Image, Wan/LTX video | Full ControlNet (Alimama inpaint, Jasper), inpaint/outpaint/pose, **on-device LoRA training**, GGUF/LoRA import | GUI + scripting/API | **~20% faster than ComfyUI on Apple Silicon**; 48 GB unlocks fp16. Best default for most users. |
| **mflux** (`filipstrand/mflux`) | MLX-native CLI/Python | Z-Image (6B), FLUX.2 (4B/9B), Ideogram 4 (9B), ERNIE (8B), FIBO (8B), Qwen-Image (20B), FLUX.1 (12B), SeedVR2 upscale, Depth Pro | img2img, multi-LoRA, ControlNet (Canny), depth, fill/inpaint, Redux, in-context edit, upscaling; 3/4/6/8-bit quant | **Excellent (scriptable CLI)** | Best for *batch folder* pipelines. MFLUX-WEBUI adds a browser UI. |
| **Core ML Stable Diffusion** (`apple/ml-stable-diffusion`) | Apple's Core ML converter (ANE+GPU) | SD 1.5 / SDXL only | Limited | Moderate | Mature for SD/SDXL, **no FLUX/Qwen support**; largely superseded by MLX/Draw Things for modern models. |
| **ComfyUI (MPS)** | Node-graph workflow engine | Broad (community nodes) | Everything, via nodes | Yes (workflows) | Works on Mac but **~20% slower than Draw Things**; many CUDA-only custom nodes won't run. Best for complex graphs. |

---

## Performance reality check (cited benchmarks)

- **M4 Pro 24 GB, ComfyUI:** FLUX.1 dev Q6_K, 1024², 20 steps = **~50–90 s/image** (Mac Mini M4 Pro ~50 s reported). SDXL 1024², 25 steps = **~20–40 s**. SD1.5 512² = ~5–10 s. (heyuan110 benchmark)
- **Draw Things ≈ 20% faster** than ComfyUI on the same Apple Silicon hardware. (Draw Things benchmark)
- **mflux on M4 Max 128 GB:** FLUX schnell, 2 steps, 1024² = **~10.56 s**. M4 Max is ~2x M4 Pro, so scale M4 Pro estimates accordingly. (mflux issue #92)
- **Takeaway:** lighter models (Z-Image-Turbo 8-step, SDXL, klein 4B) give a responsive ~10–30 s loop on M4 Pro; the 20–32B frontier models (Qwen 4-bit, FLUX.2 dev Q4) are minutes-per-image — usable for curated batches, not interactive iteration. On an M4 Max these roughly halve.

---

## License cheat-sheet (does commercial use matter?)

| License class | Models | Commercial output OK? |
|---------------|--------|------------------------|
| **Apache 2.0 / permissive** | Qwen-Image(-2512), Z-Image-Turbo, **FLUX.2 [klein] 4B**, FLUX.1 [schnell] | Yes |
| **OpenRAIL++** | SDXL (+ most fine-tunes — check each) | Yes |
| **Stability Community** | SD 3.5 Large / Turbo / Medium | Yes, free **up to $1M annual revenue** |
| **FLUX Non-Commercial** | **FLUX.1 [dev]**, **FLUX.2 [dev]**, FLUX.2 [klein] 9B | **No** (weights non-commercial; outputs require BFL agreement) |

If you ever monetize wallpapers, prefer **Qwen-Image, Z-Image-Turbo, FLUX.2 klein 4B, or SDXL**. The FLUX dev models are the quality leaders but are non-commercial.

---

## Sources

- mflux (supported models, features, quant): https://github.com/filipstrand/mflux · https://pypi.org/project/mflux/ · https://github.com/CharafChnioune/MFLUX-WEBUI · mflux M4 Max speed issue: https://github.com/filipstrand/mflux/issues/92
- FLUX.2: https://bfl.ai/blog/flux-2 · https://huggingface.co/black-forest-labs/FLUX.2-dev · https://github.com/black-forest-labs/flux2 · https://venturebeat.com/technology/black-forest-labs-launches-open-source-flux-2-klein-to-generate-ai-images-in · https://news.smol.ai/issues/25-11-25-flux2 · https://lilting.ch/en/articles/flux2-klein-apple-silicon
- FLUX local on Apple Silicon: https://insiderllm.com/guides/flux-locally-complete-guide/ · https://rentamac.io/flux-ai-mac/
- Stable Diffusion 3.5: https://stability.ai/news-updates/introducing-stable-diffusion-3-5 · https://education.civitai.com/getting-started-with-stable-diffusion-3-5/ · https://willitrunai.com/image-models/sd-3-5-medium
- Qwen-Image: https://github.com/QwenLM/Qwen-Image · https://huggingface.co/Qwen/Qwen-Image-Edit/discussions/6 · https://qwen-image-2512.com/blog/qwen-image-2512-gguf-complete-guide · https://willitrunai.com/blog/qwen-image-local-guide · https://www.atlascloud.ai/blog/guides/qwen-image-2-0-vs-flux-2-why-this-7b-model-is-beating-the-giants-in-ai-arena
- Z-Image-Turbo: https://huggingface.co/Tongyi-MAI/Z-Image-Turbo · https://www.digitalocean.com/community/tutorials/image-generation-model-review · https://localaimaster.com/blog/z-image-turbo-comfyui
- Draw Things: https://drawthings.ai/downloads/ · https://wiki.drawthings.ai/wiki/Prompting_Base_Model_Basics · https://engineering.drawthings.ai/p/metal-flashattention-2-0-pushing-forward-on-device-inference-training-on-apple-silicon-fe8aac1ab23c
- Benchmarks: https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/
- SDXL editing ecosystem: https://blog.segmind.com/best-stable-diffusion-xl-sdxl-models/ · https://huggingface.co/docs/diffusers/en/using-diffusers/ip_adapter
- Core ML SD: https://github.com/apple/ml-stable-diffusion
