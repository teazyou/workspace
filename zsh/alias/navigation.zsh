workspace () { cd $WORKSPACE/$@ }
dev () { cd ~/dev/$@ }
gdrive () { cd ~/gdrive/$@ }
# `obsi [folder]` opens a folder as an Obsidian vault (like `code .`),
# planting a symlink to the shared central config. See configs/dot-obsidian.
# (The old `cd ~/secondbrain` shortcut lives on as `secondbrain` below.)
obsi () { "$APP_CONFIGS/dot-obsidian/bin/obsi" "$@" }
secondbrain () { cd ~/secondbrain/$@ }