# ANNEX — Video-game / Anime / "Sketchy-SFW" Wallpaper Generation — Raw Research Notes

> Research date: 2026-06-23. Hardware context: Apple MacBook Pro, M4 Pro, 64 GB unified memory, macOS.
> This is the durable research record. Every claim has a URL. Conflicts and uncertainty are flagged inline.

---

## 1. THE ANIME / ILLUSTRATION MODEL ECOSYSTEM (SDXL-based)

The anime/illustration aesthetic for local generation in 2025–2026 is overwhelmingly **SDXL-based**. FLUX/Qwen are stronger at prompt adherence and text but have a far smaller anime-specific finetune + LoRA ecosystem (see §5). The dominant base lineage is:

**Kohaku-XL → Illustrious-XL → NoobAI-XL**, plus the parallel **Pony Diffusion V6 XL** and **Animagine XL 4.0** lines.

### 1a. Illustrious-XL (OnomaAI Research)
- Base: `KBlueLeaf/kohaku-xl-beta5`. Trained on **Danbooru2023**.
- Version timeline (per HF card): v0.1 (May 2024, open), v1.0 (Jul 2024), v1.1 (Aug 2024), v2.0 (Sep 2024), v3 (Nov 2024), **v3.5 incorporates Google's v-parameterization (v-pred)**.
- **License: `fair-ai-public-license-1.0-sd`** (the open v0.1).
- **CONFLICT/CAUTION:** HF card says v1.0 onward are **"closed-source"** and v2.0/v3.0/v3.5 "appear to remain proprietary"; community was "disappointed with the closed-source nature of Illustrious XL v1.0." Onoma stated plans to progressively open older versions. So *which* Illustrious is freely usable depends on version — verify per-version before relying on it.
- Recommended settings (HF card): sampler **Euler a**, **20–28 steps, CFG 5–7.5**. Composition tags supported: `upper body`, `cowboy shot`, `portrait`, `full body`. Quality range `worst quality` … `masterpiece`. Danbooru tagging.
- Source: https://huggingface.co/OnomaAIResearch/Illustrious-xl-early-release-v0

### 1b. NoobAI-XL (NAI-XL) — Laxhar Lab
- **Direct finetune of Illustrious-XL** (`OnomaAIResearch/Illustrious-xl-early-release-v0` → `Laxhar/noobai-XL_v1.0` → v-pred).
- Trained on **latest complete Danbooru (up to ~2024-10-23) + e621** datasets. One secondary source cites **~12.7 million images**; the Civitai/HF cards describe the datasets but **do not state an exact count in millions** — treat 12.7M as community-reported, not officially confirmed.
- **Two prediction families:**
  - **Epsilon-pred** variants: 1.1, 1.0, 0.75, 0.5 (standard SDXL noise prediction).
  - **V-pred** variants: V-Pred-1.0 (latest), 0.9R, 0.75S, 0.65S, 0.6, 0.5. V-pred gives **superior color gamut, richer light/shadow, fewer artifacts** but is pickier about settings.
- **V-pred settings (Civitai card): CFG 4–5, sampler MUST be Euler (others "incompatible"), steps 28–35.** Epsilon variants tolerate normal SDXL samplers.
- Quality prefix: `masterpiece, best quality, newest, absurdres, highres, safe`. Quality tiers are percentile-based (masterpiece = >95th … worst quality = <=30th). **`safe`/`sensitive`/`questionable`/`explicit` rating tags are first-class** (key for SFW control — see §6).
- **License: `fair-ai-public-license-1.0-sd`** — one source notes additional restrictions prohibiting commercialization and requiring derivatives stay open. (See §7 for the important nuance: outputs are unrestricted; the *model* redistribution is copyleft.)
- Because it descends from Illustrious, **the ~16,000 Danbooru artist-tag styles work in both** Illustrious and NoobAI.
- Sources: https://civitai.com/models/833294/noobai-xl-nai-xl ; https://huggingface.co/Laxhar/noobai-XL-1.1 ; comparison: https://www.oreateai.com/blog/illustrious-vs-noobaixl-navigating-the-cutting-edge-of-anime-ai-art/230efde972f4e5af49e75fbb12505ce9

### 1c. Pony Diffusion V6 XL (PurpleSmartAI / AstraliteHeart)
- SDXL-derived finetune; dominant for anime/furry/stylized content; **score-tag prompting** (see §2). Performs best at **16 GB+ VRAM** (or unified memory equivalent).
- **Prompt prefix:** `score_9, score_8_up, score_7_up, score_6_up, score_5_up, score_4_up`. Without score tags output is "dull." Also uses source tags (`source_anime`, `source_cartoon`, `source_furry`, `source_pony`) and rating tags (`rating_safe`, `rating_questionable`, `rating_explicit`).
- **License: MODIFIED Fair AI Public License 1.0-SD.** *Important:* the modification **prohibits running inference on monetized websites/apps** (paid inference, faster tiers, etc.), incl. derivatives/merges. **Explicit exceptions granted to CivitAI and Hugging Face**; other commercial use requires contacting contact@purplesmart.ai. (This differs from the *unmodified* faipl, which leaves outputs unrestricted — see §7.)
- Note ecosystem confusion: many Pony *merges/finetunes* exist (Prefect Pony XL, Pony Realism, etc.). "Pony V6.1 / V6-1.5" community builds appear on aggregators.
- Sources: https://civitai.com/models/257749/pony-diffusion-v6-xl ; https://civitai.com/articles/4248/what-is-score9-and-how-to-use-it-in-pony-diffusion ; https://ponydiffusion.com/faq ; https://stable-diffusion-art.com/pony-diffusion-v6-xl/

### 1d. Animagine XL 4.0 (Cagliostro Research Lab)
- **Retrained from scratch on SDXL 1.0**, **8,401,464 images**. Released **2025-01-24**; optimized variant **2025-02-13**. Version 4.0 ("Anim4gine").
- **License: CreativeML Open RAIL++-M** (unmodified SDXL license — notably MORE permissive for commercial use than the faipl models).
- Prompt format: character count + name, series, rating, descriptors, then quality markers: **`masterpiece, high score, great score, absurdres`**.
- Settings: **CFG 4–7 (5 preferred), 25–28 steps (28 preferred), Euler Ancestral.** Resolutions 1024×1024, 832×1216, 1152×896.
- Negative example: `lowres, bad anatomy, bad hands, text, error, missing finger, extra digits, fewer digits, cropped, worst quality, low quality, low score, bad score, average score, signature, watermark, username, blurry`.
- Source: https://huggingface.co/cagliostrolab/animagine-xl-4.0

### 1e. Community-favorite merges/finetunes (Civitai ecosystem)
- **WAI-illustrious-SDXL** — extremely popular Illustrious-based merge; uses rating tags + recommends `nsfw` in negatives for SFW control. https://grokipedia.com/page/WAI-illustrious-SDXL
- **comradeshipXL** (hanzogak) — Illustrious/NoobAI-lineage finetune. https://huggingface.co/hanzogak/comradeshipXL
- **Prefect Pony XL** — Pony merge. https://civitai.com/models/439889/prefect-pony-xl
- General landscape comparisons: https://techtactician.com/best-illustrious-xl-sdxl-anime-model-fine-tunes-comparison/ ; https://anifusion.ai/models/ ; https://www.aiphotogenerator.net/blog/2026/02/best-stable-diffusion-models-2026
- Civitai is the de-facto hub for these checkpoints + LoRAs.

### Quick comparison table
| Model | Base / lineage | Pred type | Prompt style | CFG / sampler / steps | License |
|---|---|---|---|---|---|
| Illustrious-XL v0.1 | Kohaku-XL beta5 / Danbooru2023 | eps (v3.5 v-pred) | Danbooru tags + quality | 5–7.5 / Euler a / 20–28 | faipl-1.0-sd (v0.1); later versions closed |
| NoobAI-XL eps | Illustrious | epsilon | Danbooru/e621 + quality + rating | std SDXL | faipl-1.0-sd |
| NoobAI-XL v-pred | Illustrious | **v-pred** | same | **4–5 / Euler only / 28–35** | faipl-1.0-sd |
| Pony Diffusion V6 XL | SDXL finetune | eps | **score_9…score_4_up** + source_ + rating_ | ~7 / common | **modified faipl (no monetized inference)** |
| Animagine XL 4.0 | SDXL 1.0 (from scratch) | eps | masterpiece/high score/great score/absurdres | 4–7(5) / Euler a / 25–28 | **CreativeML Open RAIL++-M** |

---

## 2. PROMPTING CONVENTIONS

### 2a. Tag systems
- **Danbooru tags** (Illustrious/NoobAI/Animagine): underscores→spaces conventions vary by UI; comma-separated booru tags. e.g. `1girl, solo, long hair, school uniform, classroom, looking at viewer`.
- **e621 tags** (NoobAI also trained on e621; Pony uses similar furry vocabulary).
- **Score tags (Pony only):** `score_9, score_8_up, …, score_4_up`. **These are Pony-specific and do NOT carry over to Illustrious/NoobAI/Animagine** — putting score_9 on Illustrious does little/nothing. Conversely Illustrious/NoobAI use percentile **quality tags** (`masterpiece, best quality, newest, absurdres`) and Animagine uses `masterpiece, high score, great score, absurdres`.
- **Rating tags:** Pony `rating_safe/questionable/explicit`; NoobAI/booru-style `safe/sensitive/questionable/explicit`. Critical SFW lever (§6).

### 2b. Artist tags (and the caution)
- Illustrious/NoobAI recognize **16,000+ Danbooru artist style tags**; tooling exists (ThetaCursed "Illustrious-NoobAI Style Explorer" — visual previews + dataset-strength indicators). https://github.com/ThetaCursed/Illustrious-NoobAI-Style-Explorer ; https://thetacursed.github.io/Illustrious-NoobAI-Style-Explorer/about.html ; https://civitai.com/articles/25464/common-style-tags-recognized-by-illustrious-and-other-danbooru-based-models
- **Caution (ethics):** artist tags reproduce the style of **specific, often living, named artists** without consent. Many artists object; "in the style of [living artist]" is the central flashpoint of the AI-art ethics debate. Practical guidance: prefer **mixing multiple artist tags** to create a blended/original look rather than cloning one living artist 1:1, prefer generic style descriptors, and keep artist-cloned output to personal/non-commercial use. (Search did not surface a single authoritative "controversy" doc; this is the well-documented community consensus, flag as judgment not citation.)

### 2c. Negative prompts
- Standard SDXL-anime negative (Animagine canonical): `lowres, bad anatomy, bad hands, text, error, missing finger, extra digits, fewer digits, cropped, worst quality, low quality, low score, bad score, average score, signature, watermark, username, blurry`.
- Add **`nsfw, explicit, nude, nipples, …`** to negatives for SFW (§6).
- Watermark note: Illustrious reportedly shows watermark artifacts more than NoobAI; `watermark, signature, username, text, logo` in negatives helps.

---

## 3. WALLPAPER SPECIFICS — RESOLUTION, ASPECT RATIO, UPSCALING

### 3a. SDXL native resolution buckets (~1 megapixel budget)
SDXL is trained on ~1 MP buckets; staying in-bucket avoids duplicated heads/limbs:
- 1:1 → **1024×1024**
- 4:5 / 5:4 → 896×1152 / 1152×896
- 2:3 / 3:2 → 832×1216 / 1216×832
- **16:9 (7:4 horiz) → 1344×768** (and 768×1344 vertical/phone)
- **21:9 ultrawide → 1536×640** (and 640×1536)
- Source: https://wiki.shakker.ai/en/sdxl-resolutions ; https://stability.ai/sdxl-aws-documentation

### 3b. Native-high-res vs hires-fix vs dedicated upscalers
- **Generate at the in-bucket aspect ratio first, then upscale** — generating directly at 3840×2160 from SDXL produces composition breakdown (duplications). Consensus: stable ~1 MP image → upscale.
- **Hires fix** (txt2img upscale + low-denoise second pass) is the built-in path; pick an upscaler in the dropdown. Use modest denoise (~0.3–0.5) to add detail without changing composition.
- **Dedicated upscalers / models:**
  - **4x-UltraSharp** (ESRGAN-architecture, must be installed manually; very popular for anime/illustration line cleanliness). https://civitai.com/models/116225/4x-ultrasharp
  - **RealESRGAN / Real-ESRGAN** (general restoration, synthetic-data trained). https://github.com/xinntao/Real-ESRGAN
  - **SwinIR** (transformer SR).
  - **SUPIR** (SDXL-based generative restoration; high fidelity/detail but heavy; commonly paired with **4x Foolhardy Remacri** for 8K). https://www.runcomfy.com/comfyui-workflows/8k-image-upscaling-supir-4x-foolhardy-remacri
- **Target wallpaper resolutions:** desktop 16:9 = **3840×2160** (4K UHD); 16:10 = 3840×2400/2560×1600; ultrawide 21:9 = 3440×1440; super-ultrawide 32:9 = 5120×1440; phone 9:19.5 ≈ 1284×2778 / 1080×2340. Path: native bucket → 2x–4x upscale to hit these.
- Upscaler overview: https://stable-diffusion-art.com/ai-upscaler/ ; https://www.aiarty.com/ai-upscale-image/stable-diffusion-upscale.htm
- **APPLE SILICON CAVEAT:** SUPIR is SDXL-sized + heavy; on M4 Pro 64 GB it should fit but will be slow (tens of seconds to minutes/image). 4x-UltraSharp/RealESRGAN are lightweight and fast even on Mac. SUPIR/some upscale nodes may hit MPS-unsupported ops → need `PYTORCH_ENABLE_MPS_FALLBACK=1` (CPU fallback, slower). Draw Things has built-in upscalers that run natively on Metal (avoids MPS gaps).

### 3c. Composition for wallpapers
- **Negative space for desktop icons:** compose subject off to one side (left or right third) leaving a clean area where the icon grid / dock sits. Tags like `off-center composition`, `wide shot`, `scenery`, `from above` help; explicitly prompt empty sky/wall/gradient regions.
- **Rule of thirds / subject placement:** booru tags `cowboy shot`, `full body`, `from side`, `looking away`, `profile` push subject placement; seed controls overall composition (re-roll seeds for layouts).
- **Ultrawide:** wide landscape/scenery prompts (`scenery, no humans, landscape, cityscape`) work better than single characters stretched across 21:9.
- Workflows: https://comfyui.org/en/comfyui-6k-wallpaper-generation-workflow ; https://openart.ai/workflows/city96/shape-cutout-anime-wallpaper-workflow/qaFd94pNViHDFkp6zEXE

### 3d. Batch / mass-production workflow
- **ComfyUI wildcards + dynamic prompts:** `__wildcard-name__` files and `{a|b|c}` inline syntax (ComfyUI-Impact-Pack `wildcards/` dir) to vary character/outfit/setting/artist per generation. Batch size N + queue → mass output. https://github.com/ltdrdata/ComfyUI-Impact-Pack
- **Pipeline:** wildcard prompt → SDXL anime checkpoint at in-bucket res → hires fix or save → batch upscale (4x-UltraSharp) → optional ADetailer/face-detailer pass for clean faces.
- **Draw Things** also supports batch generation natively on Mac (free, no token limits).

---

## 4. APPLE SILICON SPECIFICS (M4 Pro, 64 GB) — TOOLS, SPEED, CAVEATS

### 4a. Two main local apps
- **Draw Things** (Apple-native, SwiftUI + **Metal FlashAttention v2**, NOT a PyTorch wrapper). Free, offline, on App Store. Supports SDXL, FLUX.1, FLUX.2, Wan 2.2, Qwen-Image, Z-Image, LTX; supports Illustrious/Pony/Animagine checkpoints + LoRAs; **local LoRA training even on a 16 GB M4**. Reported **~20–40% faster than ComfyUI** on the same Mac. https://drawthings.ai/downloads/ ; https://www.heyuan110.com/posts/ai/2026-02-15-draw-things-ultimate-guide/ ; https://engineering.drawthings.ai/p/metal-flashattention-2-0-pushing-forward-on-device-inference-training-on-apple-silicon-fe8aac1ab23c
- **ComfyUI** (PyTorch + **MPS backend**). More flexible/node-based, but slower on Mac and exposed to MPS op gaps. Install needs PyTorch with MPS; set `PYTORCH_ENABLE_MPS_FALLBACK=1` so unsupported ops fall back to CPU. https://medium.com/@tchpnk/comfyui-on-apple-silicon-from-scratch-2025-9facb41c842f

### 4b. Concrete speed numbers (treat as approximate, source-reported)
- **SDXL 1024×1024, 25 steps, ComfyUI, M4 Pro 24 GB: ~20–40 s/image.** https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/
- FLUX.1-dev Q6_K, 20 steps, ComfyUI, M4 Pro 24 GB: ~50–90 s/image (context for the heavier models).
- Older datapoint: SD1.5 in Draw Things on M2 Pro 16 GB ≈ 8–15 s/image.
- **On a 64 GB M4 Pro, SDXL should be at or faster than the 24 GB figure (memory is not the bottleneck for SDXL; the GPU core count is).** No exact M4-Pro-64GB SDXL benchmark found — extrapolated. Draw Things' ~20–40% speedup would put SDXL roughly in the ~15–30 s/image range, but this is inferred, not measured.

### 4c. Caveats / honesty
- **Speed vs NVIDIA:** a single mid/high NVIDIA GPU (4090-class) does SDXL in ~3–6 s/image; Apple Silicon is several times slower per image. The Mac advantage is unified memory (large models fit) + native efficiency, not raw throughput.
- **MPS gaps:** certain ops (some upscalers, some custom nodes, some quantization kernels) are unimplemented on MPS → CPU fallback (slow) or errors. Draw Things sidesteps most of this by being natively Metal. **CONFLICT in sources:** marketing-style posts (heyuan110) claim 20–40% Draw Things advantage; treat the magnitude as approximate.
- **MLX:** Apple's MLX framework has SD/SDXL ports for Apple Silicon (alternative to PyTorch MPS) but the anime-checkpoint ecosystem lives in ComfyUI/Draw Things/A1111 formats; MLX is more niche. https://insiderllm.com/guides/stable-diffusion-mac-mlx/
- 64 GB unified memory comfortably runs SDXL + LoRAs + upscalers, and even FLUX/Qwen-Image FP16, simultaneously — memory is this machine's strength.

---

## 5. FLUX / QWEN ANIME — WORTH NOTING?
- **FLUX.1** (12B MMDiT, rectified flow): best prompt fidelity + anatomy/text, but **anime finetunes/LoRAs are sparse vs SDXL**; tends toward accidental realism for anime. https://tripleminds.co/blogs/technology/flux-vs-sdxl-vs-pony/
- **Qwen-Image:** very stylistically flexible (anime among many styles), **best-in-class text-in-image**, but again far smaller anime-specific ecosystem than SDXL. https://wavespeed.ai/blog/posts/qwen-2512-vs-sdxl-flux-text-benchmark/
- **Anima** (~2B, anime/manga/illustration-specific) — newer small model aimed at cleaner anime linework. https://diffusiondoodles.substack.com/p/anima-light-fast-and-slightly-unruly
- **Z-Image-Turbo** — fast model running on Apple Silicon/ComfyUI. https://medium.com/@tchpnk/z-image-turbo-comfyui-on-apple-silicon-2026-0aa78d05132d
- **Bottom line for anime wallpapers in 2025–2026: SDXL (Illustrious/NoobAI/Pony/Animagine) remains the right default** because of the LoRA/checkpoint breadth and booru-tag control; FLUX/Qwen are situational (text on the wallpaper, complex prompt scenes). https://localaimaster.com/blog/best-local-image-models-compared

---

## 6. THE "SKETCHY BUT SFW" LINE — STAYING SFW

These anime bases are trained heavily on NSFW booru/e621 data, so the latent space **drifts NSFW unless actively suppressed**. Hygiene:

1. **Use positive rating tags:** Pony `rating_safe` / `source_anime`; NoobAI/booru `safe` (and avoid `questionable`/`explicit`/`sensitive`). This is the single biggest lever.
2. **Negative-prompt the NSFW cluster:** `nsfw, explicit, nude, nudity, nipples, pussy, penis, sex, cum, areola, cleavage` (and `loli, shota, child` as a hard floor — see §7).
3. **Prompt clothing explicitly** — name a full outfit; under-specifying clothing is the most common cause of accidental nudity. (Confirmed by community guidance.)
4. **Watch "trigger" descriptors:** even with `safe`, tags like `bikini`, `school uniform`, `solo`, `close-up`, `cleavage` can pull "borderline anatomical emphasis" because of latent correlations. "Sketchy-but-SFW" (swimsuit/lingerie-adjacent, suggestive pose) is exactly where drift happens — keep the negative cluster strong and review outputs.
5. **WAI-illustrious** ships safety-rating tags + recommends `nsfw` in negatives as its documented SFW approach. https://grokipedia.com/page/WAI-illustrious-SDXL
6. **Lower CFG / fewer "sexy" artist tags** reduce drift; some artist styles are NSFW-leaning.
- Sources: https://www.rundiffusion.com/prompt-guide-for-juggernaut-xiii-ragnarok-by-rundiffusion ; https://zencreator.pro/ai-university/guides/stable-diffusion-nsfw-guide

---

## 7. ETHICS / LEGAL GUARDRAILS (non-negotiable)

1. **No minors.** Civitai has a **0-strike ban policy** for content involving minors; photorealistic depiction of minors is outright prohibited. For "age-up" of canonically-young characters: only generate **clearly adult** depictions; keep `loli/shota/child` in negatives. https://civitai.com/safety ; https://civitai.com/content/tos
2. **No real-person likeness / deepfakes.** Civitai (2025) **removed all real-person likeness content** (living or deceased — celebrities, influencers, private individuals) under pressure from Mastercard/Visa and laws: **US "Take It Down Act"** + **EU AI Act** synthetic-media provisions. Do not generate identifiable real people. https://civitai.com/articles/15022/policy-update-removal-of-real-person-likeness-content ; https://civitai.com/content/rules/real-people ; https://www.unite.ai/civitai-tightens-deepfake-rules-under-pressure-from-mastercard-and-visa/
3. **Respect model licenses (they differ!):**
   - **Unmodified `fair-ai-public-license-1.0-sd`** (Illustrious v0.1, NoobAI): copyleft/share-alike on the *model + modifications* (must redistribute derivatives under a compatible open license; network-use → provide source). **BUT outputs are explicitly UNRESTRICTED — "no contributor claims any rights" to generated images.** Prohibited-uses clause bans harm/discrimination/exploiting minors. https://freedevproject.org/faipl-1.0-sd/ ; https://civitai.com/articles/18619/what-the-license
   - **Pony V6 XL = MODIFIED faipl: no monetized inference** (paid/tiered services), incl. merges/derivatives; CivitAI + HF exempted; else contact PurpleSmart. https://civitai.com/models/257749/pony-diffusion-v6-xl
   - **Animagine XL 4.0 = CreativeML Open RAIL++-M** (standard SDXL RAIL; commercial use generally allowed, RAIL use-restrictions apply). https://huggingface.co/cagliostrolab/animagine-xl-4.0
   - **NET:** for *personal wallpapers*, all of these are fine. Commercial selling of outputs is **license-dependent** — unmodified faipl & RAIL++ generally OK on outputs; Pony's modification targets *inference services*, not personal output use, but verify.
4. **Copyrighted game/anime characters = personal use only.** Generating Mario/Zelda/Genshin/etc. characters is fine for a personal desktop wallpaper, but the characters remain the IP of Nintendo/HoYoverse/etc. — **do not sell, redistribute commercially, or imply official endorsement.**
5. **Civitai TOS generally:** uploader responsible for content; respect platform rules when sourcing checkpoints/LoRAs. https://civitai.com/content/tos

---

## 8. CONFLICTS & UNCERTAINTY LOG
- **NoobAI training image count (12.7M):** secondary-source figure; official cards describe datasets but don't confirm an exact million-count. LOW confidence on the precise number.
- **Illustrious version openness:** v0.1 open (faipl); v1.0+ described as closed/proprietary by the HF card and community — confirm per version before assuming free reuse.
- **Apple Silicon speeds:** all from blog/marketing posts (heyuan110, Medium), not controlled benchmarks. SDXL ~20–40 s/image (M4 Pro 24 GB ComfyUI) is the most concrete; no M4-Pro-64GB SDXL number found — the 64 GB machine should be ≥ as fast. Draw Things "20–40% faster" magnitude is source-claimed.
- **Pony license:** the *base* faipl leaves outputs free; Pony's *modification* restricts monetized inference. Two search snippets phrased this differently — the modified-license reading (no monetized inference, CivitAI/HF exempt) is the authoritative one from the Civitai model page.
- **"Sketchy-SFW" drift:** qualitative/community-sourced; no hard metric.

## 9. ALL SOURCE URLS
- https://huggingface.co/OnomaAIResearch/Illustrious-xl-early-release-v0
- https://civitai.com/models/833294/noobai-xl-nai-xl
- https://huggingface.co/Laxhar/noobai-XL-1.1
- https://huggingface.co/cagliostrolab/animagine-xl-4.0
- https://civitai.com/models/257749/pony-diffusion-v6-xl
- https://ponydiffusion.com/faq
- https://civitai.com/articles/4248/what-is-score9-and-how-to-use-it-in-pony-diffusion
- https://stable-diffusion-art.com/pony-diffusion-v6-xl/
- https://www.oreateai.com/blog/illustrious-vs-noobaixl-navigating-the-cutting-edge-of-anime-ai-art/230efde972f4e5af49e75fbb12505ce9
- https://techtactician.com/best-illustrious-xl-sdxl-anime-model-fine-tunes-comparison/
- https://anifusion.ai/models/
- https://www.aiphotogenerator.net/blog/2026/02/best-stable-diffusion-models-2026
- https://huggingface.co/hanzogak/comradeshipXL
- https://grokipedia.com/page/WAI-illustrious-SDXL
- https://github.com/ThetaCursed/Illustrious-NoobAI-Style-Explorer
- https://thetacursed.github.io/Illustrious-NoobAI-Style-Explorer/about.html
- https://civitai.com/articles/25464/common-style-tags-recognized-by-illustrious-and-other-danbooru-based-models
- https://wiki.shakker.ai/en/sdxl-resolutions
- https://stability.ai/sdxl-aws-documentation
- https://civitai.com/models/116225/4x-ultrasharp
- https://github.com/xinntao/Real-ESRGAN
- https://www.runcomfy.com/comfyui-workflows/8k-image-upscaling-supir-4x-foolhardy-remacri
- https://stable-diffusion-art.com/ai-upscaler/
- https://www.aiarty.com/ai-upscale-image/stable-diffusion-upscale.htm
- https://comfyui.org/en/comfyui-6k-wallpaper-generation-workflow
- https://openart.ai/workflows/city96/shape-cutout-anime-wallpaper-workflow/qaFd94pNViHDFkp6zEXE
- https://github.com/ltdrdata/ComfyUI-Impact-Pack
- https://drawthings.ai/downloads/
- https://www.heyuan110.com/posts/ai/2026-02-15-draw-things-ultimate-guide/
- https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/
- https://engineering.drawthings.ai/p/metal-flashattention-2-0-pushing-forward-on-device-inference-training-on-apple-silicon-fe8aac1ab23c
- https://medium.com/@tchpnk/comfyui-on-apple-silicon-from-scratch-2025-9facb41c842f
- https://insiderllm.com/guides/stable-diffusion-mac-mlx/
- https://medium.com/@tchpnk/z-image-turbo-comfyui-on-apple-silicon-2026-0aa78d05132d
- https://tripleminds.co/blogs/technology/flux-vs-sdxl-vs-pony/
- https://wavespeed.ai/blog/posts/qwen-2512-vs-sdxl-flux-text-benchmark/
- https://localaimaster.com/blog/best-local-image-models-compared
- https://diffusiondoodles.substack.com/p/anima-light-fast-and-slightly-unruly
- https://freedevproject.org/faipl-1.0-sd/
- https://civitai.com/articles/18619/what-the-license
- https://civitai.com/safety
- https://civitai.com/content/tos
- https://civitai.com/content/rules/real-people
- https://civitai.com/articles/15022/policy-update-removal-of-real-person-likeness-content
- https://www.unite.ai/civitai-tightens-deepfake-rules-under-pressure-from-mastercard-and-visa/
- https://www.rundiffusion.com/prompt-guide-for-juggernaut-xiii-ragnarok-by-rundiffusion
- https://zencreator.pro/ai-university/guides/stable-diffusion-nsfw-guide
