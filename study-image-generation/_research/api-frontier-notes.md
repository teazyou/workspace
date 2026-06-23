# Frontier Image-Editing APIs — Research Notes

Research date: 2026-06-23
Use case: image EDIT calls (text prompt + 1 input image ~1920×1080 in, ~1080p out). Volume reference = 100 edit calls.
Angle: Google Gemini, OpenAI, xAI Grok.

All three providers support image EDITING (input image + text prompt). All can output at/around 1080p (1K = 1024px tier covers 1080p region; 2K tiers exceed it). None is limited to text-to-image only — including Grok, which DOES accept an input image to edit.

---

## 1. Google Gemini API

### Models (June 2026)
- **Gemini 2.5 Flash Image** ("Nano Banana") — model id `gemini-2.5-flash-image`. Original GA flash image model.
- **Gemini 3.1 Flash Image** — id `gemini-3.1-flash-image`. Newer flash; supports 512px(0.5K)/1K/2K/4K and extreme aspect ratios (1:4, 4:1, 1:8, 8:1).
- **Gemini 3 Pro Image** ("Nano Banana Pro") — id `gemini-3-pro-image`. 1K/2K/4K. Higher quality.
- **Imagen 4** — DEPRECATED, shutting down 2026-08-17. Fast $0.02 / Standard $0.04 / Ultra $0.06 per image. (Text-to-image; do not build on it.)

### Editing support — YES
Official docs: "Provide an image and use text prompts to add, remove, or modify elements, change the style, or adjust the color grading." Exactly the user's isolate/recolor/replace-background task.

### Resolution vs 1080p
- 2.5 Flash Image: ~1024px native (1024×1024 = 1290 tokens). 1080p achievable via aspect-ratio options; ~1024 base may need light upscale for exact 1920×1080.
- 3.1 Flash Image / 3 Pro Image: explicit 1K / 2K / 4K tiers + aspect ratios — 1920×1080 comfortably within 2K, and 1K covers ~1080p region.

### How to call
- SDK: `client.interactions.create()` (Interactions API) / REST `https://generativelanguage.googleapis.com/v1beta/interactions`.
- (Older 2.5 surface used `generateContent` on `generativelanguage.googleapis.com/v1beta/models/...`.)

### EXACT pricing — source https://ai.google.dev/gemini-api/docs/pricing (fetched 2026-06-23)
**Gemini 2.5 Flash Image (Nano Banana):**
- Output: $30.00 / 1M output tokens; 1024×1024 image = 1,290 tokens => **$0.039 per image**.
- Input (text/image): $0.30 / 1M tokens.
- Batch tier: **$0.0195 per image** output; input $0.15/1M.

**Gemini 3 Pro Image (Nano Banana Pro):**
- Output: $120.00 / 1M tokens => **$0.134 per 1K/2K image**, **$0.24 per 4K image**.
- Input (text/image): $2.00 / 1M tokens (~$0.0011 per input image).
- Batch: $0.067 per 1K/2K image, $0.12 per 4K; input $0.0006/image.

### Cost for 100 edits (input 1080p + output 1080p)
- 2.5 Flash Image: output ~$0.039 × 100 = **~$3.90** + small input-image token cost (~1080p input image ≈ ~1290–1600 tokens × $0.30/1M ≈ negligible, <$0.001/call). ≈ **$3.90–$4.00**. Batch ≈ **$1.95**.
- 3 Pro Image (1K/2K): ~$0.134 × 100 = **~$13.40** + ~$0.0011 input × 100 ≈ **~$13.50**. Batch ≈ ~$6.70.

### Quality impression
Nano Banana / Nano Banana Pro are considered category-leading for instruction-based editing in 2026 (strong prompt adherence, character/element preservation, clean background replacement). Pro tier best for fidelity; Flash best for cost.

---

## 2. OpenAI API

### Models (June 2026)
- **gpt-image-1.5** — current flagship (a.k.a. `chatgpt-image-latest`). Replaces gpt-image-1. Supports `input_fidelity:"high"` to preserve up to 5 input images at higher fidelity (useful for "keep named elements").
- **gpt-image-1-mini** — budget tier.
- **gpt-image-2** — appears on the official docs pricing table (newer/higher tier; image output $30/1M). Lineup is in flux; gpt-image-1.5 is the widely-cited flagship as of Mar 2026.
- **gpt-image-1** — legacy. **DALL·E 3 / DALL·E 2** — deprecated.

### Editing support — YES
`/v1/images/edits` endpoint: input image + prompt (and optional mask). Token-based billing: text input tokens + IMAGE INPUT tokens (for the supplied image) + image OUTPUT tokens.

### Resolution vs 1080p
Output sizes: 1024×1024, 1024×1536 (portrait), 1536×1024 (landscape). Max ~1536px on long edge => **does NOT natively output 1920×1080**; 1536×1024 is the closest landscape and needs upscaling to true 1080p.

### EXACT pricing
Token pricing — source https://developers.openai.com/api/docs/pricing (fetched 2026-06-23), per 1M tokens:
- **gpt-image-1.5**: text input $5.00, image input $8.00, image output $32.00. (Batch: $2.50 / $4.00 / $16.00.)
- **gpt-image-1-mini**: text input $2.00, image input $2.50, image output $8.00. (Batch: $1.00 / $1.25 / $4.00.)
- **gpt-image-2** (on docs table): text input $5.00, image input $8.00, image output $30.00.

Per-image $ (gpt-image-1.5), source https://costgoat.com/pricing/openai-images and https://www.aifreeapi.com/en/posts/gpt-image-1-5-pricing (fetched 2026-06-23):
- 1024×1024: Low **$0.009**, Medium **$0.034**, High **$0.133**.
- 1536×1024 (landscape): Medium **$0.050**, High **$0.199–$0.20**.
- gpt-image-2 high (costgoat): 1024×1024 $0.211, 1536×1024 $0.165.

NOTE discrepancy: third-party sources show 1.5 high at 1024² = $0.133 but landscape 1536×1024 high = ~$0.20. Use output-token math ($32/1M) as authoritative; per-image $ depends on the actual output token count for the chosen size/quality.

### Cost for 100 edits (input 1080p + output ~1080p landscape, HIGH quality, gpt-image-1.5)
- Output: ~$0.20/image (1536×1024 high) × 100 = **~$20**.
- Plus image-INPUT tokens for the ~1080p source image (billed at $8/1M) — a 1536×1024-ish input ≈ a few thousand tokens ≈ <$0.05/call; text prompt negligible. Total ≈ **~$20–$22** at high quality.
- Medium quality (1536×1024 ~$0.05): ≈ **~$5–$6** for 100.
- gpt-image-1-mini is materially cheaper (output $8/1M vs $32/1M).

### Quality impression
gpt-image-1.5 is a benchmark leader for instruction following and text rendering; `input_fidelity:high` helps preserve specified elements/characters during edits. Strongest where precise prompt adherence and legible text matter; pricier at high quality and capped at 1536px output.

---

## 3. xAI Grok API

### Models (June 2026)
- **grok-imagine-image** — standard image model (the "Grok Imagine" API). grok-2-image / Aurora is the older lineage; current docs surface the grok-imagine models.
- **grok-imagine-image-quality** — higher-quality tier; this is the one documented for EDITING.

### Editing support — YES (NOT text-to-image only)
CRITICAL FINDING: Grok DOES accept an input image to edit. Official docs (image editing page, docs.x.ai): the API accepts "an existing image by providing a source image along with your prompt"; the model "understands the image content and applies your requested changes" (style transfer, add/remove/swap objects). Multi-image editing/compositing supported (up to ~3 source images). No mask required; multi-turn refinement supported. => Grok CAN do the user's edit task.
- Editing documented for **grok-imagine-image-quality**.

### Resolution vs 1080p
Supported resolutions: **1k and 2k** (per docs.x.ai image generation page). 1K covers ~1080p region; 2K exceeds 1920×1080. Adequate for 1080p output.

### EXACT pricing — source https://docs.x.ai/developers/models (fetched 2026-06-23)
- **grok-imagine-image**: **$0.02 / image**.
- **grok-imagine-image-quality**: **$0.05 / image** (some third-party sources: 1K $0.05, 2K $0.07).
- Editing bills BOTH input image + output image (effective per-edit cost = sum), per third-party (atlascloud) — NOT explicitly confirmed on official docs; treat input-image billing as unverified.
- grok-2-image: not in current pricing docs.

### Cost for 100 edits
- grok-imagine-image-quality (edit-capable) @ $0.05 output × 100 = **~$5** (plus possible input-image charge ≈ another ~$0.05/call if billed both ways => up to ~$10). 2K ≈ $0.07/image => ~$7–$14.
- grok-imagine-image @ $0.02 if it supported the edit path => ~$2, but editing is documented on the -quality model.

### Quality impression
Grok Imagine editing is competent for natural-language edits/compositing (~13s latency reported), cheap. Generally considered a step below Nano Banana Pro / gpt-image-1.5 for precise instruction adherence and element preservation, but lowest cost of the three frontier providers for the edit task.

---

## Summary comparison (100 edit calls, input ~1080p + output ~1080p)

| Provider | Edit model | Edit? | Max res vs 1080p | Per-image (~1080p) | ~100 calls | Pricing URL |
|---|---|---|---|---|---|---|
| Google | Gemini 2.5 Flash Image (Nano Banana) | Yes | ~1024px base; 1K/2K on 3.x | $0.039 (1K) | ~$3.90 (batch ~$1.95) | ai.google.dev/gemini-api/docs/pricing |
| Google | Gemini 3 Pro Image (Nano Banana Pro) | Yes | 1K/2K/4K | $0.134 (1K/2K) | ~$13.40 | ai.google.dev/gemini-api/docs/pricing |
| OpenAI | gpt-image-1.5 (/images/edits) | Yes | 1536px max (<1920) | ~$0.20 high 1536×1024 (~$0.05 med) | ~$20 high / ~$5 med | developers.openai.com/api/docs/pricing |
| xAI | grok-imagine-image-quality | Yes | 1k/2k | $0.05 (1K) / $0.07 (2K) | ~$5 (up to ~$10 if input billed) | docs.x.ai/developers/models |

Cheapest: Gemini 2.5 Flash batch (~$1.95). Best quality/value: Gemini 2.5 Flash standard (~$3.90) or Grok quality (~$5). Highest fidelity: Nano Banana Pro / gpt-image-1.5 (higher cost). OpenAI is priciest at high quality and capped below true 1920×1080 output.

### Open items / caveats
- OpenAI max output 1536px => true 1920×1080 needs upscaling.
- OpenAI lineup unsettled: gpt-image-2 appears on docs pricing table ($30/1M) alongside gpt-image-1.5 ($32/1M); flagship naming may shift.
- Grok input-image billing (input+output sum) is third-party, not confirmed on official docs.
- gpt-image-1.5 per-image high-quality figures vary by source ($0.133 sq vs ~$0.20 landscape) — token math ($32/1M output) is the reliable basis.
