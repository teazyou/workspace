# `obsi [folder]` opens a folder as an Obsidian vault (like `code .`),
# planting per-file symlinks to the shared central config in configs/dot-obsidian.
# The launcher lives at scripts/obsi; see that file for the full behavior + caveats.
obsi () { "$SCRIPTS/obsi" "$@" }
