# Local Image AI on an M4 / 48 GB Mac — Character-on-Black Wallpapers (and the SOTA Generative Stack)

> A multi-file study for a developer on macOS (M4-class, 48 GB unified memory), written 2026-06-22.
> Goal: one command that takes a **folder** of wallpaper images and, for each, **isolates the character(s) and puts everything else on solid black**.

---

## Executive verdict

**Yes — emphatically — and it is much easier and lighter than you think.** Your rule ("isolate the character, make everything else black") is fundamentally a **segmentation / image-matting + compositing** task, **not** a generative-diffusion task. You produce an alpha mask of the character with a matting model, then flatten it over black — this keeps the character's *original* pixels exactly, is deterministic, runs in **~0.2–3 s/image using ~3–4 GB**, and batches over a whole folder in minutes. On a 48 GB M4 (almost certainly an M4 Pro) this is **10×+ overkill** on the hardware; even a base M4 would breeze through it. You do **not** need — and generally should not use — a text-to-image diffusion model for this, because diffusion would *repaint and hallucinate* the character, run 10–100× slower, and give no quality benefit.

Separately: the same Mac is a **genuinely capable local image-generation box**. It comfortably runs SDXL / SD 3.5 and the new 6B-class models (Z-Image) fast, and runs FLUX-class frontier models too — speed-limited (~50–90 s/image for FLUX), never capacity-limited, with the 48 GB giving you FP16 headroom that 24 GB machines lack. That generative capability is documented here for completeness and for the LoRA annex, but it is **orthogonal to the black-background job**.

---

## TL;DR — recommended pipeline

```
Task type:   segmentation / matting + composite onto black  (NOT generative)
Installer:   uv  (brew install uv)
Tool:        rembg  (MIT) — uv tool install "rembg[cpu,cli]" --with pillow
Model:       isnet-anime   for anime/illustration/game-art wallpapers (default)
             birefnet-general  for photographic characters
Composite:   ~15-line Pillow wrapper: remove() -> alpha_composite over (0,0,0,255)
One command: blackbg ~/wallpapers     (zsh alias around the script)
Power option: BiRefNet (MIT) in PyTorch on the Metal GPU (MPS) for the cleanest hair/soft edges
```

Exact install commands and the composite script live in **[04-install-guide.md](./04-install-guide.md)** — that section owns them.

---

## How to read this study

| File | Answers |
|---|---|
| **[01-feasibility.md](./01-feasibility.md)** | Is this doable on an M4 / 48 GB Mac? Hardware + ecosystem maturity verdict, memory/speed numbers for both segmentation and generation, where the chip variant (M4 vs Pro vs Max) matters. |
| **[02-the-task-method.md](./02-the-task-method.md)** | **The actual method.** Why this is segmentation/matting not generation, the candidate models (rembg, isnet-anime, BiRefNet, InSPyReNet, SAM3), licenses, and how compositing onto black works. *Owns the method choice.* |
| **[03-sota-local-models.md](./03-sota-local-models.md)** | The SOTA **generative** model catalog for this hardware (FLUX.2, Qwen-Image, Z-Image, FLUX.1, SDXL/SD3.5), quality vs speed vs license. Read only if you also want to *generate/repaint*. |
| **[04-install-guide.md](./04-install-guide.md)** | **The concrete recommended pipeline + one-command batch install** (uv + rembg + Pillow composite script + zsh alias), plus the BiRefNet-on-MPS power path and the optional ComfyUI generative variant. *Owns install commands.* |
| **[05-annex-lora-training.md](./05-annex-lora-training.md)** | LoRA & fine-tuning on Apple Silicon: what's realistic locally (SDXL/FLUX.1), what to rent a cloud GPU for (FLUX.2/Qwen), and the honest note that **LoRA does nothing for your black-background task.** |

Raw notes and full citation lists are under [`_research/`](./_research/).

---

## Hardware assumptions

- **48 GB unified memory ⇒ almost certainly an M4 Pro** (base M4 caps at ~24–32 GB; 48 GB is an M4 Pro config; an M4 Max is also possible). The unified memory means the GPU can address most of the 48 GB.
- **For the black-background task, the variant is irrelevant** — segmentation is light and fast on any M4. Speed differences only show up in *generation*: M4 Pro ≈ 1.8–2.2× a base M4; M4 Max ≈ 3.5–4×. Where a number depends on the chip, the section flags it.
- The study assumes **M4 Pro** for planning. If it's an M4 Max, every *generation* time improves ~1.5–2.7×; *segmentation and all feasibility conclusions are unchanged.*

---

## Caveats & honest limitations

- **Use the right tool.** The single biggest trap is treating this as a "regenerate with AI" job. It is segmentation. Diffusion (FLUX/SDXL/SDMatte/inpainting) is overkill, slower, and *changes the character*. Reach for generation only to synthesize/repaint — covered in 03 and 05, not for this rule.
- **License trap — BRIA RMBG-2.0.** It is rated the best matting model by its vendor's benchmark, but it is **CC BY-NC 4.0 (non-commercial only)**. The primary path deliberately uses MIT/Apache models (rembg, isnet-anime, BiRefNet, InSPyReNet). Likewise, on the generative side FLUX.1 dev / FLUX.2 dev are non-commercial; Qwen-Image / Z-Image / SDXL are commercial-OK.
- **Apple Silicon GPU gaps.** `rembg` has **no native MPS** — its default ONNX runtime is CPU (still only seconds/image); use the BiRefNet-on-MPS PyTorch path or community CoreML/ANE onnxruntime wheels if you want true GPU matting. One BiRefNet-1024 MPS hang has been reported — fall back to CPU/CoreML if you hit it (`PYTORCH_ENABLE_MPS_FALLBACK=1`).
- **Failure cases of matting models.** Multiple characters (saliency models keep all salient objects, possibly non-characters), semi-transparent FX (partial alpha dims toward black, which is usually fine on a black background), and genuinely ambiguous "is this a character" (use isnet-anime's anime class, or SAM 3 text-prompt as a fallback to pick the subject, then matte).
- **LoRA is irrelevant to this goal.** A LoRA tunes a *generative* model's style/subject; it does nothing for mask quality. The only training that would help isolation is fine-tuning a *segmentation* model (e.g. BiRefNet on RGB→alpha pairs) — a different discipline (see 05).
- **Generation is speed-limited, not capacity-limited.** FLUX-class ≈ 50–90 s/image on M4 Pro (roughly 3–5× slower than an RTX 4090/5090) — plan generative runs as batch/overnight jobs, keep the laptop plugged in.

---

*Sections 01–05 were written by upstream agents; this README assembles and reconciles them. No contradictions were found between the method (02), the install pipeline (04), and the hardware/maturity verdict (01) — all three converge on rembg + isnet-anime/birefnet-general + Pillow composite, with BiRefNet-on-MPS as the GPU power path.*
