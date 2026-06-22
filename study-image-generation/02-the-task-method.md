# 02 — The Task & Method: Character Isolation onto Black

**Bottom line up front:** Your rule — "isolate the character(s), make everything else black" — is a **segmentation / image-matting + compositing** task, **not** a generative-diffusion task. The correct pipeline is: run a foreground/subject-segmentation model to get an **alpha mask**, then **flatten that mask over a black background** (deterministic, fast, and faithful — it keeps your character's original pixels). A text-to-image diffusion model would *repaint and hallucinate* the character, take seconds-to-minutes per image, and give you no quality benefit for "subject on black." Reach for generation only if you later want to *synthesize or creatively repaint* content (see §03/§05). **Primary recommendation: `rembg` with the `isnet-anime` model for anime/illustration wallpapers and `birefnet-general` (or InSPyReNet) for photoreal ones — both fully open (MIT/Apache), batch-friendly over a folder, and fast on your M4.** Section 04 owns the concrete install + one-command batch script; this section owns the *method choice* and *why*.

---

## 1. Segment, don't generate (the decisive distinction)

| | **Segmentation / matting (correct)** | **Generative diffusion (wrong tool here)** |
|---|---|---|
| What it does | Predicts an alpha mask of the foreground; you composite over black | Synthesizes new pixels from noise + prompt |
| Faithfulness | Keeps the character's **original** pixels exactly | Repaints/hallucinates — character changes |
| Speed (M4) | ~0.1–3 s/image | ~5 s–minutes/image |
| Determinism | Same input → same output | Seed-dependent, variable |
| Memory | Hundreds of MB | Several–tens of GB |
| When you'd want it | Never, for "put subject on black" | Only to *create/repaint* content (§03, §05) |

"Diffusion matting" (e.g. SDMatte) and generative inpainting exist and can refine edges, but they are **strictly overkill** for your rule: heavier, slower, and no win over a good matting model when the destination background is a flat color. Decision: **use a matting model.**

The whole rule reduces to: `alpha = model(image)` → `output_rgb = image_rgb * alpha` (over black, the `(1-alpha)*background` term is zero). That's it.

---

## 2. The candidate methods

### A. Background-removal / dichotomous segmentation (best fit for your rule)

These models output a single foreground-vs-background matte automatically — exactly what "everything not the character → black" needs.

| Model | Quality (fine hair / soft edges) | Auto vs click | Anime | Photoreal | License | Apple Silicon | Notes |
|---|---|---|---|---|---|---|---|
| **BiRefNet** (ZhengPeng7) | Excellent; `BiRefNet_HR`/`-matting` (Feb 2025, 2048px) are top-tier for soft alpha | **Automatic** | Good | Excellent | **MIT** ✅ | PyTorch→MPS (some 1024 hang reports, see §4) | True open SOTA; HR matting variant for soft edges |
| **BRIA RMBG-2.0** | Excellent (built *on* BiRefNet + proprietary data); vendor claims 90% vs BiRefNet 85% | **Automatic** | Good | Excellent | **CC BY-NC 4.0** ⚠️ non-commercial | CoreML/ANE build exists (fastest Apple path) | Best-rated, but **license blocks commercial use**; benchmark is vendor-run |
| **InSPyReNet** (`transparent-background`) | Excellent; community comparisons repeatedly rate it top on complex scenes | **Automatic** | Good | Excellent | **MIT** ✅ | PyTorch→MPS; `--fast` mode | Heavier PyTorch stack; has fast/quality modes |
| **isnet-general-use** (in rembg) | Very good | **Automatic** | OK | Very good | **MIT** ✅ | ONNX (CPU reliable) | Solid general default, lighter than BiRefNet |
| **u2net / u2netp** (in rembg) | Good / fair (u2netp = lite) | **Automatic** | OK | Good | **MIT** ✅ | ONNX (CPU) | The classic baseline; u2netp for speed |
| **backgroundremover** | Fair (u2net-based) | Automatic | OK | Good | MIT ✅ | CPU | Largely superseded by rembg for stills |

### B. Anime / illustration-specific (important — anime wallpapers are common)

| Model | What it is | License | Why it matters |
|---|---|---|---|
| **isnet-anime** (rembg) | The SkyTNT anime model packaged into rembg — one-line anime support | Apache-2.0 ✅ | **Best zero-effort anime path.** Trained specifically so the mask *is* an anime character |
| **SkyTNT anime-segmentation** | Source project; supports ISNet/U2Net/MODNet/InSPyReNet (ISNet@1024 recommended), `--only-matted` outputs alpha | Apache-2.0 ✅ | Use directly if you want to fine-tune or pick a non-default arch; otherwise `isnet-anime` in rembg gives you these weights for free |

General photoreal models (u2net, BiRefNet) are trained on photos and **frequently mis-handle flat-color, lineart, and white-on-white anime art**. For illustration wallpapers, `isnet-anime` is meaningfully better because it learned "anime character" as the foreground class.

### C. Promptable / general segmentation (fallback / disambiguation, not primary)

| Model | Mode | Anime | Matte quality | License | Verdict for your rule |
|---|---|---|---|---|---|
| **SAM** | Interactive (click/box) **or** auto "everything" (~100 masks/img) | Weak | Segmentation-grade edges (worse fine hair than BiRefNet) | Apache-2.0 | **Needs a click** by default → not batch-friendly; auto mode returns *many* masks, not one clean foreground |
| **SAM 2** | + video/tracking, faster | Weak | As SAM | Apache-2.0 | Same limitation for still wallpapers |
| **SAM 3** (2025) | **Text concept prompt** ("character"/"person") → masks + IDs for *every* matching instance | Better via text | Segmentation-grade | Meta (verify) | **Useful as a disambiguator**: auto-selects "the character(s)" across a folder and handles *multiple/ambiguous* subjects — but coarser edges than a matting model |

SAM-family models answer **"which region is the character?"** well (especially SAM 3's text prompt), but produce **hard segmentation masks, not fine alpha mattes**. They are the right *fallback* when a saliency model picks the wrong subject — ideally combined: SAM 3 to locate the character, then a matting model (or alpha refinement) for the edge. They are **not** the primary matte producer.

---

## 3. Recommendation for your exact rule

**Primary:** **`rembg`** (MIT, ONNX, trivial folder batch) with model chosen per image type:
- **Anime / illustration wallpapers → `isnet-anime`**
- **Photoreal wallpapers → `birefnet-general`** (or `isnet-general-use` for a lighter/faster default)

Add rembg's alpha-matting post-process (`-a`) for cleaner hair/edges when needed. rembg gives you all of BiRefNet, isnet-anime, bria-rmbg, and SAM behind one CLI with a one-line folder command — see **§04** for the concrete install + batch script.

**Fallback 1 (best edges / soft FX):** **InSPyReNet** (`transparent-background`, MIT) or **BiRefNet_HR-matting** when you need the cleanest soft alpha (translucent hair, glow). Heavier PyTorch stack but excellent mattes.

**Fallback 2 (subject ambiguity / multiple characters):** **SAM 3** text-prompt ("character"/"person") to *select* the right subject(s), then matte. Use when a saliency model keeps the wrong object or drops a character.

**Avoid for the primary path:** **BRIA RMBG-2.0** — technically excellent, but **CC BY-NC 4.0 (non-commercial only)**. Fine for personal wallpapers, but if there's any chance this becomes commercial, prefer the MIT/Apache models so you never hit a license wall. (If you stay strictly personal and want the CoreML/ANE speed, it's the fastest Apple-native option.)

### Expected accuracy
- Clean single character on a distinct background: **excellent** (>95% visually correct) with any top model.
- Anime with `isnet-anime`: **very strong** — this is its trained domain.
- Fine hair / fur: good with BiRefNet/InSPyReNet + alpha matting; weakest with u2netp/SAM.

### Failure cases (be honest)
| Case | What happens | Mitigation |
|---|---|---|
| **Multiple characters** | Foreground/bg models keep *all* salient foreground (good if all are characters; bad if a non-character object is also salient → it's kept) | SAM 3 text-prompt to select only "character"; or accept all-foreground |
| **Semi-transparent FX** (auras, glass, glow, motion blur) | Partial alpha → edges blend toward black; can look dim/clipped | Use BiRefNet-matting / InSPyReNet (best soft alpha); accept slight darkening since the target *is* black |
| **Ambiguous "is this a character?"** (props, animals, vehicles, scenery focal points) | Saliency models guess the salient blob; may keep a prop or drop a character. No general model truly knows "character" semantics | `isnet-anime` (anime-class) or SAM 3 text-prompt give semantic intent |
| **White/flat character on white bg (anime)** | Photoreal models fail; isnet-anime handles it | Use `isnet-anime` for illustration |

---

## 4. How compositing onto black actually works

The model gives you either an RGBA image or a separate alpha mask `A ∈ [0,1]`. Flattening over black is a one-liner:

```
out_rgb = fg_rgb * alpha          # background is (0,0,0), so its contribution is zero
```

Equivalently, paste the RGBA cutout onto a black canvas (PIL):

```python
from PIL import Image
rgba = Image.open("cutout.png").convert("RGBA")
black = Image.new("RGB", rgba.size, (0, 0, 0))
black.paste(rgba, mask=rgba.split()[-1])   # use alpha as the paste mask
black.save("wallpaper.png")                 # opaque — black stands in for "transparent"
```

Semi-transparent edges (soft hair, FX) blend naturally toward black because `(1-alpha)*0 = 0`. Your final wallpaper needs **no alpha channel** — black *is* the transparent stand-in — so save as opaque PNG or JPG. (rembg can also be told to output onto a chosen background color directly via post-processing; the explicit composite above is the portable, model-agnostic form. §04 wires this into the batch command.)

---

## 5. Apple Silicon (M4, 48 GB) feasibility for this task

All recommended models are **small** (hundreds of MB) and run comfortably — your 48 GB unified memory is far more than needed for inference, so even a **base M4** is fine; **M4 Pro/Max** (more GPU cores, higher bandwidth) only make each image *faster*, not *possible-vs-not*. Notes:

- **rembg (ONNX):** CPU path is universal and reliable (~a few seconds/image — fine for an overnight folder batch). The CoreML execution provider can accelerate it but isn't wired by default.
- **PyTorch models (BiRefNet, InSPyReNet, anime-seg):** run on the **MPS** backend (PyTorch ≥1.12, macOS 12.3+). One caveat to flag: some users report **BiRefNet at 1024 hanging on MPS** in ComfyUI integrations ([ComfyUI-RMBG #200](https://github.com/1038lab/ComfyUI-RMBG/issues/200)); if you hit it, fall back to CPU or a CoreML build.
- **Fastest Apple-native option:** the CoreML/ANE build of RMBG-2.0 (INT8) — but remember its **non-commercial license**.

Feasibility verdict for *this method*: **fully solved on your hardware.** This is a mature, fast, deterministic task; the only real choices are model-per-image-type and license. (The hardware/maturity verdict overall is owned by §01.)

---

## Sources
- BiRefNet (MIT): https://github.com/ZhengPeng7/BiRefNet
- BiRefNet_HR / HR-matting (Feb 2025): https://huggingface.co/ZhengPeng7/BiRefNet_HR , https://huggingface.co/ZhengPeng7/BiRefNet-matting
- BRIA RMBG-2.0 model card (CC BY-NC 4.0): https://huggingface.co/briaai/RMBG-2.0
- BRIA benchmark blog (vendor): https://blog.bria.ai/benchmarking-blog/brias-new-state-of-the-art-remove-background-2.0-outperforms-the-competition
- RMBG-2.0 CoreML build: https://huggingface.co/VincentGOURBIN/RMBG-2-CoreML
- rembg (MIT, model zoo, batch, alpha matting): https://github.com/danielgatis/rembg , https://pypi.org/project/rembg/
- InSPyReNet / transparent-background (MIT): https://github.com/plemeri/transparent-background , https://pypi.org/project/transparent-background/
- SkyTNT anime-segmentation (Apache-2.0): https://github.com/SkyTNT/anime-segmentation , https://huggingface.co/skytnt/anime-seg
- SAM 3 (concept/text segmentation): https://blog.roboflow.com/what-is-sam3/ , https://studio.aifilms.ai/blog/meta-sam3-text-segmentation-tracking
- Current SOTA model cluster (RMBG/INSPYRENET/BEN2/BiRefNet/SDMatte/SAM/SAM2/SAM3): https://github.com/1038lab/ComfyUI-RMBG
- Apple Silicon MPS BiRefNet hang report: https://github.com/1038lab/ComfyUI-RMBG/issues/200
- ONNX Runtime CoreML EP: https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html
- PyTorch on Apple Silicon (MPS): https://developer.apple.com/metal/pytorch/
