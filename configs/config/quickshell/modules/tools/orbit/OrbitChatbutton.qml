pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components
import qs.services

BarButton {
    id: root

    active: AiService.windowVisible
    contentItem: btnIcon
    onClicked: AiService.toggleWindow()

    Text {
        id: btnIcon
        anchors.centerIn: parent
        text: "󱜚"
        font.family: Config.font
        font.pixelSize: Config.fontSizeIcon
        color: root.active ? Config.accentColor : Config.textColor

        Behavior on color {
            ColorAnimation { duration: Config.animDuration }
        }
    }

    // Loading dot indicator
    Rectangle {
        anchors.top:   parent.top
        anchors.right: parent.right
        anchors.topMargin:   4
        anchors.rightMargin: 4
        width: 7; height: 7; radius: 4
        color: Config.accentColor
        visible: AiService.isLoading

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: AiService.isLoading
            NumberAnimation { to: 0.2; duration: 500 }
            NumberAnimation { to: 1.0; duration: 500 }
        }
    }
}
