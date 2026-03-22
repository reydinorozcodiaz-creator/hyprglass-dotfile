pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state.json"
    readonly property string defaultsPath: Quickshell.env("HOME") + "/.lyne-dots/.data/quickshell/defaults.json"

    property var state: ({})
    property bool isLoading: true

    Component.onCompleted: loadState()

    // Watch state.json for external changes (e.g. from lyne CLI)
    FileView {
        id: stateWatcher
        path: root.statePath
        watchChanges: true

        onFileChanged: _reloadDebounce.restart()
    }

    Timer {
        id: _reloadDebounce
        interval: 150
        onTriggered: {
            if (!loadProc.running)
                root.loadState();
        }
    }

    // --- Dot Notation Functions ---
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

    function remove(path: string) {
        const keys = path.split('.');
        let current = state;
        let parents = [];

        for (let i = 0; i < keys.length - 1; i++) {
            const key = keys[i];
            if (current === null || typeof current !== 'object' || !(key in current))
                return;
            parents.push({ parent: current, key: key });
            current = current[key];
        }

        const leafKey = keys[keys.length - 1];
        if (current === null || typeof current !== 'object' || !(leafKey in current))
            return;

        delete current[leafKey];

        for (let i = parents.length - 1; i >= 0; --i) {
            const entry = parents[i];
            const child = entry.parent[entry.key];
            if (child && typeof child === 'object' && Object.keys(child).length === 0)
                delete entry.parent[entry.key];
            else
                break;
        }

        if (!isLoading)
            saveState();
    }

    // --- IO Logic ---
    function loadState() {
        isLoading = true;
        loadProc.running = true;
    }

    function saveState() {
        const jsonStr = JSON.stringify(state, null, 2);
        // Escritura atómica: escribe a .tmp y luego renombra (rename(2) es atómico en el mismo filesystem).
        // Evita JSON corrupto si Quickshell crashea durante la escritura.
        saveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1.tmp\" && mv \"$1.tmp\" \"$1\"",
            "--", statePath, jsonStr];
        saveProc.running = true;
    }

    Process {
        id: loadProc
        command: ["bash", "-c", "cat '" + root.statePath + "' 2>/dev/null || cat '" + root.defaultsPath + "' 2>/dev/null || echo '{}'"]

        property string buffer: ""
        stdout: SplitParser {
            onRead: data => loadProc.buffer += data
        }

        onExited: (exitCode, exitStatus) => {
            try {
                const newState = JSON.parse(loadProc.buffer.trim());
                const changed = JSON.stringify(root.state) !== JSON.stringify(newState);
                root.state = newState;
                root.isLoading = false;
                loadProc.buffer = "";
                if (changed)
                    root.stateLoaded();
            } catch (e) {
                console.error("[StateService] JSON Parse Error:", e);
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
