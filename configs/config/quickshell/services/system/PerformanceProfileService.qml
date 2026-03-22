pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property bool loading: false
    property bool switching: false
    property string activeProfile: ""
    property string profileMode: ""
    property string modeDetail: ""
    property string pendingProfile: ""
    property var availableProfiles: []

    readonly property var quickProfileIds: [
        "powersave",
        "balanced-battery",
        "balanced",
        "desktop",
        "latency-performance"
    ]

    readonly property var quickProfiles: {
        const profiles = [];
        const seen = {};

        if (root.activeProfile !== "" && quickProfileIds.indexOf(root.activeProfile) === -1) {
            const current = root.profileById(root.activeProfile);
            if (current) {
                profiles.push(current);
                seen[current.id] = true;
            }
        }

        for (let i = 0; i < quickProfileIds.length; i++) {
            const profile = root.profileById(quickProfileIds[i]);
            if (profile && !seen[profile.id]) {
                profiles.push(profile);
                seen[profile.id] = true;
            }
        }

        return profiles;
    }

    readonly property string profileLabel: activeProfile !== "" ? formatProfileName(activeProfile) : "Unavailable"
    readonly property string systemIcon: iconForProfile(activeProfile)
    readonly property string modeLabel: {
        if (loading)
            return "Loading...";
        if (!available)
            return "TuneD unavailable";
        if (switching)
            return "Applying " + formatProfileName(pendingProfile);
        if (profileMode === "auto")
            return profileLabel + " · Auto";
        return profileLabel;
    }
    readonly property bool isPerformanceBiased: {
        const id = activeProfile;
        return id.indexOf("performance") !== -1
            || id.indexOf("throughput") !== -1
            || id.indexOf("latency") !== -1;
    }

    function _updateLoadingState() {
        loading = activeProfileProc.running || profilesProc.running || modeProc.running;
    }

    function _extractQuotedStrings(text) {
        const values = [];
        const regex = /'((?:\\'|[^'])*)'/g;
        let match;

        while ((match = regex.exec(text)) !== null) {
            values.push(match[1].replace(/\\'/g, "'"));
        }

        return values;
    }

    function formatProfileName(profileId) {
        if (!profileId || profileId === "")
            return "Unavailable";

        const uppercaseParts = {
            ac: "AC",
            aws: "AWS",
            cpu: "CPU",
            ece: "ECE",
            hpc: "HPC",
            hana: "HANA",
            kvm: "KVM",
            mssql: "MSSQL",
            sap: "SAP",
            sst: "SST"
        };

        return profileId.split("-").map(part => {
            const lowered = part.toLowerCase();
            if (uppercaseParts[lowered])
                return uppercaseParts[lowered];
            return lowered.charAt(0).toUpperCase() + lowered.slice(1);
        }).join(" ");
    }

    function iconForProfile(profileId) {
        const id = profileId || "";
        if (id === "")
            return "󰾅";
        if (id.indexOf("powersave") !== -1 || id === "balanced-battery")
            return "󰾆";
        if (id.indexOf("performance") !== -1 || id.indexOf("throughput") !== -1 || id.indexOf("latency") !== -1)
            return "󰓅";
        return "󰾅";
    }

    function profileById(profileId) {
        for (let i = 0; i < availableProfiles.length; i++) {
            const profile = availableProfiles[i];
            if (profile.id === profileId)
                return profile;
        }
        return null;
    }

    function refresh() {
        if (!activeProfileProc.running)
            activeProfileProc.running = true;
        if (!profilesProc.running)
            profilesProc.running = true;
        if (!modeProc.running)
            modeProc.running = true;
        _updateLoadingState();
    }

    function refreshCurrentState() {
        if (!activeProfileProc.running)
            activeProfileProc.running = true;
        if (!modeProc.running)
            modeProc.running = true;
        _updateLoadingState();
    }

    function setProfile(profileId) {
        if (!profileId || profileId === "" || switching || activeProfile === profileId)
            return;

        pendingProfile = profileId;
        switching = true;
        switchProfileProc.command = [
            "gdbus", "call",
            "--system",
            "--dest", "com.redhat.tuned",
            "--object-path", "/Tuned",
            "--method", "com.redhat.tuned.control.switch_profile",
            profileId
        ];
        switchProfileProc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: activeProfileProc
        command: [
            "gdbus", "call",
            "--system",
            "--dest", "com.redhat.tuned",
            "--object-path", "/Tuned",
            "--method", "com.redhat.tuned.control.active_profile"
        ]

        stdout: StdioCollector {
            id: activeProfileOut
            onStreamFinished: {
                const values = root._extractQuotedStrings(text);
                if (values.length > 0) {
                    root.available = true;
                    root.activeProfile = values[0];
                }
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("[PerformanceProfile] active_profile:", data)
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.available = false;
            root._updateLoadingState();
        }
    }

    Process {
        id: profilesProc
        command: [
            "gdbus", "call",
            "--system",
            "--dest", "com.redhat.tuned",
            "--object-path", "/Tuned",
            "--method", "com.redhat.tuned.control.profiles2"
        ]

        stdout: StdioCollector {
            id: profilesOut
            onStreamFinished: {
                const values = root._extractQuotedStrings(text);
                const profiles = [];

                for (let i = 0; i + 1 < values.length; i += 2) {
                    profiles.push({
                        id: values[i],
                        description: values[i + 1]
                    });
                }

                root.availableProfiles = profiles;
                if (profiles.length > 0)
                    root.available = true;
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("[PerformanceProfile] profiles2:", data)
        }

        onExited: exitCode => {
            if (exitCode !== 0 && root.activeProfile === "")
                root.available = false;
            root._updateLoadingState();
        }
    }

    Process {
        id: modeProc
        command: [
            "gdbus", "call",
            "--system",
            "--dest", "com.redhat.tuned",
            "--object-path", "/Tuned",
            "--method", "com.redhat.tuned.control.profile_mode"
        ]

        stdout: StdioCollector {
            id: modeOut
            onStreamFinished: {
                const values = root._extractQuotedStrings(text);
                root.profileMode = values.length > 0 ? values[0] : "";
                root.modeDetail = values.length > 1 ? values[1] : "";
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("[PerformanceProfile] profile_mode:", data)
        }

        onExited: exitCode => {
            if (exitCode !== 0 && root.activeProfile === "")
                root.available = false;
            root._updateLoadingState();
        }
    }

    Process {
        id: switchProfileProc
        running: false

        stdout: StdioCollector {
            id: switchProfileOut
            onStreamFinished: {
                const values = root._extractQuotedStrings(text);
                const ok = text.indexOf("true") !== -1;

                if (!ok) {
                    const reason = values.length > 0 ? values[values.length - 1] : "unknown error";
                    console.error("[PerformanceProfile] switch_profile failed:", reason);
                }
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("[PerformanceProfile] switch_profile:", data)
        }

        onExited: exitCode => {
            root.switching = false;
            if (exitCode !== 0)
                console.error("[PerformanceProfile] switch_profile exited with code", exitCode);
            root.pendingProfile = "";
            root.refreshCurrentState();
        }
    }
}
