# 04 — The Recommended Pipeline & One-Command Batch Install Guide

**Bottom line up front.** Your rule — *isolate the character(s), make everything else black* — is a **segmentation/matting + composite** job, not a generative one (see Section 02 for the method, Section 03 for the generative catalog). The fastest, most reliable, fully-local path on your M4 (Pro) / 48 GB Mac is **`rembg` (a CLI background remover that already supports SOTA BiRefNet and anime models) plus a ~15-line Pillow wrapper that composites each cutout onto solid black**. You install it once with `uv`, point it at a folder, and it writes one black-background image per input. A higher-quality power option (**BiRefNet via PyTorch on the Metal GPU**) and a **generative variant (ComfyUI)** are documented at the end. You do **not** need a diffusion model for this task.

---

## 1. Which path to use

| Path | Tool | Quality | Speed on M4 Pro | Use when |
|---|---|---|---|---|
| **A — Headline** | `rembg` CLI + Pillow composite | Very good; `isnet-anime` excels on illustrated/anime/game characters, `birefnet-general` excels on photoreal | ~0.3–3 s/img (model-dependent, CPU) | Default. One install, one command, whole folder. |
| **B — Power** | BiRefNet (PyTorch) on **MPS** (Apple GPU) | Best edges (hair, fine detail, semi-transparency) | ~1–4 s/img (GPU) | You need the cleanest possible mattes and want GPU acceleration. |
| **C — Generative** | ComfyUI (BiRefNet node + composite, optionally FLUX/SDXL) | Same matte quality + creative repaint | Slower (node graph + MPS) | You later want to *regenerate/repaint* content, not just isolate it. |

Wallpapers are frequently anime/game art — **`isnet-anime` is purpose-built for that** and is the recommended default model; switch to `birefnet-general` for photographic characters.

---

## 2. Prerequisites (macOS Apple Silicon)

```bash
# Xcode command-line tools (compilers, headers)
xcode-select --install

# Homebrew you already have. Install uv (fast, isolated Python tool/venv manager).
brew install uv
```

`uv` is preferred over system pip/conda: it creates throwaway, reproducible environments and installs CLI tools globally without polluting your shell Python. Python 3.11 or 3.12 is the sweet spot for `onnxruntime` + `torch`.

---

## 3. Install — Path A (rembg, the headline)

```bash
# Install rembg as a standalone CLI tool (isolated env), with the CLI extra.
uv tool install "rembg[cpu,cli]"

# Add Pillow into that same tool env so our composite script can import it,
# OR just run the script from a small venv (shown in §5). Simplest:
uv tool install --with pillow "rembg[cpu,cli]"
```

Notes:
- On Mac there is **no `[gpu]` extra** (`gpu` = CUDA, `rocm` = AMD). The default ships `onnxruntime` **CPU**. On an M4 Pro this is already only seconds per image for `isnet`/`u2net`. If you want Apple **Neural Engine / GPU** acceleration for the heavier BiRefNet ONNX models, swap the runtime (optional):
  ```bash
  # Optional: CoreML/ANE-accelerated onnxruntime (community wheels)
  uv pip install onnxruntime-silicon        # cansik, or:
  # uv pip install onnxruntime-coreml       # xaviviro
  ```
  rembg itself has no native MPS; if you want true GPU matting, prefer **Path B** instead.

### Model download
Models download automatically to `~/.u2net/` on first use — no manual step. To pre-fetch:
```bash
rembg i -m isnet-anime /dev/null /dev/null 2>/dev/null || true   # triggers download
```
Available models include: `isnet-anime`, `birefnet-general`, `birefnet-general-lite`, `birefnet-portrait`, `birefnet-massive`, `u2net`, `u2net_human_seg`, `isnet-general-use`, `bria-rmbg`, `sam`.

---

## 4. The one-command batch recipe (Path A) — copy/paste

`rembg p in_dir out_dir` removes backgrounds to **transparent RGBA**, but it has **no flag to fill the background with a solid colour**. So we do two trivial steps: (1) rembg → transparent cutouts, (2) Pillow → composite each cutout over black. The script below does **both** in one pass over the folder, so you truly run **one command**.

Save as `~/bin/blackbg.py`:

```python
#!/usr/bin/env python3
"""Isolate characters and composite onto solid BLACK for every image in a folder.
Usage: blackbg.py INPUT_DIR [OUTPUT_DIR] [--model isnet-anime]
"""
import sys, pathlib, argparse
from PIL import Image
from rembg import remove, new_session

EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff"}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input_dir")
    ap.add_argument("output_dir", nargs="?", default=None)
    ap.add_argument("--model", default="isnet-anime",
                    help="isnet-anime (illustration) | birefnet-general (photoreal) | u2net_human_seg")
    ap.add_argument("--format", default="png", choices=["png", "jpg"])
    args = ap.parse_args()

    in_dir = pathlib.Path(args.input_dir).expanduser().resolve()
    out_dir = pathlib.Path(args.output_dir).expanduser().resolve() if args.output_dir \
              else in_dir.parent / f"{in_dir.name}-blackbg"
    out_dir.mkdir(parents=True, exist_ok=True)

    session = new_session(args.model)   # loads + caches the model once
    files = sorted(p for p in in_dir.iterdir() if p.suffix.lower() in EXTS)
    if not files:
        sys.exit(f"No images found in {in_dir}")

    for i, src in enumerate(files, 1):
        out = out_dir / f"{src.stem}_blackbg.{args.format}"
        if out.exists():
            print(f"[{i}/{len(files)}] skip (exists) {out.name}"); continue
        orig = Image.open(src).convert("RGBA")
        cut = remove(orig, session=session)            # RGBA, bg transparent
        black = Image.new("RGBA", cut.size, (0, 0, 0, 255))
        black.alpha_composite(cut)                     # character over black
        if args.format == "jpg":
            black.convert("RGB").save(out, quality=95)
        else:
            black.save(out)
        print(f"[{i}/{len(files)}] {src.name} -> {out.name}")

    print(f"Done. {len(files)} images -> {out_dir}")

if __name__ == "__main__":
    main()
```

Make it runnable inside the rembg tool env and invoke on a folder:

```bash
chmod +x ~/bin/blackbg.py

# ONE COMMAND over a whole folder (default model = isnet-anime, output -> <folder>-blackbg/):
uv tool run --from "rembg[cpu]" --with pillow python ~/bin/blackbg.py ~/wallpapers

# Photographic characters / highest detail:
uv tool run --from "rembg[cpu]" --with pillow python ~/bin/blackbg.py ~/wallpapers --model birefnet-general

# Explicit output dir + JPG:
uv tool run --from "rembg[cpu]" --with pillow python ~/bin/blackbg.py ~/wallpapers ~/out --format jpg
```

Wrap it in a shell alias (fits your `zsh/alias/` convention) so it's literally one word:

```bash
# zsh/alias/images.zsh
blackbg() { uv tool run --from "rembg[cpu]" --with pillow python ~/bin/blackbg.py "$@"; }
```
Then: `blackbg ~/wallpapers`.

> Why a script and not pure `rembg p`? Because `rembg p` only outputs transparent PNGs; the black fill needs one compositing step. Doing both in the loop keeps it a single command, lets you batch in any image format, gives deterministic `_blackbg` naming, and skips already-done files (idempotent re-runs — matching how your `wallpapers_treatment.sh` already behaves).

---

## 5. Path B (power) — BiRefNet on the Apple GPU (MPS)

Use this when you want the absolute cleanest mattes (hair, fringe, glass). It runs BiRefNet in **PyTorch on Metal**, addressing the unified memory directly (the model uses ~3–4 GB at 1024²; trivial on 48 GB).

```bash
mkdir -p ~/birefnet && cd ~/birefnet
uv venv && source .venv/bin/activate
uv pip install torch torchvision transformers pillow timm einops kornia
```

`~/birefnet/blackbg_mps.py`:

```python
#!/usr/bin/env python3
import sys, os, pathlib
os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")  # cover any unimplemented MPS op
import torch
from torchvision import transforms
from transformers import AutoModelForImageSegmentation
from PIL import Image

DEV = "mps" if torch.backends.mps.is_available() else "cpu"
in_dir = pathlib.Path(sys.argv[1]).expanduser().resolve()
out_dir = (pathlib.Path(sys.argv[2]).expanduser().resolve()
           if len(sys.argv) > 2 else in_dir.parent / f"{in_dir.name}-blackbg")
out_dir.mkdir(parents=True, exist_ok=True)

# ZhengPeng7/BiRefNet = permissive; briaai/RMBG-2.0 is non-commercial (see note).
model = AutoModelForImageSegmentation.from_pretrained("ZhengPeng7/BiRefNet", trust_remote_code=True)
model.to(DEV).eval()
torch.set_float32_matmul_precision("high")

tf = transforms.Compose([
    transforms.Resize((1024, 1024)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
])
EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
for src in sorted(p for p in in_dir.iterdir() if p.suffix.lower() in EXTS):
    img = Image.open(src).convert("RGB")
    x = tf(img).unsqueeze(0).to(DEV)
    with torch.no_grad():
        mask = model(x)[-1].sigmoid().cpu()[0].squeeze()
    alpha = transforms.ToPILImage()(mask).resize(img.size)
    rgba = img.convert("RGBA"); rgba.putalpha(alpha)
    black = Image.new("RGBA", rgba.size, (0, 0, 0, 255))
    black.alpha_composite(rgba)
    out = out_dir / f"{src.stem}_blackbg.png"
    black.convert("RGB").save(out)
    print(f"{src.name} -> {out.name}  [{DEV}]")
print(f"Done -> {out_dir}")
```

```bash
python ~/birefnet/blackbg_mps.py ~/wallpapers
```

**License flag:** `briaai/RMBG-2.0` (same architecture, slightly different weights) is **non-commercial / Bria license**. Use `ZhengPeng7/BiRefNet` (permissive) for unrestricted use. (Detail in Section 02.)

---

## 6. Path C (generative variant) — ComfyUI, only if you want creative regeneration

For your literal rule you do **not** need this. Use it only if you later want to *repaint/synthesize* (e.g. relight the character, generate a new pose) on top of isolation.

```bash
uv tool install comfy-cli
comfy --skip-prompt install --m-series      # Apple-Silicon (MPS) install, ~/Documents/comfy/ComfyUI
comfy launch -- --listen                     # starts a REST + WebSocket API server
```

- Install a BiRefNet/RMBG node (via ComfyUI-Manager, e.g. `ComfyUI_BiRefNet_ll` → `RembgByBiRefNet`) for the matte, plus a "composite over colour" node for the black fill.
- Folder batching: a **Load Image Batch** node (WAS Node Suite / `Zar4X/ComfyUI-Batch-Process`) reads a directory by index + glob pattern; queue the workflow N times, or POST the workflow JSON to `/prompt` from a script.
- For actual generation, add FLUX/SDXL (see Section 03; **mflux** and **Draw Things** are the Apple-native generative engines).

ComfyUI is heavyweight for a fixed rule and runs slower on MPS than CUDA — that's why Path A is the headline.

---

## 7. Verification, naming, troubleshooting

**Verify a run:**
```bash
ls ~/wallpapers-blackbg | head                 # one *_blackbg.png per input
# Spot-check: open a few; background must be pure (0,0,0). Sample a corner pixel:
uv tool run --with pillow python - <<'PY'
from PIL import Image; im=Image.open(__import__("glob").glob("/Users/*/wallpapers-blackbg/*")[0]).convert("RGB")
print("corner pixel:", im.getpixel((0,0)))   # expect (0, 0, 0)
PY
```

**Output naming:** `<originalname>_blackbg.png` in a sibling `<folder>-blackbg/` (or your explicit `OUTPUT_DIR`). Re-runs skip existing files — safe to re-invoke.

**Troubleshooting:**

| Symptom | Fix |
|---|---|
| First run hangs "downloading" | Model is fetching to `~/.u2net/` (rembg) or `~/.cache/huggingface` (BiRefNet). Let it finish once; cached after. |
| Halos / grey fringe around character | Use a better model (`birefnet-general` for photos, `isnet-anime` for art); or Path B BiRefNet; rembg `-a` alpha-matting flag also helps. |
| Background not fully black | The cutout had partial alpha at edges — `alpha_composite` over opaque black handles it; if a JPG source baked artifacts, re-export as PNG. |
| `MPS ... not implemented` error (Path B) | We set `PYTORCH_ENABLE_MPS_FALLBACK=1`; the op silently falls back to CPU. Keep the env var. |
| Slow on BiRefNet ONNX (Path A) | Switch to `isnet-anime`/`u2net` (much faster) or install `onnxruntime-silicon` for CoreML/ANE, or move to Path B (true Metal GPU). |
| `uv tool run` can't import Pillow | Add `--with pillow` (shown above) or install the tool with `--with pillow`. |
| Out of memory (Path B) | Won't happen at 1024² on 48 GB. If you raise resolution drastically, lower it back to 1024. |

**Hardware note (M4 variants):** This task is light. Even a base M4 handles it; the **M4 Pro / Max** (more GPU cores, higher memory bandwidth) only matters for Path B at scale and for the optional generative Path C — the 48 GB unified memory comfortably holds any of these models plus their working set.

---

## Sources

- rembg (CLI, models, batch): https://github.com/danielgatis/rembg • https://pypi.org/project/rembg/
- BiRefNet vs rembg vs U2Net comparison: https://dev.to/om_prakash_3311f8a4576605/birefnet-vs-rembg-vs-u2net-which-background-removal-model-actually-works-in-production-4830
- BiRefNet repo + checkpoints: https://github.com/zhengpeng7/birefnet
- RMBG-2.0 model card (transformers usage, alpha matte, license): https://huggingface.co/briaai/RMBG-2.0
- onnxruntime CoreML EP: https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html
- onnxruntime-silicon / coreml wheels: https://github.com/cansik/onnxruntime-silicon • https://github.com/xaviviro/onnxruntime-coreml • https://gist.github.com/fathonix/3b9bda262226ac8842338d65ae505673
- rembg Apple-Silicon/MPS request: https://github.com/danielgatis/rembg/issues/556
- diffusers MPS docs (PYTORCH_ENABLE_MPS_FALLBACK): https://huggingface.co/docs/diffusers/en/optimization/mps
- comfy-cli + macOS install: https://github.com/Comfy-Org/comfy-cli • https://docs.comfy.org/installation/desktop/macos
- ComfyUI batch processing: https://www.apatero.com/blog/batch-process-1000-images-comfyui-guide-2025 • https://github.com/Zar4X/ComfyUI-Batch-Process
- Draw Things CLI / scripting: https://releases.drawthings.ai/p/draw-things-cli-local-media-generation • https://wiki.drawthings.ai/wiki/Scripting_Basics
- mflux (Apple-native FLUX, generative variant): https://github.com/filipstrand/mflux
