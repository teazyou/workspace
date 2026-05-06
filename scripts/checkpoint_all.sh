#!/bin/bash

source "$SCRIPTS/checkpoint_functions.sh"

for folder in "${CHECKPOINT_FOLDERS[@]}"; do
  checkpoint_folder "$folder"
done
