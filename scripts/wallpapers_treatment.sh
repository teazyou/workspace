#!/usr/bin/env bash
#
# wallpapers_treatment.sh — batch-apply an ImageMagick "profile" (e.g. blur)
# to every wallpaper under ~/gdrive/wallpapers/originals/, writing the
# processed copies into a mirrored folder tree so the originals are never
# touched.
#
# Layout:
#   ~/gdrive/wallpapers/
#     ├── originals/<category>/...                                source images, the source of truth
#     └── modified/<profile-name>/<profile-name>-<category>/...   processed copies (created here)
#
# Usage:
#   wallpapers-treatment <profile-name>
#
# Profiles live in the PROFILES array at the top of this file: each item is
# "<kebab-case-name>|<ImageMagick options>". The options are inserted between
# the input and output paths:  magick <src> <options...> <dst>.
#
# ImageMagick generates a *new* image on each invocation (it never has to
# mutate the original), so no scratch/temporary copy is needed: we read the
# original and write straight into the mirrored profile folder. Re-running is
# idempotent — an image is processed only when its copy is missing in the
# destination, so freshly-added wallpapers are picked up cheaply.
#
# originals/ is the source of truth: before converting, a clean pass prunes
# modified/ to mirror it. For every profile already under modified/ (even ones
# no longer in PROFILES), any category subfolder whose source folder is gone is
# removed wholesale, then any processed image whose source image is gone is
# removed — so modified/ only ever holds copies that still have an original.
#
# Failed conversions are collected into a retry list and re-attempted in up to
# MAX_ATTEMPTS rounds; anything still failing after the last round is reported
# and the script exits non-zero.
#
# Compatible with stock macOS bash 3.2 (no associative arrays).
#
# Wired to the `wallpapers-treatment` alias (see zsh/alias/wallpapers.zsh).

set -uo pipefail

# --- PROFILES ---------------------------------------------------------------
# One item per profile: "<name>|<ImageMagick options>".
# Names are kebab-case; options are passed verbatim to `magick`.
PROFILES=(
  "blur-1|-blur 0x1"
  "blur-2|-blur 0x2"
  "blur-3|-blur 0x3"
  "blur-4|-blur 0x4"
)

# --- PATHS ------------------------------------------------------------------
: "${WORKSPACE:=$HOME/workspace}"
WALLPAPERS_DIR="$HOME/gdrive/wallpapers"   # holds originals/ and the modified/ output tree
ORIGINALS="$WALLPAPERS_DIR/originals"      # source images live here (source of truth)
MODIFIED_DIR="$WALLPAPERS_DIR/modified"    # every profile output dir lives under here

# --- COLORS / LOGGING -------------------------------------------------------
# Reuse the workspace palette (literal "\033[..m" strings) and normalise them
# with printf %b so plain printf shows colour under bash, mirroring
# scripts/installs/helper_prompt.sh.
# shellcheck source=/dev/null
source "$WORKSPACE/zsh/configs/colors.zsh" 2>/dev/null || true
COK=$(printf '%b' "${COK:-}"); CKO=$(printf '%b' "${CKO:-}")
CW8=$(printf '%b' "${CW8:-}"); CYE=$(printf '%b' "${CYE:-}")
CBL=$(printf '%b' "${CBL:-}"); CWH=$(printf '%b' "${CWH:-}")

log_ok()   { printf "%s%s%s\n" "$COK" "$1" "$CWH"; }
log_err()  { printf "%s%s%s\n" "$CKO" "$1" "$CWH"; }
log_wait() { printf "%s%s%s\n" "$CW8" "$1" "$CWH"; }
log_info() { printf "\n%s== %s ==%s\n" "$CYE" "$1" "$CWH"; }

die() { log_err "$1"; exit 1; }

# --- HELPERS ----------------------------------------------------------------
# Echo the ImageMagick options for profile $1; return 1 if the name is unknown.
profile_args() {
  local entry
  for entry in "${PROFILES[@]}"; do
    if [ "${entry%%|*}" = "$1" ]; then
      printf '%s' "${entry#*|}"
      return 0
    fi
  done
  return 1
}

# True if $1 is a registered profile name (used to validate the CLI argument).
is_profile_name() {
  local entry
  for entry in "${PROFILES[@]}"; do
    [ "${entry%%|*}" = "$1" ] && return 0
  done
  return 1
}

# Prune modified/ so it mirrors originals/ (the source of truth). For every
# profile folder under modified/ — whether or not it is still in PROFILES — drop
# any category subfolder whose matching original is gone (whole-subtree, done
# first since it's cheaper), then drop any processed image whose matching
# original is gone. Category subfolders are named "<profile>-<category>", so the
# "<profile>-" prefix is stripped to find the matching originals/<category>.
clean_modified() {
  [ -d "$MODIFIED_DIR" ] || return 0
  local profile_dir prof sub sub_name category orig_cat img imgname
  for profile_dir in "$MODIFIED_DIR"/*/; do
    prof="$(basename "$profile_dir")"
    for sub in "$profile_dir"*/; do
      sub_name="$(basename "$sub")"
      category="${sub_name#"$prof"-}"          # strip the "<profile>-" prefix
      orig_cat="$ORIGINALS/$category"

      # Folder no longer backed by an originals/ category → remove it wholesale.
      if [ ! -d "$orig_cat" ]; then
        rm -rf "$sub"
        log_wait "cleaned $prof/$sub_name (original folder gone)"
        continue
      fi

      # Otherwise drop images whose original no longer exists.
      for img in "$sub"*.jpg "$sub"*.jpeg "$sub"*.png; do
        [ -f "$img" ] || continue
        imgname="$(basename "$img")"
        if [ ! -e "$orig_cat/$imgname" ]; then
          rm -f "$img"
          log_wait "cleaned $prof/$sub_name/$imgname (original image gone)"
        fi
      done
    done
  done
}

# --- USAGE ------------------------------------------------------------------
usage() {
  printf "%bUsage:%b wallpapers-treatment <profile-name>\n\n" "$CYE" "$CWH"
  printf "Apply an ImageMagick profile to every wallpaper under:\n"
  printf "  %s\n" "$ORIGINALS"
  printf "Processed copies are written under %s/<profile-name>/ — originals are never modified.\n\n" "$MODIFIED_DIR"
  printf "%bAvailable profiles:%b\n" "$CYE" "$CWH"
  local entry
  for entry in "${PROFILES[@]}"; do
    printf "  %b%-12s%b %s\n" "$CBL" "${entry%%|*}" "$CWH" "${entry#*|}"
  done
}

# ============================================================================
# INITIATION PHASE
# ============================================================================

# --- 1. ImageMagick present (install via Homebrew if missing) ---------------
log_info "ImageMagick"
if command -v magick >/dev/null 2>&1; then
  log_ok "magick found ($(command -v magick))"
else
  log_wait "magick not found — installing via Homebrew..."
  command -v brew >/dev/null 2>&1 || die "Homebrew is not installed; cannot install ImageMagick."
  brew install imagemagick || die "ImageMagick installation failed."
  command -v magick >/dev/null 2>&1 || die "magick still not on PATH after install."
  log_ok "ImageMagick installed"
fi

# --- 2. ImageMagick usable (real end-to-end probe) --------------------------
probe_base="$(mktemp -t wallpapers-treatment)" || die "Could not create a temp file for the probe."
probe="$probe_base.png"
if magick -size 16x16 xc:white "$probe" >/dev/null 2>&1 && [ -s "$probe" ]; then
  log_ok "magick is usable"
else
  rm -f "$probe_base" "$probe"
  die "magick is installed but not working (probe conversion failed)."
fi
rm -f "$probe_base" "$probe"

# --- 3. Source root exists --------------------------------------------------
log_info "Source folders"
[ -d "$ORIGINALS" ] || die "Folder not found: $ORIGINALS"
log_ok "found $ORIGINALS"

# --- 4. Source root has category folders ------------------------------------
shopt -s nullglob nocaseglob
source_count=0
for d in "$ORIGINALS"/*/; do
  is_profile_name "$(basename "$d")" && continue
  source_count=$((source_count + 1))
done
[ "$source_count" -gt 0 ] || die "No wallpaper category folders inside $ORIGINALS"
log_ok "$source_count category folder(s) found"

# --- 5. Profile argument ----------------------------------------------------
profile="${1:-}"
if [ -z "$profile" ] || ! is_profile_name "$profile"; then
  [ -n "$profile" ] && log_err "Unknown profile: '$profile'"
  echo
  usage
  exit 1
fi
read -ra PROFILE_ARGS <<< "$(profile_args "$profile")"

# ============================================================================
# ROUTINE
# ============================================================================
MAX_ATTEMPTS=3

# --- Clean: prune modified/ so it mirrors originals/ (source of truth) -------
log_info "Cleaning modified/ to mirror originals/"
clean_modified
log_ok "modified/ now mirrors originals/"

PROFILE_ROOT="$MODIFIED_DIR/$profile"
log_info "Applying profile: $profile  ($(profile_args "$profile"))"
mkdir -p "$PROFILE_ROOT"

processed=0; skipped=0

# --- Build the work list ----------------------------------------------------
# Each work item is just the source path; its destination is recomputed from it.
# We queue only images whose output is still missing (idempotent re-runs).
todo=()
for category_dir in "$ORIGINALS"/*/; do
  category="$(basename "$category_dir")"
  is_profile_name "$category" && continue   # skip stray profile-named folders left inside originals/

  dest_name="$profile-$category"            # prefix each category folder with the profile name (e.g. blur-4-red)
  dest_dir="$PROFILE_ROOT/$dest_name"
  mkdir -p "$dest_dir"

  for src in "$category_dir"*.jpg "$category_dir"*.jpeg "$category_dir"*.png; do
    [ -f "$src" ] || continue
    if [ -e "$dest_dir/$(basename "$src")" ]; then
      skipped=$((skipped + 1))
    else
      todo+=("$src")
    fi
  done
done

# --- Process the list, retrying failures up to MAX_ATTEMPTS rounds ----------
# Each round converts every queued image; failures go into `retry`. When the
# round ends, that retry list becomes the next round's work list, and we go
# again — up to MAX_ATTEMPTS, stopping early as soon as a round leaves nothing.
attempt=1
while [ "${#todo[@]}" -gt 0 ] && [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  [ "$attempt" -gt 1 ] && log_info "Retry $((attempt - 1))/$((MAX_ATTEMPTS - 1)) — ${#todo[@]} image(s) left"

  retry=()
  for src in "${todo[@]}"; do
    dest_name="$profile-$(basename "$(dirname "$src")")"
    dest_dir="$PROFILE_ROOT/$dest_name"
    fname="$(basename "$src")"

    # Write to a hidden temp file, then move into place only on success — so an
    # interrupted run never leaves a half-written image (and the leftover, being
    # a dotfile, is never re-globbed as a source).
    tmp="$dest_dir/.wptmp.$$.$fname"
    if magick "$src" "${PROFILE_ARGS[@]}" "$tmp" >/dev/null 2>&1 && [ -s "$tmp" ]; then
      mv -f "$tmp" "$dest_dir/$fname"
      processed=$((processed + 1))
      log_ok "$dest_name/$fname"
    else
      rm -f "$tmp"
      retry+=("$src")
      log_err "$dest_name/$fname (attempt $attempt failed)"
    fi
  done

  # Promote this round's failures to the next round's work list.
  if [ "${#retry[@]}" -gt 0 ]; then
    todo=("${retry[@]}")
  else
    todo=()
  fi
  attempt=$((attempt + 1))
done

failed="${#todo[@]}"

log_info "Done"
printf "  processed: %d   skipped(existing): %d   failed: %d\n" "$processed" "$skipped" "$failed"
if [ "$failed" -gt 0 ]; then
  log_err "Still failing after $MAX_ATTEMPTS attempts:"
  for src in "${todo[@]}"; do
    log_err "  $profile-$(basename "$(dirname "$src")")/$(basename "$src")"
  done
  exit 1
fi
exit 0
