pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.config
import "../../components/"

PanelWindow {
    id: root

    visible: LauncherService.visible

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "qs_modules"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"

    // Click on background closes
    MouseArea {
        anchors.fill: parent
        onClicked: {
            contentLoader.item.forceActiveFocus();
            LauncherService.hide();
        }
    }

    // Loader that creates/destroys the content
    Loader {
        id: contentLoader
        anchors.fill: parent
        active: LauncherService.visible

        sourceComponent: Rectangle {
            id: content
            anchors.fill: parent

            color: "transparent"

            // Scale animation on entry
            scale: 1
            opacity: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 60
                anchors.topMargin: 80
                anchors.bottomMargin: 60
                spacing: Config.spacing * 2

                // Search bar
                Rectangle {
                    id: searchBar
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(parent.width - 160, 800)
                    Layout.preferredHeight: 64
                    radius: Config.radiusLarge
                    color: Config.surface0Color
                    border.width: searchInput.activeFocus ? 2 : 0
                    border.color: Config.accentColor

                    Behavior on border.width {
                        NumberAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Config.spacing + 6
                        anchors.rightMargin: Config.spacing + 6
                        spacing: Config.spacing

                        Text {
                            text: ""
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIconLarge
                            color: searchInput.activeFocus ? Config.accentColor : Config.subtextColor

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDurationShort
                                }
                            }
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            color: Config.textColor
                            font.family: Config.font
                            font.pixelSize: 22
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            placeholderText: "Search apps..."
                            placeholderTextColor: Config.mutedColor
                            background: null

                            onTextChanged: LauncherService.query = text

                            Keys.onEscapePressed: {
                                focus = false;
                                LauncherService.hide();
                            }

                            Keys.onReturnPressed: LauncherService.launchSelected()

                            Keys.onLeftPressed: {
                                if (LauncherService.selectedIndex > 0)
                                    LauncherService.selectedIndex--;
                            }

                            Keys.onRightPressed: {
                                if (LauncherService.selectedIndex < LauncherService.filteredApps.length - 1)
                                    LauncherService.selectedIndex++;
                            }

                            Keys.onUpPressed: {
                                const cols = appList.cellWidth > 0 ? Math.floor(appList.width / appList.cellWidth) : 1;
                                const newIndex = LauncherService.selectedIndex - cols;
                                if (newIndex >= 0)
                                    LauncherService.selectedIndex = newIndex;
                            }

                            Keys.onDownPressed: {
                                const cols = appList.cellWidth > 0 ? Math.floor(appList.width / appList.cellWidth) : 1;
                                const newIndex = LauncherService.selectedIndex + cols;
                                if (newIndex < LauncherService.filteredApps.length)
                                    LauncherService.selectedIndex = newIndex;
                            }

                            Keys.onTabPressed: event => {
                                if (LauncherService.selectedIndex < LauncherService.filteredApps.length - 1)
                                    LauncherService.selectedIndex++;
                                event.accepted = true;
                            }

                            Keys.onPressed: event => {
                                const isBacktab = event.key === Qt.Key_Backtab;
                                const isShiftTab = event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier);

                                if (isBacktab || isShiftTab) {
                                    if (LauncherService.selectedIndex > 0)
                                        LauncherService.selectedIndex--;
                                    event.accepted = true;
                                }
                            }

                            Component.onCompleted: {
                                LauncherService.query = "";
                                LauncherService.selectedIndex = 0;
                                Qt.callLater(() => {
                                    if (LauncherService.visible) {
                                        forceActiveFocus();
                                    }
                                });
                            }
                        }

                        // Results counter
                        Rectangle {
                            visible: LauncherService.filteredApps.length > 0
                            Layout.preferredWidth: countText.implicitWidth + 12
                            Layout.preferredHeight: 22
                            radius: height / 2
                            color: Config.surface1Color

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: LauncherService.filteredApps.length
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.subtextColor
                            }
                        }

                        // Clear button
                        Rectangle {
                            visible: searchInput.text
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: height / 2
                            color: clearMouse.containsMouse ? Config.surface2Color : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDurationShort
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.subtextColor
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = "";
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(parent.width - 160, 800)
                    Layout.preferredHeight: 1
                    color: Config.surface1Color
                    opacity: 0.5
                }

                // App grid
                GridView {
                    id: appList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 20

                    clip: true
                    cellWidth: appList.width > 0 ? Math.floor(appList.width / Math.max(1, Math.floor(appList.width / 140))) : 140
                    cellHeight: 160
                    model: LauncherService.filteredApps
                    currentIndex: LauncherService.selectedIndex

                    // Add/remove item animations
                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Config.animDurationShort
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 0.8
                            to: 1
                            duration: Config.animDurationShort
                            easing.type: Easing.OutBack
                        }
                    }

                    remove: Transition {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: Config.animDurationShort
                        }
                    }

                    displaced: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    highlightFollowsCurrentItem: true
                    highlight: Rectangle {
                        width: appList.cellWidth
                        height: appList.cellHeight
                        radius: Config.radiusLarge
                        color: Qt.alpha(Config.accentColor, 0.15)
                        border.width: 2
                        border.color: Config.accentColor

                        Behavior on x {
                            NumberAnimation {
                                duration: Config.animDurationShort
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on y {
                            NumberAnimation {
                                duration: Config.animDurationShort
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    delegate: Item {
                        id: delegateItem
                        required property int index
                        required property var modelData

                        width: appList.cellWidth
                        height: appList.cellHeight

                        property bool isSelected: index === LauncherService.selectedIndex
                        property bool isHovered: delegateMouse.containsMouse
                        property bool isRecent: LauncherService.query === "" && LauncherService.recentIds.includes(modelData?.id ?? "")

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            // Icon container
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 96
                                height: 96
                                radius: Config.radiusLarge
                                color: delegateItem.isHovered ? Config.surface1Color : Config.surface0Color

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animDurationShort
                                    }
                                }

                                Image {
                                    anchors.centerIn: parent
                                    width: 72
                                    height: 72
                                    source: {
                                        const icon = delegateItem.modelData?.icon ?? "";
                                        return icon ? "image://icon/" + icon : "image://icon/application-x-executable";
                                    }
                                    sourceSize: Qt.size(96, 96)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                // Recent indicator dot
                                Rectangle {
                                    visible: delegateItem.isRecent
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Config.accentColor
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    anchors.margins: 4
                                }
                            }

                            // App name
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: appList.cellWidth - 12
                                text: delegateItem.modelData?.name ?? ""
                                color: delegateItem.isSelected ? Config.accentColor : Config.textColor
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeNormal
                                font.weight: delegateItem.isSelected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                maximumLineCount: 2
                                wrapMode: Text.Wrap

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animDurationShort
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: delegateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (delegateItem.isSelected) {
                                    // Second click: opens the app
                                    if (delegateItem.modelData)
                                        LauncherService.launch(delegateItem.modelData);
                                } else {
                                    // First click: selects
                                    LauncherService.selectedIndex = delegateItem.index;
                                }
                            }
                        }
                    }

                    // Empty state
                    Column {
                        anchors.centerIn: parent
                        spacing: Config.spacing
                        visible: appList.count === 0
                        opacity: visible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animDurationShort
                            }
                        }

                        Spinner {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: Config.fontSizeIconLarge
                            running: !LauncherService.query && appList.count === 0
                            color: Config.mutedColor
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: LauncherService.query ? "󰅖" : ""
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIconLarge
                            color: Config.mutedColor
                            visible: LauncherService.query
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: LauncherService.query ? "No results" : "Loading..."
                            color: Config.subtextColor
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                        }
                    }

                    // Auto-scroll when navigating
                    onCurrentIndexChanged: {
                        positionViewAtIndex(currentIndex, GridView.Contain);
                    }

                    // Smooth scroll
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded

                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: Config.surface2Color
                            opacity: parent.active ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Config.animDurationShort
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Focus grab
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: LauncherService.hide()
    }
}
