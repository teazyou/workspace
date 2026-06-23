# Research notes — Instruction-based local image-editing models (Apple Silicon)

Research angle: local (offline, Apple-Silicon) instruction-driven image-EDITING models that take an
input image + a text instruction and do "keep these things, recolor that thing, replace the background
with plain black." Compiled 2026-06-23.

Hardware target: MacBook Pro, M4 Pro, 64 GB unified memory, macOS.

Reference task (the annex's editing prompt):
> "Keep the character, keep the yoga rope, keep the flower on the ground but make them red, then
> replace the entire background with plain black — wallpaper style."

This is a **selective-keep + recolor + plain-black-background** edit on an existing image. The right
tool class is **instruction-based image editors** (image + text → edited image), not text-to-image
generators.

---

## 1. FLUX.1 Kontext [dev] (Black Forest Labs)

**Source cards / guides:**
- HF model card: https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev
- BFL model page: https://bfl.ai/models/flux-kontext
- BFL image-to-image prompting guide: https://docs.bfl.ml/guides/prompting_guide_kontext_i2i
- ComfyUI Kontext guide: https://comfyui-wiki.com/en/tutorial/advanced/image/flux/flux-1-kontext
- GGUF quants (QuantStack): https://huggingface.co/QuantStack/FLUX.1-Kontext-dev-GGUF
- city96 ComfyUI-GGUF node: https://github.com/city96/ComfyUI-GGUF
- mflux (MLX): https://github.com/filipstrand/mflux
- Together blog: https://www.together.ai/blog/flux-1-kontext

**What it is:** 12B-parameter rectified-flow transformer for instruction-based image editing. Edits an
existing image from a text instruction; strong **character consistency** across successive edits with
"minimal visual drift" (no fine-tuning needed). Good at straightforward object modification (recolor),
style/character references, and local edits.

**License:** "FLUX.1 [dev] Non-Commercial License." NON-COMMERCIAL for the open weights (commercial use
needs a BFL license / the hosted Pro/Max API). This is the key licensing disadvantage vs Qwen. The
open-weight deployment also references content filters per the license.
- NOTE / CLAIM TO VERIFY: one HF-fetch summary phrased the license as "permits personal, scientific,
  and commercial use under specific terms" — that wording is misleading; the standard reading is the
  weights are non-commercial and commercial use requires a separate BFL commercial license. Treat
  Kontext [dev] as NON-COMMERCIAL for local use.

**Apple-Silicon runnability:**
- Diffusers supports `mps` device mapping (official card lists CUDA + Apple Silicon via "mps").
- ComfyUI native: works; for Macs the practical path is **GGUF** via city96 **ComfyUI-GGUF**
  (place .gguf in `ComfyUI/models/unet`).
- **mflux** (native MLX port) supports Kontext editing + quantization (`-q 8`, 4-bit/8-bit) and local
  quantized model save/load — the most Mac-native option.
- **Draw Things** supports Kontext (runs at ~5-bit quant on M4 Pro 24GB in their benchmarks). Draw
  Things is reportedly ~25% faster per iteration than mflux on M2 Ultra, and much faster than ggml/gguf
  (ggml ≈ gguf path); Metal FlashAttention 2.0 adds up to ~20% on M3/M4.

**Memory footprint (GGUF, QuantStack):**
- Q4_K_S ≈ 6.8 GB, Q4_0 ≈ 6.8 GB, Q4_K_M ≈ 6.93 GB, Q4_1 ≈ 7.54 GB, Q8_0 ≈ 12.7 GB (transformer only;
  add T5 + CLIP text encoders + VAE on top).
- Q6_K is widely cited as the "sweet spot" for Macs; Q4_K_S + quantized T5 is the 16GB combo. On a
  64GB M4 Pro you can comfortably run Q8_0 or even bf16.

**Speed (Apple Silicon, approximate):**
- General FLUX.1 1024×1024 ≈ ~50 s on Mac Mini M4 Pro 24GB (ComfyUI/Draw Things benchmark). Kontext is
  the same 12B backbone so expect the same order of magnitude (tens of seconds per image) on a 64GB
  M4 Pro, faster with fewer steps / Draw Things' Metal FlashAttention. (No isolated Kontext-on-M4
  seconds number found — flagged as claim to verify.)
- `--use-pytorch-cross-attention` cuts ComfyUI generation time 30–50% on M3/M4.

**Prompting conventions for "keep X, change Y" (from BFL i2i guide):**
- Preserve intentionally: explicitly state what stays. Use "while maintaining the same [facial
  features / composition / lighting / position / scale / pose]".
- Background swap example phrasing: "Change the background to a beach **while keeping the person in
  the exact same position, scale, and pose**."
- Object recolor: direct instruction, e.g. "change the color of [object] to red" — Kontext is "really
  good at straightforward object modification."
- Text edits: quotation marks — `Replace '[original text]' with '[new text]'`.
- Character consistency framework: identify the subject ("the woman with short black hair…"), state the
  change, then list identity markers to preserve.
- For the annex task, a Kontext-style prompt: "Make the character, the yoga rope, and the flower on the
  ground red, while keeping their exact shapes, positions and poses. Replace the entire background with
  a solid plain black background, wallpaper style." — issue selective recolor + explicit "solid plain
  black background" + "keep position/pose" preservation clause.

---

## 2. Qwen-Image-Edit / Qwen-Image-Edit-2509 (Alibaba Qwen)

**Source cards:**
- HF card: https://huggingface.co/Qwen/Qwen-Image-Edit-2509
- Mac walkthrough (M1 Max 64GB): https://soywiz.com/qwen_image_edit/
- Lightning LoRA: https://github.com/ModelTC/LightX2V-Qwen-Image-Lightning
- Tutorial / GGUF VRAM table: https://www.stablediffusiontutorials.com/2025/09/qwen-image-edit-2509.html
- Next Diffusion ComfyUI guide: https://www.nextdiffusion.ai/tutorials/how-to-use-qwen-for-image-editing-in-comfyui

**What it is:** ~20B image-edit model built on the Qwen-Image backbone. The **2509** revision adds:
- **Multi-image editing** (person+person, person+product, person+scene; best with 1–3 images).
- Stronger **single-image consistency**: better facial identity preservation across poses/styles;
  product identity retention; text editing of content + font/color/material.
- **Native ControlNet** support (keypoint/pose, sketch, depth-style conditions).
- Does both **semantic** (what's in the image) and **appearance** (recolor/material) editing.

**License:** **Apache 2.0** — commercial use allowed. This is its main advantage over FLUX Kontext.

**Apple-Silicon runnability + the fp8 caveat:**
- KEY CAVEAT: the **MPS backend does not support fp8 tensor types** (e.g. `fp8_e4m3fn`). On MPS, fp8
  weights get converted on the fly to fp16/fp32, using **2×–4× the memory** they should — so the
  native fp8 .safetensors is the wrong choice on Mac. **Use GGUF instead** (via city96 ComfyUI-GGUF,
  files in `ComfyUI/models/unet`). This is the single most important Apple-Silicon gotcha for Qwen.
- Works in ComfyUI (GGUF), Draw Things, and stable-diffusion.cpp (slow on Mac).

**Memory footprint (GGUF VRAM, from tutorial table):**
- Q2_K ≈ 7.06 GB, Q4_K_S ≈ 12.1 GB, Q8_0 ≈ 21.8 GB (transformer only; add Qwen2.5-VL text encoder +
  VAE). On a 64GB M4 Pro, Q8_0 / Q6_K is comfortable.

**Speed (Apple Silicon, from the M1 Max 64GB walkthrough — note: M1 Max, not M4):**
- stable-diffusion.cpp, Q8_0, 20 steps, CPU-offload: ~**9 minutes** per change (very slow).
- Vulkan backend, Q4_K_S: ~**20 minutes**.
- **ComfyUI** path: ~**3–4 minutes** for a modified image from two inputs.
- Draw Things with **4-step Lightning LoRA** (2 steps configured): dramatically faster.
- These are M1 Max numbers; an M4 Pro should be meaningfully faster, but no clean M4 seconds figure was
  found — flagged as claim to verify. Bottom line: without Lightning, Qwen-Image-Edit is slow on Mac
  (minutes); with the 4-step Lightning LoRA it becomes practical.

**Lightning 4-step LoRA:** `Qwen-Image-Edit-2509-Lightning-4steps-V1.0` (fp32/bf16) — load into
`ComfyUI/models/loras/`, set KSampler steps to 4. Draw Things variant:
`qwen_image_edit_2509_lightning_4_step_v1.0_lora_f16.ckpt`. Cuts inference ~5–10× at small quality cost.
(Repo also shows newer 2511-Lightning builds; an HF discussion notes a *broken fp8* model in one
2511-Lightning release — another reason to prefer GGUF/bf16 on Mac.)

**Recommended sampler params (HF card):** `true_cfg_scale: 4.0`, `guidance_scale: 1.0`.

**Selective-keep + recolor + black background:** Qwen-Image-Edit is strong at appearance edits (color/
material) and identity preservation; its product-poster use case ("plain-background items") shows it
handles plain/solid backgrounds well. Phrase as: recolor the named objects to red, preserve their
identity/pose, replace background with solid black. Multi-image + ControlNet (pose keypoints) can lock
the character's pose if drift is an issue.

---

## 3. Other notable local editors (brief)

**Step1X-Edit (StepFun)**
- Repo: https://github.com/stepfun-ai/Step1X-Edit ; v1p2: https://huggingface.co/stepfun-ai/Step1X-Edit-v1p2
- Project: https://step1x-edit.github.io/ ; ComfyUI Wiki: https://comfyui-wiki.com/en/news/2025-04-28-step1x-edit-open-source-image-edit
- SOTA open editor aiming at GPT-4o / Gemini-2-Flash parity. Uses an MLLM to read the reference image +
  instruction. **Apache 2.0** (commercial OK). Versions: v1p1 (2025-07-09, adds text-to-image),
  v1p2-preview (2025-09-08, native reasoning edit). Does ~11 editing operation types.
- Apple-Silicon: heavy (MLLM + diffusion); no clean Mac/MPS benchmark found. Likely runnable on 64GB
  via ComfyUI but slower / less Mac-polished than FLUX/Qwen. Secondary option.

**OmniGen2 (VectorSpaceLab)**
- HF: https://huggingface.co/OmniGen2/OmniGen2 ; repo: https://github.com/VectorSpaceLab/OmniGen2
- ComfyUI native: https://docs.comfy.org/tutorials/image/omnigen/omnigen2 ; blog: https://blog.comfy.org/p/omnigen2-native-support-in-comfyui
- Unified ~7B multimodal model (text-to-image + instruction editing + multi-image composition),
  released 2025-06-16. **Apache 2.0**. Instruction-guided editing with high precision; SOTA among
  open models at release.
- VRAM: natively ~**17 GB** (≈RTX 3090); CPU-offload for less. ComfyUI native support exists. On a
  64GB M4 Pro it fits in unified memory, but no clean Apple-Silicon seconds figure found. Good
  lightweight commercial-friendly alternative.

**General Apple-Silicon fp8 workaround thread (applies to all fp8 models on Mac):**
- https://github.com/Comfy-Org/ComfyUI/discussions/13273 — workaround for FP8 on MPS in ComfyUI.

---

## Comparison summary

| Model | Params | License | Mac path | Mem (GGUF, transformer) | Speed on Mac | Keep+recolor+black-bg |
|---|---|---|---|---|---|---|
| FLUX.1 Kontext [dev] | 12B | **Non-commercial** | ComfyUI-GGUF / mflux / Draw Things | Q4≈6.8GB, Q8≈12.7GB | ~tens of sec/img (M4 Pro, ~50s class) | Excellent; strong char consistency, explicit "keep/maintain" prompting |
| Qwen-Image-Edit-2509 | ~20B | **Apache 2.0** | **GGUF only** (no fp8 on MPS) | Q2≈7GB, Q4≈12.1GB, Q8≈21.8GB | mins/img; 4-step Lightning makes it practical | Strong appearance edits + identity + plain bg; ControlNet pose lock |
| Step1X-Edit v1p2 | (large, MLLM+diff) | Apache 2.0 | ComfyUI | n/a found | likely slow on Mac | SOTA editor; secondary |
| OmniGen2 | ~7B | Apache 2.0 | ComfyUI native | ~17GB native | n/a found on Mac | Good lightweight commercial option |

**Top-line recommendation for the annex's task on a 64GB M4 Pro:**
- If commercial use is not required → **FLUX.1 Kontext [dev]** (best edit quality + character
  consistency + fastest Mac path via Draw Things/mflux/GGUF), prompt with explicit "keep …",
  per-object recolor, and "solid plain black background, wallpaper style."
- If commercial use IS required → **Qwen-Image-Edit-2509** (Apache 2.0) with GGUF (Q6/Q8) + the
  **4-step Lightning LoRA**, avoiding the fp8/MPS memory trap; optional ControlNet pose to lock the
  character.

---

## All citation URLs
- https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev
- https://bfl.ai/models/flux-kontext
- https://docs.bfl.ml/guides/prompting_guide_kontext_i2i
- https://comfyui-wiki.com/en/tutorial/advanced/image/flux/flux-1-kontext
- https://huggingface.co/QuantStack/FLUX.1-Kontext-dev-GGUF
- https://github.com/city96/ComfyUI-GGUF
- https://github.com/filipstrand/mflux
- https://www.together.ai/blog/flux-1-kontext
- https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/
- https://engineering.drawthings.ai/p/metal-flashattention-2-0-pushing-forward-on-device-inference-training-on-apple-silicon-fe8aac1ab23c
- https://huggingface.co/Qwen/Qwen-Image-Edit-2509
- https://soywiz.com/qwen_image_edit/
- https://github.com/ModelTC/LightX2V-Qwen-Image-Lightning
- https://www.stablediffusiontutorials.com/2025/09/qwen-image-edit-2509.html
- https://www.nextdiffusion.ai/tutorials/how-to-use-qwen-for-image-editing-in-comfyui
- https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/discussions/1
- https://github.com/stepfun-ai/Step1X-Edit
- https://huggingface.co/stepfun-ai/Step1X-Edit-v1p2
- https://step1x-edit.github.io/
- https://comfyui-wiki.com/en/news/2025-04-28-step1x-edit-open-source-image-edit
- https://huggingface.co/OmniGen2/OmniGen2
- https://github.com/VectorSpaceLab/OmniGen2
- https://docs.comfy.org/tutorials/image/omnigen/omnigen2
- https://blog.comfy.org/p/omnigen2-native-support-in-comfyui
- https://github.com/Comfy-Org/ComfyUI/discussions/13273
