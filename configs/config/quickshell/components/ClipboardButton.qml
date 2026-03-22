pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.config
import qs.services

BarButton {
    id: root

    active: ClipboardService.visible
    contentItem: icon
    onClicked: {
        pulseAnimation.start()
        ClipboardService.toggle()
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "󰅍"
        font.family: Config.font
        font.pixelSize: Config.fontSizeIcon
        color: root.active ? Config.accentColor : Config.textColor
        scale: 1

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }
    }

    ToolTip.visible: root.hovered
    ToolTip.text: "Clipboard History"
    ToolTip.delay: 500

    SequentialAnimation {
        id: pulseAnimation
        
        NumberAnimation {
            target: icon
            property: "scale"
            to: 1.3
            duration: 150
            easing.type: Easing.OutQuad
        }
        
        NumberAnimation {
            target: icon
            property: "scale"
            to: 1
            duration: 150
            easing.type: Easing.InQuad
        }
    }
}
