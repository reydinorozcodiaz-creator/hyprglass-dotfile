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
    implicitHeight: 320

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        PageHeader {
            icon: "󱜚"
            title: "Orbit"
            onBackClicked: root.backRequested()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.surface1Color
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            radius: Config.radius
            color: Config.surface0Color
            border.width: 1
            border.color: Qt.alpha(Config.surface2Color, 0.35)
            implicitHeight: bodyCol.implicitHeight + 24

            ColumnLayout {
                id: bodyCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "La configuracion de Orbit ahora vive en su ventana principal."
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.textColor
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: Config.radius
                    color: Qt.alpha(Config.accentColor, 0.08)
                    border.width: 1
                    border.color: Qt.alpha(Config.accentColor, 0.22)
                    implicitHeight: statusCol.implicitHeight + 18

                    ColumnLayout {
                        id: statusCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Text {
                            text: "Backend: " + AiService.backendStatusLabel
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.textColor
                            wrapMode: Text.Wrap
                        }

                        Text {
                            text: "Agente: " + (AiService.activeAgent
                                ? AiService.activeAgentDisplayName + (AiService.activeAgentModelLabel !== "" ? " · " + AiService.activeAgentModelLabel : "")
                                : "Sin seleccionar")
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                            wrapMode: Text.Wrap
                        }

                        Text {
                            text: AiService.needsSetup
                                ? "Estado: falta un agente listo o la conexion con OpenFang."
                                : "Estado: Orbit listo para usar con OpenFang."
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: AiService.needsSetup ? Config.warningColor : Config.successColor
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: Config.radius
                    color: openMouse.containsMouse ? Config.accentColor : Qt.alpha(Config.accentColor, 0.84)
                    Behavior on color { ColorAnimation { duration: Config.animDurationShort } }

                    MouseArea {
                        id: openMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            AiService.openSettings();
                            AiService.openWindow();
                            root.backRequested();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Abrir ajustes de Orbit"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        font.bold: true
                        color: Config.textReverseColor
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
