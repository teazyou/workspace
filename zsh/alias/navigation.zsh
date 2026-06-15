workspace () { cd $WORKSPACE/$@ }
dev () { cd ~/dev/$@ }
gdrive () { cd ~/gdrive/$@ }
# `obsidian [folder]` opens a folder as an Obsidian vault (like `code .`),
# planting a symlink to the shared central config. See configs/dot-obsidian.
# (The old `cd ~/secondbrain` shortcut lives on as `secondbrain` below.)
obsidian () { "$APP_CONFIGS/dot-obsidian/bin/obsidian" "$@" }
secondbrain () { cd ~/secondbrain/$@ }