pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

Rectangle {
    id: root

    property var models: []
    property string selectedModel: ""
    property string provider: ""
    property bool loading: false
    property string title: "Seleccionar modelo"
    property bool compact: false
    property int maxHeight: 230

    signal refreshRequested()
    signal modelSelected(string modelId)

    radius: Config.radius
    color: Config.surface0Color
    border.width: 1
    border.color: Qt.alpha(Config.accentColor, 0.3)
    implicitHeight: pickerInner.implicitHeight + 16

    ColumnLayout {
        id: pickerInner
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.title
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.subtextColor
                opacity: 0.78
            }

            Item { Layout.fillWidth: true }

            Spinner {
                running: root.loading
                size: Config.fontSizeSmall
                color: Config.subtextColor
                visible: root.loading
            }

            Text {
                text: "↻"
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.accentColor
                opacity: 0.68
                visible: !root.loading

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refreshRequested()
                }
            }
        }

        ListView {
            Layout.fillWidth: true
            height: Math.min(contentHeight, root.maxHeight)
            clip: true
            spacing: 2
            model: root.models

            delegate: Rectangle {
                id: modelRow

                required property var modelData

                width: ListView.view.width
                height: root.compact ? 32 : 38
                radius: Config.radiusSmall
                color: root.selectedModel === modelData.id
                    ? Qt.alpha(Config.accentColor, 0.14)
                    : (modelMouse.containsMouse ? Config.surface1Color : "transparent")

                Behavior on color {
                    ColorAnimation { duration: Config.animDurationShort }
                }

                MouseArea {
                    id: modelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.modelSelected(modelData.id)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name || modelData.id
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: root.selectedModel === modelData.id
                        color: root.selectedModel === modelData.id ? Config.accentColor : Config.textColor
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: modelData.preview === true
                        height: 14
                        width: previewLabel.implicitWidth + 6
                        radius: 3
                        color: Qt.alpha(Config.warningColor, 0.15)

                        Text {
                            id: previewLabel
                            anchors.centerIn: parent
                            text: "preview"
                            font.family: Config.font
                            font.pixelSize: 8
                            color: Config.warningColor
                        }
                    }

                    Rectangle {
                        visible: root.provider === "copilot"
                        height: 14
                        width: copilotLabel.implicitWidth + 6
                        radius: 3
                        color: modelData.premium === true
                            ? Qt.alpha(Config.errorColor, 0.15)
                            : Qt.alpha(Config.successColor, 0.15)

                        Text {
                            id: copilotLabel
                            anchors.centerIn: parent
                            text: modelData.premium === true ? "premium" : "incluido"
                            font.family: Config.font
                            font.pixelSize: 8
                            color: modelData.premium === true ? Config.errorColor : Config.successColor
                        }
                    }
                }
            }
        }
    }
}
