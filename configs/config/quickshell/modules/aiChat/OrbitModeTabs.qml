pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

Flow {
    id: root

    property string currentMode: "ask"
    property var modes: []

    signal modeSelected(string mode)

    spacing: 6

    Repeater {
        model: root.modes

        delegate: Rectangle {
            required property var modelData

            height: 28
            width: modeRow.implicitWidth + 18
            radius: 14

            readonly property bool active: root.currentMode === modelData.id

            color: active ? Qt.alpha(Config.accentColor, 0.14) : Config.surface0Color
            border.width: 1
            border.color: active
                ? Qt.alpha(Config.accentColor, 0.40)
                : Qt.alpha(Config.surface2Color, 0.28)

            Behavior on color {
                ColorAnimation { duration: Config.animDurationShort }
            }

            Row {
                id: modeRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: modelData.icon || ""
                    font.family: Config.font
                    font.pixelSize: 10
                    color: active ? Config.accentColor : Config.subtextColor
                }

                Text {
                    text: modelData.label || modelData.id
                    font.family: Config.font
                    font.pixelSize: 10
                    font.bold: active
                    color: active ? Config.accentColor : Config.textColor
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.modeSelected(modelData.id)
            }
        }
    }
}
