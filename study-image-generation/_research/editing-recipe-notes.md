# Editing-Recipe Notes — End-to-End Recipe & Route Comparison

Research angle for the NEW annex. Date: 2026-06-23. Hardware: MacBook Pro M4 Pro, 64GB unified memory, macOS.

**The exact request this annex solves:**
> "Keep the character, keep the yoga rope, keep the flower on the ground but make them red, then replace the entire background with plain black — wallpaper style."

Parsing the instruction (note the ambiguity to flag in the annex):
- Keep character (unchanged pixels ideally).
- Keep yoga rope (unchanged).
- Keep flower on the ground, BUT **recolor it red** ("make them red" — grammatically "them" is ambiguous; in context the only thing to recolor is the flower; the annex should read it as *recolor the flower red, keep character + rope as-is*).
- Replace ENTIRE background with **plain black** ("wallpaper style" = clean, minimal, solid black field suitable as a wallpaper).
- Finishing: true #000000, target resolution/aspect, upscale.

---

## THREE ROUTES (summary table)

| | Route A — One-shot generative edit | Route B — Deterministic mask/composite | Route C — Hybrid (recommended) |
|---|---|---|---|
| Core tool | FLUX.1 Kontext [dev] **or** Qwen-Image-Edit-2509 | SAM 3 text-prompt masks + compositing nodes | SAM 3 (background black) + masked generative inpaint (flower only) |
| "Keep character/rope" | Risk: model may subtly redraw | **Pixel-exact** (untouched) | **Pixel-exact** (untouched) |
| "Make flower red" | Native — model understands it | Manual color op (hue/recolor node) — can look flat | Generative inpaint on flower mask → natural red |
| "Plain black bg" | May not be perfectly #000000 → needs black-key fix | **True #000000** (composite over solid black) | **True #000000** (background is composited, not generated) |
| Setup effort | Lowest (load img, type prompt) | Highest (mask → union → composite → recolor graph) | Medium |
| M4 Pro fit | Good (GGUF) | Excellent (SAM 3 light; no diffusion needed) | Good |
| Rough time/image | Kontext ~50–120s; Qwen-Edit ~3–4 min (ComfyUI GGUF) | SAM 3 seconds + instant composite | SAM 3 seconds + 1 small inpaint pass (~30–90s) |

**Recommendation:** Route C for the best fidelity/effort tradeoff. Route A for speed/one-shot. Route B when you need a guarantee that the character/rope pixels are bit-for-bit untouched and don't care that the red is a flat color op (or want zero diffusion).

---

## ROUTE A — One-shot generative edit (FLUX.1 Kontext dev / Qwen-Image-Edit-2509)

### Models
- **FLUX.1 Kontext [dev]** — 12B rectified-flow transformer, instruction-based image editing. Released **2025-06-17** (arXiv 2506.15742). License: **FLUX.1 [dev] Non-Commercial License — NOT commercial** (commercial route = BFL Kontext Pro/Max API or paid license). Preserves "character, style and object reference" with "robust consistency" across successive edits. ~12GB VRAM comfortable; runs on Mac. **Important architectural caveat:** Kontext takes the *full image* and *regenerates* the whole thing based on the prompt — it is NOT masked inpainting by default. That's why it "may subtly redraw the character." (Source: HF card; comfyui-wiki; stablediffusiontutorials.)
- **Qwen-Image-Edit-2509** — Alibaba Qwen, released **Sept 2025**, monthly iteration of Qwen-Image-Edit. **Apache 2.0 (commercial OK).** Multi-image edit (1–3 imgs optimal), better consistency, built-in depth/edge/keypoint control. (Source: HF Qwen/Qwen-Image-Edit-2509.)

### Prompt phrasing (the load-bearing part)
Kontext/Qwen-Edit work best with **direct, instructional** prompts (verbs: change / keep / replace), one logical change described per clause, and you DON'T re-describe what's already there. Recommended prompt for this exact task:

> "Keep the person and the yoga rope exactly as they are. Recolor the flower on the ground to bright red. Replace the entire background with a solid plain black background, minimal wallpaper style. Do not change the character's pose, face, or clothing."

Tips:
- Lead with what to **preserve** ("Keep the person and yoga rope exactly as they are") — Kontext responds to explicit preservation language.
- Use "solid plain black background" not just "black" (reduces gradient/vignette backgrounds).
- Keep it ONE pass mentally but you can split into 2 successive Kontext edits (edit 1 = recolor flower; edit 2 = black background) since Kontext has low drift across edits — sometimes cleaner than asking for both at once.

### Pros / Cons
- **Pros:** effortless; understands "make red" semantically; "wallpaper style" steers toward clean minimal bg.
- **Cons:** (1) may subtly redraw the character/rope (full-image regen); (2) "plain black" is rarely exactly #000000 — there'll be noise/gradient → **fix with a final black-key / levels step** (set black point so everything below threshold → #000000). See Finishing.

### ComfyUI graph shape (Route A, Kontext)
```
Load Image
   → FluxKontextImageScale (snaps to a Kontext-friendly resolution)
   → VAEEncode ─┐
ReferenceLatent┤  (Kontext conditioning carries the source image)
UNETLoader(GGUF: flux1-kontext-dev-Qxx.gguf)  via ComfyUI-GGUF "Unet Loader (GGUF)"
DualCLIPLoader (t5xxl + clip_l)
CLIPTextEncode (the instruction prompt) → FluxGuidance (≈2.5–3.5)
   → KSampler (euler, ~20–28 steps)
   → VAEDecode  [VAE in FP32/BF16 — see MPS caveat]
   → SaveImage
```
Native Kontext nodes require ComfyUI ≥ v0.3.42 (and current builds are well past that in 2026). GGUF path: replace "Load Diffusion Model" with **Unet Loader (GGUF)** from `ComfyUI-GGUF` (city96).

### Draw Things steps (Route A)
1. Open image on canvas (or Moodboard). 2. Select **FLUX.1 Kontext [dev]** model (supported since Draw Things 1.20250626/27.0, June 2025). 3. Settings: **Strength 100%, Steps 25–35, Text Guidance 5, Shift 4, Sampler DDIM Trailing** (DT's documented Kontext defaults). 4. Type the instruction prompt. 5. Generate. 6. (Optional) mask with eraser to limit changes to a region — DT supports masking for Kontext without adjusting strength.

---

## ROUTE B — Deterministic (SAM 3 masks → composite over black → recolor)

### Model
- **SAM 3** (Meta Segment Anything Model 3) — released **2025-11-19**. **Promptable Concept Segmentation (PCS):** open-vocabulary **text prompts** ("person", "rope", "flower") produce masks; no clicking. License: **SAM License** — *permits commercial use* (royalty-free worldwide grant; restrictions are military/ITAR/nuclear/weapons + redistribution-with-license + no reverse engineering; **no MAU threshold** like Llama's 700M). (Source: github.com/facebookresearch/sam3 LICENSE; sam3ai.com/license.)
- ComfyUI node packages (multiple, all 2025): `PozzettiAndrea/ComfyUI-SAM3`, `yolain/ComfyUI-Easy-Sam3`, `wzyfromhust/ComfyUI-segment-anything-3`, `Ltamann/ComfyUI-TBG-SAM3`. ComfyUI also has an official SAM 3 / SAM 3.1 utility tutorial (docs.comfy.org). Text prompt syntax supports multi-subject + counts, e.g. `eye:2, window panels:4`.

### Steps (deterministic, no diffusion)
1. **SAM 3** with text prompt → mask for **character**; again for **yoga rope**; again for **flower**.
2. **Union** the three masks (character ∪ rope ∪ flower) = foreground mask.
3. Make a **solid #000000 canvas** at image size (LayerUtility: ColorImage default `#000000`, or an EmptyImage/SolidColor node).
4. **Composite** original image over the black canvas using the foreground mask (only foreground pixels kept; everything else = true black).
5. **Recolor flower:** take the flower mask, apply a color/hue op (hue shift / multiply with red / LayerColor) restricted to that mask. This is the manual "make red."

### Pros / Cons
- **Pros:** character & rope pixels **100% untouched**; background is **true #000000** by construction (it IS the canvas).
- **Cons:** more node/script setup; "make red" is a **manual color operation** — a flat hue shift can look unnatural (loses the flower's shading/texture variation). If the natural-red look matters, that's exactly what Route C fixes.

### ComfyUI graph shape (Route B)
```
Load Image ─────────────┐
SAM3 (text="person")  → mask_char ─┐
SAM3 (text="rope")    → mask_rope ─┤ Mask Union → fg_mask
SAM3 (text="flower")  → mask_flower┘
ColorImage(#000000, WxH) ─ as background
ImageCompositeMasked(orig over black, mask=fg_mask) → composited
LayerColor/HueRotate(on orig, mask=mask_flower → red) → blended into composited
→ SaveImage
```

---

## ROUTE C — Hybrid (RECOMMENDED): SAM 3 black bg + masked generative inpaint on flower

The idea: get Route B's **faithful black background + untouched character/rope**, but get Route A's **natural "make red"** by running a *small, masked* generative inpaint ONLY on the flower.

### Steps
1. **SAM 3** text masks: character, rope, flower (as Route B).
2. Composite character+rope+flower over **#000000** (Route B steps 2–4) → background is now true black, foreground intact.
3. **Masked inpaint on the flower region only:**
   - Option C1 (FLUX Fill / Kontext inpaint): use **FLUX.1-Fill-dev** or Kontext with `InpaintModelConditioning` + **Differential Diffusion** node (makes the inpaint context-aware so the red blends naturally), mask = flower mask, prompt "a bright red flower." Differential Diffusion improves blending at mask edges.
   - Option C2 (SDXL inpaint): SDXL inpainting model + the flower mask, prompt "red flower," moderate denoise (~0.6–0.8). Fastest/cheapest on Mac.
   - Option C3 (Draw Things): erase (mask) only the flower, prompt "bright red flower," Kontext or an inpaint model; DT confines changes to the masked area.
4. Because only the flower mask region is regenerated, the character/rope/black-bg are never touched.

### Pros / Cons
- **Pros:** best of both — true black bg, untouched subject, natural generative red on the flower.
- **Cons:** slightly more setup than A; one extra (small) diffusion pass.

### ComfyUI graph shape (Route C)
```
[Route B composite up to true-black background] → base_img
SAM3(flower) → flower_mask
DifferentialDiffusion + InpaintModelConditioning (model = FLUX.1-Fill-dev or Kontext / or SDXL-inpaint)
  inputs: base_img, flower_mask, positive="bright red flower", VAE
  → KSampler (denoise tuned) → VAEDecode (FP32 VAE!) → paste back via mask
→ SaveImage
```

---

## WALLPAPER FINISHING (applies to all three routes)

### 1. Force background to TRUE #000000
- Route B/C already give true black by construction. Route A does NOT — fix it:
  - **Black-key / Levels:** raise the **black point** so any near-black pixel clamps to #000000 (ComfyUI "Levels" node black-point control; LayerStyle/LayerColor). Or threshold + composite over a `ColorImage(#000000)`.
  - Practically: levels black-point at a low threshold (e.g. 8–16/255) snaps the background to pure black while leaving the lit subject intact. Verify with a color picker that the corners read `#000000`.

### 2. Target resolution / aspect
- **Desktop 4K wallpaper:** 3840×2160, **16:9** (4K UHD).
- **Phone (modern iPhone/Android), 19.5:9 (≈9:19.5 portrait):** common native panels — **1170×2532** (iPhone 13/14), **1179×2556** (iPhone 14/15 Pro), **1290×2796** (iPhone Pro Max). For a clean black wallpaper, oversizing then downscaling is fine.
- Compose/generate at a moderate res first, THEN upscale (less memory, better results than generating 4K directly).

### 3. Upscaling (to reach 4K from a ~1024–1536 edit)
- **4x-UltraSharp** (Kim2091, on HF, .safetensors/.pth) — crisp edges, great for illustrated/anime; via `ImageUpscaleWithModel` node. A community favorite.
- **RealESRGAN x4plus** — trained on real photos; can over-smooth illustrated content; same node.
- **SUPIR** — heaviest, "8K wallpaper-level" diffusion-guided upscale (often paired with 4x Foolhardy Remacri); highest quality, highest cost/memory — overkill for a flat-black wallpaper but worth noting for detailed subjects. On Mac it's the slowest/most memory-hungry option.
- Recommended for THIS task: subject is simple over flat black → **4x-UltraSharp** (or RealESRGAN) is plenty; skip SUPIR unless the character has fine detail you want enhanced. After upscaling, **re-apply the black-point clamp** (upscalers can introduce slight non-zero darks) and crop/pad to the exact target aspect.

---

## APPLE SILICON / M4 PRO CAVEATS (critical, verified)

1. **No fp8 on MPS.** The MPS backend does NOT support fp8 tensor types; it converts on-the-fly to fp16/fp32, **doubling/quadrupling memory** → can exceed 64GB → swap → severe slowdown. **→ Use GGUF quantized models (Q4_K_S / Q8_0), not fp8.** (Source: soywiz.com Qwen-Edit-on-64GB-Mac writeup.)
2. **MPS VAE decode black-image bug.** Keep the **VAE in FP32 (or BF16)** on Apple Silicon — the current MPS VAE decoder can output all-black images at lower precision. (Source: macgpu.com Mac memory bottleneck article.)
3. **64GB is the real threshold.** Multiple sources frame 64GB unified memory as the practical threshold for comfortable Flux/Qwen-Edit local work on Mac.
4. **SAM 3 on Mac:** HF card / GitHub examples show GPU (CUDA) usage; no explicit MPS guidance. SAM 3 is light (segmentation, not diffusion) and generally runs on MPS/CPU via the ComfyUI nodes, but this is the **least-documented Apple-Silicon path** — flag as to-verify.

### Rough seconds/image on M4 Pro 64GB (all approximate, GGUF)
- FLUX.1 [schnell] 1024² Q4_K_S: **~18–22s** (M4 Pro 64GB, GGUF) — reference baseline.
- FLUX.1 [dev]/Kontext 1024² ~20 steps: **~50s** (24GB M4 Mini reference; 64GB M4 Pro similar-to-faster). Estimate **~50–120s** for a Kontext edit.
- Qwen-Image-Edit-2509 (ComfyUI GGUF Q8_0/Q4_K_S, 2 input imgs): **~3–4 min/image**. With Draw Things + **qwen_image_edit_2509_lightning_4_step** config at **2 steps**, much faster. (Source: soywiz.com.)
- SAM 3 segmentation: **seconds** per mask.
- Composite/levels/recolor (Route B color ops): effectively **instant**.
- Upscale 4x-UltraSharp/RealESRGAN: seconds–tens of seconds; SUPIR: minutes.

**Routes that run comfortably on M4 Pro 64GB:** all three. Route B is the lightest (no diffusion). Route C adds one small inpaint pass. Route A's Qwen-Edit is the slowest (3–4 min); Kontext is the faster generative option.

---

## CITATIONS (every URL)

- ComfyUI Wiki — FLUX.1 Kontext guide: https://comfyui-wiki.com/en/tutorial/advanced/image/flux/flux-1-kontext
- HF — FLUX.1-Kontext-dev (license, 12B, preserves character, full-image regen): https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev
- ComfyUI docs — Flux Kontext Dev native workflow: https://docs.comfy.org/tutorials/flux/flux-1-kontext-dev
- stablediffusiontutorials — Kontext Dev in ComfyUI (GGUF, Unet Loader GGUF, ComfyUI v0.3.42): https://www.stablediffusiontutorials.com/2025/08/flux1-kontext-dev.html
- comfyui-wiki — Kontext release: https://comfyui-wiki.com/en/news/2025-05-30-flux-kontext-release
- HF — Qwen/Qwen-Image-Edit-2509 (Sept 2025, Apache 2.0, multi-image, 1–3 imgs): https://huggingface.co/Qwen/Qwen-Image-Edit-2509
- Next Diffusion — Qwen Multi-Image Edit 2509 in ComfyUI: https://www.nextdiffusion.ai/tutorials/how-to-use-qwen-multi-image-editing-in-comfyui-a-step-by-step-guide
- QuantStack — Qwen-Image-Edit-2509-GGUF (Q2_K 7.06GB / Q4_K_S 12.1GB / Q8_0 21.8GB): https://huggingface.co/QuantStack/Qwen-Image-Edit-2509-GGUF
- soywiz — Qwen Image Edit 2509 GGUF + 4-step Lightning on Mac 64GB (no-fp8-on-MPS, 3–4 min, DT 2-step lightning): https://soywiz.com/qwen_image_edit/
- HF — facebook/sam3 (PCS text prompts, license "other"): https://huggingface.co/facebook/sam3
- GitHub — facebookresearch/sam3 LICENSE (commercial grant, no MAU threshold, restrictions): https://github.com/facebookresearch/sam3/blob/main/LICENSE
- sam3ai.com — SAM 3 license summary (commercial + research, military/ITAR restrictions): https://sam3ai.com/license/
- Stable Diffusion Art — SAM3 on ComfyUI: https://stable-diffusion-art.com/sam3-comfyui-image/
- ComfyUI docs — SAM 3 / SAM 3.1 segment utility: https://docs.comfy.org/tutorials/utility/video-segment-sam3
- GitHub — PozzettiAndrea/ComfyUI-SAM3: https://github.com/PozzettiAndrea/ComfyUI-SAM3
- GitHub — yolain/ComfyUI-Easy-Sam3 (text prompts, `subject:N` counts): https://github.com/yolain/ComfyUI-Easy-Sam3
- GitHub — wzyfromhust/ComfyUI-segment-anything-3: https://github.com/wzyfromhust/ComfyUI-segment-anything-3
- Edge AI Vision — SAM3 overview (release 2025-11-19): https://www.edge-ai-vision.com/2025/11/sam3-a-new-era-for-open%E2%80%91vocabulary-segmentation-and-edge-ai/
- Draw Things WIKI — Flux Kontext (Strength 100/Steps 25-35/TG 5/Shift 4/DDIM Trailing; DT 1.20250627.0): https://wiki.drawthings.ai/wiki/Flux_Kontext
- Draw Things WIKI — Inpainting and Outpainting (eraser mask, describe new content): https://wiki.drawthings.ai/wiki/Inpainting_and_Outpainting
- Draw Things on X — FLUX.1 Kontext dev support in 1.20250626.0: https://x.com/drawthingsapp/status/1938743879249097194
- Releases (DT) — Introducing Qwen Image Support: https://releases.drawthings.ai/p/introducing-qwen-image-support
- ComfyUI.org — Seamless inpainting w/ FLUX + Differential Diffusion: https://comfyui.org/en/seamless-image-inpainting-with-flux
- OpenArt — Improved Flux Inpainting w/ Differential Diffusion: https://openart.ai/workflows/odam_ai/improved-flux-inpainting-with-differential-diffusion/9qsjiPvARzueaIwKBGdN
- digitalcreativeai — FLUX.1 Tools (Fill-dev, InpaintModelConditioning, mask region only): https://www.digitalcreativeai.net/en/post/how-use-powerful-flux1-tools-modify-images-comfyui
- runcomfy — LayerUtility: ColorImage (#000000 default solid color): https://www.runcomfy.com/comfyui-nodes/ComfyUI_LayerStyle/LayerUtility--ColorImage
- comfyuiweb — Upscale models (4x-UltraSharp, RealESRGAN): https://comfyuiweb.com/resources/upscale-models
- runcomfy — 4x-UltraSharp guide: https://learn.runcomfy.com/upscale-images-in-comfyui-with-4x-ultrasharp-guide
- comfyui.org — SUPIR 8K wallpaper upscaling: https://comfyui.org/en/unlock-stunning-8k-wallpapers-with-supir-upscaling
- runcomfy — 8K SUPIR + 4x Foolhardy Remacri: https://www.runcomfy.com/comfyui-workflows/8k-image-upscaling-supir-4x-foolhardy-remacri
- GitHub — zentrocdot/ComfyUI-RealESRGAN_Upscaler: https://github.com/zentrocdot/ComfyUI-RealESRGAN_Upscaler
- macgpu — Flux+ComfyUI Mac memory bottleneck / 64GB threshold / FP32 VAE on MPS: https://macgpu.com/en/blog/flux1-comfyui-mac-memory-bottleneck-64gb-unified-memory.html
- WidgetClub — smartphone wallpaper size guide 2026 (19.5:9, 1170×2532/1179×2556/1290×2796): https://widget-club.com/article/wallpaper-size-quickguide-for-smartphones
- Hongkiat — wallpaper sizes/resolutions guide: https://www.hongkiat.com/blog/common-wallpaper-sizes/

## OPEN QUESTIONS / TO-VERIFY
- SAM 3 on Apple Silicon (MPS) via the ComfyUI nodes — works, but exact perf and any CPU-fallback gaps undocumented.
- Whether FLUX.1-Fill-dev is available as a Mac-friendly GGUF for the Route C masked inpaint (vs using Kontext or SDXL-inpaint there).
- Exact Kontext edit seconds/image on M4 Pro 64GB (extrapolated from 24GB M4 ~50s + schnell 18–22s; no clean primary 64GB Kontext-edit number found).
- "make them red" plural ambiguity — annex should state the assumed interpretation (recolor flower only).
