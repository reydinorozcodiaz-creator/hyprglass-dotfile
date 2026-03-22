pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Singleton {
    id: root

    // Gets the system's default adapter. Can be null if there is no bluetooth.
    property var adapter: Bluetooth?.defaultAdapter

    // Reactive properties (return false if there is no adapter)
    readonly property bool isPowered: (adapter && adapter.enabled) === true
    readonly property bool isDiscovering: (adapter && adapter.discovering) === true

    // Property to know if we are visible to others (useful for the UI)
    readonly property bool isDiscoverable: (adapter && adapter.discoverable) === true

    // True while bluetoothctl is toggling power (prevents double-clicks)
    property bool isPowerToggling: false

    // Scan countdown in seconds (20 → 0), shown in the UI
    property int scanTimeRemaining: 0

    // Icon for the current bluetooth status
    readonly property string systemIcon: {
        if (!isPowered)
            return "󰂲";

        if (devicesList.some(dev => dev.connected))
            return "󰂱";

        return "";
    }

    // List of connected devices only
    readonly property var connectedDevices: {
        return devicesList.filter(dev => dev.connected);
    }

    // Count (For use in the UI)
    readonly property int connectedDevicesCount: connectedDevices.length

    // Smart text (For the Dashboard sublabel)
    readonly property string statusText: {
        if (!isPowered)
            return "Apagado";

        const count = connectedDevices.length;

        if (count === 0)
            return "Encendido";

        if (count === 1) {
            // If there is only 1, return its name
            const dev = connectedDevices[0];
            return dev.alias || dev.name || "Unknown";
        }

        // If there is more than 1, return the count
        return count + " devices";
    }

    // The smart device list
    readonly property var devicesList: {
        if (!adapter || !adapter.devices)
            return [];

        // Quickshell's 'values' is not a pure JS Array, so we convert it
        // to ensure that .sort() works without errors.
        let list = Array.from(adapter.devices.values);

        // Sorting function
        return list.sort((a, b) => {
            // Connected devices appear first at the top
            if (a.connected && !b.connected)
                return -1;
            if (!a.connected && b.connected)
                return 1;

            // Known devices (Paired or Trusted) appear before new ones
            const aKnown = a.paired || a.trusted;
            const bKnown = b.paired || b.trusted;
            if (aKnown && !bKnown)
                return -1;
            if (!aKnown && bKnown)
                return 1;

            // Finally, alphabetical order by name
            const nameA = (a.alias || a.name || "").toLowerCase();
            const nameB = (b.alias || b.name || "").toLowerCase();
            return nameA.localeCompare(nameB);
        });
    }

    // Addresses currently going through the pairing flow.
    // Used to prevent re-triggering pair() while BlueZ is processing.
    property var _pairingAddresses: []

    // Clear pairing state when devicesList updates (device became paired/connected)
    onDevicesListChanged: {
        const pending = _pairingAddresses.filter(addr => {
            const dev = devicesList.find(d => d.address === addr);
            return dev && !dev.paired && !dev.connected;
        });
        if (pending.length !== _pairingAddresses.length)
            _pairingAddresses = pending;
    }

    // Safety: clear all pairing guards after 45 s in case BlueZ never responded
    Timer {
        id: pairingGuardTimeout
        interval: 45000
        repeat: false
        onTriggered: root._pairingAddresses = []
    }

    // Reset power toggling state once the adapter power state actually changes
    onIsPoweredChanged: {
        isPowerToggling = false;
        powerToggleTimeout.stop();
    }

    // --- ACTIONS ---

    // Process to toggle Bluetooth power via bluetoothctl (more reliable than direct D-Bus binding)
    Process {
        id: powerProc
        onExited: exitCode => {
            // If the command failed, clear the toggling flag immediately
            if (exitCode !== 0) {
                root.isPowerToggling = false;
                powerToggleTimeout.stop();
            }
            // On success, onIsPoweredChanged will clear the flag
        }
    }

    // Safety valve: clear isPowerToggling after 5s if BlueZ never responded
    Timer {
        id: powerToggleTimeout
        interval: 5000
        repeat: false
        onTriggered: root.isPowerToggling = false
    }

    // Toggle Power (On/Off) — unblocks rfkill first, then uses bluetoothctl
    function togglePower() {
        if (isPowerToggling)
            return;
        isPowerToggling = true;
        if (isPowered) {
            powerProc.command = ["bluetoothctl", "power", "off"];
        } else {
            // rfkill soft-block must be cleared before bluetoothctl can power on.
            // A short sleep is needed so BlueZ finishes processing the unblock event.
            powerProc.command = ["bash", "-c", "rfkill unblock bluetooth && sleep 0.5 && bluetoothctl power on"];
        }
        powerProc.running = true;
        powerToggleTimeout.restart();
    }

    // Toggle Search (Scan)
    function toggleScan() {
        if (!adapter)
            return;

        if (adapter.discovering) {
            // User clicked to stop manually
            adapter.discovering = false;
            scanTimer.stop();
            scanCountdownTimer.stop();
            scanTimeRemaining = 0;
        } else {
            // User clicked to start
            adapter.discovering = true;
            scanTimeRemaining = 20;
            scanTimer.restart();
            scanCountdownTimer.restart();
        }
    }

    // Timer to automatically stop the scan after 20 seconds
    Timer {
        id: scanTimer
        interval: 20000
        repeat: false
        onTriggered: {
            if (root.adapter && root.adapter.discovering)
                root.adapter.discovering = false;
            root.scanTimeRemaining = 0;
            scanCountdownTimer.stop();
        }
    }

    // Ticks every second to update the countdown label in the UI
    Timer {
        id: scanCountdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.scanTimeRemaining > 0)
                root.scanTimeRemaining--;
        }
    }

    // Connect/Disconnect
    function toggleConnection(device) {
        if (!device)
            return;

        if (device.connected) {
            device.disconnect();
            return;
        }

        // Guard: already connecting or pairing — ignore extra clicks
        if (getIsConnecting(device)) {
            console.log("[BT] Device already connecting/pairing, ignoring click");
            return;
        }

        try {
            device.trusted = true;
        } catch (e) {
            console.warn("Could not set trusted automatically." + e);
        }

        if (!device.paired) {
            // Mark as pairing before calling pair() to block re-entry
            _pairingAddresses = [..._pairingAddresses, device.address];
            pairingGuardTimeout.restart();
            try {
                device.pair();
            } catch (e) {
                console.error("Error pairing: " + e);
                _pairingAddresses = _pairingAddresses.filter(a => a !== device.address);
            }
            return;
        }

        device.connect();
    }

    // Make visible/invisible to other devices
    function toggleDiscoverable() {
        if (!adapter)
            return;
        adapter.discoverable = !adapter.discoverable;
    }

    // Function to check if the device is trying to connect or pair
    function getIsConnecting(device) {
        return device.state === BluetoothDeviceState.Connecting
            || _pairingAddresses.indexOf(device.address) !== -1;
    }

    // Forget device
    function forgetDevice(device) {
        if (device) {
            device.forget();
        }
    }

    // Function to get icons based on the actual device type
    function getDeviceIcon(device) {
        if (!device)
            return ""; // Default Bluetooth

        // 1. Try to get the official BlueZ icon property and name
        const iconProp = (device.icon || "").toLowerCase();
        const name = (device.name || device.alias || "").toLowerCase();

        const safeName = name || "";

        // 2. Audio keyword list
        const audioKeywords = ["headset", "headphone", "airpod", "buds", "freebuds", "wh-", "wf-", "jbl", "audio", "soundcore"];

        // Check if it is audio by technical property OR by name
        if (iconProp.includes("headset") || iconProp.includes("audio") || audioKeywords.some(k => name.includes(k)))
            return "";
        if (iconProp.includes("mouse") || safeName.includes("mouse"))
            return "󰍽";
        if (iconProp.includes("keyboard") || safeName.includes("keyboard"))
            return "";
        if (iconProp.includes("phone") || safeName.includes("phone") || name.includes("android") || name.includes("iphone"))
            return "";
        if (iconProp.includes("gamepad") || iconProp.includes("joystick") || name.includes("controller"))
            return "";
        if (iconProp.includes("computer") || iconProp.includes("laptop") || name.includes("pc"))
            return " ";
        if (iconProp.includes("tv") || safeName.includes("tv"))
            return " ";

        return ""; // Default
    }
}
