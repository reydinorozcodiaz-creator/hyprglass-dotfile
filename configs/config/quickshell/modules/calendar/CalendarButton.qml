pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import "../../components/"

BarButton {
    id: root

    active: calendarWindow.visible
    contentItem: clockText
    onClicked: {
        pulseAnimation.start()
        calendarWindow.visible = !calendarWindow.visible
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        text: TimeService.format("hh:mm")
        font.family: Config.font
        font.pixelSize: Config.fontSizeLarge
        font.bold: true
        color: root.active ? Config.accentColor : Config.textColor
        scale: 1
        
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        Behavior on color {
            ColorAnimation { duration: Config.animDuration }
        }
    }

    CalendarWindow {
        id: calendarWindow
        visible: false
    }

    SequentialAnimation {
        id: pulseAnimation
        
        NumberAnimation {
            target: clockText
            property: "scale"
            to: 1.3
            duration: 150
            easing.type: Easing.OutQuad
        }
        
        NumberAnimation {
            target: clockText
            property: "scale"
            to: 1
            duration: 150
            easing.type: Easing.InQuad
        }
    }
}
