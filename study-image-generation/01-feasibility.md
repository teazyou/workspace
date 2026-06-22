# 01 — Feasibility: Hardware & Maturity Verdict

**Bottom line up front.** For your actual task — isolate the character and composite onto black — the hardware is *enormous overkill*. That task is image **segmentation / matting**, which runs in roughly **0.2–1.5 seconds per image** and needs only ~3–4 GB of memory; a base M4 would breeze through it, and your 48 GB M4 (almost certainly an **M4 Pro**, possibly an M4 Max) leaves ~45 GB unused. The bottleneck for a whole-folder batch will be disk I/O, not compute. Separately, *if* you want general local image **generation** (text-to-image, repaint, LoRA), the same machine is **comfortable** for SDXL / SD 3.5 and **usable-but-slow** for FLUX-class models (tens of seconds per image): you are speed-limited, never capacity-limited. The Mac local-image-AI ecosystem in 2026 is **mature enough for a fully hands-off batch pipeline** (Draw Things, mflux/MLX, ComfyUI, and rembg all support unattended folder processing). Where chip variant matters: GPU core count and memory bandwidth (M4 Pro 273 GB/s vs M4 Max 410–546 GB/s) change *generation* speed by ~1.5–2.7×, but do **not** change feasibility — and are irrelevant to the segmentation task.

---

## 1. The chip you have: M4 family specs

48 GB of unified memory is the key tell. The **base M4 caps at 32 GB**, so it cannot be a base M4. 48 GB is offered on the **M4 Pro** (24/48/64 GB configs) and on some **M4 Max** 16" configs. The overwhelmingly common 48 GB MacBook is an **M4 Pro**. Treat it as M4 Pro unless you know otherwise; note below where M4 Max would change the numbers.

| Chip | GPU cores | Memory bandwidth | Max unified memory | Relevance here |
|---|---|---|---|---|
| M4 (base) | up to 10 | 120 GB/s | 32 GB | Cannot be yours (32 GB cap) |
| **M4 Pro** | up to 20 | **273 GB/s** | 64 GB | **Most likely your chip** |
| M4 Max (base) | 32 | 410 GB/s | 128 GB | Possible; ~1.5× faster gen |
| M4 Max (top) | 40 | 546 GB/s | 128 GB | Possible; ~2× faster gen |

Unified memory means the GPU can address essentially all 48 GB (minus what macOS reserves — practically ~40–44 GB usable for a model). That is more than enough to hold *any* current single image model in full precision plus working buffers.

**Where chip variant materially changes the answer:** only generation throughput. An M4 Max has ~1.6× (32-core) to ~2.7× (40-core) the GPU and memory bandwidth of an M4 Pro, so FLUX/SDXL sampling is correspondingly faster. For *segmentation* (your task) the difference is noise — both finish each image in well under two seconds.

---

## 2. The Apple-Silicon ML/image stack in 2026 — maturity by layer

| Layer | What it is | Maturity for image work (2026) | Use it for |
|---|---|---|---|
| **MLX** (Apple) | Native array framework targeting unified memory directly | **High & rising.** Fastest native path; `mflux` provides MLX-native FLUX.1, FLUX.2, Z-Image, Qwen-Image, Ideogram, etc., with 4-/8-bit quant. Actively maintained. | Fastest CLI generation; quantized FLUX |
| **PyTorch MPS** | Generic Metal backend for PyTorch | **Broad but slower.** Runs ComfyUI, diffusers, A1111. ~3× slower than Draw Things on the same model; some training ops still missing/incomplete. | Maximum model/extension coverage |
| **Draw Things** | Swift/Metal app with Metal FlashAttention 2.0 | **High, turnkey.** ~20% faster than ComfyUI on Apple Silicon; scriptable API for batch. | Hands-off GUI/batch generation |
| **Core ML / coremltools** | Apple's deploy format, can use the ANE | **Lagging for SOTA.** `apple/ml-stable-diffusion` works, but conversion is fiddly and trails new models; community moved to MLX/Draw Things. | Embedding a fixed model into an app |
| **GGUF quant** (llama.cpp lineage) | Quantized weight format | **Mature for quant.** GGUF Q4/Q6/Q8 widely used for FLUX transformer weights in ComfyUI. | Shrinking FLUX to fit/run faster |

**Segmentation/matting stack** (the part you actually need) is even simpler and fully mature on Mac: **`rembg`** (CLI + Python, MPS-accelerated, BiRefNet/IS-Net/U2Net/human/anime backends, native batch over a folder), **BiRefNet** (current SOTA high-res matting), and **SAM 2** (prompted segmentation, MPS-capable). Section 02 owns the method choice; this section only certifies that the hardware and runtime are more than ready for it.

---

## 3. Realistic performance numbers

### 3a. Segmentation / matting — your actual task (fast, cheap)

| Model | Reference speed | Est. on M4 Pro (MPS) | Memory |
|---|---|---|---|
| BiRefNet (SOTA matting) | ~17 FPS / ~59 ms @1024² on RTX 4090; <1 s on A5000 | **~0.3–1.5 s/image** | ~3–4 GB |
| rembg (IS-Net/U2Net) | hundreds of ms on GPU | **~0.2–1 s/image** | ~1–2 GB |
| SAM 2 (prompted) | heavier | **~1–3 s/image** | ~3–6 GB |

No published Apple-specific BiRefNet benchmark exists; the M4 Pro estimate interpolates from the 4090 figure and the ~3–5× Mac-vs-4090 gap seen across image workloads. Even at the pessimistic end, a folder of a few hundred wallpapers finishes in **minutes**, using a fraction of memory. This is why 48 GB is irrelevant to the stated goal.

### 3b. Generation — only relevant if you later want to *synthesize*

Concrete, cited figures (M4 Pro-class, 1024², via ComfyUI/Draw Things unless noted):

| Model | Settings | M4 Pro (~24 GB) | Notes |
|---|---|---|---|
| SD 1.5 | 512², 20 steps | ~5–10 s/image | Trivial |
| SDXL | 1024², 25 steps | **~20–40 s/image** | Comfortable |
| SD 3.5 Medium | 1024² | ~15–25 s/image (M4 Air 16 GB) | Comfortable |
| FLUX.1 Dev (Q6_K) | 1024², 20 steps | **~50–90 s/image** | Usable, slow |
| FLUX.1 Dev (FP16) | 1024² | slower still, but **48 GB lets you skip quant** | Capacity headroom pays off here |

For scale: an RTX 4090/5090 does FLUX.1 Dev in ~8–12 s and SDXL in ~4.5 s — so the Mac is roughly **3–5× slower**, but runs the whole job unattended on a laptop. An M4 Max would roughly halve the Mac times above. **48 GB's real generation benefit is headroom**: you can run FLUX in full precision (FP16) and keep multiple LoRAs / large batches resident instead of fighting quantization, which is exactly where a 24 GB machine starts to compromise.

**Comfortable vs marginal for generation:** SD 1.5 / SDXL / SD 3.5 are *comfortable*. FLUX-class is *usable but slow* (tens of seconds to ~1.5 min per image) — marginal on **time**, never on memory. Nothing in the current local catalog is out of reach on 48 GB.

---

## 4. Sustained throughput & thermals for long batch jobs

Apple Silicon throttles primarily on a **power budget, not raw heat**, and M-chips run at rated clocks for extended periods because they generate relatively little heat. Practical guidance for an overnight wallpaper batch on a MacBook:

- **Segmentation batch:** so light it will **not** throttle meaningfully — the GPU is barely loaded. Run it on battery if you want.
- **Generation batch:** sustained max-GPU sampling for many minutes can shave ~10–20% off throughput on a **14"** chassis (tighter power envelope); the **16"** holds clocks better. The M4 Max has more thermal headroom than the M4 Pro under prolonged load.
- **Recommendations:** keep it **plugged in** (battery operation caps GPU performance), ensure airflow, and for very large generation runs prefer the 16" or accept a modest steady-state slowdown. None of this threatens *completion* — only wall-clock time.

---

## 5. Verdicts

**(a) For the black-background task — is the hardware enough?**
**Massively.** This is segmentation + compositing, not diffusion. Sub-2-second-per-image, ~3–4 GB, no thermal concern. A base M4 would suffice; your 48 GB M4 Pro is overkill. Buy nothing, downgrade nothing — you already have far more than the task needs.

**(b) For general local generation — comfortable vs marginal?**
**Comfortable** for SD 1.5, SDXL, SD 3.5 (seconds to tens of seconds/image). **Usable but slow** for FLUX-class (≈50–90 s/image quantized; FP16 possible thanks to 48 GB but slower). You are **speed-limited, never capacity-limited.** An M4 Max would make FLUX noticeably more pleasant (~1.5–2× faster); an M4 Pro is fine for batch/overnight use.

**(c) Ecosystem maturity — ready for a hands-off batch pipeline in 2026?**
**Yes.** Both halves are turnkey: **rembg** (and BiRefNet) batch a folder from one CLI command with MPS acceleration for the actual task; **Draw Things**, **mflux/MLX**, and **ComfyUI** all support unattended generation if you later want it. The Mac is slower than NVIDIA but fully automatable. See **Section 04** for the concrete recommended pipeline and the one-command install, and **Section 02** for the segmentation method.

**Chip-variant flags (where 48 GB ⇒ M4 Pro matters):** assume M4 Pro (273 GB/s, ≤20 GPU cores). If it's actually an M4 Max (410–546 GB/s, 32–40 GPU cores), every *generation* time above improves ~1.5–2.7×; the *segmentation* task and all feasibility conclusions are identical either way.

---

## Sources

- Apple — M4 Pro and M4 Max introduction: https://www.apple.com/newsroom/2024/10/apple-introduces-m4-pro-and-m4-max/
- Apple Support — MacBook Pro (14-inch, M4 Pro/M4 Max, 2024) tech specs: https://support.apple.com/en-us/121553
- Apple Support — MacBook Pro (14-inch, M4, 2024) tech specs: https://support.apple.com/en-us/121552
- Wikipedia — Apple M4: https://en.wikipedia.org/wiki/Apple_M4
- 9to5Mac — M4 Max 16-core CPU, 40-core GPU, +35% bandwidth: https://9to5mac.com/2024/10/30/m4-max-chip-has-16-core-cpu-40-core-gpu-and-35-increase-in-memory-bandwidth/
- Notebookcheck — Apple M4 Max (16-core) specs: https://www.notebookcheck.net/Apple-M4-Max-16-cores-Processor-Benchmarks-and-Specs.920458.0.html
- Towards Data Science — PyTorch and MLX for Apple Silicon: https://towardsdatascience.com/pytorch-and-mlx-for-apple-silicon-4f35b9f60e39/
- MetalCloud — MLX vs PyTorch: when to use Apple's framework: https://metalcloud.space/blog/mlx-vs-pytorch-comparison/
- arXiv 2510.18921 — Benchmarking On-Device ML on Apple Silicon with MLX: https://arxiv.org/html/2510.18921v1
- arXiv 2501.14925 — Profiling Apple Silicon Performance for ML Training: https://arxiv.org/pdf/2501.14925
- InsiderLLM — Stable Diffusion on Mac with MLX and Draw Things: https://insiderllm.com/guides/stable-diffusion-mac-mlx/
- filipstrand/mflux (MLX-native image models): https://github.com/filipstrand/mflux
- mflux on PyPI: https://pypi.org/project/mflux/
- Draw Things engineering — Metal FlashAttention 2.0: https://engineering.drawthings.ai/p/metal-flashattention-2-0-pushing-forward-on-device-inference-training-on-apple-silicon-fe8aac1ab23c
- heyuan110 — Mac Mini M4 local image generation (ComfyUI vs Draw Things, FLUX/SDXL timings, 24GB/48GB): https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/
- MacRumors — M4 Max & M3 Ultra image generation speed thread: https://forums.macrumors.com/threads/m4m-and-m3u-for-image-generation-speed-sd-flux-etc.2454524/
- Will It Run AI — SD 3.5 Medium VRAM/speed: https://willitrunai.com/blog/sd-3-5-medium-vram-requirements
- SolidAITech — Stable Diffusion & Flux speed/it-s benchmark 2026: https://www.solidaitech.com/2026/05/stable-diffusion-speed-calculator-its-benchmark-guide.html
- ZhengPeng7/BiRefNet (SOTA high-res segmentation/matting): https://github.com/ZhengPeng7/BiRefNet
- briaai/RMBG-2.0 (BiRefNet-based background removal): https://huggingface.co/briaai/RMBG-2.0
- danielgatis/rembg (MPS-accelerated batch background removal): https://github.com/danielgatis/rembg
- ice-ice-bear — BiRefNet vs rembg: https://ice-ice-bear.github.io/posts/2026-04-15-birefnet/
- Cloudflare — Evaluating image segmentation models for background removal: https://blog.cloudflare.com/background-removal/
- dev.to — GPU-accelerated ML on M5 Pro vs M4 Max: https://dev.to/valesys/gpu-accelerated-mldl-performance-on-macbook-pro-m5-pro-vs-m4-max-feasibility-and-benchmarks-for-2ka3
- Mayhemcode — Apple M4 chip AI performance explained: https://www.mayhemcode.com/2026/05/apple-m4-chip-ai-performance-explained.html
