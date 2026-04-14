pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string hyprConfigDir: Quickshell.env("HOME") + "/.config/hypr"
    readonly property string hyprMainFile: root.hyprConfigDir + "/hyprland.conf"
    readonly property string hyprDefaultsFile: root.hyprConfigDir + "/config/10-defaults.conf"
    readonly property string hyprKeybindsFile: root.hyprConfigDir + "/config/70-keybinds.conf"
    readonly property string parserScriptPath: Qt.resolvedUrl("../../scripts/tools/parse-hypr-keybinds.py").toString().replace("file://", "")

    property var sections: []
    property bool isLoading: false
    property string lastError: ""

    Component.onCompleted: reload()

    FileView {
        path: root.hyprMainFile
        watchChanges: true
        onFileChanged: reloadDebounce.restart()
    }

    FileView {
        path: root.hyprDefaultsFile
        watchChanges: true
        onFileChanged: reloadDebounce.restart()
    }

    FileView {
        path: root.hyprKeybindsFile
        watchChanges: true
        onFileChanged: reloadDebounce.restart()
    }

    Timer {
        id: reloadDebounce
        interval: 150
        onTriggered: root.reload()
    }

    function reload() {
        if (loadProc.running) {
            reloadDebounce.restart();
            return;
        }

        root.isLoading = true;
        root.lastError = "";
        loadProc.command = [
            "python3",
            root.parserScriptPath,
            root.hyprMainFile,
            root.hyprDefaultsFile,
            root.hyprKeybindsFile
        ];
        loadProc.running = true;
    }

    Process {
        id: loadProc

        property string buffer: ""
        property string errBuffer: ""

        stdout: SplitParser {
            onRead: data => {
                loadProc.buffer += data;
            }
        }

        stderr: SplitParser {
            onRead: data => {
                loadProc.errBuffer += data;
            }
        }

        onStarted: {
            buffer = "";
            errBuffer = "";
        }

        onExited: (exitCode) => {
            root.isLoading = false;

            if (exitCode !== 0) {
                root.sections = [];
                root.lastError = loadProc.errBuffer.trim() || "No se pudo leer la configuracion de Hyprland.";
                console.error("[HyprKeybindsService] " + root.lastError);
                return;
            }

            try {
                const parsed = JSON.parse(loadProc.buffer.trim() || "[]");
                root.sections = parsed;
                root.lastError = "";
            } catch (error) {
                root.sections = [];
                root.lastError = "No se pudo interpretar la salida del parser.";
                console.error("[HyprKeybindsService] Parse error:", error);
            }
        }
    }
}
