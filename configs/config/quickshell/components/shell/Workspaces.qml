pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config

Item {
    id: root

    // --- Sizing Properties ---
    readonly property int itemWidth: 34
    readonly property int itemHeight: 34
    readonly property int activeWidth: 54
    readonly property int activeHeight: 34
    readonly property int itemSpacing: 6
    readonly property int visibleCount: 7
    readonly property int totalWorkspaces: 10

    // --- Visible Workspaces Array (only occupied + active) ---
    property var visibleWorkspaceIds: {
        let ids = [];
        // Always include active workspace
        if (activeId > 0) {
            ids.push(activeId);
        }
        // Add all occupied workspaces
        for (let wsId in occupiedWorkspaces) {
            let id = parseInt(wsId);
            if (id > 0 && id !== activeId && occupiedWorkspaces[wsId] === true) {
                ids.push(id);
            }
        }
        // Sort numerically
        ids.sort((a, b) => a - b);
        return ids;
    }

    // --- Monitor Logic ---
    readonly property var parentWindow: QsWindow.window
    readonly property var parentScreen: parentWindow?.screen ?? null

    property var currentMonitor: {
        if (!Hyprland)
            return null;
        return (parentScreen ? Hyprland.monitorFor(parentScreen) : null) ?? Hyprland.focusedMonitor ?? null;
    }

    readonly property string monitorName: currentMonitor?.name ?? ""
    property var activeWorkspace: currentMonitor?.activeWorkspace ?? null

    // --- Special Workspace Detection ---
    property string manualSpecialName: ""
    readonly property bool isSpecialWorkspace: manualSpecialName !== ""

    readonly property string specialWorkspaceName: {
        if (!isSpecialWorkspace)
            return "";
        return manualSpecialName.startsWith("special:") ? manualSpecialName.substring(8) : manualSpecialName;
    }

    // --- Normal Workspace Math ---
    property int activeId: (activeWorkspace && activeWorkspace.id > 0) ? activeWorkspace.id : 1
    property int monitorOffset: Math.floor((activeId - 1) / 100) * 100
    readonly property int relativeActiveId: Math.max(1, Math.min(activeId - monitorOffset, totalWorkspaces))

    // --- Layout Dimensions ---
    readonly property real viewportWidth: (itemWidth * visibleCount) + (activeWidth - itemWidth) + (itemSpacing * (visibleCount - 1))
    readonly property real itemStep: itemWidth + itemSpacing

    // Calculate visible workspaces count dynamically
    property int visibleWorkspacesCount: visibleWorkspaceIds.length

    // Dynamic width based on visible workspaces
    readonly property real dynamicWidth: {
        if (visibleWorkspacesCount === 0) return 0;
        let baseWidth = (itemWidth * visibleWorkspacesCount) + (itemSpacing * Math.max(0, visibleWorkspacesCount - 1));
        // Add extra width for the active workspace
        return baseWidth + (activeWidth - itemWidth);
    }

    implicitWidth: isSpecialWorkspace ? specialIndicator.width : dynamicWidth
    implicitHeight: activeHeight

    // --- Special Workspaces Config ---
    readonly property var specialWorkspaces: ({
            "whatsapp": {
                icon: "󰖣",
                color: Config.successColor,
                name: "WhatsApp"
            },
            "spotify": {
                icon: "󰓇",
                color: Config.accentColor,
                name: "Music"
            },
            "magic": {
                icon: "󰀘",
                color: Config.warningColor,
                name: "Magic"
            }
        })

    // --- Cache Logic to prevent flashing ---
    property string cachedIcon: "󰀘"
    property string cachedName: ""
    property color cachedColor: Config.accentColor

    readonly property var currentSpecialConfig: {
        if (!isSpecialWorkspace)
            return null;
        return specialWorkspaces[specialWorkspaceName] ?? {
            icon: "󰀘",
            color: Config.accentColor,
            name: specialWorkspaceName.charAt(0).toUpperCase() + specialWorkspaceName.slice(1)
        };
    }

    // Updates the cache only when there is a valid workspace
    onCurrentSpecialConfigChanged: {
        if (currentSpecialConfig) {
            cachedIcon = currentSpecialConfig.icon;
            cachedName = currentSpecialConfig.name;
            cachedColor = currentSpecialConfig.color;
        }
    }

    // --- Scroll Logic ---
    readonly property int targetIndex: {
        let idx = visibleWorkspaceIds.indexOf(activeId);
        return idx >= 0 ? idx : 0;
    }
    readonly property real targetScrollX: 0  // No scroll needed, always show all

    property real animatedScrollX: targetScrollX
    Behavior on animatedScrollX {
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutQuint
        }
    }

    // --- Occupied Workspaces ---
    property var occupiedWorkspaces: ({})
    function updateOccupiedWorkspaces() {
        if (!Hyprland || !Hyprland.workspaces)
            return;
        let newObj = {};
        for (let ws of Hyprland.workspaces.values) {
            if (ws && ws.id > 0)
                newObj[ws.id] = true;
        }
        occupiedWorkspaces = newObj;
    }

    Component.onCompleted: updateOccupiedWorkspaces()

    Timer {
        id: occupiedUpdateTimer
        interval: 10
        onTriggered: root.updateOccupiedWorkspaces()
    }

    // --- Event Handling ---
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event)
                return;
            if (event.name === "activespecial") {
                let parts = event.data.split(',');
                let wsName = parts[0] || "";
                let targetMonitor = parts[1] || "";
                if (targetMonitor === "" || targetMonitor === root.monitorName) {
                    root.manualSpecialName = wsName;
                }
            }
            if (event.name === "workspace") {
                root.manualSpecialName = "";
                occupiedUpdateTimer.restart();
            }
            const refreshEvents = ["createworkspace", "destroyworkspace", "movewindow", "openwindow", "closewindow"];
            if (refreshEvents.includes(event.name))
                occupiedUpdateTimer.restart();
        }
    }

    // =========================================================================
    // SPECIAL WORKSPACE INDICATOR
    // =========================================================================
    Rectangle {
        id: specialIndicator
        visible: opacity > 0
        anchors.centerIn: parent

        // Opacity depends only on whether the state is special
        opacity: root.isSpecialWorkspace ? (specialHover.hovered ? 0.8 : 1.0) : 0

        scale: root.isSpecialWorkspace ? 1.0 : 0.9
        property int yOffset: root.isSpecialWorkspace ? 0 : 5
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: yOffset

        width: specialContent.width + Config.padding * 3
        height: root.activeHeight
        radius: Config.radius

        color: root.cachedColor
        border.width: 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        Row {
            id: specialContent
            anchors.centerIn: parent
            spacing: Config.padding * 0.8

            Text {
                // Uses the cached icon
                text: root.cachedIcon
                font {
                    family: Config.font
                    pixelSize: Config.fontSizeLarge
                }
                color: Config.textReverseColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                // Uses the cached name
                text: root.cachedName
                font {
                    family: Config.font
                    bold: true
                    pixelSize: Config.fontSizeNormal
                }
                color: Config.textReverseColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        TapHandler {
            onTapped: {
                if (root.specialWorkspaceName)
                    Hyprland.dispatch("togglespecialworkspace " + root.specialWorkspaceName);
            }
        }
        HoverHandler {
            id: specialHover
            cursorShape: Qt.PointingHandCursor
        }
    }

    // =========================================================================
    // NORMAL WORKSPACES LIST
    // =========================================================================
    Item {
        id: workspacesContainer
        visible: !root.isSpecialWorkspace
        opacity: visible ? 1 : 0
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        clip: false

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
            }
        }

        Item {
            id: container
            x: 0  // No scroll, always starts at 0
            width: root.dynamicWidth
            height: parent.height

            Repeater {
                model: root.visibleWorkspaceIds
                delegate: Rectangle {
                    id: workspaceItem
                    required property int index
                    required property int modelData
                    readonly property int workspaceId: modelData
                    readonly property bool isActive: workspaceId === root.activeId
                    readonly property bool isEmpty: false  // All visible workspaces are occupied

                    x: {
                        let baseX = 0;
                        // Calculate position based on index in visible array
                        for (let i = 0; i < index; i++) {
                            baseX += (root.visibleWorkspaceIds[i] === root.activeId ? root.activeWidth : root.itemWidth) + root.itemSpacing;
                        }
                        return baseX;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                    width: isActive ? root.activeWidth : root.itemWidth
                    height: isActive ? root.activeHeight : root.itemHeight
                    radius: width / 2.4
                    color: isActive ? Config.accentColor : Config.surface2Color
                    border.width: isActive ? 0 : 1
                    border.color: Qt.alpha(Config.textColor, 0.2)
                    opacity: workspaceHover.hovered ? 0.8 : 1.0
                    visible: true

                    Behavior on x {
                        NumberAnimation {
                            duration: Config.animDurationLong
                            easing.type: Easing.OutExpo
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutExpo
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutExpo
                        }
                    }
                    Behavior on radius {
                        NumberAnimation {
                            duration: 500
                            easing.type: Easing.OutExpo
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 500
                            easing.type: Easing.OutExpo
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 500
                            easing.type: Easing.OutExpo
                        }
                    }
                    Behavior on border.width {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: workspaceItem.workspaceId
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeLarge
                        font.bold: workspaceItem.isActive
                        color: workspaceItem.isActive ? Config.textReverseColor : Config.textColor
                        opacity: 1.0
                        scale: workspaceItem.isActive ? 1.0 : 0.9
                        
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutExpo
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 500
                                easing.type: Easing.OutBack
                            }
                        }
                        Behavior on font.pixelSize {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutExpo
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 400
                                easing.type: Easing.OutExpo
                            }
                        }
                    }

                    TapHandler {
                        onTapped: {
                            if (!workspaceItem.isActive)
                                Hyprland.dispatch("workspace " + workspaceItem.workspaceId);
                        }
                    }

                    HoverHandler {
                        id: workspaceHover
                        cursorShape: {
                            if (!workspaceItem.isActive)
                                return Qt.PointingHandCursor;
                        }
                    }
                }
            }
        }
    }
}
