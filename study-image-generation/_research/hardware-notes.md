# Hardware feasibility — raw research notes (2026-06-22)

## Chip specs (Apple M4 family, MacBook)

| Chip | GPU cores | Mem bandwidth | Max unified mem | Notes |
|---|---|---|---|---|
| M4 (base) | up to 10 | 120 GB/s | 32 GB | MacBook Air/Pro 14". Caps at 32 GB. |
| M4 Pro | up to 20 | 273 GB/s | 64 GB | 48 GB is a config point here. |
| M4 Max (base) | 32 | 410 GB/s | 128 GB | |
| M4 Max (top) | 40 | 546 GB/s | 128 GB | |

- **48 GB ⇒ almost certainly M4 Pro.** Base M4 caps at 32 GB; 48 GB is not an M4 Max config offered standalone (M4 Max jumps 36→48→64→128 actually — note: M4 Max IS offered at 48GB on some 16" configs). But base M4 cannot reach 48 GB, so it is M4 Pro **or** M4 Max. The bandwidth gap (273 vs 410-546 GB/s) and GPU core gap (20 vs 32-40) is where the chip variant changes generation speed by ~1.5-2.7x. Segmentation is unaffected (light).
- Correction from sources: M4 Pro tops at 64 GB. M4 Max offers 36/48/64/128. So 48 GB could be either M4 Pro (with 48? Apple lists M4 Pro 24/48/64) or M4 Max 48. Most common 48GB MacBook = M4 Pro. Flag both.

Sources: Apple newsroom M4 Pro/Max; Wikipedia Apple M4; 9to5mac M4 Max; notebookcheck; Apple support tech specs.

## Framework maturity

- **MLX (Apple)** — native, targets unified memory directly, fastest native path. Maturing fast (quant GPTQ/AWQ, profiling). `mflux` = MLX-native port of FLUX.1, FLUX.2, Z-Image, Qwen Image, Ideogram, etc. Actively maintained 2026. Supports `-q 4` / `-q 8` quant.
- **PyTorch MPS** — broad model coverage (ComfyUI, diffusers, A1111 all run), but slower than MLX, some training ops missing/incomplete. ComfyUI on MPS ~3x slower than Draw Things (Metal FlashAttention vs MPS).
- **Draw Things** — Swift/Metal app, Metal FlashAttention 2.0, fastest turnkey GUI on Mac, ~20% faster than ComfyUI. Best hands-off batch option with its API/scripting.
- **Core ML / coremltools** — Apple's apple/ml-stable-diffusion exists, ANE-capable, but image-gen community has largely moved to MLX/Draw Things; Core ML conversion is fiddly and lags new models. Good for embedding into apps, not for chasing SOTA.
- **GGUF / llama.cpp quant** — GGUF used for FLUX quant in ComfyUI (Q4/Q6/Q8). llama.cpp itself is LLM, but the GGUF quant format is reused for diffusion UNet/transformer weights.

Sources: TDS PyTorch+MLX; MetalCloud MLX vs PyTorch; InsiderLLM SD Mac MLX; mflux GitHub/PyPI; Draw Things engineering blog (Metal FlashAttention 2.0); arxiv 2510.18921 MLX bench; arxiv 2501.14925 profiling Apple Silicon.

## Generation speed numbers (concrete, cited)

- **Mac Mini M4 Pro 24GB, ComfyUI:**
  - FLUX.1 Dev Q6_K, 1024², 20 steps: **~50-90 s/image**
  - SDXL 1024², 25 steps: **~20-40 s/image**
  - SD 1.5 512², 20 steps: ~5-10 s/image
  - DiffusionBee SDXL: ~1-2 min/image (slower path)
  - 48GB "unlocks FP16" (skip heavy quant) — faster, fewer compromises. (heyuan110 2026-02)
- **M4 Max Studio 40-core 128GB:** IllustriousXL (SDXL-class) +5 LoRA, batch 8 ≈ 42 s/batch vs RTX 4090 ≈ 11 s → **~4x slower than 4090**. MLX FLUX conversions "much much better" than MPS. (MacRumors forum)
- **SD 3.5 Medium, M4 Air 16GB:** ~15-25 s/image 1024². (willitrunai)
- NVIDIA reference: FLUX.1 Dev ~8-12 s (4090/5090), SDXL ~4.5 s (5090). Mac is ~3-5x slower but runs unattended.

Sources: heyuan110 Mac Mini benchmark; MacRumors M4M/M3U thread; willitrunai; solidaitech speed calc.

## Segmentation / matting speed (the ACTUAL task)

- **BiRefNet** (SOTA dichotomous segmentation / matting): RTX 4090 ~17 FPS (~59 ms) at 1024² FP16, 3.45 GB. Cloud A5000 <1 s/image. On CPU: seconds/image. On Mac MPS expect roughly **0.3-1.5 s/image** (no hard Apple number published, interpolate from 4090 17fps and ~4x Mac slowdown → ~4-5 fps → ~0.2-0.5 s; plus overhead → sub-1.5 s).
- **rembg** (U2Net / IS-Net / BiRefNet backends) supports MPS acceleration, batch CLI, anime + human + general models. Light: ~hundreds of ms to ~1-2 s/image on M-series.
- **SAM 2** can run MPS for prompted segmentation; heavier but still seconds, not minutes.
- Key point: segmentation memory footprint is tiny (3-4 GB) and compute is ~10-50x cheaper than a diffusion sample. 48GB is wildly over-provisioned for matting.

Sources: BiRefNet GitHub; RMBG-2.0 HF; rembg GitHub; ice-ice-bear BiRefNet post; Cloudflare bg-removal eval; Runware bg-removal collection.

## Thermal / sustained throughput (MacBook batch jobs)

- Apple M chips run rated speeds ~indefinitely under typical load (low heat). Throttling on MacBook is **power-limited more than heat-limited**; 14" has tighter envelope than 16".
- M4 Max sustains heavy GPU better than base/Pro (bigger thermal mass + cooling). 14" M4 Max can throttle under prolonged max GPU; 16" holds better.
- For an overnight wallpaper batch: generation jobs may throttle 10-20% on a 14" after sustained minutes; segmentation jobs are so light they will not throttle meaningfully. Plug in (battery caps perf), good ventilation.

Sources: dev.to M5 Pro vs M4 Max; mayhemcode M4 AI; MacRumors thermal threads; xidax thermal.

## Verdict synthesis

- **Black-background task = segmentation/matting → hardware is MASSIVE overkill.** Any M4 does it in well under ~2 s/image, tiny RAM. 48GB irrelevant to the task; it's a multi-second-per-folder problem.
- **General local generation:** comfortable on 48GB M4 Pro for SDXL (good), SD 3.5 (good), FLUX schnell/quantized (fine, 50-90s/img), FLUX dev FP16 (slow but runs thanks to 48GB headroom). Marginal = speed not capacity. Chip variant matters for speed (M4 Max ~1.5-2x faster than M4 Pro), not feasibility.
- **Ecosystem maturity 2026: YES, mature enough for hands-off batch.** Draw Things + scripting, mflux CLI, ComfyUI, rembg CLI all support unattended folder batch. Mac is slower than NVIDIA but fully turnkey.
