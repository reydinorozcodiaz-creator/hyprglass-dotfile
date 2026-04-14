pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // SECURITY FIX: Move lock file from /tmp to XDG_RUNTIME_DIR
    readonly property string lockFilePath: {
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR");
        if (runtimeDir) {
            return runtimeDir + "/quickshell-modules-open.lock";
        } else {
            // Fallback to config dir if XDG_RUNTIME_DIR not available
            return Quickshell.env("HOME") + "/.config/quickshell/data/runtime/modules-open.lock";
        }
    }
    
    // Ensure runtime directory exists
    Component.onCompleted: {
        const baseRuntimeDir = Quickshell.env("XDG_RUNTIME_DIR");
        if (!baseRuntimeDir) {
            // Create fallback runtime dir
            const fallbackDir = Quickshell.env("HOME") + "/.config/quickshell/data/runtime";
            ensureRuntimeDir.command = ["mkdir", "-p", fallbackDir];
            ensureRuntimeDir.running = true;
        }
        
        // Initial cleanup to avoid remnants
        removeFile.running = true;
    }
    
    Process {
        id: ensureRuntimeDir
        running: false
    }

    // Main boolean property for other modules to query
    readonly property bool anyModuleOpen: openWindowsCount > 0
    property int openWindowsCount: 0

    // List to know EXACTLY what is open
    property var activeModules: ({})

    function registerOpen(moduleName) {
        if (!activeModules[moduleName]) {
            activeModules = Object.assign({}, activeModules, { [moduleName]: true });
            openWindowsCount++;
        }
    }

    function registerClose(moduleName) {
        if (activeModules[moduleName]) {
            const copy = Object.assign({}, activeModules);
            delete copy[moduleName];
            activeModules = copy;
            openWindowsCount = Math.max(0, openWindowsCount - 1);
        }
    }

    onAnyModuleOpenChanged: {
        if (anyModuleOpen) {
            createFile.running = true;
        } else {
            removeFile.running = true;
        }
    }

    // Control file (SECURITY FIX: XDG-compliant path)
    Process {
        id: createFile
        command: ["touch", root.lockFilePath]
    }

    Process {
        id: removeFile
        command: ["rm", "-f", root.lockFilePath]
    }
}
