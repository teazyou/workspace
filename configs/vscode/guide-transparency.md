# VS Code transparency guide

How the see-through VS Code look is built, why it needed specific settings to work
**without** a heavy macOS blur, and the gotchas (Claude Code panel, command palette)
that took experimentation to solve.

> **Read this before changing any VS Code theme/colour/transparency setting** in
> [settings.json](settings.json) — the transparency is a layered system and changing
> one value affects others (and the Claude Code panel) in non-obvious ways.

## What does what (theme vs. transparency are two separate things)

- **Theme (colours):** `"workbench.colorTheme": "Dark Red"` — a normal installed
  colour theme. This only picks the palette; it has nothing to do with transparency.
- **Transparency:** the **Vibrancy Continued** extension
  (`illixion.vscode-vibrancy-continued`, settings prefixed `vscode_vibrancy.*`).
  This is what makes the window see-through. It is *not* a theme.

So: the theme decides the colours, Vibrancy Continued decides the transparency, and
`workbench.colorCustomizations` (alpha-channel hex) decides *how transparent each
individual surface* is on top of the vibrancy layer.

## The key that made true transparency work (no heavy blur)

By default the macOS vibrancy material adds a strong system **blur** behind the
window. To get *true* transparency (see the desktop/wallpaper clearly, not a frosted
blur), these two settings are essential:

```jsonc
"vscode_vibrancy.type": "transparent",        // transparent material instead of the blurred macOS vibrancy material
"vscode_vibrancy.forceFramelessWindow": true, // frameless window — required for the transparent material to actually show through
```

Without **both** of these, you only get the heavy native-blur look and cannot achieve
clean transparency. `type: "transparent"` swaps the blurred material for a clear one,
and `forceFramelessWindow: true` removes the window chrome that otherwise blocks it.

The third vibrancy setting is the global strength:

```jsonc
"vscode_vibrancy.opacity": 0.60,  // 0 = fully transparent window, 1 = fully opaque. Base layer for everything.
```

> **Applying changes:** vibrancy settings do **not** take effect on a normal
> "Reload Window". Run **Cmd+Shift+P → "Reload Vibrancy"** (re-enable if prompted
> about a "corrupted/modified installation" — that warning is expected).

## The layering model (why one value affects another)

Two layers stack to produce the final look of any surface:

1. **Vibrancy base** (`vscode_vibrancy.opacity`) — applies to the whole window.
2. **Per-surface alpha** (`workbench.colorCustomizations`, the `#RRGGBBAA` colours) —
   sits on top of the base. `…00` = fully transparent (shows pure vibrancy), `…ff` =
   fully opaque (solid, hides vibrancy).

Lowering the vibrancy base thins **everything** at once; raising a surface's alpha
makes just that surface more solid. Tune them together.

**Alpha quick reference** (last two hex digits):
`00` = 0% · `59` ≈ 35% · `99` ≈ 60% · `cc` ≈ 80% · `e6` ≈ 90% · `ff` = 100% opaque.

## The Claude Code panel (webview) problem — and the fix

The Claude Code extension renders its chat as a **webview** (an embedded iframe), with
`"claudeCode.preferredLocation": "panel"`. The symptom: the panel looked **more opaque**
than a normal editor pane — it had an extra dark layer that ignored most colour tokens.

**Fix:** the webview takes its background from **`sideBar.background`**. Setting it
fully transparent removed the extra opacity and made the panel match the editor exactly:

```jsonc
"sideBar.background": "#1e1e1e00",
```

Key takeaways for future edits:

- The Claude Code panel's transparency is driven by **`sideBar.background`**, not
  `panel.background` (which only colours the panel container, not the webview content).
- The webview also tracks the **vibrancy base** — at `vscode_vibrancy.opacity: 0` the
  panel went fully transparent. So it has no opacity knob of its own; it follows
  `sideBar.background` + the vibrancy base.
- Because it's tied to `sideBar.background`, you can't independently tint the real
  sidebar and the Claude panel — they share the token.

## Patching the webview CSS — the tool IN/OUT box bug

> The IN/OUT fix below is one of several Claude Code **webview** patches. The full set
> (grey chat boxes, floating-message compaction, full-width input, shrunk toolbar, …) and
> a one-command re-apply script live in [guide-claude-code.md](guide-claude-code.md). This
> section keeps the IN/OUT explanation because it stems directly from the `sideBar.background`
> transparency fix above.

Making `sideBar.background` transparent (the panel fix above) has a side effect: the
**tool usage box** (the collapsed IN/OUT preview shown for Bash/Edit/etc. tool calls)
becomes **invisible** — empty boxes with no text.

**Cause (an extension bug, not a settings issue).** The Claude Code webview CSS maps
`--app-primary-background` → `var(--vscode-sideBar-background)`, and the collapsed
tool-output preview clips itself with a CSS `mask-image`:

```css
.toolBodyRowContent:not(.disableClipping) {
  mask-image: linear-gradient(to bottom, var(--app-primary-background) 50px, transparent 60px);
  max-height: 60px;  /* fade out long output after 50px */
}
```

A `mask-image` shows content according to the mask's **alpha channel**. The extension
assumed `--app-primary-background` is opaque. Since we set `sideBar.background` to
`#1e1e1e00` (alpha 0), the *entire* mask is transparent → the whole preview is masked
out to invisible. The same variable also fills the panel root (`.root` background), so
you **cannot** fix this from `colorCustomizations` — one CSS variable does both jobs.

**Fix — patch the extension's webview CSS directly.** Replace the mask's transparent
color with an opaque one (the mask only needs alpha; the RGB is irrelevant):

```bash
# file: ~/.vscode/extensions/anthropic.claude-code-<version>/webview/index.css
# before: mask-image:linear-gradient(to bottom,var(--app-primary-background)50px,transparent 60px)
# after:  mask-image:linear-gradient(to bottom,#000 50px,transparent 60px)
CSS=~/.vscode/extensions/anthropic.claude-code-*/webview/index.css
cp $CSS "$CSS.orig-transparency-bak"   # back up first
perl -i -pe 's/\Qmask-image:linear-gradient(to bottom,var(--app-primary-background)50px,transparent 60px)\E/mask-image:linear-gradient(to bottom,#000 50px,transparent 60px)/g' $CSS
```

Then **Cmd+Shift+P → "Developer: Reload Webviews"**. The IN/OUT preview is visible
again (with the intended bottom fade on long output), panel transparency untouched.

**Make the tool box stand out in the chat flow.** The box (`.toolBody`) fills with
`--app-tool-background` = `var(--vscode-editor-background)` = `#1e1e1e00` (fully
transparent), so it blends into the panel. Giving it a semi-opaque fill makes it read
as a distinct card in the conversation. (Can't use `color-mix` off the token — it's
already alpha 0 — so hardcode the colour.) Settled on **`#1e1e1e99` (~60% opaque)**:

```bash
# in the same index.css:
perl -i -pe 's/\Q.toolBody_ZUQaOA{border:.5px solid var(--app-input-border);background:var(--app-tool-background);border-radius:5px\E/.toolBody_ZUQaOA{border:.5px solid var(--app-input-border);background:#1e1e1e99;border-radius:5px/g' $CSS
# #1e1e1e99 = ~60% opaque (99 hex = 153/255). Last two hex digits = opacity:
#   33 ≈ 20% · 4d ≈ 30% · 66 ≈ 40% · 80 ≈ 50% · 99 ≈ 60%. Tune to taste.
# NB: webview CSS changes only show after Cmd+Shift+P → "Developer: Reload Webviews".
```

**Caveats — this patch is fragile:**
- The extension path is **version-pinned** (`anthropic.claude-code-<version>-<arch>`).
  A Claude Code update installs a fresh, unpatched `index.css` in a new folder, so the
  fix is **lost on every update** and must be re-applied. The pristine original is kept
  alongside as `index.css.orig-transparency-bak`.
- This file lives in `~/.vscode/extensions`, **not** in this repo, so it's outside the
  symlink/source-of-truth model and isn't version-controlled here.
- Editing `.userMessage` / `.inputContainer*` to add transparency to the chat bubble or
  the typing box **does not work**: the input box is `position:absolute` and floats over
  the scrolling conversation, so making it see-through lets scrolled text bleed through
  and become unreadable. Leave those opaque.

## The command palette / widget readability fix (Cmd+Shift+P)

At full transparency the **command palette (Cmd+Shift+P)**, menus, autocomplete and
tooltips became unreadable — you could see straight through them to the text behind.

**Fix:** keep these floating widgets mostly opaque (`e6` ≈ 90%) and give them a red
border so they read as distinct panels:

```jsonc
"quickInput.background":        "#1e1e1ee6",  // command palette (Cmd+Shift+P)
"editorWidget.background":      "#1e1e1ee6",  // find/replace, etc.
"editorHoverWidget.background": "#1e1e1ee6",  // hover tooltips
"editorSuggestWidget.background":"#1e1e1ee6", // autocomplete popup
"menu.background":              "#1e1e1ee6",  // right-click / dropdown menus
"notifications.background":     "#1e1e1ee6",
"inlineChat.background":        "#1e1e1ee6",
// matching red borders (firebrick #b22222 = window-border active_color, see configs/borders/bordersrc)
"widget.border": "#b22222", "editorWidget.border": "#b22222", "menu.border": "#b22222",
"pickerGroup.border": "#b22222", "editorSuggestWidget.border": "#b22222", /* …etc */
```

The border red `#b22222` is kept in sync with the JankyBorders `active_color`
(`0xffb22222`) so the popups match the window borders.

## Custom workbench CSS (`vscode_vibrancy.imports`) — for things with no setting

Some looks have **no native VS Code setting** — e.g. the active tab's border is
locked to ~1px (`tab.activeBorder` only sets its *colour*, not its thickness). Rather
than install a separate Custom-CSS extension, Vibrancy Continued can inject your own
CSS/JS straight into the workbench via:

```jsonc
"vscode_vibrancy.imports": [
  "/Users/teazyou/workspace/configs/vscode/custom.css"  // absolute path, forward slashes
],
```

The injected file lives in the repo at [custom.css](custom.css) (so it *is* version-
controlled, unlike the Claude Code webview patch). Current use: a **4px bright-red bar
on the active tab** (the active tab otherwise has only the 1px theme border + a faint
red tint, which read as "not enough"). The rule uses an inset box-shadow so it doesn't
depend on VS Code's internal tab markup:

```css
.monaco-workbench .tabs-container > .tab.active {
  box-shadow: inset 0 -4px 0 0 #ff3030 !important;  /* -4px = bottom; 4px = top */
}
```

- Re-apply after editing the CSS (or the `imports` list) with **"Reload Vibrancy"**,
  not a plain window reload.
- The active-tab *colour/tint* still comes from `colorCustomizations`
  (`tab.activeBorder`, `tab.activeBackground`, `tab.activeForeground`); only the
  **thickness** needs the injected CSS.

## Surface groups in `colorCustomizations` (what's transparent vs. tinted)

- **Fully transparent (`…00`)** — show the desktop/vibrancy straight through:
  `editor.background`, `sideBar.background` (Claude panel fix), `terminal.background`,
  `editorPane`, `editorGroupHeader.tabs*`, `breadcrumb`, `editorGutter`, `panel`,
  `panelStickyScroll`, `tab.active*`.
- **Lightly tinted chrome (`…99` ≈ 60%)** — readable but still see-through:
  `activityBar`, `sideBarTitle`, `sideBar/editor StickyScroll(+Gutter)`, inactive tabs.
- **Mostly opaque popups (`…e6` ≈ 90%) + red border** — kept readable on purpose:
  the command-palette/widget group above.

## Gotchas / rules of thumb

- After changing `vscode_vibrancy.*`, you **must** run **"Reload Vibrancy"** (not just
  "Reload Window"). Colour-customisation alpha changes *do* apply on a plain reload.
- "Reload Vibrancy" has been observed to rewrite the alpha channels of
  `colorCustomizations` to track `opacity`. If your manual alphas don't stick after a
  vibrancy reload, that's why — re-set them and reload the window (not vibrancy).
- Don't expect `panel.background` to affect the Claude Code panel — use
  `sideBar.background`.
- Keep popup widgets opaque enough to read; pure transparency makes Cmd+Shift+P unusable.
