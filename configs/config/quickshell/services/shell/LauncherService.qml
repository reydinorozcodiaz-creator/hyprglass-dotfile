pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property bool visible: false
    property string query: ""
    property int selectedIndex: 0
    property int maxItems: 200
    property int searchMaxItems: 36

    property var recentIds: []
    readonly property int maxRecent: 12
    readonly property var defaultPinnedIds: [
        "action:settings",
        "action:wifi",
        "action:bluetooth",
        "action:clipboard",
        "action:screenshot",
        "action:theme",
        "action:power",
        "action:lock"
    ]
    property var pinnedIds: []
    property var usageCounts: ({})

    property int _refreshToken: 0
    property var _allEntries: []
    property var _entryById: ({})

    function _normalize(text) {
        return (text || "")
            .toString()
            .toLowerCase()
            .normalize("NFD")
            .replace(/[\u0300-\u036f]/g, "");
    }

    function _compact(text) {
        return _normalize(text).replace(/[\s._-]+/g, "");
    }

    function _tokenizeNormalized(normalized) {
        return normalized.split(/[\s._-]+/).filter(Boolean);
    }

    function _prepareSearchField(text, weight, minLength) {
        const normalized = _normalize(text);
        return {
            weight,
            minLength: minLength || 1,
            normalized,
            compact: normalized.replace(/[\s._-]+/g, ""),
            tokens: normalized === "" ? [] : _tokenizeNormalized(normalized)
        };
    }

    function _prepareEntry(entry) {
        const fields = [
            _prepareSearchField(entry.name, entry.kind === "action" ? 0 : 1, 1)
        ];

        for (const alias of (entry.searchAliases || entry.aliases || []))
            fields.push(_prepareSearchField(alias, entry.kind === "action" ? 1 : 3, 1));

        if (entry.commentText)
            fields.push(_prepareSearchField(entry.commentText, 5, 3));

        if (entry.desktopId || entry.appId)
            fields.push(_prepareSearchField(entry.desktopId || entry.appId, 6, 3));

        return Object.assign({}, entry, {
            searchName: _normalize(entry.name || ""),
            searchFields: fields.filter(field => field.normalized !== "")
        });
    }

    function _compareAlpha(a, b) {
        const nameA = a?.searchName || _normalize(a?.name || "");
        const nameB = b?.searchName || _normalize(b?.name || "");
        return nameA.localeCompare(nameB);
    }

    function _normalizeStoredId(id) {
        if (!id)
            return "";
        return id.indexOf(":") !== -1 ? id : "app:" + id;
    }

    function _recentRank(itemId) {
        const index = root.recentIds.indexOf(itemId);
        return index === -1 ? 9999 : index;
    }

    function _usageCount(itemId) {
        return root.usageCounts[itemId] || 0;
    }

    function _loadPersistentState() {
        root.recentIds = StateService.get("launcher.recentIds", []).map(id => _normalizeStoredId(id)).filter(Boolean);
        root.pinnedIds = StateService.get("launcher.pinnedIds", defaultPinnedIds).map(id => _normalizeStoredId(id)).filter(Boolean);

        const rawUsage = StateService.get("launcher.usageCounts", {});
        const normalized = ({});
        for (const key in rawUsage)
            normalized[_normalizeStoredId(key)] = rawUsage[key];
        root.usageCounts = normalized;
    }

    function _saveRecentIds() {
        StateService.set("launcher.recentIds", root.recentIds);
    }

    function _savePinnedIds() {
        StateService.set("launcher.pinnedIds", root.pinnedIds);
    }

    function _saveUsageCounts() {
        StateService.set("launcher.usageCounts", root.usageCounts);
    }

    function isPinned(itemId) {
        return root.pinnedIds.includes(itemId);
    }

    function togglePinned(itemId) {
        if (!itemId)
            return;

        let pinned = root.pinnedIds.slice();
        const index = pinned.indexOf(itemId);
        if (index === -1)
            pinned.unshift(itemId);
        else
            pinned.splice(index, 1);

        root.pinnedIds = pinned;
        _savePinnedIds();
        root._refreshToken++;
    }

    function _trackUsage(itemId) {
        const nextCounts = Object.assign({}, root.usageCounts);
        nextCounts[itemId] = (nextCounts[itemId] || 0) + 1;
        root.usageCounts = nextCounts;
        _saveUsageCounts();
    }

    function _markRecent(itemId) {
        let recents = root.recentIds.filter(id => id !== itemId);
        recents.unshift(itemId);
        root.recentIds = recents.slice(0, root.maxRecent);
        _saveRecentIds();
    }

    function _createActionEntries() {
        return [
            { id: "action:settings", kind: "action", actionId: "settings", name: "Ajustes", subtitle: "Abrir Quick Settings", iconGlyph: "󰒓", aliases: ["settings", "ajustes", "config", "dashboard", "panel", "quick settings", "qs"] },
            { id: "action:wifi", kind: "action", actionId: "wifi", name: "Wi-Fi", subtitle: "Abrir redes y conexiones", iconGlyph: "󰤨", aliases: ["wifi", "wi-fi", "wireless", "internet", "network", "red"] },
            { id: "action:bluetooth", kind: "action", actionId: "bluetooth", name: "Bluetooth", subtitle: "Administrar dispositivos bluetooth", iconGlyph: "", aliases: ["bluetooth", "bt", "device", "devices", "auriculares"] },
            { id: "action:theme", kind: "action", actionId: "theme", name: "Tema", subtitle: "Cambiar apariencia del shell", iconGlyph: "󰔎", aliases: ["theme", "tema", "appearance", "apariencia", "color", "wallpaper"] },
            { id: "action:clipboard", kind: "action", actionId: "clipboard", name: "Portapapeles", subtitle: "Abrir historial del clipboard", iconGlyph: "󰅌", aliases: ["clipboard", "portapapeles", "copy", "paste", "historial"] },
            { id: "action:screenshot", kind: "action", actionId: "screenshot", name: "Captura", subtitle: "Iniciar captura de pantalla", iconGlyph: "󰹑", aliases: ["screenshot", "capture", "captura", "screen", "shot"] },
            { id: "action:power", kind: "action", actionId: "power", name: "Energia", subtitle: "Abrir menu de energia", iconGlyph: "󰐥", aliases: ["power", "energia", "shutdown", "reboot", "suspend", "logout"] },
            { id: "action:lock", kind: "action", actionId: "lock", name: "Bloquear", subtitle: "Bloquear sesion", iconGlyph: "󰌾", aliases: ["lock", "bloquear", "screenlock", "secure"] }
        ];
    }

    function _decorateAppEntry(app) {
        const genericName = app.genericName || "";
        const commentText = app.comment || "";
        const desktopId = app.id || "";

        return {
            id: "app:" + desktopId,
            kind: "app",
            appId: desktopId,
            name: app.name || "",
            subtitle: commentText || genericName || desktopId,
            commentText,
            desktopId,
            iconName: app.icon || "",
            execString: app.execString || "",
            searchAliases: [genericName]
        };
    }

    function _isAuxiliaryLauncher(entry) {
        if (!entry || entry.kind !== "app")
            return false;

        const name = entry.searchName || _normalize(entry.name || "");
        const comment = _normalize(entry.commentText || "");
        const desktopId = _normalize(entry.desktopId || "");

        return name.includes("url launcher")
            || name.includes("launcher for")
            || comment.includes("open urls with")
            || desktopId.endsWith("-open")
            || desktopId.endsWith("-url-handler")
            || desktopId.includes("url-launcher");
    }

    function _subsequencePenalty(haystack, needle) {
        let hIndex = 0;
        let penalty = 0;

        for (let nIndex = 0; nIndex < needle.length; nIndex++) {
            const nextIndex = haystack.indexOf(needle[nIndex], hIndex);
            if (nextIndex === -1)
                return -1;
            penalty += nextIndex - hIndex;
            hIndex = nextIndex + 1;
        }

        return penalty;
    }

    function _editDistanceWithin(a, b, maxDistance) {
        if (Math.abs(a.length - b.length) > maxDistance)
            return -1;

        let prev = [];
        for (let j = 0; j <= b.length; j++)
            prev[j] = j;

        for (let i = 1; i <= a.length; i++) {
            let curr = [i];
            let rowMin = curr[0];

            for (let j = 1; j <= b.length; j++) {
                const cost = a[i - 1] === b[j - 1] ? 0 : 1;
                curr[j] = Math.min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost);
                rowMin = Math.min(rowMin, curr[j]);
            }

            if (rowMin > maxDistance)
                return -1;

            prev = curr;
        }

        return prev[b.length] <= maxDistance ? prev[b.length] : -1;
    }

    function _scoreField(field, qNorm, qCompact, allowFuzzy) {
        const normalized = field.normalized;
        if (normalized === "")
            return -1;
        if (qNorm.length < (field.minLength || 1))
            return -1;

        const compact = field.compact;
        const tokens = field.tokens;
        const fieldWeight = field.weight;

        if (normalized === qNorm || compact === qCompact)
            return fieldWeight;
        if (normalized.startsWith(qNorm) || compact.startsWith(qCompact))
            return fieldWeight + 1;
        if (tokens.some(token => token.startsWith(qNorm)))
            return fieldWeight + 2;

        const containsIndex = normalized.indexOf(qNorm);
        if (containsIndex !== -1)
            return fieldWeight + 4 + Math.min(containsIndex, 12) / 100;

        const compactContainsIndex = compact.indexOf(qCompact);
        if (compactContainsIndex !== -1)
            return fieldWeight + 4.5 + Math.min(compactContainsIndex, 12) / 100;

        if (allowFuzzy && qCompact.length >= 3) {
            const penalty = _subsequencePenalty(compact, qCompact);
            if (penalty !== -1)
                return fieldWeight + 7 + Math.min(penalty, 12) / 10;
        }

        if (allowFuzzy && qNorm.length >= 3) {
            for (const token of tokens) {
                const distance = _editDistanceWithin(token, qNorm, 2);
                if (distance !== -1)
                    return fieldWeight + 6 + distance;
            }
        }

        return -1;
    }

    function _scoreCandidate(entry, qNorm, qCompact, allowFuzzy) {
        let best = -1;
        for (const field of (entry.searchFields || [])) {
            const score = _scoreField(field, qNorm, qCompact, allowFuzzy);
            if (score !== -1 && (best === -1 || score < best))
                best = score;
        }
        return best;
    }

    readonly property var filteredApps: {
        void root._refreshToken;
        const entries = root._allEntries;

        if (query.trim() === "") {
            const used = ({});
            const ordered = [];

            function pushEntry(entry) {
                if (entry && !used[entry.id]) {
                    used[entry.id] = true;
                    ordered.push(entry);
                }
            }

            root.pinnedIds.forEach(id => pushEntry(root._entryById[id] || null));

            entries
                .filter(entry => !used[entry.id] && root._usageCount(entry.id) > 0)
                .sort((a, b) => {
                    const usageDelta = root._usageCount(b.id) - root._usageCount(a.id);
                    if (usageDelta !== 0)
                        return usageDelta;
                    const recentDelta = root._recentRank(a.id) - root._recentRank(b.id);
                    if (recentDelta !== 0)
                        return recentDelta;
                    return root._compareAlpha(a, b);
                })
                .forEach(pushEntry);

            root.recentIds.forEach(id => pushEntry(root._entryById[id] || null));
            entries.forEach(pushEntry);

            return ordered.slice(0, maxItems);
        }

        const qNorm = _normalize(query.trim());
        const qCompact = _compact(query.trim());
        const resultLimit = searchMaxItems;
        let strictMatches = [];

        for (const entry of entries) {
            const score = _scoreCandidate(entry, qNorm, qCompact, false);
            if (score !== -1) {
                strictMatches.push({
                    entry,
                    score,
                    pinned: root.isPinned(entry.id) ? 0 : 1,
                    usage: root._usageCount(entry.id),
                    recentRank: root._recentRank(entry.id)
                });
            }
        }

        let scoredMatches = strictMatches;
        if (strictMatches.length === 0 && qNorm.length >= 3) {
            scoredMatches = [];
            for (const entry of entries) {
                const score = _scoreCandidate(entry, qNorm, qCompact, true);
                if (score !== -1) {
                    scoredMatches.push({
                        entry,
                        score,
                        pinned: root.isPinned(entry.id) ? 0 : 1,
                        usage: root._usageCount(entry.id),
                        recentRank: root._recentRank(entry.id)
                    });
                }
            }
        }

        scoredMatches.sort((a, b) => {
            if (a.score !== b.score)
                return a.score - b.score;
            if (a.pinned !== b.pinned)
                return a.pinned - b.pinned;
            if (a.usage !== b.usage)
                return b.usage - a.usage;
            if (a.recentRank !== b.recentRank)
                return a.recentRank - b.recentRank;
            return root._compareAlpha(a.entry, b.entry);
        });

        return scoredMatches.map(item => item.entry).slice(0, resultLimit);
    }

    function rebuildAppCaches() {
        const apps = DesktopEntries.applications.values
            .slice()
            .map(app => root._prepareEntry(root._decorateAppEntry(app)))
            .filter(entry => !root._isAuxiliaryLauncher(entry))
            .sort((a, b) => root._compareAlpha(a, b));
        const actions = root._createActionEntries()
            .map(entry => root._prepareEntry(entry))
            .sort((a, b) => root._compareAlpha(a, b));
        const allEntries = [...apps, ...actions];
        const byId = ({});

        for (const entry of allEntries) {
            if (entry && entry.id)
                byId[entry.id] = entry;
        }

        root._allEntries = allEntries;
        root._entryById = byId;
    }

    function show() {
        rebuildAppCaches();
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
            let token = match[1] !== undefined ? match[1] : (match[2] !== undefined ? match[2] : match[3]);
            token = token.replace(/\\(["'\\ ])/g, "$1");
            if (token.length > 0)
                args.push(token);
        }

        return args;
    }

    function _runAction(actionId) {
        switch (actionId) {
        case "settings":
            QuickSettingsService.show("dashboard");
            break;
        case "wifi":
            QuickSettingsService.show("wifi");
            break;
        case "bluetooth":
            QuickSettingsService.show("bluetooth");
            break;
        case "theme":
            QuickSettingsService.show("theme");
            break;
        case "clipboard":
            ClipboardService.show();
            break;
        case "screenshot":
            ShortcutService.screenshotRequested();
            break;
        case "power":
            PowerService.showOverlay();
            break;
        case "lock":
            PowerService.lock();
            break;
        default:
            console.warn("[Launcher] Unknown action:", actionId);
        }
    }

    function _launchAppArgs(args) {
        const homeDir = Quickshell.env("HOME") || "/";
        Quickshell.execDetached([
            "sh",
            "-lc",
            "cd -- \"$1\" && shift && exec \"$@\"",
            "qs-launcher",
            homeDir,
            ...args
        ]);
    }

    function launch(entry) {
        if (!entry)
            return;

        console.log("[Launcher] Launching:", entry.name);
        _markRecent(entry.id);
        _trackUsage(entry.id);

        if (entry.kind === "action") {
            hide();
            _runAction(entry.actionId);
            return;
        }

        const args = _tokenizeExecString(entry.execString);
        if (args.length === 0) {
            console.warn("[Launcher] Could not parse command for:", entry.name);
            return;
        }

        _launchAppArgs(args);
        hide();
    }

    function launchSelected() {
        if (filteredApps.length > 0 && selectedIndex >= 0 && selectedIndex < filteredApps.length)
            launch(filteredApps[selectedIndex]);
    }

    function navigateUp() {
        if (selectedIndex > 0)
            selectedIndex--;
    }

    function navigateDown() {
        if (selectedIndex < filteredApps.length - 1)
            selectedIndex++;
    }

    onQueryChanged: selectedIndex = 0

    Component.onCompleted: {
        _loadPersistentState();
        rebuildAppCaches();
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            root.rebuildAppCaches();
            root._refreshToken++;
        }
    }

    Connections {
        target: StateService
        function onStateLoaded() {
            root._loadPersistentState();
            root._refreshToken++;
        }
    }
}
