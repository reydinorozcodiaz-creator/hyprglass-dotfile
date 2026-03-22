pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string historyPath: Quickshell.env("HOME") + "/.config/quickshell/ai-history.json"

    property var state: ({})
    property bool isLoading: true

    Component.onCompleted: loadState()

    FileView {
        id: historyWatcher
        path: root.historyPath
        watchChanges: true

        onFileChanged: reloadDebounce.restart()
    }

    Timer {
        id: reloadDebounce
        interval: 150
        onTriggered: {
            if (!loadProc.running)
                root.loadState();
        }
    }

    function get(path: string, defaultValue) {
        const keys = path.split('.');
        let current = state;
        for (const key of keys) {
            if (current !== null && typeof current === 'object' && key in current) {
                current = current[key];
            } else {
                return defaultValue;
            }
        }
        return current;
    }

    function set(path: string, value) {
        const keys = path.split('.');
        let current = state;
        for (let i = 0; i < keys.length - 1; i++) {
            const key = keys[i];
            if (!(key in current) || typeof current[key] !== 'object')
                current[key] = {};
            current = current[key];
        }
        current[keys[keys.length - 1]] = value;
        if (!isLoading)
            saveState();
    }

    function loadState() {
        isLoading = true;
        loadProc.running = true;
    }

    function saveState() {
        const jsonStr = JSON.stringify(state, null, 2);
        saveProc.command = ["bash", "-c",
            "umask 077 && mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1.tmp\" && chmod 600 \"$1.tmp\" && mv \"$1.tmp\" \"$1\"",
            "--", historyPath, jsonStr];
        saveProc.running = true;
    }

    Process {
        id: loadProc
        command: ["bash", "-c", "cat '" + root.historyPath + "' 2>/dev/null || echo '{}'"]

        property string buffer: ""

        stdout: SplitParser {
            onRead: data => loadProc.buffer += data
        }

        onExited: {
            try {
                const newState = JSON.parse(loadProc.buffer.trim());
                const changed = JSON.stringify(root.state) !== JSON.stringify(newState);
                root.state = newState;
                root.isLoading = false;
                loadProc.buffer = "";
                if (changed)
                    root.stateLoaded();
            } catch (e) {
                console.error("[AiHistoryService] JSON Parse Error:", e);
                root.isLoading = false;
                loadProc.buffer = "";
            }
        }
    }

    Process {
        id: saveProc
    }

    signal stateLoaded
}
