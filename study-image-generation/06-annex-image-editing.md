# Annex — Editing an Existing Image (Isolate, Keep, Recolor, Black-Out the Background)

This annex is the practical recipe for **editing an image you already have** — not generating a new one from scratch — on the M4 Pro / 64 GB Mac. The canonical task: *"Keep the character, keep the yoga rope, keep the flower on the ground but make them red, then replace the entire background with plain black — wallpaper style."* It is a fundamentally **different job** from [`./05-annex-wallpaper-generation.md`](./05-annex-wallpaper-generation.md) (which makes a brand-new wallpaper from a prompt): here you start from fixed pixels you want to *preserve*. For the base editor models see [`./02-sota-local-models.md`](./02-sota-local-models.md); for apps and install commands defer to [`./03-tools-and-install.md`](./03-tools-and-install.md); for inpaint/ControlNet/recolor-LoRA depth see [`./04-customization-and-lora.md`](./04-customization-and-lora.md).

---

## 1. Decompose the task — two sub-problems, not one

The instruction looks like one edit but is really two:

1. **Selection + black-out (a segmentation / compositing job).** Decide which named things stay (*character, yoga rope, flower*) and replace *everything else* with plain black. The right tool here **keeps the original pixels byte-exact** and produces a *true* `#000000` background. This is not a generative problem.
2. **A semantic recolor (a color-transform or generative edit).** "Make the flower red" changes a property of one kept object. This can be a deterministic color op or a small generative inpaint.

> **Disambiguation of "make them red."** The instruction's "them" is grammatically plural and ambiguous. This annex assumes the natural reading: **recolor the flower to red; keep the character and the yoga rope unchanged.** If you genuinely want the rope red too, add it to the recolor mask — the mechanics are identical.

Keeping these two sub-problems separate is the whole insight: the part that must stay faithful (subject + true black) wants a *pixel-preserving* tool, and the part that changes (the flower's color) is the only place you want a model touching pixels.

---

## 2. The three routes

| Route | What it is | Faithfulness | Effort | Recolor quality | True `#000000` | Speed on M4 Pro 64 GB | License of tools |
|---|---|---|---|---|---|---|---|
| **A — one-shot generative** | Paste the whole instruction into FLUX.1 Kontext [dev] or Qwen-Image-Edit-2509 | Low–medium (redraws whole canvas) | **Lowest** | Natural | Not guaranteed (needs black-key finish) | ~50–120 s (Kontext, est.) / ~3–4 min (Qwen GGUF, est.) | Kontext **non-commercial**; Qwen **Apache-2.0** |
| **B — deterministic** | SAM 3 text masks → union → composite over `#000000` → LAB/colorize recolor of flower mask | **Highest** (subject pixels bit-exact) | Medium | Flat (manual color op) | **Exact** | Seconds (masks) + instant (composite) | SAM License (commercial OK); NumPy/Pillow/OpenCV |
| **C — hybrid (recommended)** | Route B's SAM-3 black-out, then a **small masked inpaint on the flower only** | **High** (subject untouched; only flower re-synthesized) | Medium–high | **Natural** | **Exact** | Seconds (mask) + ~30–90 s (flower inpaint) | SAM License + the inpaint model's license |

**Default recommendation: Route C** for the showcase wallpaper — it gives untouched subject pixels, a true black background, *and* a natural-looking red flower. Use **Route B** if you want it fully deterministic/free and are happy with a flat recolor (often fine for a stylized wallpaper). Use **Route A** only when you want the fastest possible result and can tolerate the character being subtly redrawn.

---

## 3. Route A — one-shot generative instruction edit

**When to use:** quick, low-effort, you don't mind the model re-rendering the whole frame.

### 3a. The two models (see [`./02-sota-local-models.md`](./02-sota-local-models.md))

- **FLUX.1 Kontext [dev]** — 12B rectified-flow instruction editor, strong character/identity consistency, good at recolor and background swaps. **License is the FLUX.1 [dev] Non-Commercial License**: the *model weights* may only be used for non-commercial purposes (commercial deployment needs a separate paid BFL license). Nuance worth knowing: the **outputs** (generated images) carry no ownership restriction and may be used commercially — only running the model commercially is restricted.
- **Qwen-Image-Edit-2509** — ~20B (confirmed by the model card), **Apache-2.0 (commercial OK)** — the key advantage over Kontext. Adds multi-image editing, better facial-identity preservation, and native ControlNet (pose/sketch). Recommended sampler settings: `true_cfg_scale 4.0`, `guidance_scale 1.0`.

### 3b. Critical caveat — Kontext regenerates the *whole* image

FLUX.1 Kontext takes the entire image and **re-synthesizes it** from the instruction rather than inpainting only a masked region. That is exactly why the character/rope can be subtly redrawn and why the produced "black" is rarely a clean `#000000`. (Qwen-Image-Edit behaves similarly as an in-context editor.) **You therefore need a black-key finishing step** (§6) on any Route-A output.

### 3c. Prompt wording (BFL "keep X / change Y" conventions)

Lead with preservation, then the recolor, then the background — and be explicit about black:

```
Keep the person and the yoga rope exactly as they are, in the same
position, scale, and pose. Change the color of the flower on the ground
to red. Replace the entire background with a solid, plain black
background, minimal wallpaper style. Maintain the same composition and
lighting on the subject.
```

For text/identity edits BFL recommends `while maintaining the same [position/scale/pose/composition/lighting]` — that's why it's appended above.

### 3d. Running it on Apple Silicon

Install commands live in [`./03-tools-and-install.md`](./03-tools-and-install.md); the **Mac-native paths** are:

- **Draw Things** — supports Kontext since v1.20250626.0 (June 2025). Recommended Kontext settings: **Strength 100%, Steps 25–35, Text Guidance 5, Shift 4, Sampler DDIM Trailing** (these are *recommended*, not immutable). The Qwen-Image-Edit-2509 Lightning 4-step config is the practical way to make Qwen edits fast in Draw Things.
- **ComfyUI** — load the editor as a **GGUF** quant via **ComfyUI-GGUF (city96)** (`.gguf` in `models/unet`). Launch with `PYTORCH_ENABLE_MPS_FALLBACK=1`. Add `--use-pytorch-cross-attention` (cited 30–50 % faster on M3/M4).
- **mflux (MLX)** — native MLX port of Kontext with 4/8-bit quant and local save/load.

**ComfyUI node-graph shape (Route A):** `Load Image` → `Load Diffusion Model (GGUF)` → `DualCLIPLoader` / Qwen2.5-VL text encoder → `ReferenceLatent` / Kontext-edit conditioning (the input image as context) → positive prompt (above) → `KSampler` → `VAE Decode` → **black-key Levels** (§6) → `Save Image`.

### 3e. Apple-Silicon memory/quant notes

- **No fp8 on MPS.** PyTorch's MPS backend has **no fp8 kernels** — casting `Float8_e4m3fn` to MPS throws a `TypeError`, and otherwise gets silently up-converted to fp16/fp32, using 2–4× the memory and risking swap past 64 GB. **Use GGUF** (or BF16, which *is* MPS-supported) — never the native fp8 weights.
- **Keep the VAE in FP32** (or BF16). The MPS VAE decoder can emit **all-black images** at low precision; `--fp32-vae` is the documented fix.
- **GGUF transformer-only sizes** (real peak unified-memory use is higher once the text encoder + VAE + activations load): FLUX Kontext **Q4_K_S ~6.8 GB, Q4_K_M ~6.93 GB, Q8_0 12.7 GB** (Q6_K is the cited Mac sweet spot); Qwen-Image-Edit-2509 **Q2_K 7.15 GB, Q4_K_S 12.2 GB, Q8_0 21.8 GB**. A 64 GB M4 Pro runs Q8_0 / BF16 comfortably.

### 3f. Honest speed

**No measured FLUX-Kontext-on-M4-Pro or Qwen-Edit-on-M4-Pro seconds-per-image figure exists** in primary sources. The often-cited ~50 s/1024 px is for *general FLUX 12B txt2img on a 24 GB M4 Pro Mac Mini*, not a Kontext edit. Qwen-Image-Edit-2509 GGUF in ComfyUI was measured at **~3–4 min/image on an M1 Max 64 GB** (not M4 Pro). So plan, very roughly: **Kontext edit ~50–120 s, Qwen edit ~3–4 min**, both **extrapolated estimates** — measure your own config. The **Qwen-Image-Edit-2509-Lightning 4-step LoRA** (into `models/loras/`, KSampler `steps=4`) cuts Qwen inference ~5–10×.

---

## 4. Route B — deterministic: text-prompt masks → composite on black → recolor

**When to use:** you want the subject pixels **bit-exact**, a guaranteed true-black background, zero generative drift, and a free/offline pipeline. The recolor is a flat color op (often perfectly fine for a stylized wallpaper).

### 4a. Select by text — SAM 3 / SAM 3.1

**SAM 3** (released 2025-11-19, 848M params) introduced **Promptable Concept Segmentation**: a *text phrase* returns masks + IDs for **all** matching instances at once. Unlike SAM 1/2 (one object per click), it's exhaustive multi-instance, so it can select `character`, `yoga rope`, and `flower on the ground` directly by text. **SAM 3.1** (released 2026-03-27, HF id `facebook/sam3.1`) adds "Object Multiplex" shared-memory tracking — faster, no accuracy loss. ComfyUI text prompts cap at **32 tokens** and support a count syntax (`flower:1, rope:1`).

**License:** the **SAM License permits commercial use, with no Llama-style MAU threshold.** It is **not copyleft** — you own derivatives you create; the only redistribution duty is to include a copy of the Agreement (plus attribution) when distributing SAM materials. Restrictions are military / ITAR / nuclear / weapons use.

#### Apple-Silicon reality (important)

- **The official `facebookresearch/sam3` repo does NOT run on Apple Silicon** — it hard-requires **triton (CUDA-only)** (used for Euclidean Distance Transform), CUDA 12.6+, PyTorch 2.7+, Python 3.12+. There is no MPS/CPU fallback in the official repo.
- **Working workaround for static images:** the **Hugging Face `transformers` implementation** (install from GitHub) avoids triton and runs on M-series for **images** (video tracking still had device-mismatch issues). A known MPS bug: `pin_memory()` fails on MPS.
- **Easiest path: ComfyUI.** Native SAM 3.1 support was merged (PR #13408, kijai): nodes **`SAM3_Detect` / `SAM3_VideoTrack` / `SAM3_TrackToMask` / `SAM3_TrackPreview`**, checkpoint **`Comfy-Org/sam3.1` → `sam3.1_multiplex_fp16.safetensors` (1.75 GB)** into `ComfyUI/models/checkpoints/`. Custom packs: **`yolain/ComfyUI-Easy-Sam3`** (exposes `device='mps'`), **`PozzettiAndrea/ComfyUI-SAM3`**. (Known leak: issue #13717 — memory not freed across runs → OOM in *loops*; harmless for a one-shot edit.) Whether the `mps` device path fully avoids the triton/`pin_memory` issues end-to-end, or silently falls back to CPU, is worth confirming on your install.
- **Lower-friction fallback if SAM 3 won't install: Grounded-SAM 2 / LangSAM** — GroundingDINO (text → boxes) + SAM 2 (boxes → masks), Apache-2.0, **no triton hard-dep**, well-trodden on PyTorch-MPS. ComfyUI: `storyicon/comfyui_segment_anything`, `neverbiasu/ComfyUI-SAM2` (`GroundingDinoSAMSegment`).

### 4b. The deterministic core — composite over `#000000`

This is **pure CPU NumPy / Pillow / OpenCV, no model**:

1. Get per-concept masks for `character`, `yoga rope`, `flower on the ground`.
2. **OR** them into a single keep-mask.
3. Composite the original over a `(0,0,0)` canvas: `Pillow black.paste(img, mask=keep)` or `cv2.bitwise_and` over a black canvas. → Subject pixels **byte-exact**, background **exactly `#000000`**.
4. **Feather/erode the mask edge 1–2 px** (or use a soft matting alpha) to avoid bright edge halos against the black.

### 4c. Recolor the flower the *right* way

**Do NOT use a plain HSV hue-shift.** In HSV/HSL, achromatic pixels (white/gray, S≈0) have **no defined hue**, so a hue-shift does nothing on a pale flower. Instead, on the **flower mask only**:

- **LAB method (best for shading):** keep `L` (luminance) and push `a*`/`b*` toward red — preserves the petals' light/shadow.
- **Set-hue + boost-saturation:** explicitly *set* H to red and raise S (not shift).
- **Multiply a red layer** over the region's luminance — preserves shading, very simple.

This keeps the flower's form and shading while changing only its color. It is flat/literal — if you want material realism, that's Route C.

### 4d. Character-only fallback (`character on black`)

If you only need the *person* on black (no rope/flower), a matting model via **`rembg` (MIT)** is simplest: use `u2net_human_seg` / `birefnet-portrait` / `isnet-anime`, then composite the RGBA over black. **License trap: avoid `bria-rmbg` / BRIA RMBG-2.0** — it is **CC BY-NC 4.0 (non-commercial only**, paid agreement for commercial). Use BiRefNet / ISNet / U-2-Net for commercial-safe cutouts. **Mac note:** `rembg` has **no native MPS path** and runs **CPU-only by default**; install **`onnxruntime-silicon`** to get GPU/ANE acceleration via the CoreML execution provider (`onnxruntime-coreml` is *not* a standard package).

---

## 5. Route C — hybrid (recommended): faithful black-out + masked flower inpaint

**This is the best-fidelity path for the showcase wallpaper.** It pairs Route B's pixel-faithful black-out with a *small* generative recolor so the red flower looks naturally lit instead of flat.

**Steps:**

1. **Route B black-out** (SAM 3 masks → union of character + rope + flower → composite over `#000000`). Subject pixels stay bit-exact; background is true black.
2. **Masked inpaint on the flower region ONLY.** Use **FLUX.1-Fill-dev** (true inpainting) with Differential Diffusion, or **Kontext** restricted by mask, or **SDXL-inpaint**, or Draw Things' eraser-mask. Prompt: `a red flower, same shape and position, natural lighting`. Because the mask is small, this is fast and cannot drift the character (everything outside the flower mask is locked).
3. **Black-key finish** (§6) to clamp any near-black the inpaint introduced back to `#000000`.

**Result:** true black + untouched subject/rope + a natural, properly-shaded red flower. On Apple Silicon, whether **FLUX.1-Fill-dev** is available as a Mac-friendly GGUF or whether **Kontext / SDXL-inpaint** is the more practical mask-limited inpainter is install-specific — try Kontext-in-Draw-Things first since it's already set up from Route A.

> For deeper inpaint/ControlNet usage — or training a small **recolor LoRA** so a specific red is reproducible across many images — see [`./04-customization-and-lora.md`](./04-customization-and-lora.md). For this one-off task a LoRA is overkill.

---

## 6. Wallpaper finishing — true black, sizes, upscaling

### 6a. Force the background to a *true* `#000000` (black-key / levels)

Generative routes rarely produce exactly `#000000` — backgrounds come out as very-dark gradients or `#0a0a0a`-ish. To clamp:

- **ComfyUI:** a **Levels** node raising the black point to ~**8–16 / 255**, or **threshold + composite over a `ColorImage` (`#000000`)** (e.g. `LayerUtility: ColorImage`). Verify with a color picker.
- **Route B is exact already** (you composited over a literal `(0,0,0)` canvas) — no clamp needed unless feathering bled.
- **Re-apply the black-point clamp AFTER upscaling** — upscalers can introduce slight non-zero darks.

### 6b. Target resolutions / aspect ratios

| Use | Resolution | Aspect |
|---|---|---|
| Desktop 4K | **3840×2160** | 16:9 |
| Phone (modern panels) | **1170×2532 / 1179×2556 / 1290×2796** | ~19.5:9 |

**Compose/edit at moderate resolution, then upscale** — less memory, better quality than editing directly at 4K. Crop/pad to the exact aspect last.

### 6c. Upscalers

- **4x-UltraSharp** — crisp, ideal for an illustrated subject over black. **Best default here** (simple subject, clean edges).
- **RealESRGAN x4plus** — general/photo restoration; can over-smooth illustration.
- **SUPIR** — 8K-grade generative restoration, **heaviest/slowest on Mac, overkill** for a subject-on-black wallpaper.

---

## 7. Licenses & honest caveats (the short version)

- **FLUX.1 Kontext [dev]: non-commercial weights.** Model use is non-commercial; commercial *deployment* needs a paid BFL license. **Outputs are commercially usable.** (Route A with Kontext: fine for a personal wallpaper.)
- **Qwen-Image-Edit-2509: Apache-2.0** — commercial OK; the permissive choice for Route A.
- **SAM License: commercial OK, not copyleft**, no MAU cap; military/ITAR/nuclear restrictions only. (Routes B/C.)
- **BRIA RMBG-2.0 / `bria-rmbg`: CC BY-NC 4.0 — non-commercial trap.** Use BiRefNet / ISNet / U-2-Net instead for commercial cutouts.
- **Step1X-Edit / OmniGen2** are notable **Apache-2.0** alternatives (both fit in 64 GB) but have **no published Mac seconds-per-image numbers**; OmniGen2's stated ~17 GB VRAM is a CUDA figure that doesn't map cleanly to Apple unified memory.
- **Apple-Silicon caveats (all routes):** **no fp8 on MPS → use GGUF/BF16**; **keep the VAE FP32** to avoid all-black decodes; SAM 3's official repo needs the **transformers / ComfyUI** workaround (triton is CUDA-only); launch ComfyUI with `PYTORCH_ENABLE_MPS_FALLBACK=1`.
- **Speed is largely *estimated* on M4 Pro** — no clean primary M4-Pro-64 GB benchmark exists for Kontext edits, Qwen edits, or SAM 3.1. Treat every seconds figure here as a starting estimate and measure your own machine.

Keep all of this strictly SFW, and for copyrighted game/anime characters keep edited wallpapers to **personal use** (the source image's IP still belongs to its owner).
