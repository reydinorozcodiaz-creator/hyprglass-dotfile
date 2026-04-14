pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import "./"

BarButton {
    id: root

    Component.onCompleted: notifLoader.active = false

    contentItem: icon
    
    onClicked: {
        if (notifLoader.active && notifLoader.item) {
            notifLoader.item.closeWindow();
        } else {
            notifLoader.active = true;
        }
    }
    
    onRightClicked: {
        // Toggle DND with right click
        NotificationService.toggleDnd()
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "󰂚"
        font.family: Config.font
        font.pixelSize: Config.fontSizeIcon
        color: root.hovered ? Config.accentColor : Config.textColor

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }
    }

    // Lazy-load the window only when opened by the user
    Loader {
        id: notifLoader
        active: false
        source: "./NotificationWindow.qml"

        onStatusChanged: {
            if (status === Loader.Ready && item) {
                item.visible = true;
                // Unload when closed
                item.closing.connect(() => { notifLoader.active = false; });
            }
        }
    }
}
