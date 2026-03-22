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
                notifications[i].tickTimer.stop();
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
                notifications[i].tickTimer.stop();
            }
        }
    }

    // ========================================================================
    // NOTIFICATION LISTS
    // ========================================================================

    readonly property list<NotifWrapper> notifications: []
    readonly property list<NotifWrapper> popups: notifications.filter(n => n && n.popup)

    readonly property int count: notifications.length
    readonly property int activePopupCount: popups.length

    property int hoveredNotificationId: -1

    // ========================================================================
    // NOTIFICATION SERVER
    // ========================================================================

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            console.log("[Notif] Received:", notif.appName, "-", notif.summary);

            notif.tracked = true;

            // If DND is active, don't show popup but still keep in history
            const showPopup = !root.dndEnabled;

            const wrapper = notifComponent.createObject(root, {
                "popup": showPopup,
                "notification": notif
            });

            if (wrapper) {
                root.notifications.push(wrapper);

                // Enforce max history limit to prevent unbounded memory growth
                const maxHistory = Config.notifMaxHistory;
                while (root.notifications.length > maxHistory) {
                    const oldest = root.notifications.shift();
                    if (oldest) {
                        oldest.tickTimer.stop();
                        if (oldest.notification)
                            oldest.notification.dismiss();
                    }
                }

                // Only start the lifecycle (timer) if not in DND
                if (showPopup) {
                    wrapper.startLifecycle();
                }
                
                console.log("[Notif] Wrapper created. Total:", root.notifications.length, "Popups:", root.popups.length, "DND:", root.dndEnabled);
            }
        }
    }

    // ========================================================================
    // WRAPPER COMPONENT
    // ========================================================================

    component NotifWrapper: QtObject {
        id: wrapper

        property bool popup: false

        // ====== TICK TIMER SYSTEM (for real pause) ======
        property int totalTime: Config.notifTimeout
        property int remainingTime: Config.notifTimeout

        // Progress from 0.0 to 1.0 (for the progress bar in the Card)
        property real progress: 0.0

        // Timer that decrements every 100ms (optimized from 50ms)
        readonly property Timer tickTimer: Timer {
            interval: 100
            repeat: true
            running: false

            onTriggered: {
                if (wrapper.remainingTime > 0) {
                    wrapper.remainingTime -= interval;
                    wrapper.progress = 1.0 - (wrapper.remainingTime / wrapper.totalTime);

                    if (wrapper.remainingTime <= 0) {
                        wrapper.remainingTime = 0;
                        wrapper.progress = 1.0;
                        stop();
                        wrapper.popup = false;
                        console.log("[Notif] Timer expired for:", wrapper.notifId);
                    }
                }
            }
        }

        function startLifecycle() {
            // Urgent notifications (urgency === 2) stay until dismissed manually
            if (isUrgent) {
                progress = 0.0;
                return;
            }
            remainingTime = totalTime;
            progress = 0.0;
            tickTimer.start();
        }

        // Pause the timer on hover
        property bool isPaused: root.hoveredNotificationId === (notification ? notification.id : -1)

        onIsPausedChanged: {
            if (isPaused) {
                if (tickTimer.running) {
                    tickTimer.stop();
                    console.log("[Notif] Paused:", notifId, "- Remaining:", remainingTime, "ms - Progress:", progress.toFixed(2));
                }
            } else {
                if (popup && remainingTime > 0 && !tickTimer.running) {
                    tickTimer.start();
                    console.log("[Notif] Resumed:", notifId, "- Remaining:", remainingTime, "ms");
                } else if (popup && remainingTime <= 0) {
                    popup = false;
                }
            }
        }

        // Timestamp
        readonly property date time: new Date()
        readonly property string timeStr: {
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
        readonly property string image: notification ? (notification.image || "") : ""
        readonly property int urgency: notification ? notification.urgency : 0
        readonly property bool isUrgent: urgency === 2
        readonly property var actions: notification ? (notification.actions || []) : []
        readonly property bool hasActions: actions && actions.length > 0

        readonly property Connections conn: Connections {
            target: wrapper.notification ? wrapper.notification.Retainable : null

            function onDropped(): void {
                console.log("[Notif] Dropped:", wrapper.notifId);
                wrapper.tickTimer.stop();
                root.notifications = root.notifications.filter(w => w !== wrapper);
            }

            function onAboutToDestroy(): void {
                wrapper.tickTimer.stop();
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
                notifications[i].tickTimer.stop();
                break;
            }
        }
    }

    function removeNotification(notifId) {
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].notifId === notifId) {
                const wrapper = notifications[i];
                wrapper.popup = false;
                wrapper.tickTimer.stop();
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
                wrapper.tickTimer.stop();
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
