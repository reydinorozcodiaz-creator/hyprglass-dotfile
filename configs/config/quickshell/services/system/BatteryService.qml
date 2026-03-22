pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    // Returns true if a laptop battery was found
    readonly property bool hasBattery: mainBattery !== null

    // Percentage (0 to 100)
    readonly property int percentage: mainBattery ? Math.round(mainBattery.percentage * 100) : 0

    // State (Charging, Discharging, Full...)
    readonly property int state: mainBattery ? mainBattery.state : UPowerDeviceState.Unknown

    // Boolean helper to simplify UI bindings
    readonly property bool isCharging: state === UPowerDeviceState.Charging

    // Holds the reference to the battery object
    property var mainBattery: null

    // ========================================================================
    // LOW BATTERY NOTIFICATIONS
    // ========================================================================

    // Thresholds at which we fire notifications (descending)
    readonly property var _batteryThresholds: [20, 10, 5]

    // Track the last threshold we notified at to avoid spamming
    property int _lastNotifiedThreshold: -1

    onPercentageChanged: {
        if (!hasBattery || isCharging) return;

        for (let i = 0; i < _batteryThresholds.length; i++) {
            const threshold = _batteryThresholds[i];

            if (percentage <= threshold && _lastNotifiedThreshold !== threshold) {
                _lastNotifiedThreshold = threshold;
                _sendBatteryNotification(percentage, threshold);
                break;
            }
        }
    }

    onIsChargingChanged: {
        if (isCharging) {
            // Reset so notifications fire again on next discharge cycle
            _lastNotifiedThreshold = -1;
        }
    }

    function _sendBatteryNotification(level, threshold) {
        let urgency = "normal";
        let icon = "battery-low-symbolic";
        let summary = "Batería baja";
        let body = "Queda " + level + "% de batería. Conecta el cargador.";

        if (threshold <= 5) {
            urgency = "critical";
            icon = "battery-empty-symbolic";
            summary = "⚠ ¡Batería crítica!";
            body = "¡Solo queda " + level + "%! El equipo se apagará pronto.";
        } else if (threshold <= 10) {
            urgency = "critical";
            icon = "battery-caution-symbolic";
            summary = "¡Batería muy baja!";
            body = "Queda " + level + "%. Conecta el cargador ahora.";
        }

        _notifProcess.command = [
            "notify-send",
            "--urgency=" + urgency,
            "--icon=" + icon,
            "--app-name=Battery",
            summary,
            body
        ];
        _notifProcess.running = true;
    }

    Process {
        id: _notifProcess
        command: []
        running: false
    }

    // ========================================================================
    // DEVICE SCANNER
    // ========================================================================

    // The Instantiator scans the device list without creating visuals
    Instantiator {
        model: UPower.devices

        delegate: QtObject {
            required property var modelData
            
            // When a device is created or changes, we check if it is the main battery
            Component.onCompleted: checkDevice()
            
            function checkDevice() {
                if (modelData && modelData.isLaptopBattery) {
                    root.mainBattery = modelData
                }
            }
        }
    }

    // ========================================================================
    // ICON LOGIC
    // ========================================================================

    function getBatteryIcon() {
        if (state === UPowerDeviceState.Charging) return "󰂄"

        const p = percentage
        if (p >= 90) return "󰁹"
        if (p >= 60) return "󰂀"
        if (p >= 40) return "󰁾"
        if (p >= 10) return "󰁼"
        return "󰁺"
    }
}