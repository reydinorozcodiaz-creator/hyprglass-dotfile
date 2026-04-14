pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

Singleton {
    id: root

    Component.onCompleted: dismissAllPopups()

    // ========================================================================
    // DND (DO NOT DISTURB)
    // ========================================================================

    property bool dndEnabled: false
    // -1 means indefinite, otherwise ms remaining
    property int dndMinutesLeft: -1
    readonly property string dndStatusText: {
        if (!dndEnabled)
            return "Disabled";
        if (dndMinutesLeft < 0)
            return "Enabled";
        if (dndMinutesLeft < 60)
            return dndMinutesLeft + " min left";
        const h = Math.floor(dndMinutesLeft / 60);
        const m = dndMinutesLeft % 60;
        return m > 0 ? (h + "h " + m + "m left") : (h + "h left");
    }

    // Enable DND for a set number of minutes (pass -1 for indefinite)
    function enableDndFor(minutes) {
        dndEnabled = true;
        dndMinutesLeft = minutes;
        if (minutes > 0)
            dndCountdown.restart();
        else
            dndCountdown.stop();
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i] && notifications[i].popup) {
                notifications[i].popup = false;
                notifications[i].stopLifecycle();
            }
        }
    }

    function disableDnd() {
        dndEnabled = false;
        dndMinutesLeft = -1;
        dndCountdown.stop();
    }

    // Countdown timer — ticks every minute
    Timer {
        id: dndCountdown
        interval: 60000
        repeat: true
        onTriggered: {
            if (root.dndMinutesLeft <= 1) {
                root.disableDnd();
            } else {
                root.dndMinutesLeft--;
            }
        }
    }

    function toggleDnd() {
        if (dndEnabled) {
            disableDnd();
        } else {
            enableDndFor(-1);
        }
    }

    function dismissAllPopups() {
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i] && notifications[i].popup) {
                notifications[i].popup = false;
                notifications[i].stopLifecycle();
            }
        }
    }

    Timer {
        id: popupLifecycleTimer
        interval: 33
        repeat: true
        running: root.activePopupCount > 0 && !root.dndEnabled

        onTriggered: {
            const nowMs = Date.now();
            for (let i = 0; i < root.notifications.length; i++) {
                const wrapper = root.notifications[i];
                if (wrapper && wrapper.popup)
                    wrapper.refreshLifecycle(nowMs);
            }
        }
    }

    // ========================================================================
    // NOTIFICATION LISTS
    // ========================================================================

    readonly property list<NotifWrapper> notifications: []
    property int activePopupCount: 0

    function _updateActivePopupCount() {
        let count = 0;
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i] && notifications[i].popup) count++;
        }
        activePopupCount = count;
    }

    onNotificationsChanged: Qt.callLater(_updateActivePopupCount)

    readonly property int count: notifications.length

    property int hoveredNotificationId: -1
    property int relativeTimeTick: 0

    Timer {
        id: relativeTimeTimer
        interval: 30000
        repeat: true
        running: root.count > 0
        onTriggered: root.relativeTimeTick++
    }

    // ========================================================================
    // NOTIFICATION SERVER
    // ========================================================================

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            if (notif.lastGeneration) {
                console.log("[Notif] Ignoring previous generation:", notif.appName, "-", notif.summary);
                return;
            }

            console.log("[Notif] Received:", notif.appName, "-", notif.summary);

            notif.tracked = true;

            // If DND is active, don't show popup but still keep in history
            const showPopup = !root.dndEnabled;

            const wrapper = notifComponent.createObject(root, {
                "popup": showPopup,
                "notification": notif
            });

            if (wrapper) {
                root.notifications.unshift(wrapper);

                // Enforce max history limit to prevent unbounded memory growth
                const maxHistory = Config.notifMaxHistory;
                while (root.notifications.length > maxHistory) {
                    const oldest = root.notifications.pop();
                    if (oldest) {
                        oldest.stopLifecycle();
                        if (oldest.notification)
                            oldest.notification.dismiss();
                    }
                }

                // Only start the lifecycle (timer) if not in DND
                if (showPopup) {
                    wrapper.startLifecycle();
                }

                console.log("[Notif] Wrapper created. Total:", root.notifications.length, "Popups:", root.activePopupCount, "DND:", root.dndEnabled);
            }
        }
    }

    // ========================================================================
    // WRAPPER COMPONENT
    // ========================================================================

    component NotifWrapper: QtObject {
        id: wrapper

        property bool popup: false
        onPopupChanged: Qt.callLater(root._updateActivePopupCount)

        // ====== TICK TIMER SYSTEM (for real pause) ======
        property int totalTime: Config.notifTimeout
        property int remainingTime: Config.notifTimeout
        property real progress: 0.0
        property bool lifecycleActive: false
        property double startedAtMs: 0
        property double pausedAtMs: 0
        property double pausedAccumulatedMs: 0

        function startLifecycle() {
            if (isUrgent && !forceAutoExpire) {
                progress = 0.0;
                remainingTime = totalTime;
                lifecycleActive = false;
                return;
            }
            remainingTime = totalTime;
            progress = 0.0;
            startedAtMs = Date.now();
            pausedAtMs = 0;
            pausedAccumulatedMs = 0;
            lifecycleActive = true;
            if (isPaused)
                pauseLifecycle();
        }

        function stopLifecycle() {
            lifecycleActive = false;
            pausedAtMs = 0;
        }

        function pauseLifecycle() {
            if (!lifecycleActive || pausedAtMs !== 0)
                return;
            pausedAtMs = Date.now();
        }

        function resumeLifecycle() {
            if (!lifecycleActive || pausedAtMs === 0)
                return;
            pausedAccumulatedMs += Date.now() - pausedAtMs;
            pausedAtMs = 0;
        }

        function refreshLifecycle(nowMs) {
            if (!popup || !lifecycleActive || (isUrgent && !forceAutoExpire) || pausedAtMs !== 0)
                return;

            const elapsed = nowMs - startedAtMs - pausedAccumulatedMs;
            remainingTime = Math.max(0, totalTime - elapsed);
            progress = Math.min(1.0, Math.max(0.0, 1.0 - (remainingTime / totalTime)));

            if (remainingTime <= 0) {
                popup = false;
                stopLifecycle();
            }
        }

        // Pause the timer on hover
        property bool isPaused: root.hoveredNotificationId === (notification ? notification.id : -1)

        onIsPausedChanged: {
            if (isPaused) {
                pauseLifecycle();
            } else {
                if (popup && remainingTime > 0)
                    resumeLifecycle();
                else if (popup && remainingTime <= 0)
                    popup = false;
            }
        }

        // Timestamp
        readonly property date time: new Date()
        readonly property string timeStr: {
            void root.relativeTimeTick;
            const now = new Date();
            const diff = now.getTime() - time.getTime();
            const minutes = Math.floor(diff / 60000);

            if (minutes < 1)
                return "now";
            if (minutes < 60)
                return minutes + "m ago";

            const hours = Math.floor(minutes / 60);
            if (hours < 24)
                return hours + "h ago";

            return Math.floor(hours / 24) + "d ago";
        }

        required property Notification notification

        readonly property int notifId: notification ? notification.id : -1
        readonly property string summary: notification ? (notification.summary || "") : ""
        readonly property string body: notification ? (notification.body || "") : ""
        readonly property string appIcon: notification ? (notification.appIcon || "") : ""
        readonly property string appName: notification ? (notification.appName || "System") : "System"
        readonly property string appNameNormalized: appName.trim().toLowerCase()
        readonly property string image: notification ? (notification.image || "") : ""
        readonly property int urgency: notification ? notification.urgency : 0
        readonly property bool isUrgent: urgency === 2
        // Battery alerts should look urgent, but still expire like normal popups.
        readonly property bool forceAutoExpire: appNameNormalized === "battery"
        readonly property var actions: notification ? (notification.actions || []) : []
        readonly property bool hasActions: actions && actions.length > 0

        readonly property Connections conn: Connections {
            target: wrapper.notification ? wrapper.notification.Retainable : null

            function onDropped() {
                console.log("[Notif] Dropped:", wrapper.notifId);
                wrapper.stopLifecycle();
                root.notifications = root.notifications.filter(w => w !== wrapper);
            }

            function onAboutToDestroy() {
                wrapper.stopLifecycle();
                wrapper.destroy();
            }
        }
    }

    Component {
        id: notifComponent
        NotifWrapper {}
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function setHovered(notifId) {
        hoveredNotificationId = notifId;
    }

    function clearHovered() {
        hoveredNotificationId = -1;
    }

    function expireNotification(notifId) {
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].notifId === notifId) {
                notifications[i].popup = false;
                notifications[i].stopLifecycle();
                break;
            }
        }
    }

    function removeNotification(notifId) {
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].notifId === notifId) {
                const wrapper = notifications[i];
                wrapper.popup = false;
                wrapper.stopLifecycle();
                if (wrapper.notification) {
                    wrapper.notification.dismiss();
                }
                break;
            }
        }
    }

    function clearAll() {
        const toRemove = notifications.slice();
        for (const wrapper of toRemove) {
            if (wrapper) {
                wrapper.stopLifecycle();
                if (wrapper.notification) {
                    wrapper.notification.dismiss();
                }
            }
        }
    }

    // ========================================================================
    // ICON HELPER
    // ========================================================================

    function getIconSource(appIcon, image) {
        if (image && image !== "") {
            if (image.startsWith("/"))
                return "file://" + image;
            if (image.startsWith("file://") || image.startsWith("image://"))
                return image;
            return image;
        }

        if (appIcon && appIcon !== "") {
            if (appIcon.startsWith("/"))
                return "file://" + appIcon;
            if (appIcon.startsWith("file://") || appIcon.startsWith("image://"))
                return appIcon;
            return "image://icon/" + appIcon;
        }

        return "";
    }
}
