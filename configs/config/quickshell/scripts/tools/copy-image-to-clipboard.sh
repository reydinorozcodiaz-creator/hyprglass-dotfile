#!/bin/bash
# SECURITY: Helper script to copy image to clipboard safely
# Usage: copy-image-to-clipboard.sh <image_path>

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <image_path>" >&2
    exit 1
fi

IMAGE_PATH="$1"

# Validate file exists and is readable
if [ ! -f "$IMAGE_PATH" ]; then
    echo "Error: File not found: $IMAGE_PATH" >&2
    exit 1
fi

if [ ! -r "$IMAGE_PATH" ]; then
    echo "Error: File not readable: $IMAGE_PATH" >&2
    exit 1
fi

# Copy to clipboard
wl-copy --type image/png < "$IMAGE_PATH"
