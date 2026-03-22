pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    property bool visible: false
    property string query: ""
    property int selectedIndex: 0
    property int maxItems: 200

    // Recently launched apps (stored as desktop entry IDs)
    property var recentIds: []
    readonly property int maxRecent: 8

    // Incremented on each open to force re-evaluation of the app list
    property int _refreshToken: 0

    // Filtered app list
    readonly property var filteredApps: {
        void root._refreshToken;
        let apps = DesktopEntries.applications.values;

        // Sort alphabetically
        apps = apps.slice().sort((a, b) => {
            const nameA = (a.name || "").toLowerCase();
            const nameB = (b.name || "").toLowerCase();
            return nameA.localeCompare(nameB);
        });

        if (query === "") {
            // Show recents first, then rest alphabetically
            if (root.recentIds.length > 0) {
                const recents = root.recentIds
                    .map(id => apps.find(a => a.id === id))
                    .filter(a => a != null);
                const rest = apps.filter(a => !root.recentIds.includes(a.id));
                return [...recents, ...rest].slice(0, maxItems);
            }
            return apps.slice(0, maxItems);
        }

        const q = query.toLowerCase();

        // Separate into two groups: name match vs description match
        let nameMatches = [];
        let descMatches = [];

        for (const app of apps) {
            const name = (app.name || "").toLowerCase();
            const comment = (app.comment || "").toLowerCase();
            const genericName = (app.genericName || "").toLowerCase();

            if (name.includes(q)) {
                nameMatches.push(app);
            } else if (comment.includes(q) || genericName.includes(q)) {
                descMatches.push(app);
            }
        }

        // Name first, then description
        return [...nameMatches, ...descMatches].slice(0, maxItems);
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function show() {
        _refreshToken++;
        query = "";
        selectedIndex = 0;
        visible = true;
    }

    function hide() {
        visible = false;
        query = "";
        selectedIndex = 0;
    }

    function toggle() {
        if (visible) hide();
        else show();
    }

    function _tokenizeExecString(execString) {
        let sanitized = (execString || "").trim();
        sanitized = sanitized.replace(/%%/g, "__QS_PERCENT__");
        sanitized = sanitized.replace(/%[uUfFdDnNickvm]/g, "");
        sanitized = sanitized.replace(/%[A-Za-z]/g, "");
        sanitized = sanitized.replace(/__QS_PERCENT__/g, "%");

        const regex = /"([^"\\]*(?:\\.[^"\\]*)*)"|'([^'\\]*(?:\\.[^'\\]*)*)'|([^\s]+)/g;
        let args = [];
        let match = null;

        while ((match = regex.exec(sanitized)) !== null) {
            let token = match[1] !== undefined
                ? match[1]
                : (match[2] !== undefined ? match[2] : match[3]);
            token = token.replace(/\\(["'\\ ])/g, "$1");
            if (token.length > 0)
                args.push(token);
        }

        return args;
    }

    function launch(entry) {
        if (!entry) return;

        console.log("[Launcher] Launching:", entry.name);

        // Track recent: move to front, cap at maxRecent
        const id = entry.id;
        if (id) {
            let recents = root.recentIds.filter(r => r !== id);
            recents.unshift(id);
            root.recentIds = recents.slice(0, root.maxRecent);
        }

        const args = _tokenizeExecString(entry.execString);
        if (args.length === 0) {
            console.warn("[Launcher] Could not parse command for:", entry.name);
            return;
        }

        Quickshell.execDetached(args);
        hide();
    }

    function launchSelected() {
        if (filteredApps.length > 0 && selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            launch(filteredApps[selectedIndex]);
        }
    }

    // ========================================================================
    // NAVIGATION
    // ========================================================================

    function navigateUp() {
        if (selectedIndex > 0) {
            selectedIndex--;
        }
    }

    function navigateDown() {
        if (selectedIndex < filteredApps.length - 1) {
            selectedIndex++;
        }
    }

    // Reset selectedIndex when query changes
    onQueryChanged: {
        selectedIndex = 0;
    }
}
