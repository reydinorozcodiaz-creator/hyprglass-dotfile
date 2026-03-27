#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ── Configuración ──────────────────────────────────────────────────────────────
WHISPER_BIN="${WHISPER_BIN:-${XDG_DATA_HOME:-$HOME/.local/share}/whisper.cpp/bin/whisper-cli}"
WHISPER_MODEL="${WHISPER_MODEL:-${MODEL_PATH:-${XDG_DATA_HOME:-$HOME/.local/share}/whisper.cpp/models/ggml-base-q5_1.bin}}"
AUDIO="/tmp/stt.wav"
LOCK="/tmp/stt.lock"
PID_FILE="/tmp/stt.pid"

# ── Helper de notificación ─────────────────────────────────────────────────────
notify() {
    notify-send -t "$1" \
        -h string:x-canonical-private-synchronous:stt \
        "Dictado por Voz" "$2"
}

check_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        notify 4000 "❌ Falta dependencia: $cmd"
        exit 1
    fi
}

check_binary() {
    local binary="$1"
    if command -v "$binary" >/dev/null 2>&1; then
        return 0
    fi
    if [ -x "$binary" ]; then
        return 0
    fi
    notify 5000 "❌ Falta WHISPER_BIN. Define WHISPER_BIN o instala whisper-cli fuera del repo."
    exit 1
}

# ── Toggle: si ya está grabando, detener y transcribir ────────────────────────
if [ -f "$LOCK" ]; then
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            notify 2000 "🛑 Grabación detenida"
        fi
    fi
    rm -f "$LOCK" "$PID_FILE"
    exit 0
fi

# ── Verificar dependencias ─────────────────────────────────────────────────────
check_cmd pw-record
check_cmd wtype
check_binary "$WHISPER_BIN"

if [ ! -f "$WHISPER_MODEL" ]; then
    notify 5000 "❌ Falta WHISPER_MODEL. Define WHISPER_MODEL o instala un modelo fuera del repo."
    exit 1
fi

# ── Parámetros de rendimiento (máximo rendimiento en CPU de desktop) ───────────
WHISPER_THREADS="${WHISPER_THREADS:-$(nproc 2>/dev/null || echo 1)}"
WHISPER_OPTS="${WHISPER_OPTS:--nt --no-lms --no-timestamps}"

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
    "$WHISPER_BIN" -m "$WHISPER_MODEL" -f "$AUDIO" -l es -t "$WHISPER_THREADS" $WHISPER_OPTS 2>/dev/null \
    | awk '!/^\[/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); if (length($0)) line = line $0 " " } END { gsub(/^[[:space:]]+|[[:space:]]+$/, "", line); if (length(line)) print line }'
)

rm -f "$AUDIO"

# ── Escribir o notificar vacío ─────────────────────────────────────────────────
if [ -z "$TEXT" ]; then
    notify 3000 "⚠️ No se detectó voz"
    exit 0
fi

wtype "$TEXT"
notify 2000 "✅ Texto insertado"
