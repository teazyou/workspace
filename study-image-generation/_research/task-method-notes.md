# Task-Method — Raw Research Notes

Dimension: the actual rule = isolate character(s) + composite onto solid black. This is SEGMENTATION / IMAGE MATTING + COMPOSITING, not generative diffusion.

## Core distinction (segment vs generate)
- Rule "everything not the character becomes black" = produce an alpha mask of the foreground/character, then flatten over black. Deterministic, fast, faithful (keeps original pixels of the character).
- A text-to-image diffusion model would REPAINT/HALLUCINATE the character — changes pixels, slower (seconds-minutes/image), unnecessary. Only relevant if user wants to synthesize/repaint content (covered in §03/§05).
- Generative inpainting / diffusion matting (e.g. SDMatte) exists but is overkill here: heavier, slower, no quality win for "subject on black."

## Background-removal / dichotomous segmentation models

### BiRefNet (ZhengPeng7) — MIT
- "Bilateral Reference for High-Resolution Dichotomous Image Segmentation" CAAI AIR'24. https://github.com/ZhengPeng7/BiRefNet
- MIT license (trained on DIS5K, MIT). Truly open incl. commercial.
- Feb 2025: BiRefNet_HR (trained at 2048x2048) and BiRefNet_HR-matting released — strong matting at high res. https://huggingface.co/ZhengPeng7/BiRefNet_HR , https://huggingface.co/ZhengPeng7/BiRefNet-matting
- Excellent fine detail (hair). PyTorch -> runs on MPS. ~1024 default res; HR at 2048.
- Available as `birefnet-general`, `birefnet-general-lite`, `birefnet-portrait`, dis/hrsod/cod/massive variants inside rembg.

### BRIA RMBG-2.0 — CC BY-NC 4.0 (NON-COMMERCIAL)
- Built ON BiRefNet architecture + proprietary 15k+ manually-labeled dataset. https://huggingface.co/briaai/RMBG-2.0
- BRIA benchmark (blind student voting, Jun 2025): RMBG 2.0 90% vs BiRefNet 85% vs Photoshop 46%. (vendor benchmark — take with salt) https://blog.bria.ai/benchmarking-blog/brias-new-state-of-the-art-remove-background-2.0-outperforms-the-competition
- LICENSE: CC BY-NC 4.0 — non-commercial only; commercial needs paid BRIA agreement. This is the big catch.
- Processes at 1024x1024.
- CoreML conversion exists for Apple Silicon (ANE, INT8, 233MB). https://huggingface.co/VincentGOURBIN/RMBG-2-CoreML
- Available in rembg as `bria-rmbg`.

### InSPyReNet (transparent-background, plemeri) — MIT
- ACCV 2022. https://github.com/plemeri/transparent-background , https://pypi.org/project/transparent-background/
- PyTorch stack (heavier than ONNX). pip `transparent-background`. Has `--fast` mode (lower res, faster) and base (higher quality).
- Repeatedly rated top-tier on complex scenes / fine hair in community comparisons (vs BRIA/U2Net/IsNet/SAM). Anecdotal but consistent.
- CLI batch over folder; outputs rgba/map/green etc.
- PyTorch -> MPS on Apple Silicon.

### rembg (danielgatis) — MIT  ← the batch workhorse
- https://github.com/danielgatis/rembg , https://pypi.org/project/rembg/
- ONNX Runtime based. MIT.
- Folder batch: `rembg p input_dir output_dir -m <model>`. Watch mode `-w`.
- Alpha matting post-process: `-a` (plus `-ae` erode etc.) — pymatting-based edge refinement.
- Model zoo (downloaded to ~/.u2net/): u2net, u2netp (lite), silueta, u2net_human_seg, u2net_cloth_seg, isnet-general-use, **isnet-anime**, birefnet-general, birefnet-general-lite, birefnet-portrait, birefnet-{dis,hrsod,cod,massive}, **bria-rmbg**, **sam**.
- GPU: documents CUDA (`rembg[gpu]`) and ROCm. NO explicit Apple Silicon acceleration path documented — onnxruntime CoreML EP exists but rembg doesn't wire it by default; CPU works everywhere (~10s/image on CPU per community report).
- isnet-anime = SkyTNT anime model packaged into rembg → one-line anime support.

### backgroundremover — MIT
- CLI tool, u2net-based, older. Folder/video support. Largely superseded by rembg for stills. (general knowledge; lower priority)

## Anime / illustration specific

### SkyTNT anime-segmentation — Apache-2.0
- https://github.com/SkyTNT/anime-segmentation , https://huggingface.co/skytnt/anime-seg
- Trained on AniSeg + character_bg_seg_data, cleaned via DeepDanbooru then manual; "all mask is anime character."
- Supports ISNet, U2Net, MODNet, InSPyReNet archs; ISNet recommended @1024.
- `--only-matted` outputs alpha matte. HF Space demo + ComfyUI nodes.
- This model = the `isnet-anime` weights you get via rembg. So rembg gives you it for free.
- Multi-character: not specifically addressed; trained to mask "anime character" as a class so multiple chars on one bg typically all kept (it's foreground-vs-bg, not instance).

### isnet-anime (in rembg) — best zero-effort anime path.

## Promptable / general segmentation

### SAM / SAM 2 / SAM 3 (Meta)
- SAM: interactive (point/box prompts) OR automatic "everything" mode (grid of points -> ~100 masks/image). Not a clean single foreground mask by default.
- SAM 2: adds video/tracking, faster.
- SAM 3 (2025): Promptable Concept Segmentation — TEXT noun-phrase prompt ("person", "character") returns masks+IDs for every matching instance. https://blog.roboflow.com/what-is-sam3/ , https://studio.aifilms.ai/blog/meta-sam3-text-segmentation-tracking
- License: SAM/SAM2 Apache-2.0; SAM3 check Meta license at use time.
- For OUR rule: SAM is interactive-first (needs a click) → not batch-friendly out of the box. SAM3 text-prompt "character/person" could auto-select subjects across a folder and handle MULTIPLE/AMBIGUOUS subjects better, but heavier and edges are segmentation-grade (harder masks), worse fine-hair matte than BiRefNet/InSPyReNet. Use as fallback for "which thing is the character" disambiguation, not as the primary matte producer.
- 1038lab/ComfyUI-RMBG bundles RMBG-2.0, INSPYRENET, BEN/BEN2, BiRefNet, SDMatte, SAM/SAM2/SAM3, GroundingDINO — confirms current SOTA cluster.

## Apple Silicon reality
- ONNX (rembg): CPU path universal & reliable; CoreML EP possible but not default. CPU ~ several sec/image — fine for batch overnight.
- PyTorch (BiRefNet, InSPyReNet, anime-seg): MPS backend works (PyTorch >=1.12, macOS 12.3+). 48GB unified = plenty of headroom; these models are small (hundreds of MB), so even M4 (non-Pro) is fine. Chip variant (M4/Pro/Max GPU cores, bandwidth) only changes speed, not feasibility — Pro/Max just faster per image.
- Known issue: some report BiRefNet 1024 hanging on MPS in ComfyUI-RMBG (Issue #200). Mitigation: CPU fallback or CoreML build. Flag honestly.
- CoreML RMBG-2.0 build (ANE) is the fastest Apple-native path but RMBG license is NC.

## Compositing onto black
- Model outputs RGBA (or separate alpha mask A in [0,1]).
- Flatten: out_rgb = fg_rgb * alpha  (black = 0, so out = fg*alpha + 0*(1-alpha)). Semi-transparent edges blend toward black naturally.
- Equivalent: paste RGBA onto a black RGB canvas. PIL: `Image.new("RGB", size, (0,0,0)); bg.paste(rgba, mask=rgba.split()[-1])`. Save as opaque PNG/JPG (wallpaper).
- No alpha needed in final wallpaper → black is the "transparent" stand-in.

## Failure cases
- Multiple characters: foreground/bg models keep ALL foreground (good if all are "characters"; bad if one non-character object is salient → kept). SAM3 text prompt mitigates.
- Semi-transparent FX (auras, glass, glow): matte models give partial alpha → blends to black; can look dim/clipped. BiRefNet-matting / InSPyReNet handle soft alpha best.
- Ambiguous "is this a character?": pure saliency models guess the salient subject; a prop/animal/vehicle may be kept or dropped. No model knows "character" semantics except anime-class (isnet-anime) and text-prompt (SAM3).
- Anime with white/flat bg + white character parts → fine for isnet-anime (trained on it); photoreal models can struggle.

## Sources (full)
- https://github.com/ZhengPeng7/BiRefNet
- https://huggingface.co/ZhengPeng7/BiRefNet_HR
- https://huggingface.co/ZhengPeng7/BiRefNet-matting
- https://huggingface.co/briaai/RMBG-2.0
- https://blog.bria.ai/benchmarking-blog/brias-new-state-of-the-art-remove-background-2.0-outperforms-the-competition
- https://huggingface.co/VincentGOURBIN/RMBG-2-CoreML
- https://github.com/danielgatis/rembg
- https://pypi.org/project/rembg/
- https://github.com/plemeri/transparent-background
- https://pypi.org/project/transparent-background/
- https://github.com/SkyTNT/anime-segmentation
- https://huggingface.co/skytnt/anime-seg
- https://blog.roboflow.com/what-is-sam3/
- https://studio.aifilms.ai/blog/meta-sam3-text-segmentation-tracking
- https://github.com/1038lab/ComfyUI-RMBG
- https://github.com/1038lab/ComfyUI-RMBG/issues/200
- https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html
- https://developer.apple.com/metal/pytorch/
