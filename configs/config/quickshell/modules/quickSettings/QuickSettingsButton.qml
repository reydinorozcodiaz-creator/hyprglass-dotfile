pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../../components/"

BarButton {
    id: root

    active: quickSettingsWindow.visible
    contentItem: iconsLayout
    onClicked: {
        pulseAnimation.start()
        quickSettingsWindow.visible = !quickSettingsWindow.visible
    }

    RowLayout {
        id: iconsLayout
        anchors.centerIn: parent
        spacing: Config.spacing
        scale: 1

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        property color iconColor: root.active ? Config.accentColor : Config.textColor

        Behavior on iconColor {
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        WifiIcon {
            color: iconsLayout.iconColor
        }
        BluetoothIcon {
            color: iconsLayout.iconColor
        }
        AudioIcon {
            color: iconsLayout.iconColor
        }
        BatteryIcon {
            color: iconsLayout.iconColor
        }
    }

    QuickSettingsWindow {
        id: quickSettingsWindow
        visible: false
    }

    SequentialAnimation {
        id: pulseAnimation
        
        NumberAnimation {
            target: iconsLayout
            property: "scale"
            to: 1.3
            duration: 150
            easing.type: Easing.OutQuad
        }
        
        NumberAnimation {
            target: iconsLayout
            property: "scale"
            to: 1
            duration: 150
            easing.type: Easing.InQuad
        }
    }
}
