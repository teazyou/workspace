# Hardware Feasibility, Possibilities & Limitations — Research Notes

> Topic: Local diffusion / image (& video) generation on **Apple MacBook Pro, M4 Pro, 64GB unified memory, macOS**.
> Date of research: 2026-06-23. This field moves fast; all figures verified on the live web (2025–2026 sources). Numbers from blogs/forums vary by build, sampler, attention backend, and OS version — treat single-source benchmarks as ballpark.

---

## 1. Apple Silicon unified-memory architecture — what 64GB enables

- **Unified memory**: CPU and GPU share one physical RAM pool; no PCIe copy, no separate VRAM. The GPU can address most of unified RAM.
- **GPU memory cap (the real ceiling)**: Metal exposes `recommendedMaxWorkingSetSize`. On Macs >36GB RAM macOS lets the GPU use **~75%** of unified RAM by default (≈2/3 on ≤36GB machines). On a 64GB machine that is **~48GB** available to the GPU out of the box (sources say ~51GB / 75–80%).
  - This functions as a near-hard cap for user-space GPU programs, though Apple calls it "recommended."
  - Can be raised via kernel param `sudo sysctl iogpu.wired_limit_mb=<MB>` (e.g. 60GB = 61440). Advice: leave 8–16GB for macOS to avoid memory pressure / swap.
  - Sources:
    - https://developer.apple.com/forums/thread/732035 (recommendedMaxWorkingSetSize behaves as a cap)
    - https://github.com/ivanopcode/devnote-override-macos-metal-vram-cap
    - https://blog.peddals.com/en/fine-tune-vram-size-of-mac-for-llm/
    - https://techobsessed.net/2023/12/increasing-ram-available-to-gpu-on-apple-silicon-macs-for-running-large-language-models/
- **What 64GB practically buys for diffusion**:
  - Run **FLUX.1-dev (12B) at fp16 (~24GB weights)** with full text encoders comfortably — something 16/24GB discrete-GPU machines cannot do without offload/quantization.
  - Headroom to keep **multiple models resident** (e.g. base + refiner + upscaler + ControlNet) or run **large batches**.
  - Even the **32B FLUX.2-dev** model (~64GB at BF16) is borderline — would need quantization (FP8 ~32GB / GGUF Q4 ~19GB) on this machine; full BF16 will not fit alongside encoders + OS.
  - vs typical NVIDIA consumer cards (RTX 4090 = 24GB VRAM): the Mac's 48GB usable GPU memory is the standout advantage — capacity, not speed.

### M4 Pro hardware specifics (this machine)
- M4 Pro GPU: up to **20 GPU cores**, memory bandwidth **273 GB/s**.
- vs M4 Max 40-core: **546 GB/s** (2× bandwidth).
- vs RTX 4090: **~1008–1010 GB/s** (≈3.7× the M4 Pro's bandwidth). Memory bandwidth is the dominant factor for diffusion throughput.
- M4 Pro GPU ≈ **2× the base M4** GPU.
- Sources:
  - https://nanoreview.net/en/gpu-compare/geforce-rtx-4090-vs-apple-m4-pro-gpu-20-core
  - https://www.notebookcheck.net/Apple-M4-Max-40-core-GPU-Benchmarks-and-Specs.920457.0.html

---

## 2. Backends & maturity on M4

| Backend | What it is | Strength on Apple Silicon | Gaps / caveats |
|---|---|---|---|
| **PyTorch MPS** | Metal Performance Shaders backend for PyTorch; powers ComfyUI/A1111/diffusers on Mac | Broadest model/node compatibility; "just works" for most workflows | Still **beta**; **no `Float8_e4m3fn` (FP8) support** → FP8 checkpoints fail or fall to CPU; occasional missing ops (e.g. `aten::__rshift__`) need `PYTORCH_ENABLE_MPS_FALLBACK=1` (CPU fallback = slow); some fixes only in nightly. |
| **Apple MLX** (e.g. **mflux**) | Apple's array framework, native Metal | Fastest native path for supported models; clean 4-bit/8-bit quantization; tight memory use | Smaller model coverage than ComfyUI; you use what mflux/Draw Things port. |
| **CoreML / ANE** | Apple's `ml-stable-diffusion`; can run on CPU+GPU+**Neural Engine** | Energy-efficient; ANE int8 helps latency on M4; powers Draw Things / Mochi Diffusion | Model conversion required; best for SD1.5/SDXL-class; not the path for FLUX-12B/20B. Mixed-bit palettization (1/2/4/6/8-bit). |
| **GGUF / quantization** (city96 ComfyUI-GGUF) | Q8/Q6/Q4 quantized weights | **The Apple workaround for FP8**: GGUF replaces FP8 to shrink big models on Mac | Quality loss at low bits (Q4 ~88–92% detail retention vs fp16; Q6 ~94–96%). |

- **Draw Things** (Mac app, uses optimized Metal + MFA): consistently cited **~20% (up to 40%) faster than ComfyUI** on the same Apple Silicon. Metal FlashAttention 2.0 adds up to 20% on M3/M4. Up to 25% faster per-iteration than mflux on M2 Ultra; up to 94% faster than ggml/gguf.
- Key takeaway: **FP8 is the recurring Apple-Silicon trap** — Metal doesn't implement `Float8_e4m3fn`, so the popular FP8 checkpoints used on NVIDIA don't work on MPS; Mac users must use **GGUF** or **MLX-native quantization** instead.
- Sources:
  - https://developer.apple.com/metal/pytorch/
  - https://github.com/Comfy-Org/ComfyUI/discussions/13273 (FP8 MPS workaround)
  - https://github.com/pytorch/pytorch/issues/167679
  - https://github.com/city96/ComfyUI-GGUF/issues/27
  - https://github.com/filipstrand/mflux (MIT license; `uv tool install --upgrade mflux`)
  - https://github.com/apple/ml-stable-diffusion
  - https://machinelearning.apple.com/research/stable-diffusion-coreml-apple-silicon
  - https://engineering.drawthings.ai/p/metal-flashattention-2-0-pushing-forward-on-device-inference-training-on-apple-silicon-fe8aac1ab23c

---

## 3. Memory footprint by model class (does it fit in 64GB?)

| Model | Params | fp16/BF16 weights | Quantized | Fits in 64GB Mac? |
|---|---|---|---|---|
| **SD 1.5** | ~0.9B | ~2–4GB | — | Trivially (any tier) |
| **SDXL** | ~3.5B (2.6B UNet) | ~7GB | — | Trivially |
| **SD 3.5 Medium** | 2.5B | ~9.9GB (excl. text encoders) | — | Easily |
| **SD 3.5 Large** | 8.1B | ~18GB fp16 | FP8 ~11GB (FP8 NOT on MPS → use GGUF) | Easily at fp16 |
| **FLUX.1 [dev]/[schnell]** | 12B | ~24GB (base) + 4–8GB overhead | Q8 ~13GB, Q6_K ~10GB, Q4 ~6–8GB | **Yes — fp16 comfortable** (key 64GB win) |
| **Z-Image (Turbo)** | ~6B | model fits; ~24GB total RAM in ComfyUI run | — | Easily |
| **Qwen-Image** | 20B (MMDiT) | BF16 ~48GB+ "VRAM" | GGUF Q4 runs in ~8GB; offload to 4GB | fp16 borderline-but-possible on 64GB; quantize for headroom |
| **FLUX.2 [dev]** | 32B | **~64GB BF16** | FP8 ~32GB, GGUF Q4 ~19GB | **fp16 does NOT fit cleanly** → must quantize |
| **FLUX.2 klein** | 4B / 9B | ~13GB (4B) | — | Easily |

**Video (much heavier, mostly time-bound not memory-bound on 64GB):**
| Model | Footprint (GGUF) | Notes |
|---|---|---|
| **LTX-Video / LTX-2** | ~30GB total (Q4_K_M): distilled 12GB + Gemma3 6.8GB + connector 2.7GB + VAE 2.3GB | **Most feasible** on Mac; fits in 64GB. |
| **Wan 2.2** | ~24GB total (Q4_K_S): 2× 8.75GB diffusion + 6.04GB text enc + VAE | Fits in memory but **no stable MPS path**; extremely slow. |
| **HunyuanVideo** | large | Wants 4090/3090/A6000-class; impractical on Mac. |

- Sources:
  - https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/ (Flux quant tiers/sizes)
  - https://www.apatero.com/blog/flux-apple-silicon-m1-m2-m3-m4-complete-performance-guide-2025
  - SD3.5: https://github.com/huggingface/diffusers/blob/main/docs/source/en/api/pipelines/stable_diffusion/stable_diffusion_3.md ; https://localaimaster.com/blog/stable-diffusion-local-install-guide
  - Z-Image: https://z-image.cc/blog/z-image-complete-guide-2025 ; https://medium.com/@tchpnk/z-image-turbo-comfyui-on-apple-silicon-2026-0aa78d05132d
  - Qwen-Image: https://github.com/QwenLM/Qwen-Image ; https://huggingface.co/Qwen/Qwen-Image-Edit/discussions/6
  - FLUX.2: https://github.com/black-forest-labs/flux2 ; https://localaimaster.com/blog/flux-2-local-setup-guide ; https://deepwiki.com/black-forest-labs/flux2/2.3-hardware-requirements
  - Video: https://lilting.ch/en/articles/ltx2-wan22-mac-local-video-gen ; https://localaimaster.com/blog/local-ai-video-generation

---

## 4. Speed — realistic seconds/image

### Apple Silicon, FLUX 1024×1024 fp16 (from Apatero guide)
| Chip | s/image (FLUX, fp16) |
|---|---|
| M1 Max 32GB | 180s |
| M2 Max 32GB | 145s |
| M3 Max 36GB | 105s |
| **M4 Pro 24GB** | **145s** |
| M4 Max 48GB | 85s |
| **RTX 4090 (reference)** | **12–18s** |

Note: that table's M4 Pro 145s looks pessimistic / depends on backend & quant. Other 2026 sources give a 24GB M4 Pro **~50s for FLUX (Q6_K)** in ComfyUI, **20–40s SDXL**, **5–10s SD1.5**. DiffusionBee (unoptimized) was ~6 min for FLUX. Spread reflects backend (ComfyUI vs Draw Things vs DiffusionBee), quantization, and steps.

### M4 Pro 24GB practical (ComfyUI, heyuan110 2026)
- SD 1.5: **5–10 s/image**
- SDXL: **20–40 s/image**
- FLUX.1-dev Q6_K: **50–90 s/image** (~50s typical)
- Draw Things: **~20%+ faster** than the above.

### Distilled / turbo impact (huge)
- **Z-Image Turbo**: ~2–3s for a 1024px image at **8 steps** (on capable HW) — distilled models collapse step count (8 vs 25–50) and are the practical sweet spot on Apple Silicon. (M2 Max ~14s/image cited.)
- FLUX **schnell** (few-step) >> FLUX dev for speed.

### M4 Pro vs other Apple chips
- Base M4 → M4 Pro: ~2× GPU.
- M4 Pro → M4 Max: **~40–60% faster** inference (2× bandwidth + more cores).

### vs NVIDIA (ballpark multiples)
- RTX 4090 FLUX.1-dev fp16 30 steps: **~15s**; M4 Pro **~50–145s** → **roughly 3–10× slower** depending on backend/quant.
- RTX 5090: FLUX FP4 ~5s; sd3.5-large ~12s (vs 4090 58s). 5090 ≈ 21–80% faster than 4090 on image gen → Mac gap to 5090 is even larger.
- General framing: Apple Silicon is "dramatically slower but increasingly practical"; the Mac wins on **memory capacity & efficiency**, loses on **raw speed**.
- Sources:
  - https://www.apatero.com/blog/flux-apple-silicon-m1-m2-m3-m4-complete-performance-guide-2025
  - https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/
  - https://medium.com/@tchpnk/z-image-turbo-comfyui-on-apple-silicon-2026-0aa78d05132d
  - https://www.runpod.io/gpu-compare/rtx-5090-vs-rtx-4090
  - https://blogs.nvidia.com/blog/generative-ai-studio-ces-geforce-rtx-50-series/

---

## 5. Practical: thermals, battery, overnight batches

- **Battery vs plugged-in**: macOS throttles GPU on battery; sustained diffusion should be **plugged in** for full clocks. (General Apple Silicon behavior; expect reduced throughput on battery.)
- **Thermals**: MacBook Pro M4 Pro sustains GPU loads better than fanless MacBooks but long batches will ramp fans; throughput is generally stable once warm (no hard thermal cliff like thin laptops). Efficiency is a real advantage — far lower wattage than a 4090 (~450W).
- **Overnight batch jobs**: Strongly viable use case — the **memory headroom** (run big models + queue large batches) plus **low power draw** make unattended overnight generation a genuine strength even though per-image speed lags NVIDIA. Caveat: avoid exceeding the GPU memory cap or you hit swap and slow dramatically.
- (These are reasoned from Apple Silicon behavior + bandwidth/power figures; fewer hard primary benchmarks — flagged as lower-confidence.)

---

## 6. Honest possibilities vs limitations

### CAN do well on M4 Pro 64GB
- SD1.5 / SDXL / SD3.5 (incl. Large fp16) — fast and easy.
- **FLUX.1-dev at full fp16** thanks to 48GB usable GPU memory — a real edge over 24GB NVIDIA cards.
- Z-Image / distilled-turbo models — near-interactive (single-digit seconds).
- Keep multiple models resident; large overnight batches; LoRA use.
- Qwen-Image (quantized comfortably; fp16 borderline).
- Energy-efficient, quiet-ish, fully local/private.

### Limitations
- **No CUDA** — much of the ecosystem (xformers, FP8 kernels, TensorRT, some custom CUDA ComfyUI nodes) is NVIDIA-only.
- **FP8 unsupported on MPS/Metal** (`Float8_e4m3fn`) — popular FP8 checkpoints don't run on GPU; must use GGUF or MLX quantization instead.
- **Slower than discrete GPUs**: ~3–10× slower than RTX 4090, more vs 5090, for FLUX-class.
- **Some ComfyUI nodes/models unsupported on MPS** — missing ops force CPU fallback (`PYTORCH_ENABLE_MPS_FALLBACK=1`) = slow; some workflows just NaN/fail (e.g. LTX-2 2-stage pipeline on MPS).
- **Video generation is the weak point**: LTX-Video is the only comfortably feasible one (~3–14 min/short clip). Wan 2.2 = ~82 min for a 2s clip on M-series (no stable MPS path); HunyuanVideo impractical. NVIDIA H100 does 5s video in ~2s.
- FLUX.2-dev (32B) fp16 doesn't fit — quantization required.

---

## 7. Conflicting / uncertain data (flagged)
- **M4 Pro FLUX s/image**: Apatero says 145s (fp16); heyuan110 says ~50s (Q6_K). Different precision/backend — both plausible; cite range 50–145s.
- **GPU memory cap %**: sources say "~75%", "75–80% (~51GB)", "3/4 on >36GB". Use ~75% / ~48GB as the conservative figure for 64GB.
- **Draw Things speedup**: "20%" vs "up to 40%" vs "25% vs mflux" — varies by model/chip.
- **Z-Image speed**: "2–3s at 8 steps" is on strong HW; one source oddly cited "M5 32GB ~100s default workflow" (likely a non-turbo / unoptimized path). Treat turbo 8-step single-digit-seconds as the realistic figure on Apple Silicon, but M4 Pro-specific number unconfirmed.
- Many benchmarks come from blogs/forums, not controlled labs — directional, not exact.
