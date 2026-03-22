pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    visible: false
    width: 0
    height: 0

    required property string storePath
    property var fallbackPaths: []
    property bool secureWrite: false
    property string logPrefix: "JsonStore"

    property var state: ({})
    property bool isLoading: true
    property bool _savePending: false

    signal stateLoaded

    Component.onCompleted: loadState()

    FileView {
        id: storeWatcher
        path: root.storePath
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

    Timer {
        id: saveDebounce
        interval: 200
        onTriggered: root._flushSaveState()
    }

    function shellEscape(str) {
        return "'" + String(str).replace(/'/g, "'\\''") + "'";
    }

    function _loadCandidates() {
        const candidates = [];
        if (storePath)
            candidates.push(storePath);

        const extras = fallbackPaths || [];
        for (let i = 0; i < extras.length; i++) {
            const candidate = extras[i];
            if (candidate && candidates.indexOf(candidate) === -1)
                candidates.push(candidate);
        }

        return candidates;
    }

    function _buildLoadCommand() {
        const candidates = _loadCandidates();
        const parts = [];

        for (let i = 0; i < candidates.length; i++)
            parts.push("cat " + shellEscape(candidates[i]) + " 2>/dev/null");

        parts.push("echo '{}'");
        return parts.join(" || ");
    }

    function get(path, defaultValue) {
        const keys = path.split('.');
        let current = state;
        for (const key of keys) {
            if (current !== null && typeof current === "object" && key in current)
                current = current[key];
            else
                return defaultValue;
        }
        return current;
    }

    function set(path, value) {
        const keys = path.split('.');
        let current = state;
        for (let i = 0; i < keys.length - 1; i++) {
            const key = keys[i];
            if (!(key in current) || typeof current[key] !== "object")
                current[key] = {};
            current = current[key];
        }
        current[keys[keys.length - 1]] = value;
        if (!isLoading)
            saveState();
    }

    function remove(path) {
        const keys = path.split('.');
        let current = state;
        let parents = [];

        for (let i = 0; i < keys.length - 1; i++) {
            const key = keys[i];
            if (current === null || typeof current !== "object" || !(key in current))
                return;
            parents.push({ parent: current, key: key });
            current = current[key];
        }

        const leafKey = keys[keys.length - 1];
        if (current === null || typeof current !== "object" || !(leafKey in current))
            return;

        delete current[leafKey];

        for (let i = parents.length - 1; i >= 0; --i) {
            const entry = parents[i];
            const child = entry.parent[entry.key];
            if (child && typeof child === "object" && Object.keys(child).length === 0)
                delete entry.parent[entry.key];
            else
                break;
        }

        if (!isLoading)
            saveState();
    }

    function loadState() {
        isLoading = true;
        loadProc.command = ["bash", "-c", _buildLoadCommand()];
        loadProc.running = true;
    }

    function saveState() {
        _savePending = true;
        if (isLoading)
            return;
        saveDebounce.restart();
    }

    function _flushSaveState() {
        if (!_savePending || isLoading)
            return;
        if (saveProc.running) {
            saveDebounce.restart();
            return;
        }
        _savePending = false;
        const jsonStr = JSON.stringify(state, null, 2);
        const baseCommand = secureWrite
            ? "umask 077 && mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1.tmp\" && chmod 600 \"$1.tmp\" && mv \"$1.tmp\" \"$1\""
            : "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1.tmp\" && mv \"$1.tmp\" \"$1\"";

        saveProc.command = ["bash", "-c", baseCommand, "--", storePath, jsonStr];
        saveProc.running = true;
    }

    Process {
        id: loadProc
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
                console.error("[" + root.logPrefix + "] JSON Parse Error:", e);
                root.isLoading = false;
                loadProc.buffer = "";
            }
        }
    }

    Process {
        id: saveProc
        onExited: {
            if (root._savePending)
                saveDebounce.restart();
        }
    }
}
