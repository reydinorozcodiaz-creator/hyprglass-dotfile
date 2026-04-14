# Quickshell Config

Shell de escritorio Wayland construido con [Quickshell](https://quickshell.outfoxxed.me/) y QML.

## Dependencias

| Herramienta | Uso |
|-------------|-----|
| `quickshell` | Motor del shell |
| `pipewire` / `wireplumber` | Audio |
| `networkmanager` | WiFi / Ethernet |
| `bluez` | Bluetooth |
| `hyprland` | Compositor Wayland |
| `swww` | Cambio de wallpaper |
| `hyprsunset` | Night light |
| `matugen` | Temas automáticos (Material You) |
| `python3` + `dbus-python` + `pygobject` | Agente Bluetooth |
| `kdialog` | Diálogos Bluetooth |
| `wtype` | Simulación de teclado |
| `grimblast` | Capturas de pantalla |
| `cliphist` | Historial de portapapeles |
| `wl-clipboard` | Portapapeles Wayland |

### Fuentes
- **Caskaydia Cove Nerd Font** (UI y texto)

## Estructura

```
quickshell/
├── shell.qml              # Punto de entrada principal
├── config/
│   └── Config.qml         # Configuración centralizada (colores, tamaños, fuentes)
├── components/            # Componentes reutilizables organizados por rol
│   ├── base/
│   ├── shell/
│   ├── status/
│   ├── media/
│   └── data/
├── services/              # Singletons QML con API estable vía `qs.services`
│   ├── stores/
│   ├── system/
│   ├── shell/
│   ├── appearance/
│   └── assistant/
├── modules/               # UI agrupada por dominio
│   ├── shell/             # Barra, quick settings, launcher, notificaciones…
│   ├── tools/             # Orbit, clipboard, monitor del sistema
│   └── appearance/        # Wallpaper y screenshot
├── scripts/
│   ├── ai/                # Backend AI, MCP y auth
│   ├── agents/            # Agentes de sistema
│   └── tools/             # Utilidades auxiliares
├── data/
│   ├── state/             # Estado persistente mutable
│   ├── cache/             # Cache runtime
│   └── private/           # Secretos locales
└── matugen/               # Plantillas para generación de temas automáticos
```

## Temas

Los temas se guardan en `~/.local/themes/<nombre>.json`. Hay dos modos:

- **Preset**: elige un tema JSON manualmente desde Quick Settings → Theme.
- **Auto (Material You)**: genera colores desde el wallpaper con `matugen`.

Para añadir un tema nuevo, crea un archivo JSON en `~/.local/themes/` con la estructura:

```json
{
  "name": "Mi Tema",
  "variant": "dark",
  "darkPair": "mi-tema-dark",
  "lightPair": "mi-tema-light",
  "palette": {
    "background": "#1a1b26",
    "accent": "#7aa2f7",
    ...
  },
  "hyprland": {
    "activeBorder": "7aa2f7ff",
    "inactiveBorder": "565f89ff",
    "shadowColor": "1a1b26cc"
  },
  "neovim": { "colorscheme": "tokyonight" },
  "wallpaper": "wallpaper.jpg"
}
```

## Personalización

Todas las opciones de usuario se guardan en `data/state/state.json` y son accesibles desde Quick Settings. Los valores por defecto están documentados en `config/Config.qml`.

Puedes editar `data/state/state.json` directamente; el shell detecta los cambios y se actualiza en tiempo real (debounce de 150ms).

## Datos runtime

- `data/state/state.json`: estado general del shell
- `data/state/ai-history.json`: historial y borradores de Orbit
- `data/private/secrets.json`: credenciales y secretos locales, incluyendo acceso opcional a OpenFang

La escritura nueva ocurre siempre en `data/`. Los servicios mantienen fallback de lectura para rutas antiguas durante la transición.

Si existían archivos legacy en la raíz, se consideran compatibilidad transicional y el estado canónico pasa a vivir bajo `data/`.

## Contratos externos

El proyecto sigue dependiendo de algunos artefactos fuera de este árbol:

- `~/.config/hypr/scripts/tools/AleatoryWall.sh`
- `~/.config/hypr/scripts/system/theme-unifier.sh`
- `~/.lyne-dots/.data/quickshell/defaults.json`
- `/tmp/QsAnyModuleIsOpen`

### Contratos y ownership

| Recurso externo | Consumido por | Rol | Si falla |
|---|---|---|---|
| `~/.config/hypr/scripts/tools/AleatoryWall.sh` | `WallpaperManagerService` | Aplicar y rotar wallpapers, sincronizar lockscreen y pywal | El wallpaper no cambia o queda rollback con mensaje visible |
| `~/.config/hypr/scripts/system/theme-unifier.sh` | `ThemeBackendService` | Aplicar tema GTK/iconos/cursor del sistema | El tema del sistema no se actualiza y se muestra error visible |
| `~/.lyne-dots/.data/quickshell/defaults.json` | `StateService` | Fallback de valores por defecto | Se usan solo los defaults locales de `Config.qml` y el estado persistido |
| `http://127.0.0.1:4200` (OpenFang por defecto) | `AiService`, `scripts/ai/ai_chat.py` | Backend único de Orbit: agentes, streaming, sesión y errores | Orbit no puede listar agentes ni chatear hasta recuperar OpenFang |
| `/tmp/QsAnyModuleIsOpen` | `WindowManagerService`, bluetooth agent | Coordinación ligera entre overlays/agentes | Puede degradarse la coordinación de foco/estado, pero no rompe el shell completo |

### Ownership interno de scripts

- `scripts/ai/`: bridge de Orbit hacia OpenFang.
- `scripts/agents/`: agentes de soporte runtime ligados a módulos concretos (`bluetooth`, `systemMonitor`).
- `scripts/tools/`: utilidades auxiliares pequeñas invocadas por servicios del shell.

`modules/appearance/screenshot` sigue integrado dentro del proyecto y no se ha vendor-izado todavía.

## Atajos de teclado globales

Los atajos se registran en Hyprland. Configúralos en tu `hyprland.conf`:

| Acción | Nombre del shortcut |
|--------|---------------------|
| Captura de pantalla | `take_screenshot` |
| Menú de energía | `power_menu` |
| Lanzador de apps | `app_launcher` |
| Subir volumen | `volume_up` |
| Bajar volumen | `volume_down` |
| Silenciar | `volume_mute` |
| Subir brillo | `brightness_up` |
| Bajar brillo | `brightness_down` |
| Selector de wallpaper | `wallpaper_picker` |
| Historial portapapeles | `clipboard_history` |
| Ayuda de atajos | `keybinds_help` |
