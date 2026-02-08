#!/bin/bash
set -euo pipefail

# Converts .webm wallpapers into animated .gif optimized for lower resource usage.
# swww supports animated GIFs; it does NOT play .webm.
#
# Defaults are chosen to reduce CPU/GPU load:
# - FPS: 15
# - Width: 1280 (keeps aspect ratio)
# You can override:
#   FPS=12 WIDTH=960 ./convert-webm-to-gif.sh
#
# Optional:
#   DELETE_ORIGINAL=true  (removes .webm after successful conversion)

WALL_DIR=${WALL_DIR:-"$HOME/Wallpapers"}
FPS=${FPS:-15}
WIDTH=${WIDTH:-1280}
DELETE_ORIGINAL=${DELETE_ORIGINAL:-false}

if [[ ! -d "$WALL_DIR" ]]; then
  echo "Wallpaper dir not found: $WALL_DIR" >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required." >&2
  exit 1
fi

shopt -s nullglob
mapfile -t WEBMS < <(find "$WALL_DIR" -maxdepth 1 -type f -iname '*.webm' -print | sort)

if [[ ${#WEBMS[@]} -eq 0 ]]; then
  echo "No .webm files found in $WALL_DIR" >&2
  exit 0
fi

echo "Converting ${#WEBMS[@]} file(s) from .webm to .gif"
echo "Settings: FPS=$FPS WIDTH=$WIDTH"

tmp_root=${TMPDIR:-/tmp}

for in_file in "${WEBMS[@]}"; do
  base="${in_file%.*}"
  out_file="${base}.gif"

  echo "- $(basename "$in_file") -> $(basename "$out_file")"

  palette="$tmp_root/$(basename "$base").palette.png"

  # 1) Palette generation
  ffmpeg -hide_banner -loglevel error -y \
    -i "$in_file" \
    -vf "fps=${FPS},scale=${WIDTH}:-2:flags=lanczos,palettegen=stats_mode=diff" \
    "$palette"

  # 2) GIF with palette
  ffmpeg -hide_banner -loglevel error -y \
    -i "$in_file" -i "$palette" \
    -filter_complex "fps=${FPS},scale=${WIDTH}:-2:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5" \
    -loop 0 \
    "$out_file"

  rm -f "$palette" 2>/dev/null || true

  if [[ "$DELETE_ORIGINAL" == "true" ]]; then
    rm -f "$in_file"
  fi

done

echo "Done. Tip: now AleatoryWall can rotate the .gif files via swww."
