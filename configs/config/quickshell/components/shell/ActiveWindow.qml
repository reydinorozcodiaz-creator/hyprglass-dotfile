pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.config

Item {
    id: root

    property int maxWidth: 400
    readonly property string rawWindowTitle: Hyprland.activeToplevel?.title ?? ""
    property string windowTitle: ""
    readonly property bool windowExists: windowTitle !== ""

    function syncWindowTitle() {
        const nextTitle = (rawWindowTitle || "").trim();
        if (windowTitle !== nextTitle)
            windowTitle = nextTitle;
    }

    onRawWindowTitleChanged: titleSyncTimer.restart()
    Component.onCompleted: syncWindowTitle()

    implicitWidth: windowExists ? Math.min(titleText.implicitWidth + (Config.padding * 2), maxWidth) : 0
    implicitHeight: content.implicitHeight

    visible: opacity > 0
    opacity: windowExists ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDuration
        }
    }
    Timer {
        id: titleSyncTimer
        interval: 120
        repeat: false
        onTriggered: root.syncWindowTitle()
    }

    Rectangle {
        id: content
        anchors.fill: parent
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
            width: root.maxWidth - (Config.padding * 2)
        }
    }
}
