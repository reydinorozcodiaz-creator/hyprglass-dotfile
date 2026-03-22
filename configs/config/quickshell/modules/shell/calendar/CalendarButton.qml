pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components
import qs.services

BarButton {
    id: root

    active: calendarLoader.active && calendarLoader.item && calendarLoader.item.visible
    contentItem: clockText
    onClicked: {
        pulseAnimation.start()
        if (calendarLoader.active && calendarLoader.item) {
            calendarLoader.item.closeWindow();
        } else {
            calendarLoader.active = true;
        }
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

    Loader {
        id: calendarLoader
        active: false
        source: "./CalendarWindow.qml"

        onStatusChanged: {
            if (status === Loader.Ready && item) {
                item.visible = true;
                item.closing.connect(() => { calendarLoader.active = false; });
            }
        }
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
