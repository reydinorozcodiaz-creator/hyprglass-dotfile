#!/usr/bin/env bash
# Copies a screenshot to the clipboard. Uses Wayland tools (grim + wl-copy + slurp)
# Falls back to maim/import + xclip when those aren't available.

set -euo pipefail

MODE="full"
if [[ ${1-} == "--area" || ${1-} == "area" ]]; then
  MODE="area"
fi

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Captura" "$1"
  fi
}

tmpfile="$(mktemp --suffix=.png)"

cleanup() {
  rm -f "$tmpfile"
}
trap cleanup EXIT

if command -v grim >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1; then
  if [[ "$MODE" == "area" ]]; then
    if command -v slurp >/dev/null 2>&1; then
      region=$(slurp)
      if [[ -z "$region" ]]; then
        notify "Selección cancelada"
        exit 0
      fi
      grim -g "$region" "$tmpfile"
    else
      notify "slurp no encontrado: no se puede seleccionar área"
      exit 1
    fi
  else
    grim "$tmpfile"
  fi

  wl-copy --type image/png < "$tmpfile"
  notify "Captura copiada al portapapeles"

elif command -v maim >/dev/null 2>&1 && command -v xclip >/dev/null 2>&1; then
  # X11 fallback
  if [[ "$MODE" == "area" ]]; then
    maim -s "$tmpfile"
  else
    maim "$tmpfile"
  fi
  xclip -selection clipboard -t image/png -i "$tmpfile"
  notify "Captura copiada al portapapeles (X11)"

elif command -v scrot >/dev/null 2>&1 && command -v xclip >/dev/null 2>&1; then
  # another X11 fallback
  if [[ "$MODE" == "area" ]]; then
    scrot -s "$tmpfile"
  else
    scrot "$tmpfile"
  fi
  xclip -selection clipboard -t image/png -i "$tmpfile"
  notify "Captura copiada al portapapeles (X11)"

else
  notify "No se encontraron herramientas de captura (grim/wl-copy o maim/xclip)"
  echo "Error: no screenshot tools available" >&2
  exit 2
fi
