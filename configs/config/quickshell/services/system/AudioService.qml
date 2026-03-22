pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // All available output sinks (for the audio output selector page).
    // Uses Array.from() because Pipewire.nodes.values is a QML model, not a JS array.
    // Filters out internal Bluetooth routing nodes that should not be user-visible.
    readonly property var allSinks: {
        if (!Pipewire.nodes) return [];
        return Array.from(Pipewire.nodes.values).filter(n =>
            n.isSink && !n.isStream && !n.name.includes("internal")
        );
    }

    // Keeps the objects alive in memory
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // Check if the sink is ready to operate
    readonly property bool sinkReady: sink !== null && sink.audio !== null
    readonly property bool sourceReady: source !== null && source.audio !== null

    readonly property bool muted: sinkReady ? (sink.audio.muted ?? false) : false
    readonly property real volume: {
        if (!sinkReady)
            return 0;
        const vol = sink.audio.volume;
        return Math.max(0, Math.min(1, vol));
    }
    readonly property int percentage: Math.round(volume * 100)

    readonly property bool sourceMuted: sourceReady ? (source.audio.muted ?? false) : false
    readonly property real sourceVolume: sourceReady ? (source.audio.volume ?? 0) : 0
    readonly property int sourcePercentage: Math.round(sourceVolume * 100)

    readonly property string systemIcon: {
        if (!sinkReady || muted || volume <= 0)
            return "";

        if (volume < 0.33)
            return "";

        if (volume < 0.67)
            return "";

        return "";
    }

    readonly property string sourceIcon: (!sourceReady || sourceMuted) ? "󰍭" : "󰍬"

    function setVolume(newVolume) {
        if (sinkReady) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, newVolume));
        }
    }

    function toggleMute() {
        if (sinkReady) {
            sink.audio.muted = !sink.audio.muted;
        }
    }

    function increaseVolume() {
        setVolume(volume + 0.05);
    }

    function decreaseVolume() {
        setVolume(volume - 0.05);
    }

    function setSourceVolume(newVolume) {
        if (sourceReady && source.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(1, newVolume));
        }
    }

    function toggleSourceMute() {
        if (sourceReady && source.audio) {
            source.audio.muted = !source.audio.muted;
        }
    }

    // Set a node as the preferred default audio output via pactl (reliable)
    function setDefaultSink(nodeName) {
        setDefaultSinkProc.command = ["pactl", "set-default-sink", nodeName];
        setDefaultSinkProc.running = true;
    }

    // Process to change the default sink
    Process {
        id: setDefaultSinkProc
        running: false
    }

    // Returns a readable display name for a sink node
    function getSinkLabel(node) {
        if (!node) return "Unknown";
        return node.description || node.nickname || node.name || "Unknown";
    }

    // Returns an icon for a sink node based on its name/description
    function getSinkIcon(node) {
        if (!node) return "󰓃";
        const name = (node.name || "").toLowerCase();
        const desc = (node.description || node.nickname || "").toLowerCase();
        if (name.includes("bluez") || desc.includes("bluetooth")
                || desc.includes("headphone") || desc.includes("headset"))
            return "󰋋";
        if (name.includes("hdmi") || desc.includes("hdmi") || desc.includes("display"))
            return " ";
        if (name.includes("usb") || desc.includes("usb"))
            return "";
        return "󰓃";
    }
}
