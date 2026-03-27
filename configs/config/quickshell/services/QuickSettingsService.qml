pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool visible: false
    property string requestedPage: "dashboard"
    property int requestToken: 0
    property var windowRef: null

    function show(pageName) {
        requestedPage = pageName || "dashboard";
        requestToken++;
        visible = true;
        if (windowRef && !windowRef.visible)
            windowRef.visible = true;
    }

    function openPage(pageName) {
        show(pageName);
    }

    function toggle(pageName) {
        const targetPage = pageName || "dashboard";
        if (visible && requestedPage === targetPage)
            hide();
        else
            show(targetPage);
    }

    function hide() {
        if (windowRef && windowRef.visible)
            windowRef.closeWindow();
        else
            notifyClosed();
    }

    function registerWindow(window) {
        windowRef = window;
    }

    function unregisterWindow(window) {
        if (windowRef === window)
            windowRef = null;
    }

    function notifyClosed() {
        visible = false;
        requestedPage = "dashboard";
        requestToken++;
    }
}
