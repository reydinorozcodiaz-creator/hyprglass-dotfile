pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

RowLayout {
    id: root
    spacing: 5

    // Drawer state
    property bool isOpen: false

    // We create the TrayMenu object here, but it starts invisible.
    TrayMenu {
        id: sharedMenu
        visible: false

        onVisibleChanged: {
            if (visible)
                TrayService.registerActiveMenu(sharedMenu);
        }
    }

    Item {
        id: drawer

        clip: true

        Layout.preferredHeight: 34
        Layout.preferredWidth: root.isOpen && drawerContentLoader.item ? (drawerContentLoader.item.implicitWidth + 5) : 0

        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: Config.animDurationLong
                easing.type: Easing.OutExpo
            }
        }

        opacity: root.isOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
            }
        }

        Loader {
            id: drawerContentLoader
            active: root.isOpen
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter

            sourceComponent: Row {
                spacing: 3

                Repeater {
                    model: TrayService.items

                    delegate: Rectangle {
                        id: trayDelegate
                        required property var modelData

                        implicitWidth: 26
                        implicitHeight: 26
                        radius: width / 2
                        color: mouseArea.containsMouse ? Config.surface1Color : "transparent"

                        // Primary icon (theme name, file path, or pixmap URL)
                        Image {
                            id: trayIcon
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: TrayService.getIconSource(trayDelegate.modelData.icon)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize: Qt.size(32, 32)
                            smooth: true
                            visible: status === Image.Ready
                        }

                        // Fallback when primary icon fails (e.g. pixmap-based icons from nm-applet)
                        Image {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: "image://icon/application-default-icon"
                            fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(32, 32)
                            smooth: true
                            visible: trayIcon.status === Image.Error
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    trayDelegate.modelData.activate();
                                    sharedMenu.close();
                                } else if (mouse.button === Qt.RightButton) {
                                    if (trayDelegate.modelData.hasMenu) {
                                        // 1. Gets the absolute position of the icon on screen
                                        var globalPos = trayDelegate.mapToGlobal(0, trayDelegate.height);

                                        // 2. Configures the shared menu
                                        sharedMenu.rootMenuHandle = trayDelegate.modelData.menu;
                                        sharedMenu.anchorX = globalPos.x;
                                        sharedMenu.anchorY = globalPos.y + 5;

                                        // 3. Opens the menu
                                        sharedMenu.open();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Toggle button
    Rectangle {
        id: toggleBtn

        visible: TrayService.hasItems
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        radius: width / 2

        color: (toggleMouse.containsMouse) ? Config.surface1Color : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        // Arrow Icon
        Text {
            anchors.centerIn: parent
            text: "󰅁"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconSmall + 2
            color: Config.textColor

            scale: root.isOpen ? -1 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutBack
                }
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.isOpen = !root.isOpen
        }
    }
}
