# Obsidian real (blur-free) window transparency — macOS

How Obsidian is made see-through to the **desktop wallpaper, crisply (no frosted
blur)**, with an adjustable amount — the Obsidian equivalent of the VS Code
"Vibrancy Continued" `type:"transparent"` setup (see `docs/vscode/transparency.md`).

> **Read this before touching the transparency stack.** It spans a patched system
> app (`/Applications/Obsidian.app`, outside the repo/symlink model) **and** two
> repo files. Both must be in place or the effect breaks.

## Why the built-in setting is not used

Obsidian's Settings → Appearance → **Translucent window** uses the macOS **vibrancy
material**, which adds a strong frosted **blur** — not what we want — and on
**macOS 26 (Tahoe) it is broken**: it renders flat opaque grey with no blur at all
(Obsidian-staff-acknowledged, reproduces on this exact Electron 39 build). So
vibrancy is doubly out. We use **true Electron window transparency** instead.

## The mechanism (two required halves)

Real transparency needs BOTH of these; neither alone is enough:

1. **The asar patch** — unlocks the window backing.
   Obsidian already builds its main vault window with `backgroundColor:"#00000000"`
   but **without** Electron's `transparent:true`, so that transparent colour is
   painted onto an **opaque backing** → the desktop never shows. `transparent:true`
   is a **BrowserWindow *constructor-only* option** — it cannot be set at runtime by
   a plugin/CSS, which is why no Obsidian plugin can do this. The patch injects
   `transparent:!0` into that options object inside `obsidian.asar/main.js`.
   - This is exactly what VS Code Vibrancy Continued does to VS Code's main process.
   - `frame` is already the default **hidden** (frameless), which `transparent:true`
     requires on macOS — so no frame change is needed. Do **not** switch Settings →
     Appearance → Window frame to "native" (that sets `frame:true` and breaks it).

2. **The CSS snippet** — the visible, adjustable amount.
   `configs/dot-obsidian/snippets/transparency.css` strips the opaque backgrounds off
   the window-chain elements and paints **one** tint layer per pane whose alpha is the
   knob. **Text is left opaque** so it stays readable (this is why we don't use the
   `setOpacity` plugins — those fade the whole window, text included).

### The two repo files
- `configs/dot-obsidian/snippets/transparency.css` — the snippet. The knob is
  `--wallpaper-alpha` at the top: `0` = fully see-through, `1` = opaque. Default
  `0.35` ≈ 65% wallpaper. Shared/symlinked → applies to **all vaults**.
- `configs/dot-obsidian/appearance.json` — has `"transparency"` in
  `enabledCssSnippets` (also shared). **No `translucency` key** — we are *not* using
  vibrancy.

## Applying / re-applying — `scripts/obsidian/patch-transparency.sh`

```bash
scripts/obsidian/patch-transparency.sh            # apply (idempotent)
scripts/obsidian/patch-transparency.sh --restore  # revert to stock asar
```

The script quits Obsidian, backs up the stock asar once
(`obsidian.asar.orig-transparency-bak`), injects `transparent:!0`, repacks, and
**re-signs the app ad-hoc** (`codesign --force --deep --sign -` + `xattr -cr`) so the
modified bundle launches under the hardened runtime.

### Why re-apply after every Obsidian update
`obsidian.asar` is **replaced by each Obsidian update**, wiping the patch — the same
maintenance model as the VS Code Claude-panel patch (`docs/vscode/claude-code-panel.md`).
Just re-run the script; it's idempotent.

### Integrity / signing notes
- Only `app.asar` (the 73KB loader) is covered by `Info.plist`
  **`ElectronAsarIntegrity`**; `obsidian.asar` (the 24MB bundle we patch) is **not**,
  so there is **no integrity hash to recompute** — this is what makes the patch clean.
- The ad-hoc re-sign is what prevents a "damaged" Gatekeeper prompt.

### If the patch stops applying after an update
The script anchors on the unique string
`backgroundColor:"#00000000",trafficLightPosition:` in `main.js` and aborts if it's
not found **exactly once**. If a future Obsidian build changes that, re-derive: extract
`obsidian.asar`, find the main vault window's `new BrowserWindow({…})` options object
(the one with `nodeIntegrationInWorker` + a transparent-black `backgroundColor`), and
update `ANCHOR`/`PATCHED` in the script.

## Tuning & caveats
- **Adjust transparency:** edit `--wallpaper-alpha` in `transparency.css` (lower = more
  wallpaper). Reload snippets or relaunch to see it.
- **Frameless side effects** (inherent to macOS transparent windows): no native drop
  shadow, no double-click-title maximize, and the window goes **opaque while DevTools
  is open** — all expected, not bugs.
- **Pop-out note windows** are *not* patched (only the main window) — they stay opaque.
- Keep `translucency` OUT of `appearance.json`; mixing vibrancy back in re-introduces
  the blur/grey.
