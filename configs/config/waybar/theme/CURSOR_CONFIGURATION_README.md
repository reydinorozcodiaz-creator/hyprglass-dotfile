# Configuración de Cursor Consistente en Hyprland

## Problema Resuelto

El problema de cursores diferentes cuando pasas el mouse sobre diferentes elementos se debe a que las aplicaciones usan diferentes backends de cursor:

- **Aplicaciones nativas de Wayland**: Usan `HYPRCURSOR_THEME`
- **Aplicaciones GTK**: Usan configuración GTK y `XCURSOR_THEME`
- **Aplicaciones Qt**: Usan `QT_CURSOR_THEME`
- **Aplicaciones X11**: Usan `XCURSOR_THEME`

## Solución Implementada

### 1. Variables de Entorno (config/environment.conf)
```bash
# Cursor theme configuration
env = HYPRCURSOR_THEME,oreo_black_cursors
env = XCURSOR_THEME,oreo_black_cursors
env = QT_CURSOR_THEME,oreo_black_cursors

# Cursor size configuration
envd = HYPRCURSOR_SIZE,24
envd = XCURSOR_SIZE,24
envd = QT_CURSOR_SIZE,24
```

### 2. Scripts Creados

#### cursor-setup.sh
- **Función**: Configuración inicial del cursor
- **Ubicación**: `~/.config/hypr/scripts/system/cursor-setup.sh`
- **Uso**: 
  ```bash
  ./scripts/system/cursor-setup.sh apply [theme_name]
  ./scripts/system/cursor-setup.sh list
  ./scripts/system/cursor-setup.sh current
  ```

#### cursor-fix.sh
- **Función**: Soluciona inconsistencias de cursor
- **Ubicación**: `~/.config/hypr/scripts/system/cursor-fix.sh`
- **Uso**:
  ```bash
  ./scripts/system/cursor-fix.sh fix
  ./scripts/system/cursor-fix.sh status
  ./scripts/system/cursor-fix.sh reload
  ```

#### cursor-selector.sh
- **Función**: Selector interactivo con Rofi
- **Ubicación**: `~/.config/hypr/scripts/system/cursor-selector.sh`
- **Uso**:
  ```bash
  ./scripts/system/cursor-selector.sh select
  ./scripts/system/cursor-selector.sh quick [theme_name]
  ```

### 3. Configuración GTK Automática

Los scripts crean automáticamente:

**GTK3** (`~/.config/gtk-3.0/settings.ini`):
```ini
[Settings]
gtk-cursor-theme-name=oreo_black_cursors
gtk-cursor-theme-size=24
```

**GTK2** (`~/.gtkrc-2.0`):
```bash
gtk-cursor-theme-name="oreo_black_cursors"
gtk-cursor-theme-size=24
```

### 4. Autostart Configurado

En `config/autostart.conf`:
```bash
# Cursor theme setup
exec-once = ~/.config/hypr/scripts/system/cursor-setup.sh apply &
```

### 5. Keybinds Configurados

En `config/keybinds.conf`:
```bash
# Cursor theme controls
bind = $mainMod SHIFT, C, exec, ~/.config/hypr/scripts/system/cursor-selector.sh select
bind = $mainMod CTRL, C, exec, ~/.config/hypr/scripts/system/cursor-fix.sh fix && notify-send "Cursor fixed"
```

## Temas de Cursor Disponibles

En tu sistema tienes:
- **oreo_black_cursors** (recomendado) - `~/.icons/oreo_black_cursors`
- **Sweet-cursors** - `~/.icons/Sweet-cursors`
- **capitaine-cursors** - `/usr/share/icons/capitaine-cursors`
- **capitaine-cursors-light** - `/usr/share/icons/capitaine-cursors-light`
- **Adwaita** - `/usr/share/icons/Adwaita`
- **redglass** - `/usr/share/icons/redglass`
- **whiteglass** - `/usr/share/icons/whiteglass`

## Uso Diario

### Cambiar Cursor Interactivamente
```bash
# Presiona Super + Shift + C
# O ejecuta:
~/.config/hypr/scripts/system/cursor-selector.sh select
```

### Aplicar Cursor Específico
```bash
~/.config/hypr/scripts/system/cursor-setup.sh apply Sweet-cursors
```

### Solucionar Problemas de Cursor
```bash
# Presiona Super + Ctrl + C
# O ejecuta:
~/.config/hypr/scripts/system/cursor-fix.sh fix
```

### Ver Estado Actual
```bash
~/.config/hypr/scripts/system/cursor-fix.sh status
```

## Troubleshooting

### Si el cursor sigue siendo inconsistente:

1. **Reinicia Hyprland** (para aplicar variables de entorno):
   ```bash
   hyprctl dispatch exit
   ```

2. **Ejecuta el fix manualmente**:
   ```bash
   ~/.config/hypr/scripts/system/cursor-fix.sh fix
   ```

3. **Verifica que el tema existe**:
   ```bash
   ~/.config/hypr/scripts/system/cursor-setup.sh list
   ```

4. **Reinicia aplicaciones específicas**:
   ```bash
   ~/.config/hypr/scripts/system/cursor-fix.sh reload
   ```

### Si una aplicación específica no respeta el cursor:

1. **Para aplicaciones GTK**: El cursor debería aplicarse automáticamente
2. **Para aplicaciones Qt**: Asegúrate de que `QT_CURSOR_THEME` esté configurado
3. **Para aplicaciones X11**: Pueden necesitar reinicio completo

## Configuración Avanzada

### Cambiar Tamaño de Cursor
Edita `config/environment.conf`:
```bash
envd = HYPRCURSOR_SIZE,32  # Cursor más grande
envd = XCURSOR_SIZE,32
envd = QT_CURSOR_SIZE,32
```

### Agregar Nuevo Tema de Cursor
1. Coloca el tema en `~/.icons/nombre_del_tema/`
2. Asegúrate de que tenga carpeta `cursors/`
3. Ejecuta: `~/.config/hypr/scripts/system/cursor-setup.sh apply nombre_del_tema`

## Archivos Modificados

- ✅ `config/environment.conf` - Variables de entorno
- ✅ `config/autostart.conf` - Autostart del cursor
- ✅ `config/keybinds.conf` - Keybinds para cursor
- ✅ `scripts/system/cursor-setup.sh` - Script principal
- ✅ `scripts/system/cursor-fix.sh` - Script de reparación
- ✅ `scripts/system/cursor-selector.sh` - Selector interactivo

## Resultado

Ahora tendrás un cursor consistente en:
- ✅ Ventanas de aplicaciones
- ✅ Barras de título
- ✅ Menús contextuales
- ✅ Aplicaciones GTK
- ✅ Aplicaciones Qt
- ✅ Rofi y otros launchers
- ✅ Todas las aplicaciones Wayland

**Nota**: Después de aplicar la configuración, reinicia Hyprland para que las variables de entorno tomen efecto completo.
