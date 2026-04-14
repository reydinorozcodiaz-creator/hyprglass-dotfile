pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "."

/**
 * StateService - Global persistent state management for QuickShell
 * 
 * @singleton
 * @extends JsonStore
 * 
 * Provides a centralized JSON-backed state store with automatic save/load.
 * Supports deep merge from fallback paths (legacy state, defaults).
 * 
 * Key Methods (inherited from JsonStore):
 * - get(path: string, defaultValue: any) - Get value at dot-notation path
 * - set(path: string, value: any) - Set value and trigger auto-save
 * - remove(path: string) - Remove value and cleanup empty parent objects
 * - merge(obj: object) - Deep merge object into current state
 * 
 * Properties:
 * - state: object - Current state object
 * - isLoading: bool - True while initial load is in progress
 * 
 * Architecture:
 * - ARCH-001: Race condition fixed - load/save operations now use mutex
 * - Auto-saves with 200ms debounce to avoid excessive disk writes
 * - Watches file for external changes and reloads with 150ms debounce
 * 
 * Usage:
 *   StateService.set("bar.height", 48)
 *   let height = StateService.get("bar.height", 44)
 *   StateService.merge({ theme: { mode: "dark" } })
 */
JsonStore {
    id: root

    storePath: Quickshell.env("HOME") + "/.config/quickshell/data/state/state.json"
    readonly property string defaultsPath: Quickshell.env("HOME") + "/.lyne-dots/.data/quickshell/defaults.json"
    readonly property string legacyStatePath: Quickshell.env("HOME") + "/.config/quickshell/state.json"
    fallbackPaths: [
        legacyStatePath,
        defaultsPath,
    ]
    logPrefix: "StateService"

    function _isPlainObject(value) {
        return value !== null && typeof value === "object" && !Array.isArray(value);
    }

    function _deepMerge(baseValue, extraValue) {
        if (!_isPlainObject(baseValue) || !_isPlainObject(extraValue))
            return extraValue;

        const merged = ({});
        const baseKeys = Object.keys(baseValue);
        for (let i = 0; i < baseKeys.length; i++) {
            const key = baseKeys[i];
            merged[key] = baseValue[key];
        }

        const extraKeys = Object.keys(extraValue);
        for (let i = 0; i < extraKeys.length; i++) {
            const key = extraKeys[i];
            if (key in merged)
                merged[key] = _deepMerge(merged[key], extraValue[key]);
            else
                merged[key] = extraValue[key];
        }

        return merged;
    }

    function _mergeLegacyState(legacyState) {
        if (!_isPlainObject(legacyState))
            return;

        const merged = _deepMerge(root.state || ({}), legacyState);
        const changed = JSON.stringify(root.state) !== JSON.stringify(merged);
        if (!changed)
            return;

        root.state = merged;
        root.saveState();
        root.stateLoaded();
    }

    FileView {
        id: legacyStateWatcher
        path: root.legacyStatePath
        watchChanges: true

        onFileChanged: {
            if (!root.isLoading)
                legacyReloadDebounce.restart();
        }
    }

    Timer {
        id: legacyReloadDebounce
        interval: 150
        onTriggered: {
            if (!legacyLoadProc.running)
                legacyLoadProc.running = true;
        }
    }

    Process {
        id: legacyLoadProc
        command: ["cat", root.legacyStatePath]
        property string buffer: ""

        stdout: SplitParser {
            onRead: data => legacyLoadProc.buffer += data
        }

        onStarted: buffer = ""

        onExited: (exitCode) => {
            const payload = buffer.trim();
            buffer = "";

            if (exitCode !== 0 || !payload)
                return;

            try {
                root._mergeLegacyState(JSON.parse(payload));
            } catch (e) {
                console.error("[StateService] Legacy state sync failed:", e);
            }
        }
    }
}
