# Neovim Config

Esta configuración está organizada por features para que sea más fácil de mantener, activar o recortar.

## Estructura

- `init.lua`: punto de entrada mínimo.
- `lua/config/`: opciones base, keymaps, autocmds, bootstrap de `lazy.nvim` y helpers del proyecto.
- `lua/plugins/`: plugins agrupados por dominio (`core`, `ui`, `git`, `lang`, `typescript`, `markdown`, `integrations`, `ai`, `debug`).
- `current-theme.txt`: selector simple del variant de Ayu (`ayu-dark`, `ayu-mirage`, `ayu-light`).
- `scripts/check-nvim.sh`: smoke check local para sintaxis y arranque headless.

## Configuración local

1. Copia `lua/config/local.lua.example` a `lua/config/local.lua`.
2. Ajusta solo lo que sea propio de tu máquina:
   - `obsidian_path`
   - `features`
   - overrides de AI
   - toggles de integraciones opcionales

`lua/config/local.lua` se ignora con `.gitignore` local de esta carpeta.

## Features

Puedes encender o apagar bloques enteros desde `lua/config/local.lua`:

```lua
return {
  features = {
    ai = false,
    debug = false,
    notes = true,
    database = false,
    ui_fx = true,
    wakatime = false,
  },
}
```

## Health Check

Ejecuta:

```vim
:ConfigHealth
```

Abre un reporte rápido con estado de features, rutas, variables de entorno y binarios relevantes.

## Dependencias externas esperadas

- `git`
- `make` para plugins nativos como `telescope-fzf-native.nvim`
- `npm` para `markdown-preview.nvim`
- binarios LSP/formatter/linter si no usas Mason
- `ollama` si usas `gen.nvim`
- `lazygit` si usas la integración Git

## Validación

```sh
./scripts/check-nvim.sh
```

El script valida sintaxis Lua y hace un arranque headless usando esta config.
