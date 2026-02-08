# ✨ HyprGlass Dotfiles

![Hyprland Version](https://img.shields.io/badge/Hyprland-v0.40+-blue?style=for-the-badge&logo=archlinux)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

Una configuración minimalista y estética para **Hyprland** en Arch Linux, enfocada en el estilo "Glassmorphism" (efectos de cristal/desenfoque).

<p align="center">
  <img src="assets/screenshots/preview.png" alt="Preview" width="100%">
</p>

## 🚀 Características

- **Compositor**: Hyprland con animaciones fluidas y blur.
- **Barra**: Waybar (Estilo Glass personalizado).
- **Lanzador**: Rofi / Fuzzel.
- **Notificaciones**: SwayNC & Dunst.
- **Terminal**: Kitty con transparencia.
- **Shell**: ZSH + Oh My Zsh + Powerlevel10k (Autocompletado y resaltado de sintaxis).
- **Login Manager (DM)**: SDDM con tema **Astronaut**.
- **Bootloader**: GRUB con tema **Lain**.
- **Instalador**: Script interactivo automatizado.

## 📦 Instalación

Este entorno está optimizado para **Arch Linux** y distribuciones basadas (EndeavourOS, Garuda, etc.).

### 1. Clonar el repositorio

```bash
git clone https://github.com/reydinorozcodiaz-creator/HyprGlass-dotfile.git
cd HyprGlass-dotfile
```

### 2. Ejecutar el instalador

El script se encargará de instalar paquetes (yay/paru), enlazar configuraciones y establecer temas.

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

### 3. Menú Interactivo

Verás un menú con las siguientes opciones:

1. **Full Installation**: Instala TODO (Paquetes, Dotfiles, SDDM, GRUB, ZSH). ⭐️ _Recomendado_
2. **Packages Only**: Solo instala dependencias de `requirements/arch-pacman.txt`.
3. **Dotfiles Only**: Enlaza las carpetas de `configs/` a tu usuario.
4. **SDDM Only**: Configura el tema Astronaut.
5. **ZSH Only**: Configura Oh My Zsh + Plugins + P10k.
6. **GRUB Only**: Configura el tema Lain.

> **Nota:** Al finalizar, reinicia tu sistema para aplicar los cambios de sesión y variables de entorno.

## ⌨️ Atajos de Teclado (Keybinds)

Los atajos principales están definidos en `~/.config/hypr/config/70-keybinds.conf`.

| Atajo               | Acción                            |
| ------------------- | --------------------------------- |
| `Super + Enter`     | Abrir Terminal (Kitty)            |
| `Super + Q`         | Cerrar ventana activa             |
| `Super + E`         | Explorador de archivos (Nautilus) |
| `Super + B`         | Navegador Web (Firefox)           |
| `Super + R` / `D`   | Lanzador de aplicaciones (Rofi)   |
| `Super + Shift + S` | Captura de pantalla (Región)      |
| `Super + L`         | Bloquear pantalla                 |
| `Super + M`         | Salir de Hyprland                 |

## 📂 Estructura

```
HyprGlass-dotfile/
├── configs/
│   ├── config/      # Configuraciones para ~/.config (hypr, waybar, kitty...)
│   ├── home/        # Archivos para el HOME (~/.zshrc, Wallpapers...)
│   └── system/      # Config del sistema (SDDM, GRUB)
├── scripts/         # Scripts de instalación y utilidades
├── requirements/    # Listas de paquetes necesarios
└── assets/          # Capturas de pantalla y recursos
```

## créditos

- Basado en el trabajo de **@Shidohs** (Hyprland Glass).
- Adaptado y mantenido por **@reydinorozcodiaz-creator**.
