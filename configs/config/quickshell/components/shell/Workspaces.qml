pragma ComponentBehavior: Bound

import QtQuick
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

    // --- Visible Workspaces Model ---
    ListModel {
        id: workspacesModel
    }

    function syncWorkspacesModel() {
        let ids = [];
        if (activeId > 0) {
            ids.push(activeId);
        }

        for (let wsId in occupiedWorkspaces) {
            let id = parseInt(wsId);
            if (id > 0 && id !== activeId && occupiedWorkspaces[wsId] === true)
                ids.push(id);
        }

        ids.sort((a, b) => a - b);

        for (let i = workspacesModel.count - 1; i >= 0; i--) {
            if (!ids.includes(workspacesModel.get(i).workspaceId)) {
                workspacesModel.remove(i);
            }
        }

        for (let i = 0; i < ids.length; i++) {
            let targetId = ids[i];
            let found = false;
            for (let j = 0; j < workspacesModel.count; j++) {
                if (workspacesModel.get(j).workspaceId === targetId) {
                    found = true;
                    if (j !== i) {
                        workspacesModel.move(j, i, 1);
                    }
                    break;
                }
            }
            if (!found) {
                workspacesModel.insert(i, { workspaceId: targetId });
            }
        }
    }

    onActiveIdChanged: syncWorkspacesModel()
    onOccupiedWorkspacesChanged: syncWorkspacesModel()

    // --- Monitor Logic ---
    readonly property var parentWindow: QsWindow.window
    readonly property var parentScreen: parentWindow?.screen ?? null

    property var currentMonitor: {
        if (!Hyprland)
            return null;
        return (parentScreen ? Hyprland.monitorFor(parentScreen) : null) ?? Hyprland.focusedMonitor ?? null;
    }

    readonly property string monitorName: currentMonitor?.name ?? ""

    // --- Special Workspace Detection ---
    property string manualSpecialName: ""
    readonly property bool isSpecialWorkspace: manualSpecialName !== ""

    readonly property string specialWorkspaceName: {
        if (!isSpecialWorkspace)
            return "";
        return manualSpecialName.startsWith("special:") ? manualSpecialName.substring(8) : manualSpecialName;
    }

    // --- Normal Workspace Math ---
    property int activeId: 1

    implicitWidth: isSpecialWorkspace ? specialIndicator.width : workspacesRow.implicitWidth
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

    // --- Occupied Workspaces ---
    property var occupiedWorkspaces: ({})

    function parseWorkspaceId(data) {
        const value = String(data ?? "");
        const firstPart = value.split(",")[0];
        const parsedId = Number(firstPart);
        return parsedId > 0 ? parsedId : 0;
    }

    function setWorkspaceOccupied(workspaceId, occupied) {
        const targetId = Number(workspaceId);
        if (!Number.isInteger(targetId) || targetId <= 0)
            return;

        const key = String(targetId);
        const nextState = occupied === true;
        const currentState = occupiedWorkspaces[key] === true;
        if (currentState === nextState)
            return;

        const nextWorkspaces = Object.assign({}, occupiedWorkspaces);
        if (nextState)
            nextWorkspaces[key] = true;
        else
            delete nextWorkspaces[key];

        occupiedWorkspaces = nextWorkspaces;
    }

    function syncActiveWorkspace() {
        const nextId = Number(root.currentMonitor?.activeWorkspace?.id ?? 0);
        const normalizedId = nextId > 0 ? nextId : 1;

        if (root.activeId !== normalizedId)
            root.activeId = normalizedId;
    }

    function activateWorkspace(workspaceId) {
        const targetId = Number(workspaceId);
        if (!Number.isInteger(targetId) || targetId <= 0)
            return;

        manualSpecialName = "";
        if (activeId !== targetId)
            activeId = targetId;
        setWorkspaceOccupied(targetId, true);
    }

    function focusWorkspace(workspaceId) {
        const targetId = Number(workspaceId);
        if (!Number.isInteger(targetId) || targetId <= 0)
            return;

        const currentId = root.activeId;
        if (currentId === targetId)
            return;

        Hyprland.dispatch("focusworkspaceoncurrentmonitor " + targetId);
    }

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

    onCurrentMonitorChanged: {
        root.syncActiveWorkspace();
        root.updateOccupiedWorkspaces();
    }

    Component.onCompleted: {
        root.syncActiveWorkspace();
        root.updateOccupiedWorkspaces();
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
            if (event.name === "workspace" || event.name === "workspacev2")
                root.activateWorkspace(root.parseWorkspaceId(event.data));

            if (event.name === "focusedmonv2") {
                const parts = String(event.data ?? "").split(",");
                const targetMonitor = parts[0] || "";
                const workspaceId = Number(parts[1] || 0);
                if (targetMonitor === root.monitorName)
                    root.activateWorkspace(workspaceId);
            }

            if (event.name === "createworkspace" || event.name === "createworkspacev2")
                root.setWorkspaceOccupied(root.parseWorkspaceId(event.data), true);

            if (event.name === "destroyworkspace" || event.name === "destroyworkspacev2")
                root.setWorkspaceOccupied(root.parseWorkspaceId(event.data), false);

            if (event.name === "openwindow" || event.name === "openwindowv2") {
                const parts = String(event.data ?? "").split(",");
                if (parts.length > 1)
                    root.setWorkspaceOccupied(Number(parts[1]), true);
            }
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

        Item {
            id: container
            width: workspacesRow.implicitWidth
            height: parent.height

            Row {
                id: workspacesRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.itemSpacing

                Repeater {
                    model: workspacesModel
                    delegate: Rectangle {
                        id: workspaceItem
                        // Since we append { workspaceId: X } to ListModel, it exposes workspaceId directly
                        required property int workspaceId
                        readonly property bool isActive: workspaceId === root.activeId

                        width: isActive ? root.activeWidth : root.itemWidth
                        height: isActive ? root.activeHeight : root.itemHeight
                        radius: width / 2.4
                        color: isActive ? Config.accentColor : Config.surface2Color
                        border.width: isActive ? 0 : 1
                        border.color: Qt.alpha(Config.textColor, 0.2)
                        opacity: workspaceHover.hovered ? 0.8 : 1.0

                        Behavior on width {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutExpo
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDuration
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animDuration
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
                            scale: workspaceItem.isActive ? 1.0 : 0.92

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutBack
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDuration
                                }
                            }
                        }

                        TapHandler {
                            onTapped: root.focusWorkspace(workspaceItem.workspaceId)
                        }

                        HoverHandler {
                            id: workspaceHover
                            cursorShape: !workspaceItem.isActive ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }
                    }
                }
            }
        }
    }
}
