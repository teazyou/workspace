# Hardware Feasibility, Possibilities & Limitations

This file answers the threshold question for the whole study: **can an Apple MacBook Pro (M4 Pro, 64GB unified memory) do good local image generation, and where are the ceilings?** It owns the hardware verdict, the memory-and-speed reality, and the honest "runs great / runs slow / needs a cloud GPU" split. Model-by-model picks live in [02-sota-local-models.md](./02-sota-local-models.md); the apps that run them and install commands live in [03-tools-and-install.md](./03-tools-and-install.md).

---

## Verdict

**Yes — the M4 Pro / 64GB is a genuinely good local image-generation machine, with one clear shape: it wins on memory capacity and efficiency, and loses on raw speed.** You can run essentially every current open-weights *image* model — including **FLUX.1-dev (12B) at full fp16**, which most 16–24GB discrete NVIDIA cards cannot do without offloading or quantizing. Per-image speed is roughly **3–10× slower than an RTX 4090**, but it is firmly in "usable" territory for stills, and the 48GB of GPU-addressable memory makes large models, multiple resident models, and big overnight batches a real strength.

Two hard ceilings to internalize up front:

1. **Local *video* generation is the weak point** — only LTX-Video is anywhere near practical; Wan 2.2 / HunyuanVideo are not.
2. **FP8 quantization does not work on Apple Silicon** — the single most consequential caveat, dictating which checkpoints you can download.

**Bottom line: for local *image* generation this machine is comfortably above the "good" bar. For local *video* it is below it — use a cloud GPU.**

---

## Why 64GB matters: unified memory

Apple Silicon shares one physical RAM pool between CPU and GPU (no PCIe copy, no separate VRAM). The practical ceiling is Metal's `recommendedMaxWorkingSetSize`: on Macs **>36GB** macOS lets the GPU use **~75%** of unified RAM by default (it is ~2/3 on ≤36GB machines — so the 75% figure is correct *specifically* for this 64GB target, not universal). That gives **~48GB of GPU-addressable memory** out of the box.

- It is a "recommended" value, not a hard kernel cap, but in practice it behaves as the effective ceiling for most frameworks.
- It can be raised with `sudo sysctl iogpu.wired_limit_mb=<MB>` (e.g. ~56GB), but **leave 8–16GB for macOS** to avoid memory pressure and swap (swapping kills diffusion throughput).

What 48GB usable buys you:

| Capability | M4 Pro 64GB | Typical RTX 4090 (24GB VRAM) |
|---|---|---|
| FLUX.1-dev (12B) at fp16 (~24GB weights) | Yes, comfortably | Needs offload/quant |
| Keep base + refiner + upscaler + ControlNet resident | Yes | Tight |
| Large batch sizes / big resolutions | Yes | Limited |
| Raw per-image speed | Slower | Much faster |

**The headline win is capacity, not speed** — the M4 Pro's memory bandwidth (273 GB/s) is fixed regardless of whether you have 24, 48, or 64GB, so a larger memory tier *enables bigger models and batches* but does **not** make any single image faster.

---

## Does it fit? Memory footprint by model class

| Model | Params | fp16/BF16 weights | Quantized (GGUF) | Fits on 64GB Mac? |
|---|---|---|---|---|
| SD 1.5 | ~0.9B | ~2–4GB | — | Trivially |
| SDXL | ~3.5B | ~7GB | — | Trivially |
| SD 3.5 Large | 8.1B | ~18GB | (FP8 not on MPS → use GGUF) | Easily at fp16 |
| **FLUX.1 [dev]/[schnell]** | 12B | ~24GB + 4–8GB overhead | Q8 ~13GB · Q6_K ~10GB · Q4 ~6–8GB | **Yes — fp16 comfortable (key 64GB win)** |
| Z-Image (Turbo) | ~6B | fits; ~24GB total in a ComfyUI run | — | Easily |
| Qwen-Image | 20B | BF16 ~48GB+ | GGUF Q4 ~8GB | fp16 borderline; quantize for headroom |
| FLUX.2 [dev] | 32B | **~64GB BF16** | FP8 ~32GB · Q4 ~19GB | **fp16 does NOT fit cleanly → must quantize** |
| FLUX.2 klein | 4B / 9B | ~13GB (4B) | — | Easily |

Detailed quality/license tradeoffs per model are in [02-sota-local-models.md](./02-sota-local-models.md).

---

## The Apple-Silicon caveat that dictates everything: no FP8

**FP8 (`Float8_e4m3fn`) is unsupported on Apple Metal/MPS.** This is confirmed and still current as of 2026:

- PyTorch float8-for-MPS feature requests (issues #132624, #148420) remain **open**. The runtime errors with: `Trying to convert Float8_e4m3fn to the MPS backend but it does not have support for that dtype.`
- ComfyUI issues (#5533 / #8988 / #8785) reproduce this for FLUX / SD3.5 FP8 checkpoints on Apple Silicon.

Practical consequences:

- The popular **FP8 checkpoints used on NVIDIA fail or fall back to CPU** on a Mac. Do not download `*-fp8` checkpoints expecting GPU speed.
- **Use GGUF quantization instead** (city96's ComfyUI-GGUF): Q8 ~13GB, Q6_K ~10GB, Q4 ~6–8GB for FLUX-class. Or use **MLX-native** 4/8-bit quant (mflux), or simply load in **float16**.
- PyTorch MPS is still **beta**; occasional missing ops require `PYTORCH_ENABLE_MPS_FALLBACK=1`, which routes that op to the (slow) CPU.

GGUF quality cost is modest: roughly 94–96% detail retention at Q6, ~88–92% at Q4, versus fp16.

---

## Backends on M4: pick the right path

| Backend | What it is | Strength on Apple Silicon | Caveats |
|---|---|---|---|
| **PyTorch MPS** | Metal backend powering ComfyUI / A1111 / diffusers | Broadest model & node compatibility; "just works" | Beta; **no FP8**; occasional CPU fallback; some nodes NaN/fail |
| **Apple MLX** (`mflux`) | Apple's native array framework | Fastest native path; clean 4/8-bit quant; tight memory | Smaller model coverage than ComfyUI |
| **CoreML / ANE** | Apple `ml-stable-diffusion` (CPU+GPU+Neural Engine) | Energy-efficient; int8 ANE helps latency | Conversion required; best for SD-class, not FLUX-12B |
| **Draw Things** | Mac app, optimized Metal + FlashAttention 2.0 | **~20% (up to 40%) faster than ComfyUI** | App-curated model set |

`mflux` is MIT-licensed and supports Z-Image, FLUX.1/FLUX.2, and Qwen-Image with `-q 8` quantization. Install commands and a fuller tool comparison are in [03-tools-and-install.md](./03-tools-and-install.md).

---

## Speed: realistic seconds-per-image

These are directional figures from 2025–2026 blogs/benchmarks (not controlled labs), and vary with sampler, attention backend, OS, quant, and step count. The best M4 Pro data is from a **24GB M4 Pro Mac Mini**; since speed is bandwidth-bound and the M4 Pro's bandwidth is fixed, the **64GB MacBook Pro should be similar — capacity differs, speed does not** (unconfirmed but well-reasoned).

| Model | M4 Pro (ComfyUI / MPS) | Notes |
|---|---|---|
| SD 1.5 | **5–10 s** | Interactive |
| SDXL | **20–40 s** | Comfortable |
| FLUX.1-dev (Q6_K, 20 steps) | **50–90 s** (best case ~50s) | The realistic FLUX number |
| Draw Things (any of the above) | ~20%+ faster | Same workflow, optimized Metal |
| RTX 4090 (reference) | ~12–18 s for FLUX | ~3–10× faster than M4 Pro |

**On a widely-cited "145s for FLUX" figure: do not apply it to the M4 Pro.** That number is real but belongs to an **M2 Max at fp16** (the Apatero Apple-Silicon guide also lists M4 Max ~85s, M3 Max ~105s, M2 Max ~145s). The often-repeated "3× discrepancy on the same hardware" is a conflation of two different articles and two different chips — partly a different chip (M2 Max), partly best-vs-typical (50s is the best end of a 50–90s Q6_K range). Treat **50–90s as the honest M4 Pro FLUX range**.

### Distilled / turbo models — the real sweet spot

Step count dominates wall-clock time (8 steps vs 25–50), so **distilled models and FLUX schnell are dramatically faster than FLUX dev**. **Z-Image Turbo (~6B, 8 steps)** is the fastest practical local image model on Mac — roughly **3× faster than FLUX** and the closest thing to interactive generation.

**Important correction:** the widely-quoted "**2–3s at 8 steps**" for Z-Image Turbo is an **RTX 4090 / 4070** number, **not** Apple Silicon. Real Mac data points are far slower — **~14s on M2 Max** (512px / 7 steps), **~23s on M1 Max**, and **~160s at 1024px / 9 steps** on one Apple-Silicon ComfyUI writeup. No M4 Pro-specific Z-Image timing has been published; **expect roughly 15–30s+ at 512px and well over two minutes at 1024px** on M-series. It is the fastest local option on Mac — just not single-digit seconds at full resolution.

### M4 Pro vs other chips and NVIDIA

- Base M4 → **M4 Pro ≈ 2× GPU**.
- M4 Pro → **M4 Max ≈ 40–60% faster** (2× bandwidth: 273 vs 546 GB/s, plus more cores).
- **RTX 4090 ≈ 1008 GB/s** (~3.7× the M4 Pro). Memory bandwidth is the dominant factor for diffusion throughput, which is why the Mac is 3–10× slower for FLUX-class and the gap widens against a 5090.

---

## Video generation: the honest weak point — use a cloud GPU

Local video is where the M4 Pro stops being "good" and becomes "don't bother for serious work."

| Model | M-series feasibility | Measured / cited |
|---|---|---|
| **LTX-Video / LTX-2** | The most feasible — but with caveats | MLX-based native path (mlx-video) ~4–6 min for a 10s 1080p clip on M3 Max (one source); the **official 2-stage LTX-2 pipeline was found "not feasible" on Mac** by lilting.ch (can NaN on MPS) |
| **Wan 2.2** | Impractical | **~82 min** (1h22m45s) for a 2s 832×480 clip on M1 Max 64GB via GGUF; officially CUDA-only; FP8 checkpoints fail on Metal |
| **HunyuanVideo** | Not practical | Wants 4090/3090/A6000-class GPUs |

Caveats on the above (all single-source, chip-specific, fast-moving):

- The 82-min Wan figure is from an **M1 Max 64GB** writeup; an M4 Pro would be somewhat faster but **still on the order of an hour** — i.e. still impractical.
- "No stable MPS path" for Wan **overstates it**: a GGUF MPS path *does* run, just very slowly. "No *practical* MPS path" is the accurate framing.
- Calling LTX-Video the "*only* feasible" local video model is an overgeneralization — it is the *most* feasible, but the cited source was actually pessimistic about its official pipeline.

For reference, an NVIDIA H100 produces a 5s clip in ~2s. **Verdict: do local video on a rented cloud GPU.**

---

## Thermals, battery, and overnight batches (reasoned, lightly benchmarked)

These are inferred from Apple Silicon behavior and power/bandwidth figures, not hard primary benchmarks — treat as lower-confidence:

- **Plug in for sustained work.** macOS throttles GPU clocks on battery; long diffusion runs want AC power for full throughput.
- **Thermals are stable, not cliff-edged.** A MacBook Pro chassis sustains GPU load far better than a fanless MacBook; long batches will ramp the fans, but throughput is generally steady once warm — no thin-laptop thermal cliff.
- **Overnight batches are a genuine strength.** The memory headroom (big models + queued large batches) plus very low power draw (vs a ~450W 4090) make unattended overnight generation a real selling point — the slower per-image speed matters far less when nobody is watching. Just stay under the GPU memory cap to avoid swap.

---

## Possibilities & limitations summary

**Runs great locally (image):**
- SD 1.5 / SDXL / SD 3.5 (incl. Large at fp16) — fast and easy.
- **FLUX.1-dev at full fp16** — the standout 64GB win over 24GB NVIDIA cards.
- Z-Image / distilled-turbo models — the fastest practical local path (but ~15–30s+ at 512px on M-series, not the 2–3s NVIDIA figure).
- Qwen-Image (quantized comfortably; fp16 borderline), multiple resident models, large overnight batches, LoRA use (see [04-customization-and-lora.md](./04-customization-and-lora.md)).
- Fully local, private, quiet, energy-efficient.

**Runs but slow / with friction:**
- FLUX-class at 1024px (~50–90s/image), FLUX.2-dev (must quantize — 32B fp16 doesn't fit), the occasional MPS CPU-fallback op.

**Needs a cloud GPU:**
- Serious local **video** (Wan 2.2, HunyuanVideo, and arguably the official LTX-2 pipeline).
- Anything depending on **CUDA-only tooling** (xformers, FP8 kernels, TensorRT, some custom CUDA ComfyUI nodes) or **FP8 checkpoints**.
- Heavy training — full fine-tunes (see [04-customization-and-lora.md](./04-customization-and-lora.md)).

### Open questions (unconfirmed)

- M4 Pro-specific FLUX.1-dev speed at a *fixed* config (Q6_K, 20 steps, Draw Things vs ComfyUI) on the 64GB MacBook Pro — most data is the 24GB Mac Mini; bandwidth-bound speed should match but is unconfirmed.
- Real sustained-load throttling on battery vs AC, and long-batch thermal/fan behavior (reasoned, not benchmarked).
- Current MLX/mflux seconds-per-image for FLUX and Qwen-Image on M4 Pro specifically (not published).
- Whether any 2026 macOS/PyTorch update has begun adding FP8 or improved MPS operator coverage — as of this writing the FP8 feature requests remain open.
