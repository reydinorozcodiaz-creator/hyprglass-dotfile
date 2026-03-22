pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.config

Item {
    id: root

    property int maxWidth: 400

    // Internal state to force clearing
    property bool windowExists: Hyprland.activeToplevel !== null

    readonly property string windowTitle: Hyprland.activeToplevel?.title ?? ""

    // Logic to verify focus changes
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // "activewindowv2" is sent even when clicking the desktop (returns empty)
            if (event.name === "activewindowv2") {
                // If the address is empty, no window is focused
                root.windowExists = event.data !== "," && event.data !== "";
            }

            // Clear title when changing workspaces to an empty one
            if (event.name === "workspace") {
                // Small delay to let Hyprland update its internal state
                Qt.callLater(() => {
                    if (root)
                        root.windowExists = Hyprland.activeToplevel !== null;
                });
            }
        }
    }

    implicitWidth: windowExists ? content.implicitWidth : 0
    implicitHeight: content.implicitHeight

    visible: opacity > 0
    opacity: windowExists ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDuration
        }
    }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: content
        anchors.fill: parent
        implicitWidth: Math.min(titleText.implicitWidth + (Config.padding * 2), root.maxWidth)
        implicitHeight: titleText.implicitHeight + (Config.padding * 1.2)
        radius: Config.radius
        color: Qt.alpha(Config.surface2Color, 0.7)
        border.width: 1
        border.color: Qt.alpha(Config.textColor, 0.12)

        Text {
            id: titleText
            anchors.centerIn: parent
            text: root.windowTitle !== "" ? "  " + root.windowTitle : ""
            color: Config.textColor
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            font.bold: true
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.maxWidth - (Config.padding * 2))
        }
    }
}
