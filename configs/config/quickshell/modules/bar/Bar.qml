pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"
import "../quickSettings/"
import "../notifications/"
import "../systemMonitor/"
import "../calendar/"
import "../aiChat/"

Scope {
    id: root

    readonly property int gapIn: 5
    readonly property int gapOut: 15

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            property bool enableAutoHide: StateService.get("bar.autoHide", false)
            // When hidden, leave 1px visible at the top to catch mouse hover
            readonly property int hiddenMargin: -(height - 1)

            // NameSpace
            WlrLayershell.namespace: "qs_modules"

            // --- BAR CONFIGURATION ---
            implicitHeight: StateService.get("bar.height", 44)
            color: "transparent"
            screen: modelData

            // Overlay ensures it stays above games/fullscreen
            // WlrLayershell.layer: WlrLayer.Overlay

            // Set the exclusion mode
            exclusionMode: enableAutoHide ? ExclusionMode.Ignore : ExclusionMode.Normal

            // Ensure reserved area size when in Normal mode
            exclusiveZone: enableAutoHide ? 0 : height

            anchors {
                top: true
                left: true
                right: true
            }

            // --- AUTOHIDE LOGIC ---
            // If mouse is hovering, margin is 0 (show everything).
            // Otherwise, hiddenMargin hides the bar leaving 1px to catch the mouse.
            margins.top: {
                if (WindowManagerService.anyModuleOpen || !enableAutoHide || mouseSensor.hovered)
                    return 0;

                return hiddenMargin;
            }

            // Smooth window movement animation
            Behavior on margins.top {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutExpo
                }
            }

            // --- MOUSE SENSOR ---
            // Covers the entire window. Since the window never "disappears" (only moves off-screen),
            // the remaining 1px still detects the mouse.
            HoverHandler {
                id: mouseSensor
            }

            Rectangle {
                id: barContent
                anchors.fill: parent
                radius: Config.radius
                clip: true
                color: Qt.alpha(Config.backgroundColor, 0.65)
                border.width: 1
                border.color: Qt.alpha(Config.textColor, 0.10)

                Rectangle {
                    anchors.fill: parent
                    radius: barContent.radius
                    opacity: 0.35
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Qt.alpha(Config.textColor, 0.12)
                        }
                        GradientStop {
                            position: 1.0
                            color: Qt.alpha(Config.textColor, 0.02)
                        }
                    }
                }

                // --- LEFT ---
                RowLayout {
                    anchors.left: parent.left
                    anchors.leftMargin: root.gapOut
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.gapIn

                    CalendarButton {}
                    SystemMonitorButton {}
                    ActiveWindow {}
                }

                // --- CENTER ---
                RowLayout {
                    anchors.centerIn: parent
                    spacing: root.gapIn
                    Layout.fillWidth: false

                    Workspaces {}
                }

                // --- RIGHT ---
                RowLayout {
                    anchors.right: parent.right
                    anchors.rightMargin: root.gapOut
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.gapIn

                    ClipboardButton {}
                    AiChatButton {}
                    TrayWidget {}
                    QuickSettingsButton {}
                    NotificationButton {}
                }
            }
        }
    }
}
