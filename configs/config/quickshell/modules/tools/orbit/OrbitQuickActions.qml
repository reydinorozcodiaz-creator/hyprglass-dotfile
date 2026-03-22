pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: root

    property var actions: []
    property int columns: 2

    signal actionRequested(string actionId)

    implicitHeight: actionsGrid.implicitHeight

    Grid {
        id: actionsGrid
        width: parent.width
        columns: root.columns
        spacing: 8

        Repeater {
            model: root.actions

            delegate: Rectangle {
                required property var modelData

                width: (actionsGrid.width - actionsGrid.spacing * Math.max(actionsGrid.columns - 1, 0)) / Math.max(actionsGrid.columns, 1)
                height: 72
                radius: Config.radius
                color: actionMouse.containsMouse ? Config.surface1Color : Config.surface0Color
                border.width: 1
                border.color: actionMouse.containsMouse
                    ? Qt.alpha(Config.accentColor, 0.36)
                    : Qt.alpha(Config.surface2Color, 0.28)

                Behavior on color {
                    ColorAnimation { duration: Config.animDurationShort }
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.actionRequested(modelData.id)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        width: 30
                        height: 30
                        radius: 15
                        color: Qt.alpha(Config.accentColor, 0.12)

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon || ""
                            font.family: Config.font
                            font.pixelSize: 13
                            color: Config.accentColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title || modelData.id
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: true
                            color: Config.textColor
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.subtitle || ""
                            font.family: Config.font
                            font.pixelSize: 10
                            color: Config.subtextColor
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            opacity: 0.72
                        }
                    }
                }
            }
        }
    }
}
