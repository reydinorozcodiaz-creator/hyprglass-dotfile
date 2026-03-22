pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root

    signal backRequested

    Layout.fillWidth: true
    implicitHeight: 480

    // Computed grouped model: interleaves section headers with device rows.
    // Sections: "Conectado" → "Guardado" (paired/trusted) → "Disponible"
    readonly property var groupedModel: {
        if (!BluetoothService.isPowered)
            return [];

        const devices = BluetoothService.devicesList;
        const connected = devices.filter(d => d.connected);
        const saved = devices.filter(d => !d.connected && (d.paired || d.trusted));
        const available = devices.filter(d => !d.connected && !d.paired && !d.trusted);

        let result = [];
        if (connected.length > 0) {
            result.push({isSection: true, label: "Conectado"});
            connected.forEach(d => result.push({isSection: false, device: d}));
        }
        if (saved.length > 0) {
            result.push({isSection: true, label: "Guardado"});
            saved.forEach(d => result.push({isSection: false, device: d}));
        }
        if (available.length > 0) {
            result.push({isSection: true, label: "Available"});
            available.forEach(d => result.push({isSection: false, device: d}));
        }
        return result;
    }

    // Auto-scan when this page becomes visible if BT is on but no devices are listed
    onVisibleChanged: {
        if (visible && BluetoothService.isPowered
                && !BluetoothService.isDiscovering
                && BluetoothService.devicesList.length === 0) {
            BluetoothService.toggleScan();
        }
    }

    ColumnLayout {
        id: main
        anchors.fill: parent
        spacing: 12

        // Header
        PageHeader {
            icon: BluetoothService.systemIcon
            title: "Bluetooth"
            onBackClicked: root.backRequested()

            // Scan button — shows a live countdown while scanning
            RowLayout {
                visible: BluetoothService.isPowered
                spacing: 4

                Text {
                    visible: BluetoothService.isDiscovering
                    text: BluetoothService.scanTimeRemaining + "s"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: Config.accentColor
                }

                RefreshButton {
                    loading: BluetoothService.isDiscovering
                    onClicked: BluetoothService.toggleScan()
                }
            }

            // Visibility Button
            ActionButton {
                visible: BluetoothService.isPowered
                icon: BluetoothService.isDiscoverable ? "󰈈" : "󰈉"
                baseColor: BluetoothService.isDiscoverable ? Config.accentColor : Config.surface1Color
                hoverColor: BluetoothService.isDiscoverable ? Config.accentColor : Config.surface2Color
                textColor: BluetoothService.isDiscoverable ? Config.textReverseColor : Config.textColor
                onClicked: BluetoothService.toggleDiscoverable()
            }

            // On/Off Switch — disabled while bluetoothctl is in flight
            QsSwitch {
                checked: BluetoothService.isPowered
                enabled: !BluetoothService.isPowerToggling
                opacity: BluetoothService.isPowerToggling ? 0.5 : 1.0
                Behavior on opacity { NumberAnimation { duration: Config.animDurationShort } }
                onToggled: {
                    if (!BluetoothService.isPowered)
                        startScanTimer.restart();
                    BluetoothService.togglePower();
                }
            }

            // Timer to start scanning after turning on bluetooth
            Timer {
                id: startScanTimer
                interval: 500
                repeat: false
                onTriggered: BluetoothService.toggleScan()
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.surface1Color
        }

        // Device List with section grouping
        ListView {
            id: deviceList
            clip: true
            spacing: 6

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10

            model: root.groupedModel

            delegate: Item {
                id: delegateItem
                required property var modelData

                readonly property bool isSection: modelData.isSection === true
                readonly property var dev: isSection ? null : (modelData.device ?? null)

                width: deviceList.width
                height: isSection ? 28 : 60

                // Section label
                Text {
                    visible: delegateItem.isSection
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 4
                    anchors.bottomMargin: 4
                    text: delegateItem.modelData.label ?? ""
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: Config.subtextColor
                    opacity: 0.6
                }

                // Device card
                DeviceCard {
                    id: card
                    visible: !delegateItem.isSection
                    width: parent.width

                    readonly property var dev: delegateItem.dev

                    title: card.dev ? (card.dev.alias || card.dev.name || "Unknown") : ""
                    subtitle: card.dev ? (card.dev.address || "") : ""
                    icon: card.dev ? BluetoothService.getDeviceIcon(card.dev) : ""

                    active: card.dev !== null && card.dev.connected
                    connecting: card.dev !== null && BluetoothService.getIsConnecting(card.dev)

                    statusText: {
                        if (card.connecting)
                            return "Conectando...";
                        if (card.active)
                            return "Conectado";
                        if (card.dev && card.dev.paired)
                            return "Paired";
                        if (card.dev && card.dev.trusted)
                            return "Trusted";
                        return "";
                    }

                    showMenu: card.dev !== null && (card.dev.paired || card.dev.trusted || card.dev.connected)

                    menuModel: {
                        if (!card.dev) return [];
                        var list = [];
                        if (card.dev.connected) {
                            list.push({
                                text: "Disconnect",
                                action: "disconnect",
                                icon: "",
                                textColor: Config.warningColor,
                                iconColor: Config.warningColor
                            });
                        } else {
                            list.push({
                                text: "Connect",
                                action: "connect",
                                icon: "",
                                textColor: Config.successColor,
                                iconColor: Config.successColor
                            });
                        }
                        list.push({
                            text: "Forget",
                            action: "forget",
                            icon: "",
                            textColor: Config.errorColor,
                            iconColor: Config.errorColor
                        });
                        return list;
                    }

                    onMenuAction: actionId => {
                        if (!card.dev) return;
                        if (actionId === "forget")
                            BluetoothService.forgetDevice(card.dev);
                        else
                            BluetoothService.toggleConnection(card.dev);
                    }

                    onClicked: {
                        if (card.dev)
                            BluetoothService.toggleConnection(card.dev);
                    }
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: !BluetoothService.isPowered || BluetoothService.devicesList.length === 0

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64
                    height: 64
                    radius: 32
                    color: Config.surface1Color

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (!BluetoothService.isPowered)
                                return "󰂲";
                            if (BluetoothService.isDiscovering)
                                return "󰂱";
                            return "󰂳";
                        }
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconLarge
                        color: Config.subtextColor
                        opacity: 0.5
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (!BluetoothService.isPowered)
                            return "Bluetooth Off";
                        if (BluetoothService.isDiscovering)
                            return "Searching...";
                        return "No devices found";
                    }
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                    opacity: 0.7
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (!BluetoothService.isPowered)
                            return "Turn on to connect";
                        if (BluetoothService.isDiscovering)
                            return "Looking for devices";
                        return "Press scan to search for devices";
                    }
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                    opacity: 0.5
                }
            }
        }
    }
}
