pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.config

PanelWindow {
    id: root

    visible: LauncherService.visible

    readonly property string trackedModuleName: "Launcher"
    readonly property color selectionColor: Qt.rgba(0.50, 0.67, 0.92, 0.26)
    readonly property color selectionBorderColor: Qt.rgba(0.72, 0.84, 1.0, 0.42)
    readonly property color selectionGlowColor: Qt.rgba(0.50, 0.67, 0.92, 0.12)
    readonly property color hoverColor: Qt.alpha(Config.surface1Color, 0.18)
    readonly property string matchColorCss: "#E8F1FF"

    function escapeMarkup(text) {
        return (text || "")
            .toString()
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
    }

    function highlightedLabel(text) {
        const plainText = (text || "").toString();
        const query = (LauncherService.query || "").trim().toLowerCase();
        if (query === "")
            return escapeMarkup(plainText);

        const lowerText = plainText.toLowerCase();
        const matchIndex = lowerText.indexOf(query);
        if (matchIndex === -1)
            return escapeMarkup(plainText);

        const before = escapeMarkup(plainText.slice(0, matchIndex));
        const match = escapeMarkup(plainText.slice(matchIndex, matchIndex + query.length));
        const after = escapeMarkup(plainText.slice(matchIndex + query.length));
        return before + "<font color=\"" + matchColorCss + "\"><b>" + match + "</b></font>" + after;
    }

    function resultTypeLabel(item) {
        const kind = item?.kind || "app";
        if (kind === "intent")
            return "Action";
        if (kind === "action")
            return "Shortcut";
        return "App";
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "qs_modules"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1

    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    onVisibleChanged: {
        if (visible)
            WindowManagerService.registerOpen(trackedModuleName);
        else
            WindowManagerService.registerClose(trackedModuleName);
    }

    Component.onDestruction: WindowManagerService.registerClose(trackedModuleName)

    MouseArea {
        anchors.fill: parent
        onClicked: LauncherService.hide()
    }

    Loader {
        anchors.fill: parent
        active: LauncherService.visible

        sourceComponent: Item {
            anchors.fill: parent

            readonly property int canvasMaxWidth: 1334
            readonly property int canvasMaxHeight: 726
            readonly property int desiredColumns: Math.max(5, Math.min(8, Math.floor(gridArea.width / 132)))

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Config.backgroundColor, Math.min(0.58, Config.launcherOpacity + 0.08))
            }

            Rectangle {
                id: canvas

                width: Math.min(root.width - 16, canvasMaxWidth)
                height: Math.min(root.height - Config.barHeight - 10, canvasMaxHeight)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Config.barHeight + 2

                color: Qt.alpha(Config.backgroundColor, 0.12)
                border.width: 0

                Rectangle {
                    id: searchShell

                    width: 236
                    height: 54
                    radius: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 56

                    color: Qt.rgba(0.10, 0.11, 0.14, 0.72)
                    border.width: 1
                    border.color: Qt.alpha(searchInput.activeFocus ? Config.textColor : Config.surface1Color,
                                           searchInput.activeFocus ? 0.14 : 0.08)

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: event => event.accepted = true
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: "󰀻"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Qt.alpha(Config.textColor, 0.78)
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            color: Config.textColor
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            placeholderText: "Search"
                            placeholderTextColor: Qt.alpha(Config.textColor, 0.55)
                            selectionColor: Qt.alpha(root.selectionColor, 0.35)
                            selectedTextColor: Config.textColor
                            background: null

                            onTextChanged: querySyncTimer.restart()

                            Keys.onEscapePressed: {
                                focus = false;
                                LauncherService.hide();
                            }

                            Keys.onReturnPressed: {
                                if (querySyncTimer.running) {
                                    querySyncTimer.stop();
                                    LauncherService.query = text;
                                }
                                LauncherService.launchSelected();
                            }

                            Keys.onLeftPressed: event => {
                                if (LauncherService.query.trim() !== "")
                                    return;
                                if (LauncherService.selectedIndex > 0) {
                                    LauncherService.selectedIndex--;
                                    event.accepted = true;
                                }
                            }

                            Keys.onRightPressed: event => {
                                if (LauncherService.query.trim() !== "")
                                    return;
                                if (LauncherService.selectedIndex < LauncherService.filteredApps.length - 1) {
                                    LauncherService.selectedIndex++;
                                    event.accepted = true;
                                }
                            }

                            Keys.onUpPressed: event => {
                                if (LauncherService.query.trim() !== "") {
                                    if (LauncherService.selectedIndex > 0)
                                        LauncherService.selectedIndex--;
                                    event.accepted = true;
                                    return;
                                }
                                const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth));
                                const newIndex = LauncherService.selectedIndex - cols;
                                if (newIndex >= 0)
                                    LauncherService.selectedIndex = newIndex;
                                event.accepted = true;
                            }

                            Keys.onDownPressed: event => {
                                if (LauncherService.query.trim() !== "") {
                                    if (LauncherService.selectedIndex < LauncherService.filteredApps.length - 1)
                                        LauncherService.selectedIndex++;
                                    event.accepted = true;
                                    return;
                                }
                                const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth));
                                const newIndex = LauncherService.selectedIndex + cols;
                                if (newIndex < LauncherService.filteredApps.length)
                                    LauncherService.selectedIndex = newIndex;
                                event.accepted = true;
                            }

                            Component.onCompleted: {
                                querySyncTimer.stop();
                                LauncherService.query = "";
                                LauncherService.selectedIndex = 0;
                                Qt.callLater(() => {
                                    if (LauncherService.visible)
                                        forceActiveFocus();
                                });
                            }
                        }
                    }

                    Timer {
                        id: querySyncTimer
                        interval: 16
                        repeat: false
                        onTriggered: LauncherService.query = searchInput.text
                    }
                }

                Item {
                    id: gridArea

                    anchors.top: searchShell.bottom
                    anchors.topMargin: 62
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 72
                    anchors.rightMargin: 72
                    anchors.bottomMargin: 36

                    GridView {
                        id: grid

                        anchors.fill: parent

                        clip: true
                        reuseItems: true
                        cacheBuffer: 240
                        boundsBehavior: Flickable.StopAtBounds
                        visible: LauncherService.query.trim() === ""
                        model: LauncherService.filteredApps
                        currentIndex: LauncherService.selectedIndex
                        cellWidth: Math.max(118, Math.floor(width / Math.max(1, desiredColumns)))
                        cellHeight: 178

                    delegate: Item {
                        id: delegateItem
                        required property int index
                        required property var modelData

                        width: grid.cellWidth
                        height: grid.cellHeight

                        property bool isSelected: index === LauncherService.selectedIndex
                        property bool isHovered: tileMouse.containsMouse
                        property bool isAction: (modelData?.kind || "app") === "action"
                        property bool isPinned: LauncherService.isPinned(modelData?.id || "")
                        property bool canPin: (modelData?.kind || "app") !== "intent"

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: delegateItem.isSelected ? -4 : 0
                            width: Math.min(parent.width - 6, 126)
                            height: delegateItem.isSelected ? 162 : 154
                            radius: 22
                            visible: delegateItem.isSelected
                            color: root.selectionGlowColor
                        }

                        Rectangle {
                            id: tileBackground
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            width: Math.min(parent.width - 14, 116)
                            height: 154
                            radius: 18
                            color: delegateItem.isSelected
                                ? root.selectionColor
                                : (delegateItem.isHovered ? Qt.alpha(root.hoverColor, 1.15) : "transparent")
                            border.width: delegateItem.isSelected ? 1 : (delegateItem.isHovered ? 1 : 0)
                            border.color: delegateItem.isSelected
                                ? root.selectionBorderColor
                                : Qt.alpha(Config.surface1Color, 0.18)
                            opacity: delegateItem.isHovered || delegateItem.isSelected ? 1 : 0.92

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: parent.radius - 1
                                color: delegateItem.isSelected
                                    ? Qt.rgba(0.82, 0.89, 1.0, 0.05)
                                    : "transparent"
                            }

                            Rectangle {
                                visible: delegateItem.canPin && delegateItem.isPinned
                                width: 20
                                height: 20
                                radius: 10
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 8
                                color: Qt.alpha(Config.textColor, 0.18)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐃"
                                    font.family: Config.font
                                    font.pixelSize: 10
                                    color: Config.textColor
                                }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.topMargin: delegateItem.isSelected ? 20 : 16
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 12

                                Item {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: delegateItem.isSelected ? 72 : 68
                                    height: delegateItem.isSelected ? 72 : 68

                                    Image {
                                        anchors.centerIn: parent
                                        visible: !delegateItem.isAction
                                        asynchronous: true
                                        width: parent.width
                                        height: parent.height
                                        source: {
                                            const icon = delegateItem.modelData?.iconName ?? "";
                                            return icon ? "image://icon/" + icon : "image://icon/application-x-executable";
                                        }
                                        sourceSize: Qt.size(96, 96)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: delegateItem.isAction
                                        text: delegateItem.modelData?.iconGlyph ?? "󰀻"
                                        font.family: Config.font
                                        font.pixelSize: delegateItem.isSelected ? 44 : 40
                                        color: Config.textColor
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: root.highlightedLabel(delegateItem.modelData?.name ?? "")
                                    textFormat: Text.StyledText
                                    color: Config.textColor
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall + 1
                                    font.weight: delegateItem.isSelected ? Font.Medium : Font.Normal
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                }
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton && delegateItem.canPin) {
                                    LauncherService.togglePinned(delegateItem.modelData?.id || "");
                                    return;
                                }
                                if (delegateItem.isSelected) {
                                    if (delegateItem.modelData)
                                        LauncherService.launch(delegateItem.modelData);
                                } else {
                                    LauncherService.selectedIndex = delegateItem.index;
                                    }
                                }
                            }
                        }

                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded

                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: Qt.alpha(Config.surface2Color, 0.45)
                            }

                            background: Rectangle {
                                implicitWidth: 4
                                color: "transparent"
                            }
                        }
                    }

                    ListView {
                        id: searchResults

                        anchors.fill: parent
                        visible: LauncherService.query.trim() !== ""
                        clip: true
                        reuseItems: true
                        cacheBuffer: 320
                        spacing: 10
                        boundsBehavior: Flickable.StopAtBounds
                        model: LauncherService.filteredApps
                        currentIndex: LauncherService.selectedIndex

                        delegate: Item {
                            id: rowItem
                            required property int index
                            required property var modelData

                            width: searchResults.width
                            height: 72

                            property bool isSelected: index === LauncherService.selectedIndex
                            property bool isHovered: rowMouse.containsMouse
                            property bool isAction: (modelData?.kind || "app") !== "app"
                            property bool isPinned: LauncherService.isPinned(modelData?.id || "")
                            property bool canPin: (modelData?.kind || "app") !== "intent"

                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: rowItem.isSelected
                                    ? root.selectionColor
                                    : (rowItem.isHovered ? Qt.alpha(root.hoverColor, 1.1) : "transparent")
                                border.width: rowItem.isSelected ? 1 : (rowItem.isHovered ? 1 : 0)
                                border.color: rowItem.isSelected
                                    ? root.selectionBorderColor
                                    : Qt.alpha(Config.surface1Color, 0.18)
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 17
                                visible: rowItem.isSelected
                                color: Qt.rgba(0.82, 0.89, 1.0, 0.05)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 14

                                Item {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42

                                    Image {
                                        anchors.fill: parent
                                        visible: !rowItem.isAction
                                        asynchronous: true
                                        source: {
                                            const icon = rowItem.modelData?.iconName ?? "";
                                            return icon ? "image://icon/" + icon : "image://icon/application-x-executable";
                                        }
                                        sourceSize: Qt.size(64, 64)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: rowItem.isAction
                                        text: rowItem.modelData?.iconGlyph ?? "󰀻"
                                        font.family: Config.font
                                        font.pixelSize: 30
                                        color: Config.textColor
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.highlightedLabel(rowItem.modelData?.name ?? "")
                                        textFormat: Text.StyledText
                                        color: Config.textColor
                                        font.family: Config.font
                                        font.pixelSize: Config.fontSizeNormal
                                        font.weight: rowItem.isSelected ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.highlightedLabel(rowItem.modelData?.subtitle ?? "")
                                        textFormat: Text.StyledText
                                        color: Qt.alpha(Config.textColor, 0.64)
                                        font.family: Config.font
                                        font.pixelSize: Config.fontSizeSmall
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 12
                                    color: Qt.alpha(Config.textColor, 0.10)
                                    visible: rowItem.canPin && rowItem.isPinned
                                    implicitWidth: pinRow.implicitWidth + 12
                                    implicitHeight: 24

                                    Row {
                                        id: pinRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: "󰐃"
                                            font.family: Config.font
                                            font.pixelSize: 11
                                            color: Config.textColor
                                        }

                                        Text {
                                            text: "Pinned"
                                            font.family: Config.font
                                            font.pixelSize: Config.fontSizeSmall - 1
                                            color: Config.textColor
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 12
                                    color: Qt.alpha(Config.textColor, 0.08)
                                    implicitWidth: typeText.implicitWidth + 12
                                    implicitHeight: 24

                                    Text {
                                        id: typeText
                                        anchors.centerIn: parent
                                        text: root.resultTypeLabel(rowItem.modelData)
                                        font.family: Config.font
                                        font.pixelSize: Config.fontSizeSmall - 1
                                        color: Qt.alpha(Config.textColor, 0.78)
                                    }
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton && rowItem.canPin) {
                                        LauncherService.togglePinned(rowItem.modelData?.id || "");
                                        return;
                                    }
                                    if (rowItem.isSelected) {
                                        if (rowItem.modelData)
                                            LauncherService.launch(rowItem.modelData);
                                    } else {
                                        LauncherService.selectedIndex = rowItem.index;
                                    }
                                }
                            }
                        }

                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded

                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: Qt.alpha(Config.surface2Color, 0.45)
                            }

                            background: Rectangle {
                                implicitWidth: 4
                                color: "transparent"
                            }
                        }
                    }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: canvas.top
                anchors.topMargin: 232
                spacing: 8
                visible: LauncherService.filteredApps.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No results"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    color: Config.textColor
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Try another search term."
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Qt.alpha(Config.textColor, 0.68)
                }
            }
        }
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: LauncherService.hide()
    }
}
