pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    property bool visible: false
    property string type: "volume" // "volume", "brightness", "message"
    property real value: 0
    property bool muted: false
    property string messageIcon: ""
    property string messageText: ""

    // ========================================================================
    // HIDE TIMER
    // ========================================================================

    Timer {
        id: hideTimer
        interval: Config.osdTimeout
        onTriggered: root.visible = false
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function showVolume(vol, isMuted) {
        root.type = "volume";
        root.value = vol;
        root.muted = isMuted;
        root.visible = true;
        hideTimer.restart();
    }

    function showBrightness(brightness) {
        root.type = "brightness";
        root.value = brightness;
        root.muted = false;
        root.visible = true;
        hideTimer.restart();
    }

    function showMessage(icon, text) {
        root.type = "message";
        root.messageIcon = icon;
        root.messageText = text;
        root.muted = false;
        root.value = 0;
        root.visible = true;
        hideTimer.restart();
    }

    function hide() {
        root.visible = false;
    }
}
