# Scripts

## Ownership

- `ai/`: bridge fino entre Orbit y OpenFang. No contiene providers locales ni runtime agéntico propio.
- `agents/`: procesos runtime de apoyo para módulos del shell.
- `tools/`: utilidades pequeñas invocadas por servicios concretos.

## Contratos importantes

- `agents/bluetooth-agent.py`
  Lo usa el shell principal para responder a solicitudes Bluetooth mientras haya overlays activos.

- `agents/sys-agent.py`
  Lo usa `SystemMonitorService` y solo debe emitir JSON por stdout.

- `tools/clear-unpinned.py`
  Lo usa `ClipboardService` y depende de `data/state/state.json`.

- `ai/ai_chat.py`
  Bridge principal de Orbit. Expone comandos JSON por stdin/stdout y traduce la GUI a la API HTTP de OpenFang.
