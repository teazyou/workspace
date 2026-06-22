# LoRA / Fine-Tuning Annex — Raw Research Notes

Target HW: M4 MacBook, 48 GB unified memory (likely M4 Pro; possibly M4 Max). MPS backend.
User's actual goal: isolate character → composite on solid black. This is SEGMENTATION/MATTING, NOT generation. LoRA is largely IRRELEVANT to that goal.

## RELEVANCE CAVEAT (the core honesty point)
- LoRA fine-tunes a GENERATIVE diffusion model to learn a STYLE or SUBJECT. It changes what the model *paints*.
- The user's rule (foreground extraction → black bg) needs an ALPHA MASK, produced by a segmentation/matting model (RMBG-2.0, BiRefNet, SAM2, isnet-anime). See section 02.
- A LoRA does nothing to improve mask quality or background removal. Training a LoRA will NOT help the stated task at all.
- IF isolation accuracy is poor on a specific art style, the right move is to FINE-TUNE A SEGMENTATION MODEL, not train a LoRA.
  - Precedent: ToonOut (arxiv 2509.06839) fine-tuned BiRefNet on 1,228 annotated anime images. Pixel accuracy 95.3% -> 99.5%. Dataset = RGB + GT alpha mattes (RGBA). Code/weights/data: github.com/MatteoKartoon/BiRefNet. This is supervised matting training (needs alpha-mask labels), a different discipline from diffusion LoRA.
  - For anime specifically, isnet-anime (rembg) is the recommended off-the-shelf model.

## mflux (filipstrand/mflux) — MLX-native
- Line-by-line MLX port of Diffusers FLUX. Apple Silicon native (no PyTorch/MPS).
- LoRA fine-tuning via DreamBooth technique since v0.5.0.
- 2026: local-model LoRA training; FLUX.2 + Z-Image training adapters; expanded LoRA key mapping for FLUX.2/Z-Image.
- Supports multi-LoRA, scales, library lookup at inference.
- Config-file driven training (JSON/TOML config + image folder + captions).
- Caveat: detailed training memory/time numbers not in README top; per-model READMEs in src/mflux/models/.

## Draw Things (drawthings.ai) — GUI, recommended easy path on Mac
- Free Mac/iOS app. Built-in LoRA training on Apple Silicon (Metal, no PyTorch).
- Trains: SDXL, SD1.5, SD3 Medium 3.5, FLUX.1 [dev], Kwai Kolors; 2026 added FLUX.2 [klein] 4B/9B, Z-Image, Qwen Image.
- DreamBooth-style personalization built in.
- Metal FlashAttention v2 → 20-25% RAM reduction. Only efficient macOS/iOS app that both infers AND fine-tunes FLUX.1 [dev] (11B).
- drawthings engineering blog: training FLUX.1 LoRA ~9 sec/step/image @1024 on M2 Ultra. M4 Pro will be slower (fewer GPU cores, less bandwidth); M4 Max closer.
- Best "it just works" option on Mac — avoids the MPS/PyTorch breakage.

## ai-toolkit (ostris) — the de facto standard, but CUDA-first
- Primary tool for FLUX.2 / Z-Image / Qwen training. CUDA-first.
- Mac/MPS = painful. Needs forks: hughescr/ai-toolkit (torch.amp not torch.cuda.amp, spawn not fork, disable T5 quantizer on MPS, num_workers=0); poyen-wu/ai-toolkit-mps dedicated fork.
- Issue #871: extensive FLUX.2-dev LoRA attempts on M-series FAILED to converge. Loss 0.6->0.513 over 200 steps (only ~13 epochs, 15 imgs); oscillation 0.45-0.56; fp16 -> OOM ("allocated 155.74 GiB"); cached embeds + high LR -> NaN. Gradient checkpointing mandatory. NO working config documented, NO maintainer confirmation MPS is supported.
- Verdict: ai-toolkit on Mac is experimental/unreliable for FLUX.2. SDXL more tractable but still rough.

## kohya_ss / sd-scripts — Mac support marginal
- macOS "compatibility may vary"; Linux is the maintained target.
- SDXL LoRA: 16 GB insufficient without grad checkpointing (speed sacrifice). 48 GB unified helps but MPS still lacks xFormers/CUDA kernels → much slower per step than NVIDIA.
- M1 mac got it running historically (issue #1248) but slow and fiddly.

## Memory / quantization facts (FLUX LoRA)
- FLUX.1 LoRA: Kohya needs ~16-24 GB VRAM. Quantize-at-startup ~50 GB system RAM.
- Rank-16 full LoRA: >30 GB unquantized; ~9 GB if NF4/int2 + bf16.
- 4-bit (bitsandbytes) cuts peak ~60GB -> ~37GB negligible quality loss; +cached VAE latents -> under 10 GB. (NOTE: bitsandbytes is CUDA-only — does NOT work on MPS. This optimization is unavailable on Mac, a key Apple-Silicon gap.)
- FLUX.2 (32B) / Qwen / FLUX.2 Klein: need 32 GB, practically 48 GB to avoid OOM. On 48 GB unified Mac this is borderline and only with heavy quant + grad checkpointing.

## Cloud rental (the realistic path for serious training)
- RunPod 2026: A100 PCIe ~$1.29-1.39/hr; A100 80GB; H100 PCIe ~$2.65-2.89/hr; H100 SXM ~$2.69/hr. Billed by ms.
- A100 40GB or L40S 48GB good cost/perf for LoRA. FLUX.2/Qwen LoRA: pick >=32GB, ideally 48GB.
- Typical SDXL/FLUX.1 LoRA finishes in ~20-60 min on A100 → ~$1-2 total. FLUX.2 longer.
- Pattern: rent GPU for the few hours of TRAINING (fast, full ecosystem incl. bitsandbytes/xformers), download the small LoRA file (~10-300 MB), run INFERENCE locally on the Mac (mflux/Draw Things). Best of both.
- Also: Replicate (managed FLUX LoRA trainer, no infra), fal.ai, Civitai trainer, Google Colab (cheaper/free tier but session limits).

## No-training alternatives (often achieve intent without any LoRA)
- IP-Adapter: give a reference image for style/subject, no training, orders of magnitude cheaper than fine-tuning. IP-Adapter-FaceID for identity. Better composability than full FT.
- ControlNet: structural control (pose/depth/canny/composition). Combine w/ IP-Adapter (style) — common pattern (ICAS arxiv 2504.13224).
- Reference / style transfer: quick variations from one reference image.
- Use LoRA only for long-term identity recall / a repeated specific subject/style; otherwise IP-Adapter wins on speed.
- ALL of these are still GENERATIVE tools — none help the black-bg segmentation task.

## Feasibility verdict (48 GB M4)
- SDXL LoRA: realistic on Mac. Draw Things easiest; mflux N/A (FLUX-line); kohya works but slow/fiddly. Hours not minutes.
- FLUX.1 [dev] LoRA: realistic via Draw Things or mflux on 48 GB (quantized). Slow (~sec-tens-of-sec/step). ai-toolkit unreliable.
- FLUX.2 / Qwen LoRA: borderline-to-unsupported on Mac (48 GB tight, convergence issues per #871). Recommend cloud.
- Chip variant matters: M4 Pro (~16-20 GPU cores, ~273 GB/s) vs M4 Max (~32-40 cores, ~410-546 GB/s) → Max ~2x throughput. Both far below A100/H100.

## Dataset prep (for LoRA, if they do want generation)
- Subject LoRA: 10-30 high-quality images, varied pose/lighting/background; consistent subject. Captions (trigger word). 1024px.
- Style LoRA: 20-100 images of the style.
- Steps: ~1000-3000 (subject), rank 16-32. Overfitting risk if too many steps / too few images.

---
## Sources
- mflux: https://github.com/filipstrand/mflux ; releases https://github.com/filipstrand/mflux/releases ; pypi https://pypi.org/project/mflux/0.6.2/
- Draw Things LoRA training wiki: https://wiki.drawthings.ai/wiki/LoRA_Training (403 to fetcher; cited from search)
- Draw Things engineering (fine-tuning, MFA v2): https://engineering.drawthings.ai/p/draw-things-democratizes-local-large-model-fine-tuning-on-iphone-ipad-and-mac-2ceb60b5b462 ; https://engineering.drawthings.ai/p/metal-flashattention-2-0-pushing-forward-on-device-inference-training-on-apple-silicon-fe8aac1ab23c
- Draw Things 2026 review: https://www.heyuan110.com/posts/ai/2026-02-15-draw-things-ultimate-guide/
- ai-toolkit: https://github.com/ostris/ai-toolkit ; MPS issue #871 https://github.com/ostris/ai-toolkit/issues/871 ; MPS fork https://github.com/poyen-wu/ai-toolkit-mps ; hughescr fork https://github.com/hughescr/ai-toolkit
- Mac FLUX training blog: https://huggingface.co/blog/AlekseyCalvin/mac-flux-training
- kohya_ss: https://github.com/bmaltais/kohya_ss ; M1 issue #1248 https://github.com/bmaltais/kohya_ss/issues/1248 ; sd-scripts https://github.com/kohya-ss/sd-scripts
- LoRA training guide 2026 (VRAM): https://sanj.dev/post/lora-training-2025-ultimate-guide/
- FLUX QLoRA consumer HW: https://huggingface.co/blog/flux-qlora
- SimpleTuner FLUX: https://github.com/bghira/SimpleTuner/blob/main/documentation/quickstart/FLUX.md
- Civitai VRAM FLUX: https://civitai.com/articles/9487/managing-vram-to-optimize-performance-for-flux-training
- RunPod pricing: https://www.runpod.io/pricing ; GPU pricing 2026: https://www.spheron.network/blog/gpu-cloud-pricing-comparison-2026/
- ToonOut (segmentation fine-tune): https://arxiv.org/html/2509.06839v1 ; dataset https://huggingface.co/datasets/joelseytre/toonout
- BiRefNet: https://github.com/zhengpeng7/birefnet ; RMBG-2.0 https://huggingface.co/briaai/RMBG-2.0 ; ComfyUI-RMBG https://github.com/1038lab/ComfyUI-RMBG
- IP-Adapter: https://huggingface.co/docs/diffusers/using-diffusers/ip_adapter ; ICAS https://arxiv.org/html/2504.13224v1
- MLX fine-tuning guide: https://insiderllm.com/guides/fine-tuning-mac-lora-mlx/
