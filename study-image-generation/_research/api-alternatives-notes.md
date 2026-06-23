# Alternative Cloud Image-Editing API Providers — Research Notes

Research date: 2026-06-23
Use case: prompt + 1 input image EDIT (isolate character, recolor, replace background with plain black — wallpaper style). Input ~1080p (1920×1080 ≈ 2.07 MP), output ~1080p. Cost reference: **100 image-EDIT calls**.
Angle: Top-3 ALTERNATIVE API providers beyond Gemini / OpenAI / Grok.

NOTE on resolution math: 1920×1080 = 2,073,600 px ≈ **2.07 megapixels (MP)**. Megapixel-priced models cost more than their headline "1 MP / 1024×1024" rate for true 1080p I/O. Many "edit" models internally normalize to ~1 MP (1024-class) output; getting a true 1920×1080 output sometimes requires upscaling or a model that supports the aspect ratio natively.

---

## 1. Black Forest Labs (BFL) — FLUX.1 Kontext / FLUX.2  ★ BEST FOR EDITING

**Editing support:** YES — purpose-built. FLUX.1 Kontext is an instruction-based image-to-image editor (input image + text prompt; targeted local edits, recolor, background replacement, character preservation). FLUX.2 [pro]/[flex] also have native image-editing endpoints. This is the FLUX "Kontext-class" editor the use case specifically calls for.

**Pricing (official):**
- Source: https://docs.bfl.ai/quick_start/pricing (fetched 2026-06-23) and https://bfl.ai/pricing
- **FLUX.1 Kontext [pro]: 4 credits = $0.04 per image** (text + image editing). Flat per-image.
- **FLUX.1 Kontext [max]: 8 credits = $0.08 per image** (max quality editing).
- **FLUX.2 [pro]: megapixel-based** — "from $0.03" text-to-image, **"from $0.045" for image editing**, scales with output resolution. Per WebSearch of BFL calculator: input charged ~$0.015/MP, output first MP $0.03 then +$0.015/MP (figures from search of bfl.ai calculator, NOT confirmed on a static page — flagged to verify).
- **FLUX.2 [flex]: "from $0.05"** for both text-to-image and image editing.
- Also listed on bfl.ai/pricing: FLUX.2 [max], FLUX.2 [klein] 4B/9B, FLUX Outpainting, FLUX Eraser, FLUX VTO (exact $ not captured — calculator is JS-rendered).

**Cost for 100 edits:**
- Kontext [pro] flat: **100 × $0.04 = $4.00** (cleanest to compute; resolution-independent flat rate).
- Kontext [max]: 100 × $0.08 = $8.00.
- FLUX.2 [pro] edit at true 1080p I/O: more than $0.045 because both input (~2.07 MP) and output (~2.07 MP) are billed by MP — likely ~$0.07–$0.10/edit → ~$7–$10 / 100. (Verify on calculator.)

**Max resolution vs 1080p:** Kontext handles 1080p-class fine; example outputs at fal in 1248×832 range. FLUX.2 megapixel model explicitly scales to higher resolutions. 1920×1080 achievable. (Exact hard cap not pinned on static docs.)

**Quality tier:** Frontier-adjacent for editing specifically. FLUX.2 launched late 2025 explicitly to challenge Nano Banana Pro / Gemini and Midjourney (VentureBeat). Kontext is the de-facto reference instruction-editor.

**Licensing / content policy:** Commercial use permitted via the paid API (BFL commercial terms). Has standard content/safety filters. (Confirm commercial-use clause on bfl.ai terms.)

---

## 2. fal.ai — aggregator hosting FLUX Kontext, Qwen-Image-Edit, FLUX.2  ★ BEST AGGREGATOR FOR EDITING

**Editing support:** YES — hosts the strongest editing models behind one pay-per-use API. FLUX.1 Kontext (image-to-image), FLUX.2 [pro]/edit, and Qwen-Image-Edit 2511 (instruction editing, identity preservation, multi-image compositing).

**Pricing (official fal model pages, fetched/searched 2026-06-23):**
- **FLUX.1 Kontext [pro]: $0.04 per image** — https://fal.ai/models/fal-ai/flux-pro/kontext (fetched; confirmed "$0.04 per image", supports image editing, example out 1248×832).
- **FLUX.1 Kontext [max]: $0.08 per image** (per pricepertoken / fal flux page).
- **Qwen-Image-Edit 2511: $0.03 per megapixel** — https://fal.ai/models/fal-ai/qwen-image-edit-2511 . LoRA / multiple-angles variants $0.035/MP. Native up to **2560×2560**; 20B param instruction editor with identity preservation. (Search-confirmed; verify on model page.)
- **FLUX.2 [pro] edit:** https://fal.ai/models/fal-ai/flux-2-pro/edit (MP-based, mirrors BFL).
- Pricing index: https://fal.ai/pricing , https://fal.ai/docs/documentation/model-apis/pricing

**Cost for 100 edits:**
- Kontext [pro] flat: **100 × $0.04 = $4.00**.
- Qwen-Image-Edit at true 1080p (output ~2.07 MP): 2.07 × $0.03 = **~$0.062/edit → ~$6.22 / 100** (output-MP only; if input MP also billed it is higher — verify whether fal bills input+output or output-only).

**Max resolution vs 1080p:** Qwen-Image-Edit native 2560×2560 (well above 1080p). Kontext ~1 MP class outputs (1080p reachable). 1920×1080 supported.

**Quality tier:** Same model weights as BFL/Qwen → equal quality to source models; fal's value is unified API + many editors + per-MP option that is cheap at standard resolution.

**Licensing:** Pay-per-use, no subscription. Commercial use of generated outputs allowed; underlying model licenses (FLUX.1 [dev] non-commercial vs Kontext [pro]/[max] commercial via API) apply — Kontext pro/max via API are commercial-OK. Qwen-Image is Apache-2.0 open weights → commercial-friendly.

---

## 3. Stability AI — Stable Image / SD3.5 (dedicated edit endpoints)  ★ BEST DEDICATED EDIT-PRIMITIVES

**Editing support:** YES — dedicated REST edit endpoints: Inpaint, Outpaint, Erase, Remove Background, Search-and-Replace, Search-and-Recolor, plus Control (Structure/Style) and image-to-image. "Replace background with black" maps directly to Remove Background + composite or Search-and-Replace. More surgical/primitive than instruction-style editors.

**Pricing (official):**
- Credit system: **1 credit = $0.01** (1000 credits = $10). https://platform.stability.ai/pricing
- Edit-op credit costs (https://stability.ai/api-pricing-update-25, effective 2025-08-01, fetched 2026-06-23):
  - **Inpaint: 5 credits = $0.05**
  - **Erase: 5 credits = $0.05**
  - **Remove Background: 5 credits = $0.05**
  - **Search and Replace: 5 credits = $0.05**
  - **Control Structure: 5 credits = $0.05**
  - **Control Style: 5 credits = $0.05**
  - (Outpaint / Search-and-Recolor / image-to-image not listed in the update post — verify on pricing page.)
- Generation models (context): Stable Image Core ~3 credits ($0.03); Stable Image Ultra (SD3.5 Large) 8 credits ($0.08); SD3.5 Large 6.5 cr, Large Turbo 4 cr, Medium 3.5 cr.

**Cost for 100 edits:** Remove-Background or Search-and-Replace at 5 credits = **100 × $0.05 = $5.00**.

**Max resolution vs 1080p:** SD3.5 / Stable Image services output ~1 MP class (1024-ish) by default; edit endpoints generally preserve input dimensions up to limits → 1920×1080 feasible for the edit ops (which return at input resolution). Verify exact max.

**Quality tier:** Below FLUX/frontier on photoreal instruction-following, but the dedicated edit primitives (remove-bg, search-replace) are reliable and well-suited to "isolate character / black background" tasks.

**Licensing:** Outputs from paid API are commercial-use OK under Stability's terms (the API/Core/Ultra commercial license, distinct from the gated SD3.5 self-host community license). Content filtering applies.

---

## Also evaluated (did NOT make top 3)

### Replicate — aggregator
- Editing support: YES — hosts FLUX Kontext pro/max ("state-of-the-art image editing model, edit via text prompts" — https://replicate.com/black-forest-labs/flux-kontext-pro), Qwen-Image-Edit 2511 (https://replicate.com/qwen/qwen-image-edit-2511), SDXL, inpainting models.
- Pricing: per-run / hardware-per-second; FLUX images quoted **$0.003–$0.04 per image** range (pricepertoken / checkthat). Kontext-pro run price not pinned on the model page (page is capability-focused). Public models bill active processing time only.
- Why not top-3: same models as fal but fal exposes flat per-image edit pricing more transparently; Replicate's per-second billing is less predictable for the cost reference. Strong honorable mention / interchangeable with fal.

### Recraft — https://www.recraft.ai/docs/api-reference/pricing
- Editing support: YES — prompt-based editing, inpaint/outpaint, background removal.
- Pricing: **$0.04 per raster image**, $0.08 per vector; Recraft 20B $0.022 raster. → 100 edits ≈ $4.00.
- Why not top-3: strong for design/vector/typography, but less of a photoreal instruction-editor than FLUX Kontext for the "isolate character / wallpaper" task.

### Ideogram — https://ideogram.ai/features/api-pricing (redirects; about.ideogram.ai/api-pricing)
- Editing support: YES — Edit, Remix, Replace Background, Reframe operations (input image + prompt). "Replace Background" maps directly to the use case.
- Pricing (search-derived, V3 tiers): Turbo ~$0.03–$0.0375, Default ~$0.075, Quality ~$0.1125 per image; overall API range $0.025–$0.10. → 100 edits ≈ $3–$11 depending on tier.
- Why not top-3: good text rendering & has a literal "Replace Background" op, but exact per-op edit prices not confirmed on a static page; quality for surgical character isolation trails FLUX Kontext.

### Adobe Firefly Services API — https://helpx.adobe.com/.../generative-credits
- Editing support: YES — Generative Fill / Expand, background, Photoshop API.
- Pricing: credit-based, ~$0.02–$0.10/image effective; **~$1,000/month minimum enterprise commitment** (SudoMock). Generative Fill ~1 credit.
- Why not top-3: enterprise minimum + commercial gating makes it heavy for a 100-call hobby/study workload; strong on commercial-safety/indemnification if that matters.

### Midjourney — NO OFFICIAL PUBLIC API (excluded)
- As of early–mid 2026 Midjourney has **no broadly available official API** (no public REST/SDK/API keys; closed/limited beta only — myarchitectai, 10b.ai, cometapi). Has a web "Editor" for inpaint/reframe but not programmatic. Third-party "Midjourney APIs" are unofficial browser-automation wrappers (ToS-risky). NOT a viable official API provider for this use case.

---

## TOP 3 (ranked) for "edit an existing image (prompt + input image)"

1. **Black Forest Labs (FLUX.1 Kontext / FLUX.2)** — purpose-built instruction editor, flat **$0.04/edit** (Kontext pro), frontier-class editing quality. ≈ **$4 / 100**.
2. **fal.ai** — best aggregator: same Kontext pricing ($0.04) PLUS Qwen-Image-Edit at $0.03/MP and 2560² resolution, unified pay-per-use API, no subscription. ≈ **$4–$6.2 / 100**.
3. **Stability AI (Stable Image / SD3.5)** — dedicated edit primitives (Remove Background / Search-and-Replace at **$0.05**) that map cleanly to "isolate character + black background." ≈ **$5 / 100**.

(Replicate is a near-tie alternate to #2; Recraft/Ideogram are viable cheaper-but-lower-edit-fidelity options; Adobe = enterprise; Midjourney = no official API.)

## Pricing URLs (quick reference)
- BFL: https://bfl.ai/pricing , https://docs.bfl.ai/quick_start/pricing
- fal: https://fal.ai/pricing , https://fal.ai/models/fal-ai/flux-pro/kontext , https://fal.ai/models/fal-ai/qwen-image-edit-2511
- Stability: https://platform.stability.ai/pricing , https://stability.ai/api-pricing-update-25
- Replicate: https://replicate.com/black-forest-labs/flux-kontext-pro , https://replicate.com/qwen/qwen-image-edit-2511
- Recraft: https://www.recraft.ai/docs/api-reference/pricing
- Ideogram: https://ideogram.ai/features/api-pricing
- Adobe Firefly: https://helpx.adobe.com/creative-cloud/apps/generative-ai/generative-credits-faq.html
