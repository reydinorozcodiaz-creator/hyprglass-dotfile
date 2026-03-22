pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "./AppearanceCommands.js" as AppearanceCommands

Singleton {
    id: root

    // Signals
    signal themeLoaded(string themeName, var data)
    signal pairSchemeLoaded(string pairName)
    signal themesListed(var themes)
    signal previewsLoaded(var previews)
    signal matugenFinished()
    signal matugenFailed()
    signal matugenPaletteLoaded(var palette)
    signal backendError(string area, string message)

    // System theme signals
    signal systemThemesListed(var gtkThemes, var iconThemes, var cursorThemes)
    signal currentSystemThemeLoaded(string gtkTheme, string iconTheme, string cursorTheme)
    signal systemThemeApplied()

    readonly property string unifierPath: Quickshell.env("HOME") + "/.config/hypr/scripts/system/theme-unifier.sh"

    // ========================================================================
    // PUBLIC API FOR THEMESERVICE
    // ========================================================================

    function loadTheme(themesDir, themeName) {
        loadThemeProc._themeName = themeName;
        loadThemeProc._buffer = "";
        loadThemeProc.command = ["cat", themesDir + "/" + themeName + ".json"];
        loadThemeProc.running = true;
    }

    function loadPairScheme(themesDir, currentThemeName, targetScheme) {
        _schemeSwitchProc._targetScheme = targetScheme;
        _schemeSwitchProc._buffer = "";
        _schemeSwitchProc.command = ["cat", themesDir + "/" + currentThemeName + ".json"];
        _schemeSwitchProc.running = true;
    }

    function listThemes(themesDir) {
        listThemesProc._themesDir = themesDir;
        listThemesProc._collected = [];
        listThemesProc.command = ["bash", "-c", AppearanceCommands.listJsonThemeNamesCommand(themesDir)];
        listThemesProc.running = true;
    }

    function loadPreviews(themesDir) {
        previewProc._buffer = "";
        previewProc.command = ["bash", "-c", AppearanceCommands.loadThemePreviewsCommand(themesDir)];
        previewProc.running = true;
    }

    // Side Effects API
    
    function applyHyprland(cmds) {
        if (cmds.length > 0) {
            hyprProc.command = ["bash", "-c", AppearanceCommands.applyHyprlandCommand(cmds)];
            hyprProc.running = true;
        }
    }

    function applyNeovim(nvimThemePath, colorscheme) {
        nvimProc.command = ["bash", "-c", AppearanceCommands.applyNeovimCommand(nvimThemePath, colorscheme)];
        nvimProc.running = true;
    }

    function applyWallpaper(wallpaperDir, wallpaperFile) {
        const path = wallpaperDir + "/" + wallpaperFile;
        wallpaperProc.command = ["bash", "-c", AppearanceCommands.applyWallpaperCommand(path)];
        wallpaperProc.running = true;
    }

    function writeGtkColors(gtkColorsPath3, gtkColorsPath4, content, gtkThemeName, scheme) {
        gtkProc.command = ["bash", "-c", AppearanceCommands.writeGtkColorsCommand(gtkColorsPath3, gtkColorsPath4, content, gtkThemeName, scheme)];
        gtkProc.running = true;
    }

    function clearGtkColors(gtkColorsPath3, gtkColorsPath4) {
        gtkProc.command = ["bash", "-c", AppearanceCommands.clearFilesCommand([gtkColorsPath3, gtkColorsPath4])];
        gtkProc.running = true;
    }

    function switchGtkTheme(gtkThemeName, scheme) {
        gtkThemeSwitchProc.command = ["bash", "-c", AppearanceCommands.switchGtkThemeCommand(gtkThemeName, scheme)];
        gtkThemeSwitchProc.running = true;
    }

    function writeQtColors(qtColorSchemePath, content) {
        qtProc.command = ["bash", "-c",
            AppearanceCommands.writeQtColorsCommand(
                Quickshell.env("HOME") + "/.local/share/color-schemes",
                qtColorSchemePath,
                content
            )];
        qtProc.running = true;
    }

    function clearQtColors(qtColorSchemePath) {
        qtProc.command = ["bash", "-c", AppearanceCommands.clearFilesCommand([qtColorSchemePath])];
        qtProc.running = true;
    }

    // Matugen API

    function runMatugen(wallpaperPath, colorScheme, matugenConfigPath) {
        matugenProc._buffer = "";
        matugenProc.command = ["matugen", "image", wallpaperPath, "-m", colorScheme, "-c", matugenConfigPath, "--source-color-index", "0"];
        matugenProc.running = true;
    }

    function loadMatugenPalette(matugenCachePath) {
        loadMatugenPaletteProc._buffer = "";
        loadMatugenPaletteProc.command = ["cat", matugenCachePath + "/quickshell-palette.json"];
        loadMatugenPaletteProc.running = true;
    }

    // ========================================================================
    // SYSTEM THEME API
    // ========================================================================

    function listSystemThemes() {
        _listSystemThemesProc._buffer = "";
        _listSystemThemesProc.command = ["bash", "-c", AppearanceCommands.listSystemThemesCommand()];
        _listSystemThemesProc.running = true;
    }

    function getCurrentSystemTheme() {
        _getCurrentThemeProc._buffer = "";
        _getCurrentThemeProc.command = ["bash", "-c", AppearanceCommands.currentSystemThemeCommand()];
        _getCurrentThemeProc.running = true;
    }

    function applySystemTheme(gtkTheme, iconTheme, cursorTheme) {
        _applySystemThemeProc.command = ["bash", "-c", AppearanceCommands.applySystemThemeCommand(unifierPath, gtkTheme, iconTheme, cursorTheme)];
        _applySystemThemeProc.running = true;
    }

    // ========================================================================
    // PROCESSES
    // ========================================================================

    Process {
        id: loadThemeProc
        property string _themeName: ""
        property string _buffer: ""

        stdout: SplitParser { onRead: data => loadThemeProc._buffer += data + "\n" }
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend] " + data) }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const data = JSON.parse(_buffer.trim());
                    root.themeLoaded(_themeName, data);
                } catch (e) {
                    console.error("[ThemeBackend] Failed to parse theme:", e);
                    root.backendError("theme", "No se pudo interpretar el preset " + _themeName + ".");
                }
            } else {
                console.error("[ThemeBackend] Theme file not found:", _themeName);
                root.backendError("theme", "No se encontro el preset " + _themeName + ".");
            }
            _buffer = "";
        }
    }

    Process {
        id: _schemeSwitchProc
        property string _targetScheme: ""
        property string _buffer: ""

        stdout: SplitParser { onRead: data => _schemeSwitchProc._buffer += data + "\n" }
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:SchemeSwitch] " + data) }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const data = JSON.parse(_buffer.trim());
                    var pairName = "";
                    if (_targetScheme === "light" && data.lightPair)
                        pairName = data.lightPair;
                    else if (_targetScheme === "dark" && data.darkPair)
                        pairName = data.darkPair;
                    
                    root.pairSchemeLoaded(pairName);
                } catch (e) {
                    console.error("[ThemeBackend] Failed to read pair:", e);
                    root.backendError("theme", "No se pudo resolver la variante " + _targetScheme + " del tema.");
                    root.pairSchemeLoaded("");
                }
            } else {
                root.pairSchemeLoaded("");
            }
            _buffer = "";
        }
    }

    Process {
        id: listThemesProc
        property string _themesDir: ""
        property var _collected: []

        stdout: SplitParser {
            onRead: data => {
                const name = data.trim();
                if (name) listThemesProc._collected.push(name);
            }
        }

        onExited: root.themesListed(_collected)
    }

    Process {
        id: previewProc
        property string _buffer: ""

        stdout: SplitParser { onRead: data => previewProc._buffer += data + "\n" }

        onExited: exitCode => {
            if (exitCode !== 0) return;

            const chunks = _buffer.split("---THEME_SEP---");
            var previews = {};

            for (var i = 0; i < chunks.length; i++) {
                var chunk = chunks[i].trim();
                if (!chunk) continue;

                var nameMatch = chunk.indexOf("---THEME_NAME:");
                if (nameMatch === -1) continue;
                var nameEnd = chunk.indexOf("---", nameMatch + 14);
                if (nameEnd === -1) continue;
                
                var themeName = chunk.substring(nameMatch + 14, nameEnd).trim();
                var jsonStr = chunk.substring(nameEnd + 3).trim();

                try {
                    var data = JSON.parse(jsonStr);
                    previews[themeName] = {
                        name: data.name || themeName,
                        palette: data.palette || {},
                        wallpaper: data.wallpaper || "",
                        variant: data.variant || "dark",
                        lightPair: data.lightPair || "",
                        darkPair: data.darkPair || ""
                    };
                } catch (e) {
                    console.error("[ThemeBackend] Preview parse error for " + themeName + ":", e);
                    root.backendError("theme", "Una vista previa de tema esta dañada: " + themeName + ".");
                }
            }

            root.previewsLoaded(previews);
            _buffer = "";
        }
    }

    Process {
        id: hyprProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:Hyprland] " + data) }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.backendError("hyprland", "No se pudo aplicar la paleta a Hyprland.");
        }
    }

    Process {
        id: nvimProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:Neovim] " + data) }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.backendError("neovim", "No se pudo actualizar el tema de Neovim.");
        }
    }

    Process {
        id: wallpaperProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:Wallpaper] " + data) }
        onExited: exitCode => {
            if (exitCode === 0) {
                // We use global WallpaperService here to trigger the signal
                WallpaperService.getCurrentWallpaper();
            } else {
                root.backendError("wallpaper", "No se pudo aplicar el wallpaper del tema.");
            }
        }
    }

    Process {
        id: gtkProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:GTK] " + data) }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.backendError("gtk", "No se pudieron escribir los colores GTK.");
        }
    }

    Process {
        id: gtkThemeSwitchProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:GtkSwitch] " + data) }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.backendError("gtk", "No se pudo cambiar el tema GTK.");
        }
    }

    Process {
        id: qtProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:Qt] " + data) }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.backendError("qt", "No se pudieron escribir los colores Qt.");
        }
    }

    Process {
        id: matugenProc
        property string _buffer: ""

        stdout: SplitParser { onRead: data => matugenProc._buffer += data + "\n" }
        stderr: SplitParser { onRead: data => console.log("[ThemeBackend:Matugen] " + data) }

        onExited: exitCode => {
            if (exitCode === 0) {
                root.matugenFinished();
            } else {
                console.error("[ThemeBackend] Matugen failed with exit code:", exitCode);
                root.backendError("matugen", "No se pudo generar la paleta automatica.");
                root.matugenFailed();
            }
            _buffer = "";
        }
    }

    Process {
        id: loadMatugenPaletteProc
        property string _buffer: ""

        stdout: SplitParser { onRead: data => loadMatugenPaletteProc._buffer += data + "\n" }
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:MatugenPalette] " + data) }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const pal = JSON.parse(_buffer.trim());
                    root.matugenPaletteLoaded(pal);
                } catch (e) {
                    console.error("[ThemeBackend] Failed to parse matugen palette:", e);
                    root.backendError("matugen", "La paleta generada por Matugen no pudo leerse.");
                }
            }
            _buffer = "";
        }
    }

    // ========================================================================
    // SYSTEM THEME PROCESSES
    // ========================================================================

    Process {
        id: _listSystemThemesProc
        property string _buffer: ""

        stdout: SplitParser { onRead: data => _listSystemThemesProc._buffer += data + "\n" }
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:ListSystem] " + data) }

        onExited: exitCode => {
            const sections = _buffer.split("---SECTION---");
            var gtkThemes = [], iconThemes = [], cursorThemes = [];

            if (sections.length >= 1)
                gtkThemes = sections[0].trim().split("\n").filter(s => s.length > 0);
            if (sections.length >= 2)
                iconThemes = sections[1].trim().split("\n").filter(s => s.length > 0);
            if (sections.length >= 3)
                cursorThemes = sections[2].trim().split("\n").filter(s => s.length > 0);

            root.systemThemesListed(gtkThemes, iconThemes, cursorThemes);
            _buffer = "";
        }
    }

    Process {
        id: _getCurrentThemeProc
        property string _buffer: ""

        stdout: SplitParser { onRead: data => _getCurrentThemeProc._buffer += data + "\n" }

        onExited: exitCode => {
            const parts = _buffer.split("---SEP---");
            var gtk = "", icons = "", cursor = "";
            if (parts.length >= 1) gtk = parts[0].trim();
            if (parts.length >= 2) icons = parts[1].trim();
            if (parts.length >= 3) cursor = parts[2].trim();
            root.currentSystemThemeLoaded(gtk, icons, cursor);
            _buffer = "";
        }
    }

    Process {
        id: _applySystemThemeProc
        stderr: SplitParser { onRead: data => console.log("[ThemeBackend:SystemApply] " + data) }

        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("[ThemeBackend] System theme applied successfully");
                root.systemThemeApplied();
            } else {
                console.error("[ThemeBackend] System theme apply failed with code:", exitCode);
            }
        }
    }
}
