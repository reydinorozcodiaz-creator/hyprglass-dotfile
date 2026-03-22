pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services

RowLayout {
    id: root

    visible: MprisService.hasPlayer
    spacing: 8

    // Album Art
    Rectangle {
        id: albumArtContainer
        width: 36
        height: 36
        radius: Config.radius
        color: Qt.alpha(Config.surface2Color, 0.5)
        clip: true
        Layout.preferredWidth: 36
        Layout.preferredHeight: 36

        Image {
            id: albumArt
            anchors.fill: parent
            source: MprisService.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(36, 36)
            cache: false
        }

        // Fallback gradient if no art
        Rectangle {
            anchors.fill: parent
            visible: albumArt.status !== Image.Ready
            color: "transparent"
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.alpha(Config.accentColor, 0.3)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.alpha(Config.accentColor, 0.1)
                }
            }

            Text {
                anchors.centerIn: parent
                text: "♪"
                font.family: Config.font
                font.pixelSize: 20
                color: Config.accentColor
            }
        }
    }

    // Song Info
    ColumnLayout {
        spacing: 2
        Layout.fillWidth: true

        // Title
        Text {
            text: MprisService.title
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textColor
            elide: Text.ElideRight
            Layout.fillWidth: true

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                id: titleHover
                acceptedButtons: Qt.NoButton
            }

            ToolTip.visible: titleHover.containsMouse && parent.truncated
            ToolTip.text: text
            ToolTip.delay: 500
        }

        // Artist
        Text {
            text: MprisService.artist
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Qt.alpha(Config.textColor, 0.7)
            elide: Text.ElideRight
            Layout.fillWidth: true

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                id: artistHover
                acceptedButtons: Qt.NoButton
            }

            ToolTip.visible: artistHover.containsMouse && parent.truncated
            ToolTip.text: text
            ToolTip.delay: 500
        }
    }
}
