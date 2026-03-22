pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ========================================================================
    // CPU PROPERTIES
    // ========================================================================

    readonly property int cpuUsage: internal.cpuUsage
    readonly property int cpuTemp: internal.cpuTemp
    readonly property string cpuIcon: "󰻠"

    // ========================================================================
    // GPU PROPERTIES
    // ========================================================================

    readonly property int gpuUsage: internal.gpuUsage
    readonly property int gpuTemp: internal.gpuTemp
    readonly property string gpuIcon: "󰢮"
    readonly property string gpuType: internal.gpuType // "nvidia", "amd", "intel", "unknown"

    // ========================================================================
    // RAM PROPERTIES
    // ========================================================================

    readonly property int ramUsage: internal.ramUsage
    readonly property string ramUsed: internal.ramUsed   // GiB, e.g. "5.2"
    readonly property string ramTotal: internal.ramTotal  // GiB, e.g. "15.8"

    // ========================================================================
    // DISK PROPERTIES
    // ========================================================================

    readonly property int diskUsage: internal.diskUsage
    readonly property string diskUsed: internal.diskUsed   // GiB
    readonly property string diskTotal: internal.diskTotal  // GiB

    // ========================================================================
    // NETWORK PROPERTIES
    // ========================================================================

    readonly property string networkDown: internal.networkDown // e.g. "1.2 MB/s"
    readonly property string networkUp: internal.networkUp     // e.g. "340 KB/s"

    // ========================================================================
    // UPTIME
    // ========================================================================

    readonly property string uptime: internal.uptime // e.g. "2d 5h" or "3h 12m"

    // ========================================================================
    // INTERNAL STATE
    // ========================================================================

    QtObject {
        id: internal

        // CPU
        property int cpuUsage: 0
        property int cpuTemp: 0

        // GPU
        property int gpuUsage: 0
        property int gpuTemp: 0
        property string gpuType: "unknown"

        // CPU calculation state
        property real prevTotal: 0
        property real prevIdle: 0

        // RAM
        property int ramUsage: 0
        property string ramUsed: "0"
        property string ramTotal: "0"

        // Disk
        property int diskUsage: 0
        property string diskUsed: "0"
        property string diskTotal: "0"

        // Network
        property string networkDown: "0 B/s"
        property string networkUp: "0 B/s"
        property real prevRx: 0
        property real prevTx: 0

        // Uptime
        property string uptime: "0m"
    }

    // ========================================================================
    // INITIALIZATION & AGENT
    // ========================================================================

    readonly property string sysAgentScriptPath: Qt.resolvedUrl("../scripts/sys-agent.py").toString().replace("file://", "")
    
    // Controlled by SystemMonitorButton.qml visibility
    property bool monitorActive: false

    onMonitorActiveChanged: {
        sysAgent.running = monitorActive;
    }

    Process {
        id: sysAgent
        command: ["python3", root.sysAgentScriptPath]
        running: false // Will be set by property watcher above

        stdout: SplitParser {
            onRead: data => {
                if (!data || data.trim() === "") return;
                try {
                    const info = JSON.parse(data.trim());
                    
                    if (info.cpu) {
                        internal.cpuUsage = info.cpu.usage || 0;
                        internal.cpuTemp = info.cpu.temp || 0;
                    }
                    if (info.gpu) {
                        internal.gpuType = info.gpu.type || "unknown";
                        internal.gpuUsage = info.gpu.usage || 0;
                        internal.gpuTemp = info.gpu.temp || 0;
                    }
                    if (info.ram) {
                        internal.ramUsage = info.ram.usage || 0;
                        internal.ramUsed = root._formatGiB(info.ram.used || 0);
                        internal.ramTotal = root._formatGiB(info.ram.total || 0);
                    }
                    if (info.disk) {
                        internal.diskUsage = info.disk.usage || 0;
                        internal.diskUsed = root._formatGiB(info.disk.used || 0);
                        internal.diskTotal = root._formatGiB(info.disk.total || 0);
                    }
                    if (info.network) {
                        internal.networkDown = root._formatBytes(info.network.rx || 0);
                        internal.networkUp = root._formatBytes(info.network.tx || 0);
                    }
                    if (info.uptime) {
                        internal.uptime = info.uptime;
                    }
                } catch (e) {
                    console.error("[SystemMonitor] Error parsing sys-agent data:", e, data);
                }
            }
        }
        
        stderr: SplitParser {
            onRead: data => console.error("[SystemMonitor] sys-agent err:", data)
        }
    }

    // ========================================================================
    // HELPER FUNCTIONS
    // ========================================================================

    function _formatBytes(bytes) {
        if (bytes >= 1073741824) {
            return (bytes / 1073741824).toFixed(1) + " GB/s";
        } else if (bytes >= 1048576) {
            return (bytes / 1048576).toFixed(1) + " MB/s";
        } else if (bytes >= 1024) {
            return (bytes / 1024).toFixed(0) + " KB/s";
        }
        return bytes.toFixed(0) + " B/s";
    }

    function _formatGiB(bytes) {
        return (bytes / 1073741824).toFixed(1);
    }

}
