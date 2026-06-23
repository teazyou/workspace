# Annex — Doing the Edit via Cloud APIs Instead (Gemini / OpenAI / Grok + Top Alternatives), Priced per 100 Images in VND

This annex is the **cloud counterpart** to the local workflow in files 01–06. Same task — *send a text **prompt** + one **input image** (~1920×1080) and get back an edited ~1080p wallpaper: isolate the character, keep named elements, recolor one, replace the background with plain black* — but run on a **hosted API** instead of your Mac. It answers: how to call each frontier provider (Google Gemini, OpenAI, xAI Grok), whether each can actually do an **edit** (input image + prompt, not just text-to-image), the **top 3 alternatives**, whether the results are equivalent in quality, and **how much 100 such edits cost, priced in VND**. For the *local* way to do the exact same job (free after the hardware you already own), see [`./06-annex-image-editing.md`](./06-annex-image-editing.md).

> **FX rate used throughout:** **1 USD = 26,320 ₫**, as of **2026-06-23** (Google Finance `USD-VND`, cross-checked against Wise — both 26,320). API prices and FX both drift; **re-check the cited pricing pages** before you commit a budget.

> **Scope / privacy framing.** Calling a cloud API means your **input image and prompt leave your machine** and transit a third party's servers (often retained for abuse-monitoring windows). That is the central trade-off vs the fully-offline pipeline in 01–06. If the source image is private, sensitive, or copyrighted IP you don't control, weigh that before sending it. See the [local-vs-API note](#7-local-vs-api--the-honest-trade-off) at the end.

---

## 1. Headline answer

- **Every provider here can do the edit task** — prompt **+** input image → edited image. **None is text-to-image only**, and that explicitly includes **xAI Grok** (a common misconception — Grok *can* take a source image).
- **Recommended default: Black Forest Labs FLUX.1 Kontext [pro]** — a purpose-built instruction editor, **flat $0.04/edit at any resolution**, true 1080p with no upscale, top-tier fidelity. **≈ 105,280 ₫ / 100 edits.**
- **Cheapest viable:** Gemini 2.5 Flash (batch tier) ≈ **51,324 ₫ / 100** and Ideogram Turbo ≈ **78,960 ₫ / 100** — but both need an upscale or a tier-bump for *true* native 1080p.
- **Best frontier quality:** Gemini 3 Pro Image (Nano Banana Pro) or FLUX.1 Kontext [max].
- **Worst value:** OpenAI gpt-image-2 (~**539,560 ₫ / 100**, and the prior-gen gpt-image-1.5 hard-caps at 1536 px — can't natively hit 1080p).

---

## 2. The headline table

Provider/model × supports editing × max output resolution × per-image USD × **cost for 100 edits in VND** (1 USD = 26,320 ₫, 2026-06-23, Google Finance cross-checked vs Wise). **Bold = cheapest viable** and **best-quality**. Rows ordered by per-100 cost.

| Provider / model | Edits? | Max output res | Per-image USD | **100 edits (VND)** | Notes |
|---|---|---|---|---|---|
| Gemini 2.5 Flash Image (`gemini-2.5-flash-image`) — **batch** | Yes | ≤1024² at the priced tier | ≈ $0.0195 | **≈ 51,324 ₫** | Cheapest, but ≤1024 px tier → upscale/tier-bump for true 1080p |
| Ideogram 3.0 **Turbo** (Replace-BG / Edit) | Yes | ~1 MP-class | $0.03 | ≈ 78,960 ₫ | Dedicated Replace-Background op; verify native res |
| Gemini 2.5 Flash Image — standard | Yes | ≤1024² at the priced tier | ≈ $0.040 | ≈ 105,280 ₫ | Same res caveat as batch row |
| **BFL FLUX.1 Kontext [pro]** | Yes | 1920×1080 ✓ (flat) | **$0.04** | **≈ 105,280 ₫** | **BEST FIT — true 1080p, top fidelity, flat price** |
| Recraft (raster edit/inpaint/bg-removal) | Yes | ~1 MP-class | $0.04 | ≈ 105,280 ₫ | Design/vector-strong; verify true-1080p res |
| Replicate (FLUX Kontext / Qwen host) | Yes | matches model (≤2560²) | ≈ $0.003–0.04 | ≈ 7,896–105,280 ₫ | **Uncertain** — per-second/per-run billing |
| fal.ai **Qwen-Image-Edit 2511** | Yes | up to 2560×2560 ✓ | ≈ $0.045 @1080p | ≈ 118,440 ₫ | Native true 1080p, output-MP billing only |
| Stability AI (Remove-BG / Search-Replace / Inpaint) | Yes | returns at **input** res ✓ | $0.05 | ≈ 131,600 ₫ | Primitive-driven; 1080p-in → 1080p-out |
| Ideogram 3.0 **Default** | Yes | ~1 MP-class | $0.06 | ≈ 157,920 ₫ | — |
| xAI Grok (`grok-imagine-image-quality`) @1K | Yes | 1K (~1 MP) / 2K | ≈ $0.06 @1K | ≈ 157,920 ₫ | Edit-capable; **use 2K for true 1080p** |
| xAI Grok @2K | Yes | 2K ✓ | ≈ $0.08 @2K | ≈ 210,560 ₫ | Bills input **+** output image (official) |
| BFL FLUX.1 Kontext [max] | Yes | 1920×1080 ✓ (flat) | $0.08 | ≈ 210,560 ₫ | Higher-fidelity Kontext tier |
| Ideogram 3.0 **Quality** | Yes | ~1 MP-class | $0.09 | ≈ 236,880 ₫ | — |
| **Gemini 3 Pro Image** (`gemini-3-pro-image`) | Yes | native 1K/2K/4K ✓ | ≈ $0.135 (1K/2K) | **≈ 355,320 ₫** | **BEST FRONTIER QUALITY**, native 1080p, no upscale |
| OpenAI **gpt-image-2** (flagship) | Yes | 1.5: 1536 px cap; 2: higher* | ≈ $0.19–0.21 *(uncertain)* | ≈ 539,560 ₫ | **Priciest; no flat per-image price** |

\* OpenAI's **gpt-image-1.5** is hard-capped at 1536 px (no native 1920×1080 → needs an upscale). The newer flagship **gpt-image-2** reportedly adds higher/custom resolutions but the exact 1080p price is **not officially pinned**. The ~$0.20/image (~$20.50/100) figure is a **calculator-derived order-of-magnitude estimate**, not an official flat price — treat it as approximate.

> Batch tiers (where offered, e.g. Gemini's Batch/Flex at 50% off) roughly **halve** these numbers if you can tolerate asynchronous turnaround.

---

## 3. The three frontier providers

All three confirmed edit-capable. Below: the model id, the edit vs generate endpoint, a minimal snippet, the use-case verdict, and resolution vs 1080p.

### 3a. Google Gemini — cheapest frontier, best value

- **Model ids:** `gemini-2.5-flash-image` ("Nano Banana", mid-tier) and `gemini-3-pro-image` ("Nano Banana Pro", high-fidelity). A newer `gemini-3.1-flash-image` adds explicit 0.5K/1K/2K/4K sizes.
- **Edit vs generate:** *same* call for both. You pass the input image as an inline part alongside the text prompt; the model adds/removes/modifies elements, restyles, and recolors. Endpoint: `generativelanguage.googleapis.com` `generateContent` (Interactions / `generate_content`).
- **Max res vs 1080p:** the **$0.039 price is only for output up to 1024×1024**. True 1920×1080 (>1 MP) consumes more output tokens and costs a bit more, **or** needs an upscale. For native, no-fuss 1080p use **`gemini-3-pro-image`** (native 1K/2K covers 1080p; 4K is the $0.24 tier).

```python
# pip install google-genai
from google import genai
from google.genai import types

client = genai.Client(api_key="GEMINI_API_KEY")
img = open("input_1080p.png", "rb").read()
resp = client.models.generate_content(
    model="gemini-2.5-flash-image",          # or gemini-3-pro-image for native 1080p
    contents=[
        types.Part.from_bytes(data=img, mime_type="image/png"),
        "Isolate the character and the yoga rope, recolor the flower red, "
        "replace the entire background with plain solid black (#000000). Wallpaper style.",
    ],
)
# resp.candidates[0].content.parts -> the edited image bytes
```

- **Pricing (official):** image output **$30/1M tokens**; 1024² = 1,290 tokens = **$0.039/image** → **≈ $3.90 / 100 (batch ≈ $1.95)**. Gemini 3 Pro: output $120/1M → **$0.134 per 1K/2K image** (**$0.24 per 4K**), input image ~$0.0011.
- **Per 100 in VND:** 2.5 Flash ≈ **105,280 ₫** (batch ≈ **51,324 ₫**); **3 Pro ≈ 355,320 ₫** (batch ≈ 176,344 ₫); 3 Pro 4K ≈ 631,680 ₫.
- **Use-case verdict:** ✅ **Fully covers it.** Cheapest frontier path. Use 2.5 Flash + an upscale for true 1080p on a budget, or 3 Pro for native high-fidelity 1080p.

### 3b. OpenAI — capable but priciest, with a resolution caveat

- **Model ids:** **`gpt-image-2`** is the current **flagship** (image output $30/1M, image input $8/1M, text input $5/1M). **`gpt-image-1.5`** is the prior gen (output $32/1M, same inputs). `gpt-image-1-mini` is the cheap lane (output $8/1M, ~¼ the output cost).
- **Edit vs generate:** distinct endpoints. Edits use **`POST /v1/images/edits`** (input image + **optional** mask + prompt). `input_fidelity:"high"` preserves up to 5 input images — good for keeping the character faithful.
- **Max res vs 1080p:** **gpt-image-1.5 is hard-capped at 1536 px** — only `1024×1024`, `1024×1536`, `1536×1024`, so **no native 1920×1080** (upscale required). gpt-image-2 reportedly adds higher/custom resolutions, but the 1080p price isn't officially pinned.

```bash
curl https://api.openai.com/v1/images/edits \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F model="gpt-image-2" \
  -F image="@input_1080p.png" \
  -F input_fidelity="high" \
  -F prompt="Isolate the character and yoga rope, recolor the flower red, \
replace the whole background with solid black. Wallpaper style."
```

- **Pricing:** token-driven, **no published flat per-image price** — OpenAI defers to its image calculator. A high-quality 1536×1024 output is **~$0.19–0.21** (output tokens) **plus** input-image tokens ($8/1M) since edits also bill the source image. **Treat ~$0.20/image (~$20.50/100) as an order-of-magnitude estimate.**
- **Per 100 in VND:** ≈ **539,560 ₫** (range ≈ 500,080–552,720 ₫). `gpt-image-1-mini` is materially cheaper if its quality suffices.
- **Use-case verdict:** ✅ **Can do it**, but it is the **most expensive** option for this task and gpt-image-1.5 **can't natively output 1080p**. Pick it only if you specifically want OpenAI's look or already live in its stack.

### 3c. xAI Grok — edit-capable (not text-to-image only), low-cost

- **Model id:** **`grok-imagine-image-quality`** for editing (the standard `grok-imagine-image` is generate-oriented). Supports add/remove/swap, style-transfer, and multi-image compositing (~3 sources), no mask required.
- **Edit vs generate:** you supply a **source image** (public URL, base64 data URI, or Files API file id) via the `image_url` parameter on the `sample()` method, together with the text prompt. **This is the key correction to the myth that Grok is generate-only — it is not.**
- **Max res vs 1080p:** supports **1K** (~1 MP, *below* 1080p) and **2K** (comfortably exceeds 1080p). **Use the 2K tier for true 1080p.**

```python
# xAI Python SDK (xai-sdk)
from xai_sdk import Client
client = Client(api_key="XAI_API_KEY")
chat = client.image  # image surface
result = chat.sample(
    model="grok-imagine-image-quality",
    prompt="Isolate the character and the yoga rope, recolor the flower red, "
           "replace the background with solid black. Wallpaper style.",
    image_url="data:image/png;base64,<...base64 of input_1080p.png...>",
)
# result -> the edited image
```

- **Pricing:** output **$0.05/image at 1K** ($0.07 at 2K). **Official docs confirm edits bill BOTH the input and the output image**, so an effective per-edit cost is **~$0.06 at 1K** (output $0.05 + input ~$0.01, input adds ~20% — *not* the ~2× some sources claim) and **~$0.08 at 2K**.
- **Per 100 in VND:** **≈ 157,920 ₫ at 1K**; **≈ 210,560 ₫ at 2K** (the tier you'd actually use for true 1080p).
- **Use-case verdict:** ✅ **Covers it.** Mid-tier fidelity, low cost. For true 1080p budget the 2K tier (~$0.08/edit, ~$8/100).

> **Is any frontier provider text-to-image only?** **No.** Gemini, OpenAI, and Grok all accept an input image + prompt for editing. The only "no API at all" name in this space is **Midjourney** (no broadly available official public API as of mid-2026 — third-party "Midjourney APIs" are unofficial automation wrappers; *uncertain, based on third-party reporting*).

---

## 4. Top 3 alternatives to the frontier trio

These beat the frontier names on **fit for instruction-editing** and/or price. All three are confirmed edit-capable.

### #1 — Black Forest Labs (FLUX.1 Kontext / FLUX.2) — the purpose-built editor

The **best alternative and the recommended default overall.** FLUX.1 Kontext is an **image-to-image instruction editor** built for exactly this job: local edits, recolor, **background replacement**, and subject preservation. Pricing is **flat per image, resolution-independent**:

- **FLUX.1 Kontext [pro]** = 4 credits = **$0.04/image** → **$4.00 / 100 ≈ 105,280 ₫** (confirmed; 1 credit = $0.01).
- **FLUX.1 Kontext [max]** = 8 credits = **$0.08/image** → $8.00 / 100 ≈ 210,560 ₫ (higher fidelity).
- **FLUX.2 [pro] edit** is megapixel-based ("from $0.045"): $0.03 first output MP + $0.015/extra MP, input ~$0.015/extra MP → **~$0.045–0.06 at 1080p** (~$4.50–6.00 / 100).

True 1920×1080 is achievable with **no per-MP penalty** on Kontext (the flat price holds at any resolution). Callable via the **BFL API** or via **fal.ai** at the same price. **Best price-to-quality fit for the use case.**

```bash
# BFL API — FLUX.1 Kontext [pro] edit
curl -X POST https://api.bfl.ai/v1/flux-kontext-pro \
  -H "x-key: $BFL_API_KEY" -H "Content-Type: application/json" \
  -d '{"prompt":"Recolor the flower red, replace background with solid black, keep the character and yoga rope. Wallpaper style.","input_image":"<base64 of input_1080p.png>"}'
# returns a polling id; GET /v1/get_result?id=... for the edited image URL
```

### #2 — fal.ai (Qwen-Image-Edit 2511) — best aggregator, highest native resolution

fal.ai is an **aggregator** that hosts the same top editors (FLUX.1 Kontext pro/max at the same BFL prices, FLUX.2) **plus Qwen-Image-Edit 2511** — an instruction editor with **native resolution up to 2560×2560** (true 1080p, no upscale) on the **Apache-2.0** Qwen model (commercial-friendly). Pay-per-use, no subscription.

- **Qwen-Image-Edit 2511:** **$0.03 per *output* megapixel** (rounded up, output-only billing). fal's own example: a 1920×1080 image = **$0.045** → **$4.50 / 100 ≈ 118,440 ₫**. (The LoRA/multi-angle variant is $0.035/MP.)
- **Best choice when you want true native 1080p+ output at low cost** without a separate upscale step.

### #3 — Stability AI (Stable Image / SD3.5) — dedicated edit primitives

Stability exposes **dedicated REST edit endpoints** that map cleanly onto the "isolate character + black background" task: **Remove Background**, **Search-and-Replace**, **Inpaint**, **Erase** — each **5 credits = $0.05** (1 credit = $0.01) → **$5.00 / 100 ≈ 131,600 ₫**. Edit endpoints **return at the input resolution**, so a 1920×1080 input yields **native 1080p output**. Strongest when the task is a clean primitive (remove/replace background) rather than free-form prompt editing; quality on nuanced photoreal instruction-following trails FLUX/Gemini.

> **Honorable mentions.** **Replicate** hosts the same FLUX Kontext / Qwen editors (functionally interchangeable with fal) but bills **per-second/per-run**, so the exact per-image cost is **less predictable** (~$0.003–0.04/image, **uncertain**) — prefer fal for a flat price on the same models. **Recraft** ($0.04/image, design/vector-strong, verify true-1080p res) and **Ideogram** (literal **Replace-Background** op; **official** tiers Turbo $0.03 / Default $0.06 / Quality $0.09, ~1 MP-class) are viable cheaper/lower-fidelity options. **Adobe Firefly Services** is credit-based (~$0.02–0.10/image) but gated behind a **~$1,000/month enterprise minimum**. **Midjourney** has **no usable official public API** — excluded.

---

## 5. Are they equivalent in result? (Quality — clearly tiered, not equal)

**No — quality is clearly tiered, not equivalent.** Roughly comparable *within* a tier; visibly better at the top end for nuanced, subject-preserving wallpaper edits.

- **Tier 1 — top instruction-edit fidelity:** **FLUX.1 Kontext [pro]/[max]** and **Gemini 3 Pro Image**. Best at *preserving named elements*, clean recolor, and photoreal background replacement — i.e. the exact "isolate character + plain-black wallpaper" task.
- **Tier 2 — strong frontier mid-tier:** **Gemini 2.5 Flash Image**, **OpenAI gpt-image-2**, **Qwen-Image-Edit 2511** (Qwen adds the **highest native resolution** of the lot). **xAI Grok** sits here too — solidly edit-capable, mid fidelity.
- **Tier 3 — reliable but lower photoreal fidelity / primitive-driven:** **Stability AI** (excellent for clean background remove/replace, weaker free-form prompt edits), **Ideogram** (dedicated Replace-Background, mid fidelity), **Recraft** (design/vector-strong, weaker photoreal).

For a one-off showcase wallpaper, a Tier-1 editor is worth the modest premium; for bulk/disposable edits, a Tier-2/3 option at a few cents each is plenty.

---

## 6. Can an API cover your use case? (Verdict)

**Yes — comfortably, and cheaply.** Every provider here accepts **prompt + input image → edited image**; none is text-to-image only (Grok included). For your specific *"prompt + 1080p input → edited 1080p plain-black wallpaper"*:

- **Best overall:** **FLUX.1 Kontext [pro]** — purpose-built, flat **$0.04/edit**, true 1080p, top fidelity (**≈ 105,280 ₫/100**). The recommended default.
- **Best native-1080p value:** **fal.ai Qwen-Image-Edit 2511** (native up to 2560 px, **~$0.045/edit ≈ 118,440 ₫/100**).
- **Best frontier quality:** **Gemini 3 Pro Image** (native 1K/2K, **~$0.135/edit ≈ 355,320 ₫/100**).
- **Cheapest:** Gemini 2.5 Flash batch (≈ **51,324 ₫/100**) or Ideogram Turbo (≈ **78,960 ₫/100**) — but both need an **upscale or tier-bump** for *true* native 1080p.

**Resolution caveats (need an upscale for true 1920×1080):** OpenAI gpt-image-1.5 (hard 1536 px cap), Gemini 2.5 Flash (the $0.039 tier is ≤1024 px), and ~1 MP-class Ideogram/Recraft/SD3.5 — **except** Stability's edit endpoints, which return at the input resolution, so 1080p-in yields 1080p-out. **No-upscale-needed:** FLUX.1 Kontext, Qwen-Image-Edit, Gemini 3 Pro, Stability (input-res).

---

## 7. Local vs API — the honest trade-off

| Dimension | **Local (files 01–06)** | **Cloud API (this file)** |
|---|---|---|
| **Privacy** | Image **never leaves** your Mac | Image + prompt **sent to a third party**; may be retained for abuse-monitoring |
| **Cost shape** | **One-time** hardware you already own; $0/edit thereafter | **Per-edit** forever (~51k–540k ₫ per 100, by provider/tier) |
| **Compute** | Needs your M4 Pro's GPU time (seconds–minutes/edit) | **No Mac compute** — runs on their servers, your machine just makes a request |
| **Quality ceiling** | FLUX.1 Kontext [dev] / Qwen-Image-Edit local; strong, but you manage the pipeline | Same or higher (Kontext [pro/max], Gemini 3 Pro) with zero setup |
| **Speed** | Bound by ~273 GB/s memory bandwidth; minutes for heavy edits | Often faster (data-center GPUs), minus network latency |
| **Commercial use** | Watch model licenses (FLUX [dev] non-commercial weights; Qwen Apache-2.0) | Paid-API outputs generally commercial-OK — confirm each provider's terms |

**Rule of thumb:** if the source image is **private/sensitive** or you'll run **thousands** of edits, the **local** pipeline in [`./06-annex-image-editing.md`](./06-annex-image-editing.md) wins (privacy + amortized $0/edit on hardware you already paid for). If you want **top fidelity with zero setup**, **occasional volume** (100 edits is pocket change — **~50k–355k ₫** for the good options), or you don't want to spend Mac GPU time, an **API is the pragmatic choice** — and **FLUX.1 Kontext [pro]** is the best default.

> The same edit, done locally and free, is in [`./06-annex-image-editing.md`](./06-annex-image-editing.md). The local model catalog (including the Kontext/Qwen editors these APIs also host) is in [`./02-sota-local-models.md`](./02-sota-local-models.md); customization/LoRA (local **and** cloud training) is in [`./04-customization-and-lora.md`](./04-customization-and-lora.md).

---

## 8. Caveats (read before budgeting)

- **Prices drift — re-check the cited pages.** All figures are mid-2026 snapshots. **Re-verify** before committing: BFL `docs.bfl.ai/quick_start/pricing`, fal `fal.ai/pricing`, Stability `platform.stability.ai/pricing`, Gemini `ai.google.dev/gemini-api/docs/pricing`, OpenAI `developers.openai.com/api/docs/pricing`, xAI `docs.x.ai`, Ideogram `ideogram.ai/api-pricing`.
- **Uncertain figures, stated as such:** OpenAI has **no official flat per-image price** (~$20.50/100 is a calculator estimate, and edits add input-image tokens so true per-*edit* > per-generation); Replicate's per-second/per-run billing makes its per-image cost **unpinned** (~7,896–105,280 ₫/100 range).
- **Confirmed billing nuances:** Grok edits bill **input + output** image (≈ +20%, not ×2); Qwen-Image-Edit bills **output MP only**; Gemini's $0.039 is **≤1024 px output** only; FLUX Kontext is **flat/resolution-independent**.
- **FX:** 1 USD = 26,320 ₫ (2026-06-23). A swing in the rate moves every VND figure proportionally.
- **Keep it SFW**, and for copyrighted game/anime characters keep edited wallpapers to **personal use** — the source image's IP still belongs to its owner, regardless of which API touched the pixels.
