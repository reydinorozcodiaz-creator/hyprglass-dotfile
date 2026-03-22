pragma Singleton
pragma ComponentBehavior: Bound

// ThemeService — gestiona todos los temas del shell.
//
// Dependencias:
//   - StateService: lee/escribe theme.name, theme.mode, theme.scheme, wallpaper.current
//   - WallpaperService: notificado cuando el tema cambia el wallpaper
//   - Config.qml: lee ThemeService.color() para todos los colores de la UI
//
// Flujo de aplicación de tema (modo preset):
//   applyTheme(name) → loadThemeProc (cat JSON) → _applyThemeData()
//     ├─ palette → Config.qml se actualiza reactivamente
//     ├─ hyprland → hyprProc (hyprctl keyword)
//     ├─ neovim  → nvimProc (socket + archivo)
//     ├─ wallpaper → wallpaperProc (swww img)
//     ├─ GTK    → gtkProc (colors.css) + gtkThemeSwitchProc (gsettings)
//     └─ Qt     → qtProc (Lyne.colors)
//
// Flujo en modo auto (Material You):
//   runMatugen(wallpath) → matugenProc → loadMatugenPaletteProc → palette

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.config

Singleton {
    id: root

    // Helper function to shorten the service call
    function getState(path, fallback) {
        return StateService.get(path, fallback);
    }

    function setState(path, value) {
        StateService.set(path, value);
    }

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    readonly property string themesDir: Quickshell.env("HOME") + "/.local/themes"
    readonly property string nvimThemePath: Quickshell.env("HOME") + "/.config/nvim/current-theme.txt"
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.local/wallpapers"

    // GTK/Qt paths
    readonly property string gtkColorsPath3: Quickshell.env("HOME") + "/.config/gtk-3.0/colors.css"
    readonly property string gtkColorsPath4: Quickshell.env("HOME") + "/.config/gtk-4.0/colors.css"
    readonly property string qtColorSchemePath: Quickshell.env("HOME") + "/.local/share/color-schemes/Lyne.colors"
    readonly property string matugenConfigPath: Quickshell.env("HOME") + "/.config/quickshell/matugen/config.toml"
    readonly property string matugenCachePath: Quickshell.env("HOME") + "/.cache/matugen"

    property string currentThemeName: getState("theme.name", "tokyonight")
    property string themeMode: getState("theme.mode", "preset") // "preset" | "auto"
    property string colorScheme: getState("theme.scheme", "dark") // "dark" | "light"
    readonly property bool isAutoMode: themeMode === "auto"
    readonly property bool isDarkMode: colorScheme === "dark"
    readonly property string gtkThemeName: isDarkMode ? "adw-gtk3-dark" : "adw-gtk3"
    property var availableThemes: []

    // System theme state
    property string systemGtkTheme: ""
    property string systemIconTheme: ""
    property string systemCursorTheme: ""
    property var availableGtkThemes: []
    property var availableIconThemes: []
    property var availableCursorThemes: []

    // Themes filtered by current color scheme (dark shows dark, light shows light)
    readonly property var displayThemes: {
        var result = [];
        var themes = availableThemes;
        var previews = themePreviews;
        var scheme = colorScheme;
        for (var i = 0; i < themes.length; i++) {
            var name = themes[i];
            var preview = previews[name];
            var variant = (preview && preview.variant) ? preview.variant : "dark";
            if (variant === scheme)
                result.push(name);
        }
        // If no themes match (e.g. no light presets yet), show all
        if (result.length === 0)
            return themes;
        return result;
    }

    // Preview data: { "themeName": { name, palette: { background, accent, ... } } }
    property var themePreviews: ({})

    // The palette is the single source of truth for all colors
    // Config.qml reads from here
    property var palette: ({
            "background": "#1a1b26",
            "surface0": "#24283b",
            "surface1": "#292e42",
            "surface2": "#414868",
            "surface3": "#565f89",
            "text": "#c0caf5",
            "textReverse": "#1a1b26",
            "subtext": "#a9b1d6",
            "subtextReverse": "#565f89",
            "accent": "#7aa2f7",
            "success": "#9ece6a",
            "warning": "#e0af68",
            "error": "#f7768e",
            "muted": "#545c7e",
            "greyBlue": "#283457",
            "blueDark": "#16161e"
        })

    // Helper for Config.qml to read palette with fallback
    function color(key, fallback) {
        return palette[key] ?? fallback;
    }

    // ========================================================================
    // INITIALIZATION & CONNECTIONS
    // ========================================================================

    Component.onCompleted: {
        listThemes();
        ThemeBackendService.listSystemThemes();
        ThemeBackendService.getCurrentSystemTheme();
    }

    Connections {
        target: ThemeBackendService
        function onThemeLoaded(themeName, data) {
            root._applyThemeData(themeName, data);
        }
        function onPairSchemeLoaded(pairName) {
            if (pairName) {
                console.log("[ThemeService] Switching to pair theme:", pairName);
                root.applyTheme(pairName);
            } else {
                console.log("[ThemeService] No pair for scheme, re-applying current theme");
                root.applyTheme(root.currentThemeName);
            }
        }
        function onThemesListed(themes) {
            root.availableThemes = themes;
            console.log("[ThemeService] Available themes:", root.availableThemes.join(", "));
            root.loadPreviews();
        }
        function onPreviewsLoaded(previews) {
            root.themePreviews = previews;
            console.log("[ThemeService] Loaded previews for", Object.keys(previews).length, "themes");
        }
        function onMatugenFinished() {
            console.log("[ThemeService] Matugen finished, loading palette...");
            ThemeBackendService.loadMatugenPalette(root.matugenCachePath);
        }
        function onMatugenFailed() {
            console.error("[ThemeService] Matugen failed. Falling back to preset mode.");
            root.themeMode = "preset";
            root.setState("theme.mode", "preset");
        }
        function onMatugenPaletteLoaded(palette) {
            root.palette = palette;
            console.log("[ThemeService] Auto palette applied");
            root._loadAndApplyHyprlandColors();
        }

        // System theme connections
        function onSystemThemesListed(gtkThemes, iconThemes, cursorThemes) {
            root.availableGtkThemes = gtkThemes;
            root.availableIconThemes = iconThemes;
            root.availableCursorThemes = cursorThemes;
            console.log("[ThemeService] System themes: GTK=" + gtkThemes.length +
                ", Icons=" + iconThemes.length + ", Cursors=" + cursorThemes.length);
        }
        function onCurrentSystemThemeLoaded(gtkTheme, iconTheme, cursorTheme) {
            root.systemGtkTheme = gtkTheme;
            root.systemIconTheme = iconTheme;
            root.systemCursorTheme = cursorTheme;
            console.log("[ThemeService] Current system: GTK=" + gtkTheme +
                ", Icons=" + iconTheme + ", Cursor=" + cursorTheme);
        }
        function onSystemThemeApplied() {
            // Refresh current state after apply
            ThemeBackendService.getCurrentSystemTheme();
        }
    }

    // Load theme when state is ready
    Connections {
        target: StateService
        function onStateLoaded() {
            root.themeMode = root.getState("theme.mode", "preset");
            root.colorScheme = root.getState("theme.scheme", "dark");
            root.currentThemeName = root.getState("theme.name", "tokyonight");
            if (root.isAutoMode) {
                const wallpaper = root.getState("wallpaper.current", "");
                if (wallpaper) {
                    root.runMatugen(wallpaper, false);
                } else {
                    // Fallback to preset if no wallpaper
                    root.applyTheme(root.currentThemeName);
                }
            } else {
                root.applyTheme(root.currentThemeName);
            }
        }
    }

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    function applyTheme(themeName) {
        console.log("[ThemeService] Loading theme:", themeName);
        ThemeBackendService.loadTheme(themesDir, themeName);
    }

    function setPresetMode(themeName) {
        console.log("[ThemeService] Switching to preset mode:", themeName);
        themeMode = "preset";
        setState("theme.mode", "preset");
        applyTheme(themeName);
    }

    function setAutoMode() {
        console.log("[ThemeService] Switching to auto (Material You) mode");
        themeMode = "auto";
        setState("theme.mode", "auto");
        const wallpaper = getState("wallpaper.current", "");
        if (wallpaper) {
            runMatugen(wallpaper);
        }
    }

    function setColorScheme(scheme: string) {
        console.log("[ThemeService] Switching color scheme to:", scheme);
        colorScheme = scheme;
        setState("theme.scheme", scheme);

        // Update GTK theme name and gsettings
        _applyGtkThemeSwitch();

        // Re-apply current colors with new scheme
        if (isAutoMode) {
            const wallpaper = getState("wallpaper.current", "");
            if (wallpaper)
                runMatugen(wallpaper);
        } else {
            // Load current theme JSON to find the pair for the new scheme
            ThemeBackendService.loadPairScheme(themesDir, currentThemeName, scheme);
        }
    }

    function runMatugen(wallpaperPath: string, announce: bool = true) {
        console.log("[ThemeService] Running matugen on:", wallpaperPath);
        if (announce)
            OsdService.showMessage("󰏘", "Generating theme…");
        ThemeBackendService.runMatugen(wallpaperPath, colorScheme, matugenConfigPath);
    }

    function listThemes() {
        ThemeBackendService.listThemes(themesDir);
    }

    function loadPreviews() {
        ThemeBackendService.loadPreviews(themesDir);
    }

    // System theme API
    function setSystemGtkTheme(name) {
        console.log("[ThemeService] Setting system GTK theme:", name);
        systemGtkTheme = name;
        ThemeBackendService.applySystemTheme(name, "", "");
    }

    function setSystemIconTheme(name) {
        console.log("[ThemeService] Setting system icon theme:", name);
        systemIconTheme = name;
        ThemeBackendService.applySystemTheme("", name, "");
    }

    function setSystemCursorTheme(name) {
        console.log("[ThemeService] Setting system cursor theme:", name);
        systemCursorTheme = name;
        ThemeBackendService.applySystemTheme("", "", name);
    }

    // ========================================================================
    // INTERNAL
    // ========================================================================

    function _applyThemeData(themeName, data) {
        // 1. Update palette (triggers Config.qml rebinding)
        if (data.palette) {
            root.palette = data.palette;
        }

        // 2. Update opacity in StateService (user preference, not theme-owned)
        if (data.opacity && data.opacity.background !== undefined) {
            setState("opacity.background", data.opacity.background);
        }

        // 3. Save theme name
        currentThemeName = themeName;
        setState("theme.name", themeName);

        // 4. Apply to Hyprland
        _applyHyprland(data.hyprland);

        // (Kitty theme management is disabled - user has custom theme)

        // 6. Apply to Neovim
        _applyNeovim(data.neovim);

        // 7. Apply theme wallpaper
        _applyWallpaper(data.wallpaper);

        // 8. Apply GTK/Qt colors from palette
        _applyGtkFromPalette(data.palette);
        _applyQtFromPalette(data.palette);

        console.log("[ThemeService] Theme applied:", data.name || themeName);
    }

    function _applyHyprland(hyprColors) {
        if (!hyprColors)
            return;

        const cmds = [];
        if (hyprColors.activeBorder)
            cmds.push("hyprctl keyword general:col.active_border 'rgba(" + hyprColors.activeBorder + ")'");
        if (hyprColors.inactiveBorder)
            cmds.push("hyprctl keyword general:col.inactive_border 'rgba(" + hyprColors.inactiveBorder + ")'");
        if (hyprColors.shadowColor)
            cmds.push("hyprctl keyword decoration:shadow:color 'rgba(" + hyprColors.shadowColor + ")'");

        ThemeBackendService.applyHyprland(cmds);
    }

    function _applyNeovim(neovimConfig) {
        if (!neovimConfig || !neovimConfig.colorscheme)
            return;

        const colorscheme = neovimConfig.colorscheme;
        ThemeBackendService.applyNeovim(nvimThemePath, colorscheme);
    }

    function _applyWallpaper(wallpaperFile) {
        if (!wallpaperFile || !WallpaperService.dynamicWallpaper)
            return;

        ThemeBackendService.applyWallpaper(wallpaperDir, wallpaperFile);
    }

    function _clearGtkColors() {
        ThemeBackendService.clearGtkColors(gtkColorsPath3, gtkColorsPath4);
    }

    function _clearQtColors() {
        ThemeBackendService.clearQtColors(qtColorSchemePath);
    }

    function _applyGtkThemeSwitch() {
        const theme = gtkThemeName;
        const scheme = isDarkMode ? "prefer-dark" : "prefer-light";
        ThemeBackendService.switchGtkTheme(theme, scheme);
    }

    function _applyGtkFromPalette(pal) {
        if (!pal)
            return;

        var lines = [];
        lines.push("/* Auto-generated by ThemeService - Do not edit manually */");
        lines.push("");
        lines.push("@define-color accent_bg_color " + pal.accent + ";");
        lines.push("@define-color accent_color " + pal.accent + ";");
        lines.push("@define-color accent_fg_color " + pal.textReverse + ";");
        lines.push("");
        lines.push("@define-color window_bg_color " + pal.background + ";");
        lines.push("@define-color window_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color view_bg_color " + pal.background + ";");
        lines.push("@define-color view_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color headerbar_bg_color " + pal.surface0 + ";");
        lines.push("@define-color headerbar_fg_color " + pal.subtext + ";");
        lines.push("");
        lines.push("@define-color card_bg_color " + pal.surface0 + ";");
        lines.push("@define-color card_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color popover_bg_color " + pal.surface0 + ";");
        lines.push("@define-color popover_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color dialog_bg_color " + pal.surface1 + ";");
        lines.push("@define-color dialog_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color sidebar_bg_color " + pal.surface1 + ";");
        lines.push("@define-color sidebar_fg_color " + pal.subtext + ";");
        lines.push("");
        lines.push("@define-color destructive_bg_color " + pal.error + ";");
        lines.push("@define-color destructive_fg_color " + pal.textReverse + ";");
        lines.push("@define-color destructive_color " + pal.error + ";");
        lines.push("");
        lines.push("@define-color error_bg_color " + pal.error + ";");
        lines.push("@define-color error_fg_color " + pal.textReverse + ";");
        lines.push("@define-color error_color " + pal.error + ";");
        lines.push("");
        lines.push("@define-color success_bg_color " + pal.success + ";");
        lines.push("@define-color success_fg_color " + pal.textReverse + ";");
        lines.push("@define-color success_color " + pal.success + ";");
        lines.push("");
        lines.push("@define-color warning_bg_color " + pal.warning + ";");
        lines.push("@define-color warning_fg_color " + pal.textReverse + ";");
        lines.push("@define-color warning_color " + pal.warning + ";");
        lines.push("");

        const content = lines.join("\n");
        const scheme = isDarkMode ? "prefer-dark" : "prefer-light";

        ThemeBackendService.writeGtkColors(gtkColorsPath3, gtkColorsPath4, content, gtkThemeName, scheme);
    }

    function _applyQtFromPalette(pal) {
        if (!pal)
            return;

        const bg = hexToRgb(pal.background);
        const s0 = hexToRgb(pal.surface0);
        const s1 = hexToRgb(pal.surface1);
        const fg = hexToRgb(pal.text);
        const ac = hexToRgb(pal.accent);
        const fgR = hexToRgb(pal.textReverse);
        const sub = hexToRgb(pal.subtext);
        const err = hexToRgb(pal.error);
        const warn = hexToRgb(pal.warning);
        const succ = hexToRgb(pal.success);
        const muted = hexToRgb(pal.muted);

        var lines = [];
        lines.push("[ColorEffects:Disabled]");
        lines.push("Color=56,56,56");
        lines.push("ColorAmount=0");
        lines.push("ColorEffect=0");
        lines.push("ContrastAmount=0.65");
        lines.push("ContrastEffect=1");
        lines.push("IntensityAmount=0.1");
        lines.push("IntensityEffect=2");
        lines.push("");
        lines.push("[ColorEffects:Inactive]");
        lines.push("ChangeSelectionColor=true");
        lines.push("Color=112,111,110");
        lines.push("ColorAmount=0.025");
        lines.push("ColorEffect=2");
        lines.push("ContrastAmount=0.1");
        lines.push("ContrastEffect=2");
        lines.push("Enable=false");
        lines.push("IntensityAmount=0");
        lines.push("IntensityEffect=0");
        lines.push("");

        // Helper: generate a color group
        var groups = ["Button", "Header", "Selection", "Tooltip", "View", "Window"];
        for (var i = 0; i < groups.length; i++) {
            var group = groups[i];
            var bgColor = s0;
            var fgColor = fg;

            if (group === "View") bgColor = bg;
            if (group === "Header") bgColor = s1;
            if (group === "Window") bgColor = s0;
            if (group === "Tooltip") bgColor = s0;
            if (group === "Selection") { bgColor = ac; fgColor = fgR; }

            lines.push("[Colors:" + group + "]");
            lines.push("BackgroundAlternate=" + (group === "Selection" ? ac : s1));
            lines.push("BackgroundNormal=" + bgColor);
            lines.push("DecorationFocus=" + ac);
            lines.push("DecorationHover=" + ac);
            lines.push("ForegroundActive=" + ac);
            lines.push("ForegroundInactive=" + muted);
            lines.push("ForegroundLink=" + ac);
            lines.push("ForegroundNegative=" + err);
            lines.push("ForegroundNeutral=" + warn);
            lines.push("ForegroundNormal=" + fgColor);
            lines.push("ForegroundPositive=" + succ);
            lines.push("ForegroundVisited=" + sub);
            lines.push("");
        }

        lines.push("[General]");
        lines.push("ColorScheme=Lyne");
        lines.push("Name=Lyne");
        lines.push("");
        lines.push("[WM]");
        lines.push("activeBackground=" + s0);
        lines.push("activeBlend=" + bg);
        lines.push("activeForeground=" + fg);
        lines.push("inactiveBackground=" + bg);
        lines.push("inactiveBlend=" + bg);
        lines.push("inactiveForeground=" + muted);
        lines.push("");

        const content = lines.join("\n");
        ThemeBackendService.writeQtColors(qtColorSchemePath, content);
    }

    function hexToRgb(hex: string): string {
        if (!hex || hex.length < 7)
            return "0,0,0";
        var r = parseInt(hex.substring(1, 3), 16);
        var g = parseInt(hex.substring(3, 5), 16);
        var b = parseInt(hex.substring(5, 7), 16);
        return r + "," + g + "," + b;
    }

    function _loadAndApplyHyprlandColors() {
        // Generate Hyprland colors from palette
        const hyprColors = {
            activeBorder: palette.accent ? palette.accent.substring(1) + "ff" : "7aa2f7ff",
            inactiveBorder: palette.surface3 ? palette.surface3.substring(1) + "ff" : "565f89ff",
            shadowColor: palette.background ? palette.background.substring(1) + "cc" : "1a1b26cc"
        };
        root._applyHyprland(hyprColors);
    }
}
