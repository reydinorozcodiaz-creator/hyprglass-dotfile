pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root

    signal backRequested

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    ColumnLayout {
        id: main
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        // Header
        PageHeader {
            icon: NotificationService.dndEnabled ? "󰂛" : "󰂚"
            iconColor: NotificationService.dndEnabled ? Config.accentColor : Config.subtextColor
            title: "Do Not Disturb"
            onBackClicked: root.backRequested()

            QsSwitch {
                checked: NotificationService.dndEnabled
                onToggled: NotificationService.toggleDnd()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.surface1Color
        }

        // Duration presets
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 8
            spacing: 8

            Text {
                text: "Duration"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.subtextColor
            }

            // Preset buttons grid
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: [
                        { label: "30 minutes", minutes: 30 },
                        { label: "1 hour",     minutes: 60 },
                        { label: "2 hours",    minutes: 120 },
                        { label: "Indefinite", minutes: -1 }
                    ]

                    delegate: Rectangle {
                        id: presetBtn
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: Config.radius

                        readonly property bool isActive: NotificationService.dndEnabled
                            && NotificationService.dndMinutesLeft === modelData.minutes

                        color: isActive ? Config.accentColor : Config.surface1Color

                        Behavior on color {
                            ColorAnimation { duration: Config.animDurationShort }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: presetBtn.modelData.label
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            font.bold: presetBtn.isActive
                            color: presetBtn.isActive ? Config.textReverseColor : Config.textColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.enableDndFor(presetBtn.modelData.minutes)
                        }
                    }
                }
            }

            // Status text when active
            Text {
                visible: NotificationService.dndEnabled
                Layout.fillWidth: true
                text: NotificationService.dndStatusText
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: 4
            }

            // Turn off button (when active)
            Rectangle {
                visible: NotificationService.dndEnabled
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Config.radius
                color: Config.surface1Color

                Behavior on color {
                    ColorAnimation { duration: Config.animDurationShort }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Turn Off"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.errorColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.disableDnd()
                }
            }
        }
    }
}
