pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

BarButton {
    id: root

    active: monitorWindow.visible
    contentItem: buttonContent
    onClicked: {
        pulseAnimation.start()
        monitorWindow.visible = !monitorWindow.visible
    }

    RowLayout {
        id: buttonContent
        anchors.centerIn: parent
        spacing: Config.spacing
        scale: 1
        
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        Text {
            text: "󰍛"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIcon
            color: root.active ? Config.accentColor : Config.textColor

            Behavior on color {
                ColorAnimation { duration: Config.animDuration }
            }
        }
    }

    SystemMonitorWindow {
        id: monitorWindow
        visible: false
        onVisibleChanged: SystemMonitorService.monitorActive = visible
    }

    SequentialAnimation {
        id: pulseAnimation
        
        NumberAnimation {
            target: buttonContent
            property: "scale"
            to: 1.3
            duration: 150
            easing.type: Easing.OutQuad
        }
        
        NumberAnimation {
            target: buttonContent
            property: "scale"
            to: 1
            duration: 150
            easing.type: Easing.InQuad
        }
    }
}
