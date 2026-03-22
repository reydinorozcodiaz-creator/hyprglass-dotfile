pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

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

    // System theme signals
    signal systemThemesListed(var gtkThemes, var iconThemes, var cursorThemes)
    signal currentSystemThemeLoaded(string gtkTheme, string iconTheme, string cursorTheme)
    signal systemThemeApplied()

    // Helper functions from ThemeService needed here
    function shellEscape(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'";
    }

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
        listThemesProc.command = ["bash", "-c", "ls -1 '" + themesDir + "'/*.json 2>/dev/null | sed 's|.*/||;s|\\.json$||' | sort"];
        listThemesProc.running = true;
    }

    function loadPreviews(themesDir) {
        previewProc._buffer = "";
        previewProc.command = ["bash", "-c", "for f in '" + themesDir + "'/*.json; do echo \"---THEME_NAME:$(basename \"$f\" .json)---\"; cat \"$f\"; echo '---THEME_SEP---'; done"];
        previewProc.running = true;
    }

    // Side Effects API
    
    function applyHyprland(cmds) {
        if (cmds.length > 0) {
            hyprProc.command = ["bash", "-c", cmds.join(" && ")];
            hyprProc.running = true;
        }
    }

    function applyNeovim(nvimThemePath, colorscheme) {
        nvimProc.command = ["bash", "-c", "echo '" + colorscheme + "' > " + shellEscape(nvimThemePath) + " && " + "for sock in /run/user/$(id -u)/nvim.*.0; do " + "  [ -S \"$sock\" ] && nvim --server \"$sock\" --remote-send '<Cmd>colorscheme " + colorscheme + "<CR>' 2>/dev/null & " + "done; wait"];
        nvimProc.running = true;
    }

    function applyWallpaper(wallpaperDir, wallpaperFile) {
        const path = wallpaperDir + "/" + wallpaperFile;
        wallpaperProc.command = ["bash", "-c", "[ -f '" + path + "' ] && swww img '" + path + "'" + " --transition-type grow --transition-duration 1 --transition-fps 60 --transition-step 90" + " || echo '[ThemeBackend] Wallpaper not found: " + wallpaperFile + "' >&2"];
        wallpaperProc.running = true;
    }

    function writeGtkColors(gtkColorsPath3, gtkColorsPath4, content, gtkThemeName, scheme) {
        gtkProc.command = ["bash", "-c",
            "cat > " + shellEscape(gtkColorsPath3) + " << 'GTK_EOF'\n" + content + "GTK_EOF\n" +
            "cp " + shellEscape(gtkColorsPath3) + " " + shellEscape(gtkColorsPath4) + " && " +
            "gsettings set org.gnome.desktop.interface gtk-theme " + shellEscape(gtkThemeName) + " 2>/dev/null; " +
            "gsettings set org.gnome.desktop.interface color-scheme " + shellEscape(scheme) + " 2>/dev/null; true"
        ];
        gtkProc.running = true;
    }

    function clearGtkColors(gtkColorsPath3, gtkColorsPath4) {
        gtkProc.command = ["bash", "-c", "rm -f " + shellEscape(gtkColorsPath3) + " " + shellEscape(gtkColorsPath4)];
        gtkProc.running = true;
    }

    function switchGtkTheme(gtkThemeName, scheme) {
        gtkThemeSwitchProc.command = ["bash", "-c",
            "gsettings set org.gnome.desktop.interface gtk-theme " + shellEscape(gtkThemeName) + " 2>/dev/null; " +
            "gsettings set org.gnome.desktop.interface color-scheme " + shellEscape(scheme) + " 2>/dev/null; true"];
        gtkThemeSwitchProc.running = true;
    }

    function writeQtColors(qtColorSchemePath, content) {
        qtProc.command = ["bash", "-c",
            "mkdir -p " + shellEscape(Quickshell.env("HOME") + "/.local/share/color-schemes") + " && " +
            "cat > " + shellEscape(qtColorSchemePath) + " << 'QT_EOF'\n" + content + "QT_EOF"];
        qtProc.running = true;
    }

    function clearQtColors(qtColorSchemePath) {
        qtProc.command = ["bash", "-c", "rm -f " + shellEscape(qtColorSchemePath)];
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
        // Script outputs 3 sections separated by ---SECTION---
        _listSystemThemesProc.command = ["bash", "-c",
            // GTK themes: dirs containing gtk-3.0 or gtk-4.0
            "for d in /usr/share/themes $HOME/.themes $HOME/.local/share/themes; do " +
            "  [ -d \"$d\" ] && for t in \"$d\"/*/; do " +
            "    [ -d \"${t}gtk-3.0\" ] || [ -d \"${t}gtk-4.0\" ] && basename \"$t\"; " +
            "  done; " +
            "done | sort -u; " +
            "echo '---SECTION---'; " +
            // Icon themes: dirs containing index.theme but NOT only cursors
            "for d in /usr/share/icons $HOME/.icons $HOME/.local/share/icons; do " +
            "  [ -d \"$d\" ] && for t in \"$d\"/*/; do " +
            "    [ -f \"${t}index.theme\" ] && basename \"$t\"; " +
            "  done; " +
            "done | sort -u; " +
            "echo '---SECTION---'; " +
            // Cursor themes: dirs containing cursors/
            "for d in /usr/share/icons $HOME/.icons $HOME/.local/share/icons; do " +
            "  [ -d \"$d\" ] && for t in \"$d\"/*/; do " +
            "    [ -d \"${t}cursors\" ] && basename \"$t\"; " +
            "  done; " +
            "done | sort -u"
        ];
        _listSystemThemesProc.running = true;
    }

    function getCurrentSystemTheme() {
        _getCurrentThemeProc._buffer = "";
        _getCurrentThemeProc.command = ["bash", "-c",
            "gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d \"'\" ; " +
            "echo '---SEP---'; " +
            "gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d \"'\" ; " +
            "echo '---SEP---'; " +
            "gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d \"'\""
        ];
        _getCurrentThemeProc.running = true;
    }

    function applySystemTheme(gtkTheme, iconTheme, cursorTheme) {
        // Patch theme-unifier.sh variables and run apply
        var cmds = [];
        if (gtkTheme)
            cmds.push("sed -i 's/^GTK_THEME=\".*\"/GTK_THEME=\"" + gtkTheme + "\"/' " + shellEscape(unifierPath));
        if (iconTheme)
            cmds.push("sed -i 's/^ICON_THEME=\".*\"/ICON_THEME=\"" + iconTheme + "\"/' " + shellEscape(unifierPath));
        if (cursorTheme)
            cmds.push("sed -i 's/^CURSOR_THEME=\".*\"/CURSOR_THEME=\"" + cursorTheme + "\"/' " + shellEscape(unifierPath));

        // Run unifier apply
        cmds.push(shellEscape(unifierPath) + " apply");

        // Immediate cursor change via hyprctl
        if (cursorTheme)
            cmds.push("hyprctl setcursor '" + cursorTheme + "' 24");

        _applySystemThemeProc.command = ["bash", "-c", cmds.join(" && ")];
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
                }
            } else {
                console.error("[ThemeBackend] Theme file not found:", _themeName);
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
                }
            }

            root.previewsLoaded(previews);
            _buffer = "";
        }
    }

    Process {
        id: hyprProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:Hyprland] " + data) }
    }

    Process {
        id: nvimProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:Neovim] " + data) }
    }

    Process {
        id: wallpaperProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:Wallpaper] " + data) }
        onExited: exitCode => {
            if (exitCode === 0) {
                // We use global WallpaperService here to trigger the signal
                WallpaperService.getCurrentWallpaper();
            }
        }
    }

    Process {
        id: gtkProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:GTK] " + data) }
    }

    Process {
        id: gtkThemeSwitchProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:GtkSwitch] " + data) }
    }

    Process {
        id: qtProc
        stderr: SplitParser { onRead: data => console.error("[ThemeBackend:Qt] " + data) }
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
