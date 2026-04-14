pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * DependencyCheckService - Validates required scripts and dependencies at startup
 * 
 * @singleton
 * 
 * Automatically checks for presence of critical Python and shell scripts on Component.onCompleted.
 * Emits warnings for missing optional dependencies and errors for missing critical files.
 * 
 * Key Properties:
 * - allCriticalPresent: bool - True if all required scripts exist
 * - checkComplete: bool - True after validation finishes
 * - missingCritical: array - List of missing required script paths
 * - missingOptional: array - List of missing optional script paths
 * - requiredScripts: array (readonly) - Paths to critical dependencies
 * - optionalScripts: array (readonly) - Paths to nice-to-have dependencies
 * 
 * Signals:
 * - checkCompleted(missing: array) - Emitted when validation finishes with list of missing critical files
 * 
 * Architecture:
 * - ARCH-003: Implemented startup dependency validation
 * - Uses async Process to avoid blocking during startup
 * - Logs errors to console for easy debugging
 * 
 * Usage:
 *   // Service auto-validates on startup
 *   Connections {
 *       target: DependencyCheckService
 *       function onCheckCompleted(missing) {
 *           if (missing.length > 0) {
 *               console.error("Missing dependencies:", missing)
 *           }
 *       }
 *   }
 */
Singleton {
    id: root

    // Critical scripts required at startup
    readonly property var requiredScripts: [
        "scripts/ai/ai_chat.py",
        "scripts/agents/bluetooth-agent.py",
        "scripts/agents/sys-agent.py",
        "scripts/tools/parse-hypr-keybinds.py",
        "scripts/tools/clear-unpinned.py",
        "scripts/tools/copy-image-to-clipboard.sh"
    ]

    // Optional external scripts (warnings only)
    readonly property var optionalScripts: [
        "../../../hypr/scripts/AleatoryWall.sh",
        "../../../hypr/scripts/theme-unifier.sh"
    ]

    property var missingCritical: []
    property var missingOptional: []
    property bool allCriticalPresent: true
    property bool checkComplete: false

    signal checkCompleted(var missing)

    Component.onCompleted: {
        validateDependencies();
    }

    function validateDependencies() {
        const configDir = Quickshell.env("HOME") + "/.config/quickshell/";
        
        // Build command to check all files at once
        let testCommands = [];
        
        // Critical files
        for (let i = 0; i < requiredScripts.length; i++) {
            const scriptPath = configDir + requiredScripts[i];
            testCommands.push("test -f '" + scriptPath.replace(/'/g, "'\\''") + "'");
        }
        
        const checkCommand = testCommands.join(" && ");
        
        criticalCheckProc.command = ["bash", "-c", checkCommand];
        criticalCheckProc.running = true;
    }

    Process {
        id: criticalCheckProc
        
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // At least one critical file is missing, check individually
                root.findMissingScripts();
            } else {
                // All critical files present
                root.allCriticalPresent = true;
                root.checkComplete = true;
                console.log("[DependencyCheck] ✓ All critical dependencies present");
                root.checkOptionalScripts();
            }
        }
    }

    function findMissingScripts() {
        const configDir = Quickshell.env("HOME") + "/.config/quickshell/";
        let checkScript = "#!/bin/bash\n";
        
        for (let i = 0; i < requiredScripts.length; i++) {
            const scriptPath = configDir + requiredScripts[i];
            checkScript += "test -f '" + scriptPath.replace(/'/g, "'\\''") + "' || echo 'MISSING:" + requiredScripts[i] + "'\n";
        }
        
        detailCheckProc.command = ["bash", "-c", checkScript];
        detailCheckProc.running = true;
    }

    Process {
        id: detailCheckProc
        property string buffer: ""
        
        stdout: SplitParser {
            onRead: data => detailCheckProc.buffer += data
        }
        
        onExited: {
            const lines = detailCheckProc.buffer.trim().split('\n');
            let missing = [];
            
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                if (line.startsWith("MISSING:")) {
                    const scriptName = line.substring(8);
                    missing.push(scriptName);
                    console.error("[DependencyCheck] CRITICAL: Missing script:", scriptName);
                }
            }
            
            root.missingCritical = missing;
            root.allCriticalPresent = missing.length === 0;
            root.checkComplete = true;
            
            if (missing.length > 0) {
                console.error("[DependencyCheck] ========================================");
                console.error("[DependencyCheck] STARTUP VALIDATION FAILED");
                console.error("[DependencyCheck] Missing", missing.length, "critical dependencies");
                console.error("[DependencyCheck] QuickShell may not function properly");
                console.error("[DependencyCheck] ========================================");
            }
            
            root.checkOptionalScripts();
            root.checkCompleted(missing);
        }
    }

    function checkOptionalScripts() {
        const homeDir = Quickshell.env("HOME") + "/.config/";
        let checkScript = "#!/bin/bash\n";
        
        for (let i = 0; i < optionalScripts.length; i++) {
            const scriptPath = homeDir + optionalScripts[i];
            checkScript += "test -f '" + scriptPath.replace(/'/g, "'\\''") + "' || echo 'MISSING:" + optionalScripts[i] + "'\n";
        }
        
        optionalCheckProc.command = ["bash", "-c", checkScript];
        optionalCheckProc.running = true;
    }

    Process {
        id: optionalCheckProc
        property string buffer: ""
        
        stdout: SplitParser {
            onRead: data => optionalCheckProc.buffer += data
        }
        
        onExited: {
            const lines = optionalCheckProc.buffer.trim().split('\n');
            let missing = [];
            
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                if (line.startsWith("MISSING:")) {
                    const scriptName = line.substring(8);
                    missing.push(scriptName);
                    console.warn("[DependencyCheck] Optional script not found:", scriptName);
                }
            }
            
            root.missingOptional = missing;
            
            if (missing.length > 0) {
                console.warn("[DependencyCheck] ⚠", missing.length, "optional dependencies missing");
            }
        }
    }
}
