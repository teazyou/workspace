#!/usr/bin/env bash
# Re-apply all Claude Code (VS Code extension) chat-panel webview customizations.
# Run standalone, or via the `workspace-patch` alias (which also runs the Obsidian
# patch). Re-run after every Claude Code extension update (updates install a fresh,
# unpatched index.css + extension.js in a new folder, wiping these edits).
# After running: Cmd+Shift+P -> "Developer: Reload Window".
# Full per-patch reference: docs/vscode/claude-code-panel.md.
# Idempotent: value patches match the extension's ORIGINAL declarations (no-op once
# applied); appended rules are guarded against duplicates.
set -euo pipefail

CSS=$(ls -dt ~/.vscode/extensions/anthropic.claude-code-*/webview/index.css 2>/dev/null | head -1 || true)
[ -z "${CSS:-}" ] && { echo "❌ Claude Code extension index.css not found"; exit 1; }
EXT=$(ls -dt ~/.vscode/extensions/anthropic.claude-code-*/extension.js 2>/dev/null | head -1 || true)
[ -z "${EXT:-}" ] && { echo "❌ Claude Code extension.js not found"; exit 1; }
echo "Patching: $CSS"
echo "Patching: $EXT"
cp "$CSS" "$CSS.bak-$(date +%Y%m%d-%H%M%S)"
cp "$EXT" "$EXT.bak-$(date +%Y%m%d-%H%M%S)"

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

# ── extension.js: don't lock the Claude Code editor group ────────────────────
# The editor-tab ("Panel (New Tab)") location force-locks its group right after creating
# the webview panel (createPanel(...) -> executeCommand("workbench.action.lockEditorGroup")),
# so CMD+N / opening files can't land in that locked group and spawn a NEW group instead.
# Swap the lock command for unlock. Idempotent: once patched the string is
# action.unlockEditorGroup, which this pattern ("action.lockEditorGroup") no longer matches.
perl -i -pe 's/action\.lockEditorGroup/action.unlockEditorGroup/g' "$EXT"

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
grep -qF "action.unlockEditorGroup" "$EXT" \
  && echo "  OK      extension.js: editor-group lock disabled" \
  || echo "  MISSING extension.js: action.lockEditorGroup not patched (element changed?)"
echo; echo 'Done. Now: Cmd+Shift+P -> "Developer: Reload Window"'
echo '  (a full window reload is required for the extension.js patch; "Reload Webviews"'
echo '   alone only refreshes the index.css visual tweaks.)'
