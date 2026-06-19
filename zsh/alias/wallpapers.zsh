# `wallpapers-treatment <profile-name>` batch-applies an ImageMagick profile
# (e.g. blur) to every wallpaper under ~/gdrive/wallpapers/originals/, writing
# the processed copies into a mirrored <originals>/<profile-name>/ tree so the
# originals are never touched. Run with no/invalid profile to see the profiles.
# The script lives at scripts/wallpapers_treatment.sh.
alias wallpapers-treatment="bash $SCRIPTS/wallpapers_treatment.sh"
