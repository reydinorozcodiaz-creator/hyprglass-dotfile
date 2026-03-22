pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.services
import "../../../components/"

Item {
    id: root

    signal backRequested

    Layout.fillWidth: true
    implicitHeight: 480

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ── Header ──────────────────────────────────────────────────────
        PageHeader {
            icon: AudioService.systemIcon
            title: "Audio"
            onBackClicked: root.backRequested()

            ActionButton {
                icon: "󰙵"
                baseColor: Config.surface1Color
                hoverColor: Config.surface2Color
                textColor: Config.subtextColor
                onClicked: pavuProc.running = true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.surface1Color
        }

        // ── Current output summary ───────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            implicitHeight: 40

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 10

                Text {
                    text: AudioService.getSinkIcon(AudioService.sink)
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIcon
                    color: Config.accentColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Current output"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                        opacity: 0.6
                    }
                    Text {
                        text: AudioService.getSinkLabel(AudioService.sink)
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        font.bold: true
                        color: Config.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.surface1Color
        }

        // ── Section label ───────────────────────────────────────────────
        Text {
            Layout.leftMargin: 14
            text: "Available outputs"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.subtextColor
            opacity: 0.6
        }

        // ── Sink list ────────────────────────────────────────────────────
        ListView {
            id: sinkList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            clip: true
            spacing: 6

            model: AudioService.allSinks

            delegate: Item {
                id: sinkDelegate
                required property var modelData

                readonly property bool isDefault: AudioService.sink !== null
                    && AudioService.sink.name === sinkDelegate.modelData.name

                width: sinkList.width
                height: 60

                Rectangle {
                    anchors.fill: parent
                    radius: Config.radiusLarge
                    border.width: 1
                    border.color: sinkDelegate.isDefault ? Config.accentColor : "transparent"

                    color: {
                        if (sinkDelegate.isDefault)
                            return Qt.alpha(Config.accentColor, 0.12);
                        if (cardMouse.containsMouse)
                            return Config.surface1Color;
                        return Qt.alpha(Config.surface1Color, 0.5);
                    }

                    Behavior on color { ColorAnimation { duration: Config.animDurationShort } }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: sinkDelegate.isDefault ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!sinkDelegate.isDefault)
                                AudioService.setDefaultSink(sinkDelegate.modelData.name);
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // Icon circle
                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: sinkDelegate.isDefault ? Config.accentColor : Config.surface2Color

                            Text {
                                anchors.centerIn: parent
                                text: AudioService.getSinkIcon(sinkDelegate.modelData)
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeIcon
                                color: sinkDelegate.isDefault ? Config.textReverseColor : Config.textColor
                            }
                        }

                        // Device name
                        Text {
                            Layout.fillWidth: true
                            text: AudioService.getSinkLabel(sinkDelegate.modelData)
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            font.bold: sinkDelegate.isDefault
                            color: Config.textColor
                            elide: Text.ElideRight
                        }

                        // "Active" badge or hover hint
                        Rectangle {
                            visible: sinkDelegate.isDefault
                            height: 20
                            width: lblActive.implicitWidth + 14
                            radius: 10
                            color: Config.accentColor

                            Text {
                                id: lblActive
                                anchors.centerIn: parent
                                text: "Active"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                font.bold: true
                                color: Config.textReverseColor
                            }
                        }

                        Text {
                            visible: !sinkDelegate.isDefault && cardMouse.containsMouse
                            text: "Use"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: true
                            color: Config.accentColor
                        }
                    }
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: AudioService.allSinks.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰓃"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge
                    color: Config.subtextColor
                    opacity: 0.4
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No output devices found"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                    opacity: 0.5
                }
            }
        }

        // ── PavuControl button ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10
            height: 38
            radius: Config.radius
            color: pavuMouse.containsMouse ? Config.surface2Color : Config.surface1Color
            Behavior on color { ColorAnimation { duration: Config.animDurationShort } }

            MouseArea {
                id: pavuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pavuProc.running = true
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "󰙵"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    color: Config.subtextColor
                }
                Text {
                    text: "Open PavuControl"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }
            }
        }
    }

    Process {
        id: pavuProc
        command: ["pavucontrol"]
        running: false
    }
}
