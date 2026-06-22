# SOTA Local Generative Image Models — Raw Research Notes (2026-06-22)

Scope: open-weight / locally-runnable text-to-image models that run on a 48 GB Apple-Silicon (M4-class) Mac. For the user's actual task (character isolation onto black) see section 02 — generation is NOT required for that. This catalog serves the "best local image AI I can get" ask and feeds the LoRA annex.

## Hardware framing
- Target: M4-class Mac, 48 GB unified memory. 48 GB => almost certainly M4 Pro (Air/base Pro cap 24–32 GB). Could be M4 Max.
- Chip variant matters for SPEED, not capability. GPU core counts: M4 (10c), M4 Pro (16–20c), M4 Max (32–40c). Memory bandwidth: M4 ~120 GB/s, M4 Pro ~273 GB/s, M4 Max ~410–546 GB/s. Image-gen throughput scales roughly with GPU cores + bandwidth, so M4 Max is ~2x M4 Pro per step.
- 48 GB unified means the GPU can address ~36–44 GB of weights+activations. This unlocks running the largest open models (FLUX.2 dev 32B, Qwen-Image 20B) at meaningful quant, and FLUX.1/SDXL at full fp16 comfortably.
- 48 GB "unlocks FP16" per Draw Things benchmarks; 24 GB pushes you to GGUF quant for FLUX.

## FLUX family (Black Forest Labs)
- FLUX.1 [dev]: 12B rectified-flow transformer. Top open quality for most of 2024–2025. ~20–25 steps. NON-COMMERCIAL license (outputs commercial use is debated; weights non-commercial). Most mature LoRA + ControlNet + IP-Adapter ecosystem of any open model.
- FLUX.1 [schnell]: 12B, distilled, ~4 steps, Apache 2.0 (commercial OK). Lower diversity/quality than dev but fast and license-clean.
- FLUX.2 launched 2025-11-25. Family: pro, flex, dev, klein.
  - FLUX.2 [dev]: 32B rectified-flow transformer. SOTA open text-to-image + single/multi-reference editing. Up to 4 MP output, up to 10 reference images. NON-COMMERCIAL (FLUX dev license). Wants 24GB+ VRAM; GGUF Q4 makes it run on 48 GB Mac comfortably.
  - FLUX.2 [klein]: distillation-free size reduction (keeps diversity, unlike schnell). 4B variant = Apache 2.0 (commercial OK!), 9B variant = FLUX non-commercial. "Sub-second on datacenter GPU." GGUF Q4 9B fits ~12GB. 4B Apache is the license-clean speed pick.
- FLUX.1 dev memory: 16GB Mac runs Q4_KS (~7GB), 24GB runs Q6_K (~10GB), 48GB runs fp16 (~24GB).

## Stable Diffusion 3.5 (Stability AI)
- SD3.5 Large: 8.1B MMDiT. fp16 ~18GB VRAM; NVIDIA FP8 build ~11GB. Released Oct 2024.
- SD3.5 Large Turbo: distilled, 4 steps, high prompt adherence.
- SD3.5 Medium: 2.5B, ~9.9GB VRAM (excl text encoders). Most accessible.
- License: Stability AI Community License — FREE commercial up to $1M annual revenue, free non-commercial/research. Much friendlier than FLUX dev.
- Quality generally below FLUX.1 dev and well below FLUX.2/Qwen by 2026, but license + speed + ecosystem keep it relevant.

## SDXL + ecosystem
- SDXL 1.0: 3.5B UNet. Released 2023. fp16 ~7–8GB. Runs trivially on 48GB at full precision; fast.
- THE deepest ecosystem: thousands of fine-tunes (Juggernaut, RealVis, DreamShaper, Copax, ZavyChroma, Illustrious, Pony, NoobAI), full ControlNet suite, IP-Adapter (incl. face variants), inpainting models, LoRAs.
- Best for editing existing wallpapers (img2img/inpaint/ControlNet/IP-Adapter) because of tooling maturity. CreativeML OpenRAIL++ license — commercial OK.
- 2025: Illustrious/NoobAI ControlNets added; ecosystem still very active for anime/illustration.

## Qwen-Image (Alibaba Tongyi)
- Qwen-Image: 20.4B DiT + 8.3B text encoder. Released Aug 2025. Qwen-Image-2512 (Dec 2025) update.
- Ranks #1 open-source on AI Arena (10k+ blind rounds); competitive with closed models. Especially strong text rendering + photorealism + editing.
- fp16 ~42GB VRAM (too big for fp16 on 48GB w/ headroom — tight). FP8 ~22GB. 4-bit ~17GB (quality 91.7 vs 95.2 fp). DiffSynth layer offload can run in 4GB (slow).
- Qwen-Image-Edit-2509/2511: instruction editing, multi-image editing.
- Apache 2.0 license — commercial OK. Big deal vs FLUX.
- Atlas note: a newer "Qwen Image 2.0" 7B variant reportedly beating FLUX.2 in AI Arena — worth flagging as emerging.

## Z-Image-Turbo (Alibaba Tongyi-MAI)
- 6B single-stream DiT. Released Nov 2025. Distilled, 8 steps. ~2–3s/image on datacenter GPU.
- BF16 ~14–16GB, FP8 ~8GB, GGUF onto 6GB. Strong photorealism, bilingual EN/CN text. Apache-style/open.
- Best quality-per-VRAM and quality-per-second in the lightweight tier. Supported in mflux.
- ControlNet via "ZImage Turbo Fun ControlNet" patch but reported quality issues.

## Other notable (2025-2026)
- PixArt-Σ: 0.6B DiT, very light, 1024px+, weak vs modern models now — lighter/older option.
- Würstchen / Stable Cascade: efficient latent cascade, largely superseded; low community momentum.
- FIBO (8B, JSON prompts, edit), ERNIE-Image (8B, Baidu, vivid), Ideogram 4 (9B, typography), LongCat-Image, Ovis-Image — emerging, all in mflux's supported list.
- SeedVR2 (3B/7B) — upscaling, not t2i.

## Apple-native runtimes
- Draw Things (free, App Store): the recommended Mac app. Metal/MLX backend. ~20% faster than ComfyUI on Apple Silicon. Supports SDXL, FLUX.1, FLUX.2, FLUX.2 klein (4B/9B + base), Qwen Image + Qwen Edit 2509, Wan 2.2, Z-Image, LTX video. Full ControlNet (Alimama inpaint, Jasper), inpaint/outpaint/pose, on-device LoRA training, GGUF import, LoRA import. 48GB unlocks fp16.
- mflux (filipstrand/mflux): MLX-native CLI/python. Supports Z-Image (6B), FLUX.2 (4B/9B), Ideogram 4 (9B), ERNIE-Image (8B), FIBO (8B), SeedVR2 (3B/7B), Qwen-Image (20B), Depth Pro, FLUX.1 (12B). Features: img2img, multi-LoRA, ControlNet (Canny), depth, fill/inpaint, Redux, in-context edit, upscaling. Quant: 3/4/6/8-bit. Scriptable -> good for batch.
- MFLUX-WEBUI (CharafChnioune): web UI on mflux. Qwen/Qwen Edit, IC-Edit, ControlNet, FLUX2 Klein tabs.
- Core ML Stable Diffusion (apple/ml-stable-diffusion): converts SD/SDXL to Core ML for ANE+GPU. Mature for SD1.5/SDXL, no modern (FLUX/Qwen) support; largely superseded by MLX/Draw Things for new models.
- ComfyUI: works on MPS but ~20% slower than Draw Things on Mac; best for complex node graphs/ControlNet workflows. Many CUDA-only nodes won't run.

## Benchmarks (concrete, cited)
- M4 Pro 24GB: FLUX.1 dev Q6_K, 1024x1024, 20 steps = ~50–90 s/image (ComfyUI). Mac Mini M4 Pro 24GB ~50s reported.
- M4 Pro 24GB: SDXL 1024x1024, 25 steps = ~20–40 s/image (ComfyUI).
- SD1.5 512x512 20 steps = ~5–10s.
- Draw Things ~20% faster than ComfyUI on same HW.
- mflux M4 Max 128GB: schnell 2 steps 1024x1024 = ~10.56s. (M4 Max ~2x M4 Pro.)
- Extrapolation for 48GB M4 Pro: fp16 fits, FLUX.1 dev fp16 ~40–60s/img (faster than Q-quant if bandwidth-bound? actually larger weights => slower; quant helps speed via less bandwidth). Practically: FLUX.1 dev ~40–70s, FLUX.2 dev (32B Q4) noticeably slower ~2–4min, Qwen 20B Q4 ~1–3min, SDXL ~15–30s, Z-Image Turbo 8-step ~10–25s.

## License summary (commercial use)
- Apache 2.0 / commercial-OK: FLUX.1 schnell, FLUX.2 klein 4B, Qwen-Image, Z-Image-Turbo, SDXL (OpenRAIL++).
- $1M revenue gate: SD3.5 (all).
- Non-commercial weights: FLUX.1 dev, FLUX.2 dev, FLUX.2 klein 9B.

## Sources
- https://github.com/filipstrand/mflux
- https://pypi.org/project/mflux/
- https://github.com/CharafChnioune/MFLUX-WEBUI
- https://bfl.ai/blog/flux-2
- https://huggingface.co/black-forest-labs/FLUX.2-dev
- https://github.com/black-forest-labs/flux2
- https://venturebeat.com/technology/black-forest-labs-launches-open-source-flux-2-klein-to-generate-ai-images-in
- https://news.smol.ai/issues/25-11-25-flux2
- https://insiderllm.com/guides/flux-locally-complete-guide/
- https://lilting.ch/en/articles/flux2-klein-apple-silicon
- https://stability.ai/news-updates/introducing-stable-diffusion-3-5
- https://education.civitai.com/getting-started-with-stable-diffusion-3-5/
- https://willitrunai.com/image-models/sd-3-5-medium
- https://github.com/QwenLM/Qwen-Image
- https://huggingface.co/Qwen/Qwen-Image-Edit/discussions/6
- https://qwen-image-2512.com/blog/qwen-image-2512-gguf-complete-guide
- https://willitrunai.com/blog/qwen-image-local-guide
- https://www.atlascloud.ai/blog/guides/qwen-image-2-0-vs-flux-2-why-this-7b-model-is-beating-the-giants-in-ai-arena
- https://huggingface.co/Tongyi-MAI/Z-Image-Turbo
- https://www.digitalocean.com/community/tutorials/image-generation-model-review
- https://localaimaster.com/blog/z-image-turbo-comfyui
- https://drawthings.ai/downloads/
- https://wiki.drawthings.ai/wiki/Prompting_Base_Model_Basics
- https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/
- https://www.heyuan110.com/posts/ai/2026-02-15-drawthings-ultimate-guide/
- https://engineering.drawthings.ai/p/metal-flashattention-2-0-pushing-forward-on-device-inference-training-on-apple-silicon-fe8aac1ab23c
- https://huggingface.co/docs/diffusers/en/using-diffusers/ip_adapter
- https://blog.segmind.com/best-stable-diffusion-xl-sdxl-models/
- https://github.com/apple/ml-stable-diffusion
