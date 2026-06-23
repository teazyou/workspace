# Annex — Video-Game / Anime / "Sketchy-SFW" Wallpaper Generation

This annex is the practical recipe for making **anime, video-game, and edgy-but-SFW illustration wallpapers** locally on the M4 Pro / 64 GB Mac. It covers the model ecosystem that matters for this look (SDXL-based, not FLUX/Qwen), the model-specific prompting conventions, wallpaper resolutions and upscaling, a batch workflow, how to keep "sketchy" stylization from drifting into NSFW, and the concrete ethics/legal guardrails. For the base model catalog see [`./02-sota-local-models.md`](./02-sota-local-models.md), for the apps and install commands see [`./03-tools-and-install.md`](./03-tools-and-install.md), and for training your own style LoRA see [`./04-customization-and-lora.md`](./04-customization-and-lora.md).

---

## 1. Why SDXL, not FLUX/Qwen, for anime wallpapers

FLUX.1/FLUX.2 and Qwen-Image have better prompt adherence and far better text-in-image (covered in [`./02-sota-local-models.md`](./02-sota-local-models.md)), but the **anime checkpoint + LoRA ecosystem lives almost entirely on SDXL**. The breadth of community finetunes, the Danbooru/e621 tag vocabulary, and the artist-style control all sit in the SDXL family. As of mid-2026 there is no FLUX/Qwen anime finetune with a comparable LoRA library, so **SDXL remains the right default for anime/game wallpapers**. Reach for FLUX/Qwen only when you need legible text on the wallpaper or a complex multi-element scene.

The dominant lineage is **Kohaku-XL → Illustrious-XL → NoobAI-XL**, with parallel **Pony Diffusion V6 XL** and **Animagine XL 4.0** lines.

| Model | Lineage | Prediction | Prompt style | CFG / sampler / steps | License |
|---|---|---|---|---|---|
| **Illustrious-XL v0.1** | Kohaku-XL beta5 / Danbooru2023 | epsilon | Danbooru tags + quality | 5–7.5 / Euler a / 20–28 | `fair-ai-public-license-1.0-sd` |
| **Illustrious-XL v1.0/1.1/2.0** | above | epsilon (v3.5 adds v-pred) | same | same | **CreativeML Open RAIL++-M** (open weights) |
| **NoobAI-XL (eps)** | Illustrious finetune | epsilon | Danbooru/e621 + quality + rating | standard SDXL | `fair-ai-public-license-1.0-sd` |
| **NoobAI-XL (v-pred)** | Illustrious finetune | **v-pred** | same | **4–5 / Euler ONLY / 28–35** | `fair-ai-public-license-1.0-sd` |
| **Pony Diffusion V6 XL** | SDXL finetune | epsilon | `score_9…score_4_up` + `source_` + `rating_` | ~7 / common | **MODIFIED faipl** (no monetized inference) |
| **Animagine XL 4.0** | SDXL 1.0 (from scratch, ~8.4M imgs, Jan 2025) | epsilon | `masterpiece, high score, great score, absurdres` | 4–7 (5) / Euler a / 25–28 | **CreativeML Open RAIL++-M** |

Notes worth flagging:
- **NoobAI-XL** is a direct finetune of Illustrious trained on the latest complete Danbooru (to ~2024-10-23) plus e621. A widely-repeated "~12.7 million images" figure circulates, but the official Laxhar model cards describe the datasets without stating a count — **treat 12.7M as community-reported, not official**.
- **NoobAI v-pred** gives richer color and light/shadow but is picky: it **requires the Euler sampler**, CFG 4–5, 28–35 steps. The epsilon variants tolerate normal SDXL samplers. Whether Draw Things vs ComfyUI loads v-pred checkpoints cleanly on Apple Silicon without MPS/Metal quirks is worth verifying on your specific install before committing to a batch.
- Because NoobAI descends from Illustrious, **the ~16,000 Danbooru artist-style tags work in both** (see §2b and the ethics caution).
- Popular Civitai merges: **WAI-illustrious-SDXL** (Illustrious-based, ships rating tags for SFW control), **comradeshipXL**, **Prefect Pony XL**, **Pony Realism**. Civitai is the de-facto hub for these checkpoints and LoRAs.

---

## 2. Prompting — conventions do NOT transfer between families

Each family has its own tag system. Copying one family's prefix onto another mostly does nothing.

### 2a. Quality / score prefixes

| Family | Prefix you must use |
|---|---|
| **Pony V6 XL** | `score_9, score_8_up, score_7_up, score_6_up, score_5_up, score_4_up` |
| **Illustrious / NoobAI** | `masterpiece, best quality, newest, absurdres, highres, safe` |
| **Animagine XL 4.0** | `masterpiece, high score, great score, absurdres` |

Pony's `score_*` tags are **Pony-only** and do essentially nothing on Illustrious/NoobAI/Animagine. Conversely Illustrious/NoobAI use percentile quality tags (masterpiece ≈ >95th percentile … worst quality ≈ ≤30th).

### 2b. Booru/rating tags and artist styles

- **Body of the prompt** is comma-separated Danbooru tags: `1girl, solo, long hair, school uniform, classroom, looking at viewer, off-center composition`.
- **Rating tags** are first-class and the main SFW lever (§6): Pony `rating_safe` / `source_anime`; NoobAI/booru `safe` (avoid `sensitive`/`questionable`/`explicit`).
- **Artist-style tags:** Illustrious/NoobAI recognize 16,000+ Danbooru artist tags; the [ThetaCursed Illustrious-NoobAI Style Explorer](https://github.com/ThetaCursed/Illustrious-NoobAI-Style-Explorer) gives visual previews. **Ethics caution:** these reproduce the look of specific, often living, named artists without consent — the central AI-art ethics flashpoint. Practical guidance: **blend several artist tags** to make an original look rather than 1:1 cloning a living artist, prefer generic style descriptors where possible, and keep any artist-cloned output to personal/non-commercial use.

### 2c. Negative prompt

Canonical anime negative (Animagine's):

```
lowres, bad anatomy, bad hands, text, error, missing finger, extra digits,
fewer digits, cropped, worst quality, low quality, low score, bad score,
average score, signature, watermark, username, blurry
```

Add the NSFW-suppression cluster from §6. Illustrious tends to show watermark artifacts more than NoobAI, so keep `watermark, signature, username, text, logo` in negatives.

---

## 3. Wallpaper resolution & upscaling

**Always generate at SDXL's native ~1-megapixel aspect-ratio bucket first, then upscale.** Generating directly at 3840×2160 breaks composition (duplicated heads/limbs).

### 3a. Native buckets → target wallpaper sizes

| Aspect | Generate at (SDXL bucket) | Upscale target |
|---|---|---|
| 16:9 desktop | **1344×768** | 3840×2160 (4K UHD) — ~3× |
| 21:9 ultrawide | **1536×640** | 3440×1440 — ~2.2× |
| 32:9 super-ultrawide | 1536×640 | 5120×1440 |
| 1:1 | **1024×1024** | 2048–4096 square |
| Phone (9:19.5) | **768×1344** | 1284×2778 / 1080×2340 |

### 3b. Upscalers

- **4x-UltraSharp** (ESRGAN architecture) — lightweight, fast on Mac, excellent for clean anime linework. Must be installed manually. **Best default for 4K anime wallpapers.**
- **RealESRGAN / Real-ESRGAN** — general restoration, also lightweight and fast on Mac.
- **SUPIR** — SDXL-based generative restoration, highest fidelity but heavy; commonly paired with 4x Foolhardy Remacri for 8K. On the M4 Pro 64 GB it fits but is slow (tens of seconds to minutes per image), and in ComfyUI some upscale nodes hit MPS-unsupported ops requiring CPU fallback. Use only when 4x-UltraSharp's output isn't enough.
- **Hires-fix** (built-in second pass at low denoise, ~0.3–0.5) adds detail without changing composition and is the simplest path inside Draw Things or A1111/Forge.

Which upscaler best preserves anime linework at 4K, and whether SUPIR runs without CPU fallback on MPS (vs natively in Draw Things), is install-specific and worth a quick test before a big batch.

### 3c. Composition for wallpapers

- **Leave negative space for desktop icons:** compose the subject in a side third. Tags: `off-center composition`, `wide shot`, `from above`, plus an explicit empty region (`clear sky`, `gradient background`).
- **Ultrawide (21:9/32:9):** scenery prompts (`scenery, no humans, landscape, cityscape`) work far better than a single character stretched across the frame.
- Seed controls overall layout — re-roll seeds to explore compositions.

---

## 4. Apple Silicon: tools, speed, caveats

Two apps matter here; both are detailed in [`./03-tools-and-install.md`](./03-tools-and-install.md).

- **Draw Things (recommended)** — Apple-native (SwiftUI + Metal FlashAttention v2, not a PyTorch wrapper). Free, offline, App Store. Runs SDXL/Illustrious/Pony/Animagine + LoRAs, has built-in Metal upscalers (sidesteps MPS gaps), and supports local LoRA training even on 16 GB. Reported faster than ComfyUI on the same Mac.
- **ComfyUI** — PyTorch + MPS backend, more flexible/node-based but slower on Mac and exposed to MPS op gaps. Launch with `PYTORCH_ENABLE_MPS_FALLBACK=1` so unsupported ops fall back to CPU.

**Speed — treat as approximate and low-confidence.** The most concrete public figure is **~20–40 s/image for SDXL 1024×1024 at 25 steps**, but it was measured on an **M4 Pro 24 GB in ComfyUI**, not a 64 GB M4 Pro — **no 64 GB M4 Pro SDXL benchmark exists**. For SDXL the bottleneck is GPU core count, not memory, so the 64 GB machine should be at or modestly above that figure. Draw Things is reported "~20–40% faster," but the sourcing is inconsistent (one blog says ">20%", its own title says "40%") and not a controlled benchmark — **directionally plausible, numerically soft.** Plan, very roughly, on the order of ~15–40 s per 1024-px image plus a few-to-tens of seconds for a 4x upscale, and measure your own config.

**Honest comparison:** a single 4090-class NVIDIA GPU does SDXL in ~3–6 s/image — several times faster per image. The Mac's edge is **unified memory** (SDXL + multiple LoRAs + upscalers, and even FP16 FLUX/Qwen, all fit comfortably in 64 GB), **not throughput**. This sits in the "runs great locally for SDXL, runs but slow for heavy upscalers like SUPIR" zone; nothing here "needs a cloud GPU."

---

## 5. Batch / mass-wallpaper workflow

The headless **ComfyUI** path is the most automatable:

1. **Wildcards + dynamic prompts** — `__wildcard-name__` files and inline `{a|b|c}` syntax (via [ComfyUI-Impact-Pack](https://github.com/ltdrdata/ComfyUI-Impact-Pack)) to vary character / outfit / setting / artist per image.
2. **Generate** at the in-bucket resolution with your SDXL anime checkpoint + style LoRA (train one per [`./04-customization-and-lora.md`](./04-customization-and-lora.md)).
3. **Detail pass** — ADetailer / face-detailer for clean faces.
4. **Batch upscale** — 4x-UltraSharp to hit 4K.
5. **Queue** a large batch size and walk away.

**Draw Things** also does batch generation natively (free, no token limits) and is the lower-friction option if you don't need wildcard combinatorics or want everything on Metal. Per-aspect-ratio bucket switching across a single automated run is the rough edge in both — the cleanest approach is one batch (and one bucket) per target aspect ratio.

---

## 6. Keeping "sketchy" SFW

"Sketchy" here means **edgy/suggestive-adjacent stylization** (swimsuit-, lingerie-adjacent, moody/suggestive posing) — **never explicit content**. These bases are trained on heavy NSFW booru/e621 data, so the latent space drifts NSFW unless actively suppressed. Hygiene, in order of leverage:

1. **Positive rating tag — the single biggest lever.** Pony `rating_safe` (+ `source_anime`); NoobAI/booru `safe`. Avoid `questionable`/`explicit`/`sensitive`.
2. **Strong NSFW negative cluster:** `nsfw, explicit, nude, nudity, nipples, areola, cleavage, sex` plus the hard floor `loli, shota, child` (see §7).
3. **Name a full outfit explicitly** — under-specified clothing is the top cause of accidental nudity.
4. **Watch trigger descriptors.** Even with `safe`, tags like `bikini`, `school uniform`, `cleavage`, `close-up` can pull borderline anatomy via latent correlations — exactly the suggestive-pose zone where drift happens. Keep the negative cluster strong and **review every output**.
5. WAI-illustrious documents this same approach (rating tags + `nsfw` in negatives). Lower CFG and avoiding NSFW-leaning artist tags also reduce drift.

---

## 7. Ethics & legal guardrails (non-negotiable, but practical)

These are short and concrete — follow them and you're fine for personal wallpapers.

1. **No minors.** Civitai operates a **0-strike ban** for any minor-related content. For "age-up" of canonically-young characters, depict **clearly adult** subjects only and keep `loli/shota/child` in negatives.
2. **No real-person likeness / deepfakes.** Civitai **removed all real-person likeness content** (any depiction of a real person, any rating — celebrities, influencers, private individuals), citing the **US Take It Down Act** (signed May 2025) and the **EU AI Act**. Do not generate identifiable real people. *(Platform policies change fast — recheck the live TOS.)*
3. **Licenses differ — and only matter for commercial use:**
   - **Unmodified `fair-ai-public-license-1.0-sd`** (Illustrious v0.1, NoobAI): copyleft/share-alike on the *model*, but **outputs are completely unrestricted** — "the output of this software is not covered by this license, and no contributor claims any rights to it" (free, including commercially).
   - **Illustrious-XL v1.0/v1.1** are **open-weight under CreativeML Open RAIL++-M** (commercial use allowed, no share-alike); v2.0 was announced as open source. They are **not** closed/proprietary — early community grumbling was about dropping copyleft, not about the weights being unavailable. Still check the per-version license before reuse, as Onoma's terms have shifted across releases.
   - **Pony V6 XL** uses a **MODIFIED faipl that prohibits monetized inference** (running the model on paid/tiered services), extending to merges/derivatives, with blanket exceptions for Civitai and Hugging Face. The restriction targets *inference services*, not personal ownership of outputs.
   - **Animagine XL 4.0** uses **CreativeML Open RAIL++-M** — the most commercial-friendly of the set.
   - **Net:** for **personal desktop wallpapers, all of these are fine.** Selling outputs is license-dependent; verify before any commercial use.
4. **Copyrighted game/anime characters = personal use only.** Mario, Zelda, Genshin characters, etc. are fine on your own desktop but remain the IP of Nintendo / HoYoverse / etc. — do not sell, redistribute commercially, or imply official endorsement.
