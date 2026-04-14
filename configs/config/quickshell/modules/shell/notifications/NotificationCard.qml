pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

Item {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    // The notification wrapper (from NotificationService)
    required property var wrapper

    // Popup mode (true) or history mode (false)
    property bool popupMode: false

    // Internal state for exit animation
    property bool isExiting: false
    property bool isCollapsed: false
    property bool bodyExpanded: false

    // Drag/Swipe state
    property real dragOffset: 0
    property real dragStartX: 0
    property bool isDragging: false
    readonly property real dragThreshold: width * 0.3  // 30% of width to trigger dismiss
    property bool isDismissing: false

    // ========================================================================
    // PROPERTIES DERIVED FROM WRAPPER
    // ========================================================================

    readonly property int notifId: wrapper ? wrapper.notifId : -1
    readonly property string summary: wrapper ? wrapper.summary : ""
    readonly property string body: wrapper ? wrapper.body : ""
    readonly property string appName: wrapper ? wrapper.appName : "System"
    readonly property string appIcon: wrapper ? wrapper.appIcon : ""
    readonly property string image: wrapper ? wrapper.image : ""
    readonly property int urgency: wrapper ? wrapper.urgency : 0
    readonly property bool isUrgent: wrapper ? wrapper.isUrgent : false
    readonly property var actions: wrapper ? wrapper.actions : []
    readonly property bool hasActions: wrapper ? wrapper.hasActions : false
    readonly property bool showPopup: wrapper ? wrapper.popup : false
    readonly property string timeStr: wrapper ? wrapper.timeStr : ""

    // Check if paused (hover)
    readonly property bool isPaused: wrapper && wrapper.isPaused

    // Filter actions that should not be shown as buttons
    readonly property var visibleActions: {
        if (!actions || actions.length === 0)
            return [];

        let filtered = [];
        for (let i = 0; i < actions.length; i++) {
            const action = actions[i];
            if (!action)
                continue;

            const identifier = (action.identifier || "").toLowerCase();
            const text = action.text || "";

            if (identifier === "default" && text === "")
                continue;
            if (identifier === "activate" && text === "")
                continue;
            if (text.toLowerCase() === identifier && (identifier === "default" || identifier === "activate"))
                continue;

            if (text !== "") {
                filtered.push(action);
            }
        }
        return filtered;
    }

    readonly property bool hasVisibleActions: visibleActions && visibleActions.length > 0
    readonly property bool canExpandBody: !root.popupMode && (root.body.length > 160 || root.body.indexOf("\n") !== -1)

    function getActionLabel(action) {
        if (!action)
            return "";

        const text = action.text || "";
        if (text !== "")
            return text;

        const id = action.identifier || "";
        if (id === "")
            return "Abrir";

        return id.charAt(0).toUpperCase() + id.slice(1);
    }

    // ========================================================================
    // DIMENSIONS
    // ========================================================================

    readonly property int visualHeight: contentColumn.implicitHeight + 24
    implicitWidth: Config.notifWidth

    implicitHeight: {
        if (isCollapsed)
            return 0;
        if (popupMode && !showPopup)
            return 0;
        if (!wrapper)
            return 0;
        return visualHeight + Config.notifSpacing;
    }

    visible: !isCollapsed && (popupMode ? showPopup : true) && opacity > 0 && wrapper !== null

    // ========================================================================
    // VISUAL
    // ========================================================================

    // Container
    Item {
        id: clippedContainer
        width: parent.width
        height: root.visualHeight
        visible: root.wrapper !== null

        // Remove heavy Ops (Opacity Mask and MSAA) which cause severe lag on multiple notifications

        // Apply drag offset with smooth animation
        Behavior on x {
            enabled: !root.isDragging && !root.isDismissing
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuad
            }
        }

        x: root.dragOffset

        // Background
        Rectangle {
            anchors.fill: parent
            color: Config.backgroundTransparentColor
            radius: Config.radiusLarge
        }

        // Content
        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Main row: Icon + Text
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Icon / Image
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    Layout.alignment: Qt.AlignTop
                    radius: width / 2
                    color: root.isUrgent ? Qt.alpha(Config.errorColor, 0.2) : Config.surface1Color

                    Image {
                        id: notifImage
                        anchors.fill: parent
                        anchors.margins: root.image !== "" ? 0 : 8
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        mipmap: false
                        antialiasing: false
                        smooth: false
                        sourceSize: Qt.size(64, 64)

                        source: NotificationService.getIconSource(root.appIcon, root.image)

                        onStatusChanged: {
                            if (status === Image.Error && source !== "") {
                                source = "image://icon/dialog-information";
                            }
                        }
                    }

                    // Fallback icon if there is no image
                    Text {
                        visible: notifImage.status === Image.Error || (notifImage.source + "") === ""
                        anchors.centerIn: parent
                        text: "󰍡"
                        font.family: Config.font
                        font.pixelSize: 20
                        color: Config.subtextColor
                    }
                }

                // Texts
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    // Header: Title + App Name + Time
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: root.summary
                            color: Config.textColor
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                        }

                        Text {
                            text: root.appName
                            color: root.isUrgent ? Config.errorColor : Config.accentColor
                            font.family: Config.font
                            font.pixelSize: 10
                            font.bold: true
                            opacity: 0.8
                        }
                    }

                    // Time (only in history)
                    Text {
                        visible: !root.popupMode && root.timeStr !== ""
                        text: root.timeStr
                        color: Config.subtextColor
                        font.family: Config.font
                        font.pixelSize: 10
                        opacity: 0.7
                    }

                    // Notification body
                    Text {
                        id: bodyText
                        text: root.body
                        color: Config.subtextColor
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        wrapMode: Text.Wrap
                        maximumLineCount: root.bodyExpanded ? 0 : 3
                        elide: root.bodyExpanded ? Text.ElideNone : Text.ElideRight
                        Layout.fillWidth: true
                        visible: text !== ""
                        textFormat: Text.StyledText
                        onLinkActivated: link => {
                            if (/^https?:\/\//i.test(link))
                                Qt.openUrlExternally(link);
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: expandLabel.implicitHeight
                        visible: bodyText.visible && root.canExpandBody

                        Text {
                            id: expandLabel
                            anchors.left: parent.left
                            text: root.bodyExpanded ? "Mostrar menos" : "Mostrar mas"
                            font.family: Config.font
                            font.pixelSize: 10
                            font.bold: true
                            color: Config.accentColor
                            opacity: expandMouse.containsMouse ? 1.0 : 0.78
                        }

                        MouseArea {
                            id: expandMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.bodyExpanded = !root.bodyExpanded
                        }
                    }
                }
            }
        }
    }

    // Outer border (hover state)
    Rectangle {
        width: parent.width
        height: root.visualHeight
        radius: Config.radiusLarge
        color: "transparent"
        border.width: 1
        border.color: {
            if (root.isUrgent)
                return Config.errorColor;
            if (mouseArea.containsMouse)
                return Config.surface2Color;
            return "transparent";
        }
    }

    // Main MouseArea
    MouseArea {
        id: mouseArea
        width: parent.width
        height: root.visualHeight
        hoverEnabled: true
        acceptedButtons: Qt.RightButton | (root.popupMode ? Qt.LeftButton : Qt.NoButton)
        drag.target: root
        drag.axis: Drag.XAxis
        drag.minimumX: -root.width * 0.5
        drag.maximumX: root.width * 0.5

        onEntered: NotificationService.setHovered(root.notifId)
        onExited: {
            if (!root.isDragging)
                NotificationService.clearHovered()
        }

        onPressed: mouse => {
            root.isDragging = true
            root.dragStartX = mouse.x
        }

        onPositionChanged: mouse => {
            if (root.isDragging && pressedButtons & Qt.LeftButton) {
                root.dragOffset = mouse.x - root.dragStartX
            }
        }

        onReleased: mouse => {
            root.isDragging = false
            NotificationService.clearHovered()

            // Check if swipe threshold was crossed
            if (Math.abs(root.dragOffset) > root.dragThreshold) {
                // Animate out in the direction swiped
                const direction = root.dragOffset > 0 ? 1 : -1
                root.isDismissing = true
                swipeDismissAnim.toValue = direction * (root.width + 50)
                swipeDismissAnim.start()
            } else {
                // Snap back to original position
                root.dragOffset = 0
            }
        }

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.startExitAnimation(true);
            } else {
                if (root.popupMode) {
                    root.startExitAnimation(false);
                }
            }
        }
    }

    Rectangle {
        z: 3
        visible: mouseArea.containsMouse
        width: 22
        height: 22
        radius: 11
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        color: closeMouse.containsMouse ? Config.surface2Color : Config.surface1Color
        border.width: 1
        border.color: Qt.alpha(Config.textColor, 0.12)

        Text {
            anchors.centerIn: parent
            text: "󰅖"
            font.family: Config.font
            font.pixelSize: 11
            color: Config.textColor
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.startExitAnimation(true)
        }
    }

    // ========================================================================
    // EXIT ANIMATIONS
    // ========================================================================

    // Swipe dismiss animation (when swiped left/right)
    NumberAnimation {
        id: swipeDismissAnim
        target: root
        property: "dragOffset"
        duration: Config.animDuration
        easing.type: Easing.OutQuad

        onFinished: {
            root.isDismissing = false
            root.isCollapsed = true
            const id = root.notifId
            NotificationService.removeNotification(id)
            root.dragOffset = 0
            root.isCollapsed = false
        }
    }

    function startExitAnimation(removeCompletely) {
        if (isExiting)
            return;
        isExiting = true;
        exitAnim.removeCompletely = removeCompletely;
        exitAnim.start();
    }

    SequentialAnimation {
        id: exitAnim
        property bool removeCompletely: false

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 0
                duration: Config.animDuration
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "x"
                to: 50
                duration: Config.animDuration
                easing.type: Easing.InQuad
            }
        }

        ScriptAction {
            script: root.isCollapsed = true
        }

        PauseAnimation {
            duration: Config.animDuration
        }

        ScriptAction {
            script: {
                const id = root.notifId;

                if (exitAnim.removeCompletely) {
                    NotificationService.removeNotification(id);
                } else {
                    NotificationService.expireNotification(id);
                }

                root.opacity = 1;
                root.x = 0;
                root.isCollapsed = false;
                root.isExiting = false;
            }
        }
    }
}
