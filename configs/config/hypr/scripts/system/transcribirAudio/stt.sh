#!/bin/bash

# ── Configuración ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$HOME/.config/hypr/scripts/system/transcribirAudio"
MODEL="$SCRIPT_DIR/whisper.cpp-1.8.3/models/ggml-base-q5_1.bin"
WHISPER="$SCRIPT_DIR/whisper.cpp-1.8.3/build/bin/whisper-cli"
AUDIO="/tmp/stt.wav"
LOCK="/tmp/stt.lock"
PID_FILE="/tmp/stt.pid"

# ── Helper de notificación ─────────────────────────────────────────────────────
notify() {
    notify-send -t "$1" \
        -h string:x-canonical-private-synchronous:stt \
        "Dictado por Voz" "$2"
}

# ── Toggle: si ya está grabando, detener y transcribir ────────────────────────
if [ -f "$LOCK" ]; then
    # Matar el proceso de grabación guardado
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null
    fi
    rm -f "$LOCK" "$PID_FILE"
    exit 0
fi

# ── Verificar dependencias ─────────────────────────────────────────────────────
for cmd in pw-record wtype "$WHISPER"; do
    if ! command -v "$cmd" &>/dev/null && [ ! -x "$cmd" ]; then
        notify 4000 "❌ Falta dependencia: $(basename "$cmd")"
        exit 1
    fi
done

# ── Marcar como activo ─────────────────────────────────────────────────────────
touch "$LOCK"

# ── Limpieza si el script muere de forma inesperada ───────────────────────────
cleanup() {
    rm -f "$LOCK" "$PID_FILE"
}
trap cleanup EXIT

# ── Grabar sin límite de tiempo ────────────────────────────────────────────────
notify 60000 "🎤 Grabando... (pulsa otra vez para detener)"

pw-record --channels 1 --rate 16000 "$AUDIO" &
REC_PID=$!
echo "$REC_PID" > "$PID_FILE"

# Esperar a que el proceso de grabación termine (lo mata el segundo disparo)
wait "$REC_PID" 2>/dev/null

rm -f "$LOCK" "$PID_FILE"

# ── Transcribir ────────────────────────────────────────────────────────────────
notify 10000 "🧠 Transcribiendo..."

TEXT=$(
    "$WHISPER" -m "$MODEL" -f "$AUDIO" -l es -nt 2>/dev/null \
    | grep -v '^\[' \
    | grep -v '^\s*$' \
    | sed 's/^[[:space:]]*//' \
    | sed 's/[[:space:]]*$//' \
    | tr '\n' ' ' \
    | tr -s ' ' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
)

rm -f "$AUDIO"

# ── Escribir o notificar vacío ─────────────────────────────────────────────────
if [ -z "$TEXT" ]; then
    notify 3000 "⚠️ No se detectó voz"
    exit 0
fi

wtype "$TEXT"
notify 2000 "✅ Texto insertado"
