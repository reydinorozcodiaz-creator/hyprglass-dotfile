# Scripts

## Ownership

- `ai/`: backend de Orbit, integración MCP, auth y utilidades compartidas del asistente.
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
  Backend principal de Orbit. Expone comandos JSON por stdin/stdout y no debe escribir texto arbitrario fuera de ese contrato.

- `ai/ai_agent_runtime.py`
  Runtime local de herramientas del asistente. Su estado transitorio vive en `data/state/assistant/`.
