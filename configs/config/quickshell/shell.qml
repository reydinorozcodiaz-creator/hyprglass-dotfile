//@ pragma Env QS_NO_RELOAD_POPUP=1
pragma ComponentBehavior: Bound

// shell.qml — punto de entrada principal del shell.
//
// Módulos lazy-loaded (se activan por flags en sus servicios):
//   NotificationService.activePopupCount > 0  → NotificationOverlay
//   PowerService.overlayVisible               → PowerOverlay
//   LauncherService.visible                   → Launcher
//   OsdService.visible                        → OsdOverlay
//   WallpaperService.pickerVisible            → WallpaperPicker
//   ClipboardService.visible                  → ClipboardHistory
//   root.screenshotActive                     → ScreenshotManager
//   keybindsLoader.active (manual)            → KeybindsOverlay
//
// El agente Bluetooth (bluetooth-agent.py) se auto-reinicia si falla.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import "./modules/shell/bar/"
import "./modules/tools/orbit/"
import "./modules/appearance/screenshot/"

ShellRoot {
    id: root

    // =========================================================================
    // GLOBAL MODULE STATE
    // =========================================================================

    property bool screenshotActive: false

    // =========================================================================
    // BLUETOOTH AGENT
    // =========================================================================

    readonly property string bluetoothAgentScriptPath: Qt.resolvedUrl("./scripts/agents/bluetooth-agent.py").toString().replace("file://", "")

    Process {
        id: bluetoothAgent
        command: ["python3", root.bluetoothAgentScriptPath]
        running: true

        stdout: SplitParser {
            onRead: data => console.log("[BluetoothAgent]: " + data)
        }
        stderr: SplitParser {
            onRead: data => console.error("[BluetoothAgent]: " + data)
        }

        // Auto-restart if the agent dies unexpectedly
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("[BluetoothAgent] Exited with code", exitCode, "— restarting in 3s");
                bluetoothAgentRestartTimer.restart();
            }
        }
    }

    Timer {
        id: bluetoothAgentRestartTimer
        interval: 3000
        repeat: false
        onTriggered: {
            console.log("[BluetoothAgent] Restarting...");
            bluetoothAgent.running = true;
        }
    }

    // =========================================================================
    // UI COMPONENTS - LAZY LOADING
    // =========================================================================

    // Bar - always active (main component)
    Bar {}

    Loader {
        active: AiService.windowVisible
        source: "./modules/tools/orbit/AiChatWindow.qml"
    }

    // Notifications Overlay - Shows notification popups
    Loader {
        id: notificationLoader
        active: NotificationService.activePopupCount > 0
        source: "./modules/shell/notifications/NotificationOverlay.qml"
    }

    // Power Overlay
    Loader {
        id: powerLoader
        active: PowerService.overlayVisible
        source: "./modules/shell/power/PowerOverlay.qml"

        onStatusChanged: {
            if (status === Loader.Ready)
                console.log("[Shell] PowerOverlay loaded");
        }
    }

    // Screenshot Manager
    Loader {
        id: screenshotLoader
        active: root.screenshotActive
        source: "./modules/appearance/screenshot/ScreenshotManager.qml"

        onStatusChanged: {
            if (status === Loader.Ready) {
                console.log("[Shell] ScreenshotManager loaded");
                screenshotLoader.item.startCapture();
            }
        }

        // Deactivate when screenshot finishes
        Connections {
            target: screenshotLoader.item
            enabled: screenshotLoader.status === Loader.Ready

            function onActiveChanged() {
                if (screenshotLoader.item && !screenshotLoader.item.active) {
                    root.screenshotActive = false;
                }
            }
        }
    }

    // Launcher
    Loader {
        active: LauncherService.visible
        source: "./modules/shell/launcher/Launcher.qml"
    }

    // OSD
    Loader {
        active: OsdService.visible
        source: "./modules/shell/osd/OsdOverlay.qml"
    }

    // Wallpaper Picker
    Loader {
        active: WallpaperService.pickerVisible
        source: "./modules/appearance/wallpaper/WallpaperPicker.qml"
    }

    // Clipboard History
    Loader {
        active: ClipboardService.visible
        source: "./modules/tools/clipboard/ClipboardHistory.qml"
    }

    // Keybinds Overlay
    Loader {
        id: keybindsLoader
        active: false
        source: "./modules/shell/keybinds/KeybindsOverlay.qml"

        function toggle() {
            if (active && item) {
                item.hide();
                active = false;
            } else {
                active = true;
            }
        }

        Connections {
            target: keybindsLoader.item
            enabled: keybindsLoader.status === Loader.Ready

            function onShowingChanged() {
                if (keybindsLoader.item && !keybindsLoader.item.showing)
                    keybindsLoader.active = false;
            }
        }

        onStatusChanged: {
            if (status === Loader.Ready && item)
                item.showing = true;
        }
    }

    // =========================================================================
    // GLOBAL SHORTCUTS
    // =========================================================================

    // Shortcut: Screenshot (Print)
    GlobalShortcut {
        name: "take_screenshot"
        description: "Screenshot capture"

        onPressed: {
            console.log("[Shell] Screenshot requested");
            root.screenshotActive = true;
        }
    }

    // Shortcut: Power Menu
    GlobalShortcut {
        name: "power_menu"
        description: "Power menu"

        onPressed: {
            console.log("[Shell] Power menu requested");
            PowerService.showOverlay();
        }
    }

    // Shortcut: Launcher
    GlobalShortcut {
        name: "app_launcher"
        description: "App Launcher"

        onPressed: LauncherService.show()
    }

    // Shortcut: Volume Up
    GlobalShortcut {
        name: "volume_up"
        description: "Increase volume"

        onPressed: {
            AudioService.increaseVolume();
            OsdService.showVolume(AudioService.volume, AudioService.muted);
        }
    }

    // Shortcut: Volume Down
    GlobalShortcut {
        name: "volume_down"
        description: "Decrease volume"

        onPressed: {
            AudioService.decreaseVolume();
            OsdService.showVolume(AudioService.volume, AudioService.muted);
        }
    }

    // Shortcut: Volume Mute
    GlobalShortcut {
        name: "volume_mute"
        description: "Mute volume"

        onPressed: {
            AudioService.toggleMute();
            OsdService.showVolume(AudioService.volume, AudioService.muted);
        }
    }

    // Shortcut: Brightness Up
    GlobalShortcut {
        name: "brightness_up"
        description: "Increase brightness"

        onPressed: {
            BrightnessService.increaseBrightness();
            OsdService.showBrightness(BrightnessService.brightness);
        }
    }

    // Shortcut: Brightness Down
    GlobalShortcut {
        name: "brightness_down"
        description: "Decrease brightness"

        onPressed: {
            BrightnessService.decreaseBrightness();
            OsdService.showBrightness(BrightnessService.brightness);
        }
    }

    // Shortcut: Wallpaper Picker
    GlobalShortcut {
        name: "wallpaper_picker"
        description: "Wallpaper picker"

        onPressed: WallpaperService.toggle()
    }

    // Shortcut: Clipboard History
    GlobalShortcut {
        name: "clipboard_history"
        description: "Clipboard history"

        onPressed: ClipboardService.toggle()
    }

    // Shortcut: Orbit
    GlobalShortcut {
        name: "orbit_assistant"
        description: "Orbit assistant"

        onPressed: AiService.toggleWindow()
    }

    // Shortcut: Keybinds Help
    GlobalShortcut {
        name: "keybinds_help"
        description: "Keybinds help"

        onPressed: keybindsLoader.toggle()
    }
}
