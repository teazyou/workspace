# Research Notes — Deterministic Route: Text-Prompted Segmentation + Composite-on-Black + Recolor

> Angle for the editing annex. Goal task: take an EXISTING image and "keep the character, keep the yoga rope, keep the flower on the ground but make the flower red, then replace the whole background with plain black (#000000) wallpaper style."
> Hardware: MacBook Pro, M4 Pro, 64 GB unified memory, macOS. Date: 2026-06-23.
>
> This route is PIXEL-FAITHFUL / non-generative: it keeps the original character/object pixels EXACTLY and only blacks out everything else. Contrast with the generative-edit route (Qwen-Image-Edit / Flux Kontext / nano-banana), which re-synthesizes pixels and can drift.

---

## 0. The pipeline at a glance

1. **Select** the things to keep, by TEXT: "person/character", "yoga rope", "flower on the ground" → one mask per concept (open-vocabulary segmentation).
2. **Union** the masks (character ∪ rope ∪ flower) = the keep-mask.
3. **Composite** the original pixels of the keep-mask over a solid pure-black canvas → true #000000 background, original pixels untouched. Deterministic.
4. **Recolor ONE region** (flower → red): operate only inside the flower's mask. Non-generative (HSV/LAB/colorize in OpenCV/Pillow) OR a tiny generative inpaint limited to that mask.

Why this route vs. a generative edit: zero hallucination on the kept subject, mathematically exact black, fully reproducible, cheap on compute. Weakness: the recolor of a neutral object and any fine matting (hair) need care.

---

## 1. Open-vocabulary / text-prompted segmentation models

### SAM 3 / SAM 3.1 — Meta "Segment Anything with Concepts" (the headline option)

- **SAM 3** released **2025-11-19**. Introduces **Promptable Concept Segmentation (PCS)**: give a short noun phrase ("yellow school bus", "yoga rope") or an image exemplar, and it returns masks + IDs for EVERY matching instance at once. SAM 1/2 returned one object per prompt; SAM 3 is exhaustive multi-instance. This is exactly what we need for "select the flower(s) on the ground".
  - Architecture: detector + tracker sharing a vision encoder. **848M parameters**. DETR-based detector conditioned on text/geometry/image-exemplar.
  - Paper: arxiv 2511.16719. Repo: github.com/facebookresearch/sam3. HF: facebook/sam3 (gated — request access).
- **SAM 3.1** released **2026-03-27**. HF id **facebook/sam3.1**. Adds the **"Object Multiplex"** / shared-memory approach for joint multi-object tracking — "significantly faster without sacrificing accuracy." This is the current SOTA checkpoint as of mid-2026.
- **Text prompt limits (ComfyUI native):** max **32 tokens** per text prompt; short specific phrases work best ("person", "car"). Multi-object syntax with optional count: `eye:2, window panels:4`. Comma-separated multi-category ("cat, dog, person") in the wrapper nodes.
- **Checkpoint sizes:**
  - Official facebook/sam3 full checkpoint ≈ **3.2–3.44 GB** (fp32-ish), 848M params.
  - Community **fp16 ≈ 1.72 GB** (yolain/sam3-safetensors `sam3-fp16.safetensors`).
  - ComfyUI-native repackaged: **Comfy-Org/sam3.1 → `sam3.1_multiplex_fp16.safetensors` = 1.75 GB** (only file in that checkpoints dir; no fp32/bf16 variant published there). Goes in `ComfyUI/models/checkpoints/`.
- **License:** **SAM License** (Meta custom). Allows broad research AND COMMERCIAL use. Prohibits military / ITAR / weapons / illegal use. Copyleft-ish on redistribution: if you redistribute weights or derivatives you must ship them under the SAM License + include the agreement. NOT a plain MIT/Apache license — note for anyone shipping a product.

#### ⚠️ Apple-Silicon caveat for SAM 3/3.1 (IMPORTANT)
- The **official Meta `facebookresearch/sam3` package has a HARD dependency on `triton`** (CUDA-only, no MPS). Triton is used for Euclidean Distance Transform calculations; PyTorch 2.9+ also expects it. **It will NOT run as-is on M-series Macs.** (HF discussion #11: "Cannot run on Apple Silicon (M4) due to Triton".)
- Official requirements listed: Python 3.12+, PyTorch 2.7+, **CUDA 12.6+ GPU** — i.e. written for NVIDIA.
- **Workarounds for Mac:**
  1. **Use the Hugging Face `transformers` implementation instead of the Meta repo** — `pip install git+https://github.com/huggingface/transformers torchvision`. A user confirmed "it works if we install from github on apple silicon." This path avoids the triton dependency for STATIC IMAGES (our use case). Video had device-mismatch errors needing minor patches.
  2. **ComfyUI wrapper nodes select `device="mps"`** (yolain ComfyUI-Easy-Sam3 supports mps) — but watch for the same triton/`pin_memory` issues underneath.
  3. **CPU fallback fork**: `Sompote/SAM3_CPU` (CPU-optimized). Also `MaximeLglr/sam3-apple-silicon` and an Ultralytics MPS bug (`pin_memory()` fails on MPS, ultralytics issue #22954).
- Net: SAM 3 on this Mac is doable but NOT turnkey — prefer the `transformers` route or a wrapper that's been patched for MPS, and expect possible CPU fallback. Budget extra setup time vs. the rembg path.

### Grounded-SAM 2 (GroundingDINO + SAM 2) — the pre-SAM3 standard text-prompt route
- `IDEA-Research/Grounded-SAM-2`: GroundingDINO (open-vocab box detector from text) → feeds boxes to SAM 2 for masks. Also supports Florence-2 / DINO-X for grounding. Mature, widely used before SAM 3.
- Good when SAM 3 won't install cleanly; GroundingDINO + SAM2 is well-trodden on Mac (PyTorch MPS), no triton hard-dependency.

### LangSAM (lang-segment-anything, luca-medeiros)
- Thin wrapper: GroundingDINO + SAM 2.1 → text-prompt → masks. Same checkpoints as Grounded-SAM2's grounding+SAM stack but simpler API. Differs from Grounded-SAM2 which can use DINO-X.

---

## 2. ComfyUI segmentation nodes (Mac-runnable)

### SAM 3 / 3.1 in ComfyUI
- **NATIVE support (no custom node):** merged into ComfyUI core via PR **#13408** (kijai), "SAM (segment anything) 3.1 support (CORE-34)". Native nodes: **`SAM3_Detect`, `SAM3_VideoTrack`, `SAM3_TrackToMask`, `SAM3_TrackPreview`**. Tutorial: docs.comfy.org/tutorials/utility/video-segment-sam3. Checkpoint `sam3.1_multiplex_fp16.safetensors` (1.75 GB) → `ComfyUI/models/checkpoints/`.
- **`yolain/ComfyUI-Easy-Sam3`** (custom node pack) — nodes: Load SAM3 Model, SAM3 Image Segmentation, SAM3 Video Segmentation, SAM3 Get Object IDs, SAM3 Get Object Mask, SAM3 Video Model Extra Config, Sam3 Visualization, Frames Editor.
  - **Load SAM3 Model node exposes `device` incl. `mps`** → explicit Apple-Silicon path. Precision fp32/fp16/bf16 for memory. `keep_model_loaded` toggle for VRAM/RAM. Models in `ComfyUI/models/sam3/`; pulls facebook/sam3 or yolain/sam3-safetensors (fp16 1.72 GB).
- **`PozzettiAndrea/ComfyUI-SAM3`** — wrapper, open-vocab image+video text-prompt segmentation.
- Also referenced: `ComfyUI-segment-anything-3`, `ComfyUI-TBG-SAM3`, `1038lab/sam3` (HF repackage), `wouterverweirder/comfyui_sam3`.
- ⚠️ **Memory leak / OOM**: ComfyUI issue **#13717 (2026-05-05)** — `SAM3ClipModelWrapper` memory accumulates across runs and is not released by cleanup nodes → OOM in looping workflows. For a one-shot single-image edit this is a non-issue; matters for batch loops.

### Pre-SAM3 ComfyUI text-segmentation nodes (fallback, very Mac-friendly)
- **`storyicon/comfyui_segment_anything`** — GroundingDINO + SAM, "use semantic strings to segment any element" (ComfyUI port of sd-webui-segment-anything). The classic text-prompt mask node.
- **`neverbiasu/ComfyUI-SAM2`** — provides `GroundingDinoSAMSegment` (text → mask).
- Mask union/composite are then done with stock ComfyUI mask nodes (Mask add/combine, ImageCompositeMasked over a solid-color image node).

---

## 3. Union of masks + composite on pure black (deterministic core)

- After getting per-concept masks (character, rope, flower), **OR them together** (binary union) → keep-mask.
- **Composite original pixels over #000000:** create a black canvas same size, paste original using keep-mask as alpha.
  - Pillow:
    ```python
    black = Image.new('RGB', img.size, (0,0,0))
    black.paste(img, mask=keep_mask_L)   # keep_mask_L = 8-bit L mask
    ```
  - OpenCV: `out = cv2.bitwise_and(img, img, mask=keep_mask)` (background becomes exact 0,0,0).
  - ComfyUI: `ImageCompositeMasked` with a solid-black `EmptyImage`/`SolidColor` node as the base.
- This keeps the kept pixels byte-identical and guarantees true black — the whole point of the deterministic route.
- Edge tip: feather/erode the mask 1–2 px or use the soft alpha from a matting model (below) to avoid a hard halo at object edges.

---

## 4. Recolor ONE kept region (flower → red)

Operate ONLY inside the flower's mask (which we already have for free from segmentation).

### Non-generative options (deterministic, preferred when it works)
- **HSV hue-shift** (OpenCV): convert region to HSV, `hnew = (h + delta) % 180`, merge, back to BGR. Hue range in OpenCV is [0,179], S/V [0,255].
  - ⚠️ **Fails on neutral objects.** If the flower is white/gray/black, hue is UNDEFINED (S≈0) so hue-shift does nothing. A real red needs you to SET hue and BOOST saturation, not shift.
- **Colorize / tint** (better for neutral or any → red): keep the object's luminance, replace chroma. Practical recipes:
  - LAB space: keep L (lightness), set a*/b* toward red, convert back — preserves shading/contrast.
  - Multiply/overlay a red layer onto grayscale luminance of the region, blended by the mask (preserves highlights/shadows). This is the robust "make-it-red regardless of original color" approach.
  - Pillow `ImageOps.colorize` of the region's grayscale (black→dark-red, white→light-red).
- **Channel ops**: simplest crude version — zero G,B inside mask, scale R; loses shading, usually too flat.
- Net recommendation: **LAB-set-chroma or luminance×red-tint**, masked, gives a believable red on any starting color while staying fully deterministic and keeping the flower's form/shading.

### Small generative inpaint limited to the mask (when you want texture/relight)
- Run an inpaint model (Flux Fill / Qwen-Image-Edit / SDXL inpaint) constrained to the flower mask with a prompt like "red flower." Gives nicer relighting/material but RE-SYNTHESIZES those pixels (no longer pixel-faithful) and is heavier on the M4. Use only if the deterministic tint looks fake.
- **Trade-off summary:** HSV/LAB/colorize = exact, instant, free, can look flat on complex materials. Masked inpaint = prettier material/lighting, slower, non-deterministic, can alter flower shape slightly. For a "wallpaper" with a stylized red, the deterministic tint is usually enough.

---

## 5. Plain character-only fallback ("character on black", no named objects)

If you only need the CHARACTER on black (no rope/flower), skip open-vocab segmentation and use a **matting / background-removal** model — gives a soft alpha (good hair edges), then composite on black as in §3.

### rembg (danielgatis/rembg) — MIT tool, multiple models
- `pip install "rembg[cpu,cli]"` (CPU) / `[gpu,cli]` (CUDA) / `[rocm,cli]`. **No MPS path advertised** — on Mac it runs CPU by default.
- 14 models. Relevant ones:
  - `u2net`, `u2netp`, `silueta`, `isnet-general-use` — general, permissive (U-2-Net etc.).
  - `u2net_human_seg`, `birefnet-portrait` — best for a person/character.
  - `isnet-anime` — anime characters.
  - **`bria-rmbg`** — SOTA quality BUT see license trap below.
- Use:
  ```python
  from rembg import remove
  out = remove(Image.open('person.png'))   # RGBA
  black = Image.new('RGB', out.size, 'black')
  black.paste(out, mask=out.split()[3])     # over black
  ```
- **Apple-Silicon acceleration for rembg:** stock onnxruntime on arm64 Mac is CPU-only. For GPU/ANE use **CoreML EP** via `onnxruntime-coreml` (xaviviro) or `onnxruntime-silicon` (cansik) as a drop-in replacement; there's a gist "Install Rembg with CoreML support to use Neural Engine." CoreML EP needs macOS 10.15+; Python must be built for arm64 (3.8–3.11). On M4 even CPU u2net is ~1–2 s/image; CoreML/ANE is faster.

### ⚠️ The BRIA RMBG non-commercial trap
- **`briaai/RMBG-2.0`** (BiRefNet-based, top-tier quality) is **CC BY-NC 4.0 — NON-COMMERCIAL only.** Commercial use requires a paid agreement with BRIA. This applies whether you use it directly or through rembg's `bria-rmbg` model. Same story for RMBG-1.4.
- For commercial-safe cutouts use **BiRefNet (open weights), ISNet/DIS, or U-2-Net** instead. Note even some BiRefNet portrait weights have their own terms — check per checkpoint.

---

## 6. Tools that run this whole route on this Mac (M4 Pro / 64 GB)

- **ComfyUI** (native SAM 3.1 nodes OR yolain/Easy-Sam3 with `device=mps`) for the segmentation + mask union + composite-on-black graph. Fits easily in 64 GB; fp16 checkpoint 1.75 GB.
- **Python script** (Pillow + OpenCV + PyTorch-MPS) for a headless deterministic pipeline: transformers-SAM3 (or Grounded-SAM2) → union → black composite → LAB recolor. Best reproducibility.
- **rembg** for the character-only fallback (CoreML EP for speed).
- All non-generative steps (union, composite, recolor) are pure CPU NumPy/Pillow — instant, no model.

### Apple-Silicon caveats roll-up
- **SAM 3/3.1 official Meta repo: triton (CUDA-only) hard dep → won't run on MPS.** Use HF `transformers` impl (works for images), ComfyUI mps node, or CPU fork.
- General MPS gaps: no fp8 on MPS (use fp16/GGUF for any generative step), occasional `pin_memory()` MPS bugs, device-mismatch on video.
- Grounded-SAM2 / GroundingDINO + SAM2 is the lower-friction text-prompt route on Mac if SAM3 install fights you.
- rembg: CPU by default; add `onnxruntime-coreml`/`-silicon` for ANE/GPU.

---

## 7. License quick table

| Model / tool | License | Commercial? | Note |
|---|---|---|---|
| SAM 3 / 3.1 (facebook/sam3, sam3.1) | SAM License (Meta custom) | YES (broad) | no military/ITAR; copyleft-style on redistribution; gated download |
| Grounded-SAM-2 / GroundingDINO | Apache-2.0 (GroundingDINO) / SAM2 (Apache-2.0) | Yes | clean |
| LangSAM | wrapper, underlying GroundingDINO+SAM2.1 | Yes | inherits component licenses |
| rembg (tool) | MIT | Yes | per-model licenses vary |
| U-2-Net / ISNet / BiRefNet weights | mostly permissive (Apache/MIT-ish) | Yes | verify per checkpoint |
| **BRIA RMBG-2.0 / 1.4** | **CC BY-NC 4.0** | **NO** (paid BRIA agreement) | the trap; avoid for products |
| OpenCV / Pillow / NumPy | BSD / MIT-style / BSD | Yes | the deterministic recolor+composite stack |

---

## Citations (URLs)

- SAM 3 paper: https://arxiv.org/html/2511.16719v1 ; Meta research: https://ai.meta.com/research/publications/sam-3-segment-anything-with-concepts/
- SAM 3 repo: https://github.com/facebookresearch/sam3
- SAM 3.1 Meta blog: https://ai.meta.com/blog/segment-anything-model-3/
- SAM 3 HF (gated): https://huggingface.co/facebook/sam3 ; checkpoint discussion: https://huggingface.co/facebook/sam3/discussions/59
- SAM 3 overview/specs: https://blog.roboflow.com/what-is-sam3/ ; https://docs.ultralytics.com/models/sam-3 ; https://www.marktechpost.com/2025/11/20/meta-ai-releases-segment-anything-model-3-sam-3-for-promptable-concept-segmentation-in-images-and-videos/
- SAM License terms: https://github.com/facebookresearch/sam3/blob/main/LICENSE ; https://sam3ai.com/license/
- ComfyUI native SAM 3.1 tutorial: https://docs.comfy.org/tutorials/utility/video-segment-sam3
- ComfyUI native PR #13408: https://github.com/Comfy-Org/ComfyUI/pull/13408
- Comfy-Org/sam3.1 checkpoints (1.75 GB fp16): https://huggingface.co/Comfy-Org/sam3.1/tree/main/checkpoints
- ComfyUI SAM3 OOM issue #13717: https://github.com/Comfy-Org/ComfyUI/issues/13717
- yolain/ComfyUI-Easy-Sam3: https://github.com/yolain/ComfyUI-Easy-Sam3
- yolain/sam3-safetensors (fp16 1.72 GB): https://huggingface.co/yolain/sam3-safetensors
- PozzettiAndrea/ComfyUI-SAM3: https://github.com/PozzettiAndrea/ComfyUI-SAM3
- Apple-Silicon triton problem: https://huggingface.co/facebook/sam3/discussions/11
- SAM3 MPS pin_memory bug: https://github.com/ultralytics/ultralytics/issues/22954
- SAM3 CPU fork: https://github.com/Sompote/SAM3_CPU/ ; Apple-Silicon fork: https://github.com/MaximeLglr/sam3-apple-silicon
- Grounded-SAM-2: https://github.com/IDEA-Research/Grounded-SAM-2
- LangSAM: https://github.com/luca-medeiros/lang-segment-anything
- ComfyUI segment_anything (GroundingDINO+SAM): https://github.com/storyicon/comfyui_segment_anything
- ComfyUI-SAM2: https://github.com/neverbiasu/ComfyUI-SAM2
- rembg: https://github.com/danielgatis/rembg
- rembg CoreML gist: https://gist.github.com/fathonix/3b9bda262226ac8842338d65ae505673
- onnxruntime-silicon: https://github.com/cansik/onnxruntime-silicon ; onnxruntime-coreml: https://github.com/xaviviro/onnxruntime-coreml ; CoreML EP: https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html
- BRIA RMBG-2.0 (CC BY-NC 4.0): https://huggingface.co/briaai/RMBG-2.0 ; https://github.com/Bria-AI/RMBG-2.0
- OpenCV colorspaces (HSV): https://docs.opencv.org/4.13.0/df/d9d/tutorial_py_colorspaces.html
- HSV neutral-color hue-undefined: https://en.wikipedia.org/wiki/HSL_and_HSV
- OpenCV object recolor walkthrough: https://mevlutardic.medium.com/color-change-of-the-selected-object-with-opencv-d385f0795f64
