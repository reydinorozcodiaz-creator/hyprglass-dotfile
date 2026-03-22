#!/usr/bin/env sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG_HOME=$(CDPATH= cd -- "$ROOT/.." && pwd)
CACHE_DIR=$(mktemp -d)
STATE_DIR=$(mktemp -d)
ERR_FILE=$(mktemp)

cleanup() {
  rm -rf "$CACHE_DIR" "$STATE_DIR" "$ERR_FILE"
}

trap cleanup EXIT

cd "$ROOT"

luac -p init.lua

find lua -type f -name '*.lua' | sort | while IFS= read -r file; do
  luac -p "$file"
done

XDG_CONFIG_HOME="$CONFIG_HOME" \
XDG_CACHE_HOME="$CACHE_DIR" \
XDG_STATE_HOME="$STATE_DIR" \
nvim --headless -i NONE '+qa' 2>"$ERR_FILE"

if [ -s "$ERR_FILE" ]; then
  cat "$ERR_FILE"
  exit 1
fi
