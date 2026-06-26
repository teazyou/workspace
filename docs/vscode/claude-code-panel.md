# Claude Code panel — webview customizations

Every visual tweak we made to the **Claude Code chat panel** (grey chat boxes, the
floating/sticky message, full-width input, compact spacing, shrunk toolbar, …), plus a
**one-command script to re-apply them all** after a Claude Code update.

> Companion to [transparency.md](transparency.md). That guide covers the
> VS Code *window* transparency (Vibrancy + `colorCustomizations` + `custom.css`). **This**
> guide covers the *Claude Code chat panel*, which is a different world — see why below.

## Why these can't live in settings.json or custom.css

The Claude Code chat is a **webview**: a sandboxed `<iframe>` served from a separate
`vscode-webview://` origin. Two hard consequences:

- **`custom.css` (Vibrancy `imports`) cannot reach it.** That CSS is injected into the VS
  Code *workbench* document; CSS never crosses an iframe boundary (and cross-origin JS
  can't either). Vibrancy's own code only ever targets `workbench.html` — never webviews.
- **`workbench.colorCustomizations` reaches it only via theme tokens.** The webview maps
  e.g. `--app-input-background → var(--vscode-input-background)`. So you *could* grey the
  chat boxes by setting `input.background` — but that also greys **every** VS Code input
  field (search, find, settings…), and it can't express the structural changes (a
  `mask-image`, `background-image:none`, paddings, `zoom`).

So the only surgical way to style the chat is to **edit the extension's own webview CSS**:

```
~/.vscode/extensions/anthropic.claude-code-<version>-<arch>/webview/index.css
```

**These edits are NOT in this repo and are LOST on every Claude Code extension update**
(the new version installs a fresh, unpatched `index.css` in a new folder). That's the
whole reason this guide exists: the script below re-applies them in one shot. A VS Code
*app* update does **not** touch them (extensions live elsewhere); only a *Claude Code
extension* update does.

`index.css` is a single minified line, so all edits are exact-string `perl` substitutions
or appended rules.

## Re-apply everything (run after a Claude Code update)

Paste this into a terminal. It auto-finds the current version, backs up, applies all
patches idempotently (re-running is safe), and verifies. Then run **Cmd+Shift+P →
"Developer: Reload Webviews"**.

```bash
#!/usr/bin/env bash
# Re-apply all Claude Code chat-panel webview customizations.
# Idempotent: value patches match the extension's ORIGINAL declarations (no-op once
# applied); appended rules are guarded against duplicates.
set -euo pipefail

CSS=$(ls -dt ~/.vscode/extensions/anthropic.claude-code-*/webview/index.css 2>/dev/null | head -1 || true)
[ -z "${CSS:-}" ] && { echo "❌ Claude Code extension index.css not found"; exit 1; }
echo "Patching: $CSS"
cp "$CSS" "$CSS.bak-$(date +%Y%m%d-%H%M%S)"

P(){ perl -i -pe "$1" "$CSS"; }                                 # in-place substitution
A(){ grep -qF "$1" "$CSS" || printf '\n%s\n' "$1" >> "$CSS"; }  # guarded append

# ── colours / surfaces ───────────────────────────────────────────────────────
# IN/OUT collapsed tool preview: clip-mask used sideBar bg (now transparent) -> opaque
P 's/\Qmask-image:linear-gradient(to bottom,var(--app-primary-background)50px,transparent 60px)\E/mask-image:linear-gradient(to bottom,#000 50px,transparent 60px)/g'
# tool (IN/OUT) box fill -> semi-opaque so it reads as a card
P 's/\Q.toolBody_ZUQaOA{border:.5px solid var(--app-input-border);background:var(--app-tool-background)\E/.toolBody_ZUQaOA{border:.5px solid var(--app-input-border);background:#1e1e1e99/g'
# input box (two layers) -> grey
P 's/\Q.inputContainerBackground_cKsPxg{background:var(--app-input-background)\E/.inputContainerBackground_cKsPxg{background:#2b2b2b/g'
P 's/\Q.inputContainer_cKsPxg{background:var(--app-input-secondary-background)\E/.inputContainer_cKsPxg{background:#2b2b2b/g'
# user message bubble -> grey
P 's/\Q.userMessage_07S1Yg{white-space:pre-wrap;word-break:break-word;border:1px solid var(--app-input-border);border-radius:var(--corner-radius-medium);background-color:var(--app-input-background)\E/.userMessage_07S1Yg{white-space:pre-wrap;word-break:break-word;border:1px solid var(--app-input-border);border-radius:var(--corner-radius-medium);background-color:#2b2b2b/g'
# "show more" truncation fade -> grey (match the bubble instead of a dark band)
P 's/\Q.truncationGradient_xGDvVg{position:absolute;background:linear-gradient(to bottom,transparent 0%,var(--app-input-background)100%)\E/.truncationGradient_xGDvVg{position:absolute;background:linear-gradient(to bottom,transparent 0%,#2b2b2b 100%)/g'
# sticky (floating, pinned) message header: drop the dark gradient backdrop...
P 's/\Qbackground-image:linear-gradient(to bottom,var(--sticky-bg)calc(100% - 12px),transparent 100%),linear-gradient(to bottom,var(--app-secondary-background)calc(100% - 12px),transparent 100%)\E/background-image:none/g'
# ...and remove its top spacing (14px -> 0)
P 's/\Qalign-items:stretch;padding-top:14px;padding-bottom:12px;top:0\E/align-items:stretch;padding-top:0;padding-bottom:12px;top:0/g'

# ── input box geometry ───────────────────────────────────────────────────────
# flush to bottom, 10px side gaps (was bottom:16 left:16 right:16)
P 's/\Qflex-direction:column;bottom:16px;left:16px;right:16px\E/flex-direction:column;bottom:0;left:10px;right:10px/g'
# full panel width: lift the 680px centered cap
P 's/\Q.inputWrapper_cKsPxg{width:100%;max-width:680px;margin:0 auto}\E/.inputWrapper_cKsPxg{width:100%;max-width:none;margin:0}/g'
# halve padding around the typing area (10/36/10/14 -> 5/18/5/7), keep mirror aligned
P 's/\Qpadding:10px 36px 10px 14px\E/padding:5px 18px 5px 7px/g'
P 's/\Q.mentionMirror_cKsPxg{padding-right:64px}\E/.mentionMirror_cKsPxg{padding-right:32px}/g'

# ── conversation width (more text per line) ──────────────────────────────────
# halve the side padding 20px -> 10px, in both normal and sticky layouts
P 's/\Qmin-width:0;padding:20px 20px 40px\E/min-width:0;padding:20px 10px 40px/g'
P 's/\Q.stickyMode_07S1Yg{isolation:isolate;padding:0 20px 40px}\E/.stickyMode_07S1Yg{isolation:isolate;padding:0 10px 40px}/g'

# ── appended rules: floating box compaction + toolbar shrink ─────────────────
A '.stickyHeader_07S1Yg .userMessage_07S1Yg{font-size:11px}'
A '.stickyHeader_07S1Yg .pill_lcdCYQ{background:none!important;border:none!important;border-radius:0!important;padding:0!important;height:auto!important;max-width:none!important}'
A '.stickyHeader_07S1Yg .label_lcdCYQ{color:#777!important;font-size:10px!important}'
A '.stickyHeader_07S1Yg .meta_lcdCYQ{font-size:10px!important}'
A '.stickyHeader_07S1Yg .userMessageAttachments_07S1Yg{padding-bottom:3px!important}'
# floating message spans full panel width (match the input box) instead of hugging its text
A '.stickyHeader_07S1Yg .userMessageContainer_07S1Yg,.stickyHeader_07S1Yg .userMessage_07S1Yg{display:block!important;width:auto!important;max-width:none!important}'
# conversation body text +3px (base is 13px); input text unaffected (separate element)
A '.messagesContainer_07S1Yg{font-size:16px}'
# your own message bubbles in the conversation a touch larger (the more-specific sticky
# rule above keeps the floating copy at 11px)
A '.userMessage_07S1Yg{font-size:18px}'
# typed input text +2px (base 13px); both layers so caret + highlight stay aligned
A '.messageInput_cKsPxg,.mentionMirror_cKsPxg{font-size:15px}'
A '.inputFooter_gGYT1w{zoom:.6}'

# ── verify (each line should say OK; MISSING => that element changed in a new version) ─
echo; echo "Verification:"
while IFS= read -r m; do
  grep -qF "$m" "$CSS" && echo "  OK      ${m:0:46}" || echo "  MISSING ${m:0:46}"
done <<'MARKERS'
mask-image:linear-gradient(to bottom,#000 50px
.toolBody_ZUQaOA{border:.5px solid var(--app-input-border);background:#1e1e1e99
.inputContainerBackground_cKsPxg{background:#2b2b2b
.inputContainer_cKsPxg{background:#2b2b2b
border-radius:var(--corner-radius-medium);background-color:#2b2b2b
transparent 0%,#2b2b2b 100%
background-image:none;align-items:stretch;padding-top:0
flex-direction:column;bottom:0;left:10px;right:10px
.inputWrapper_cKsPxg{width:100%;max-width:none
padding:5px 18px 5px 7px
.mentionMirror_cKsPxg{padding-right:32px}
min-width:0;padding:20px 10px 40px
.stickyMode_07S1Yg{isolation:isolate;padding:0 10px 40px}
.stickyHeader_07S1Yg .userMessage_07S1Yg{font-size:11px}
display:block!important;width:auto!important;max-width:none!important
.messagesContainer_07S1Yg{font-size:16px}
.userMessage_07S1Yg{font-size:18px}
.messageInput_cKsPxg,.mentionMirror_cKsPxg{font-size:15px}
.inputFooter_gGYT1w{zoom:.6}
MARKERS
echo; echo 'Done. Now: Cmd+Shift+P -> "Developer: Reload Webviews"'
```

If a line says **MISSING** after a Claude Code update, that element's original markup
changed in the new version; open `index.css`, find the new equivalent (search the nearby
class name), and update that one `perl` pattern.

## What each change does (reference)

CSS vars referenced: `--app-primary-background`=`sideBar.background` (we set transparent),
`--app-input-background`=`input.background`, `--app-secondary-background`=`editor.background`,
`--app-tool-background`=`editor.background`. The greys are hard-coded (`#2b2b2b`, `#1e1e1e99`,
`#777`) so they're independent of the transparent theme tokens.

### Colours / surfaces
| Element | Change | Why |
|---|---|---|
| `.toolBodyRowContent…` (IN/OUT preview) | `mask-image` gradient color `var(--app-primary-background)` → `#000` | `sideBar.background` is transparent (`#…00`); a transparent mask hid the whole tool preview. Mask only needs alpha, so any opaque colour fixes it. |
| `.toolBody_ZUQaOA` | `background` `var(--app-tool-background)` → `#1e1e1e99` (~60%) | Make the IN/OUT tool box read as a distinct card. |
| `.inputContainerBackground_cKsPxg` + `.inputContainer_cKsPxg` | `background` → `#2b2b2b` | Grey, opaque input box (no scroll bleed-through). Both layers set. |
| `.userMessage_07S1Yg` | `background-color` → `#2b2b2b` | Your sent-message bubbles match the input box. |
| `.truncationGradient_xGDvVg` | fade target `var(--app-input-background)` → `#2b2b2b` | The "show more" fade on long messages blends into the grey bubble instead of a dark band. |
| `.stickyHeader_07S1Yg` | `background-image` → `none` | The pinned/floating message had a dark (then grey) full-width band spilling around the bubble. Removing it leaves just the grey bubble (it's opaque, so no bleed-through). |

### Floating (sticky / pinned) message — compaction
| Element | Change | Why |
|---|---|---|
| `.stickyHeader_07S1Yg` | `padding-top` `14px` → `0` | Remove the gap between the top of the panel and the floating box. |
| `.stickyHeader_07S1Yg .userMessage_07S1Yg` | append `font-size:11px` | Smaller floating-message text (base is 13px) → box takes less room. Scoped to the floating box only. |
| `.stickyHeader_07S1Yg .pill_lcdCYQ` | append: strip `background/border/border-radius/padding/height/max-width` | A linked-file attachment renders as a big pill "button"; this collapses it to a plain text line (icon + name kept). |
| `.stickyHeader_07S1Yg .label_lcdCYQ` | append `color:#777;font-size:10px` | The attachment filename: dark grey, 1px smaller. |
| `.stickyHeader_07S1Yg .meta_lcdCYQ` | append `font-size:10px` | Attachment meta text matches the filename size. |
| `.stickyHeader_07S1Yg .userMessageAttachments_07S1Yg` | append `padding-bottom:3px` | Halve the gap between the attachment line and the message text (was 6px). |
| `.stickyHeader_07S1Yg .userMessageContainer_07S1Yg` + `.userMessage_07S1Yg` | append `display:block;width:auto;max-width:none` | Floating message spans the **full panel width** (same 10px side gaps as the input box) instead of an inline-block bubble that hugs its text. |

### Input box geometry
| Element | Change | Why |
|---|---|---|
| `.inputContainer_07S1Yg` | `bottom:16px→0`, `left/right:16px→10px` | Input box flush to the bottom, 10px side gaps so it doesn't touch the panel border. |
| `.inputWrapper_cKsPxg` | `max-width:680px→none`, `margin:0 auto→0` | Lift the centered 680px cap → input spans the full panel width. |
| `.messageInput_cKsPxg` + `.mentionMirror_cKsPxg` | `padding:10px 36px 10px 14px → 5px 18px 5px 7px` (mirror `padding-right:64px→32px`) | Halve the padding around the text you type. (`.messageInput` is the transparent contenteditable; `.mentionMirror` is the visible highlighted overlay — both must match to stay aligned with the caret.) |
| `.messageInput_cKsPxg` + `.mentionMirror_cKsPxg` | append `font-size:15px` | Typed input text +2px (base 13px). Both layers set so the caret and the highlight overlay stay aligned. |
| `.inputFooter_gGYT1w` | append `zoom:.6` | Shrink **only** the bottom toolbar row (+, /, model, "Bypass permissions", send) to 60%. Modern Chromium `zoom` keeps the row full-width while scaling its contents. |

### Conversation width
| Element | Change | Why |
|---|---|---|
| `.messagesContainer_07S1Yg` (+ `.stickyMode_07S1Yg`) | side padding `20px → 10px` | More text per line in the conversation area (halved the margin to the panel border). |
| `.messagesContainer_07S1Yg` | append `font-size:16px` | Conversation body text +3px (base 13px). Doesn't touch the input text (separate element) or the floating message (explicit 11px). |
| `.userMessage_07S1Yg` | append `font-size:18px` | Your own message bubbles in the conversation are +2px over the body. The more-specific `.stickyHeader_07S1Yg .userMessage_07S1Yg{font-size:11px}` rule keeps the floating copy small. |

## Tuning cheatsheet
- **Grey shade** of the chat boxes: the `#2b2b2b` values (input bg ×2, bubble, truncation fade). Darker `#222`, lighter `#333`.
- **Floating message text size**: `.stickyHeader_07S1Yg .userMessage_07S1Yg{font-size:…}`.
- **Toolbar size**: `.inputFooter_gGYT1w{zoom:…}` (`.6` = 40% smaller; lower = smaller).
- **Input side gap**: `.inputContainer_07S1Yg` `left/right`.
- **Conversation width**: `.messagesContainer_07S1Yg` / `.stickyMode_07S1Yg` side padding.
- **Watch-point**: input right padding is now `18px` (was 36px, which reserved room for the
  mic button). If typed text overlaps the mic icon, bump just that side back up.

## Reverting
Each run writes a timestamped `index.css.bak-<ts>` next to the file; restore it to undo a
run. A pristine copy from the first session is kept as `index.css.orig-transparency-bak`.
To drop everything cleanly, reinstall/disable-enable the Claude Code extension (gives you a
fresh `index.css`), or `cp index.css.orig-transparency-bak index.css`.
