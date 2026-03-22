pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root

    signal backRequested
    signal passwordRequested(string ssid)

    property bool showEthernetFallback: NetworkService.ethernetConnected
        && (!NetworkService.wifiEnabled || NetworkService.accessPoints.length === 0)
    property var displayNetworks: {
        var base = (NetworkService.wifiEnabled && NetworkService.accessPoints) ? NetworkService.accessPoints : [];
        if (showEthernetFallback) {
            base = base.concat([{
                type: "ethernet",
                connection: NetworkService.ethernetConnection || "Ethernet"
            }]);
        }
        return base;
    }

    Layout.fillWidth: true
    implicitHeight: 350

    ColumnLayout {
        id: main
        anchors.fill: parent
        spacing: 12

        // Header
        PageHeader {
            icon: NetworkService.systemIcon
            title: "Wi-Fi"
            onBackClicked: root.backRequested()

            // Scan Button
            RefreshButton {
                visible: NetworkService.wifiEnabled
                loading: NetworkService.scanning
                onClicked: NetworkService.scan()
            }

            // On/Off Switch
            QsSwitch {
                checked: NetworkService.wifiEnabled
                onToggled: NetworkService.toggleWifi()
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.surface1Color
        }

        // Network List
        ListView {
            id: wifiList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 10
            clip: true
            spacing: 8

            model: root.displayNetworks

            delegate: DeviceCard {
                required property var modelData
                property bool isEthernet: modelData.type === "ethernet"
                property bool isConnectingThis: !isEthernet && NetworkService.connectingSsid === modelData.ssid

                title: isEthernet ? "Ethernet" : (modelData.ssid || "Red oculta")
                subtitle: isEthernet ? (modelData.connection || "Conectado") : (modelData.signal + "%")
                icon: isEthernet ? NetworkService.ethernetIcon : NetworkService.getWifiIcon(modelData.signal)

                active: isEthernet ? true : modelData.active
                connecting: isEthernet ? false : isConnectingThis
                secured: !isEthernet && modelData.secure && !active && !connecting

                statusText: {
                    if (isEthernet)
                        return "Conectado";
                    if (connecting)
                        return "Conectando...";
                    if (active)
                        return "Conectado";
                    if (modelData.saved)
                        return "Guardada";
                    if (modelData.secure)
                        return "Secured";
                    return "Abierta";
                }

                showMenu: !isEthernet && !connecting

                menuModel: {
                    if (isEthernet)
                        return [];
                    var list = [];
                    if (active) {
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
                    if (active || modelData.saved) {
                        list.push({
                            text: "Forget",
                            action: "forget",
                            icon: "",
                            textColor: Config.errorColor,
                            iconColor: Config.errorColor
                        });
                    }
                    return list;
                }

                onMenuAction: actionId => {
                    if (isEthernet)
                        return;
                    if (actionId === "disconnect") {
                        NetworkService.disconnect();
                    } else if (actionId === "connect") {
                        wifiToggleConnect();
                    } else if (actionId === "forget") {
                        NetworkService.forget(modelData.ssid);
                    }
                }

                onClicked: {
                    if (!isEthernet)
                        wifiToggleConnect();
                }

                function wifiToggleConnect() {
                    if (active) {
                        NetworkService.disconnect();
                        return;
                    }
                    if (modelData.saved) {
                        NetworkService.connect(modelData.ssid, "");
                        return;
                    }
                    if (modelData.secure) {
                        // Navigate to password page; do NOT call connect() here
                        root.passwordRequested(modelData.ssid);
                        return;
                    }
                    // Open network — connect directly
                    NetworkService.connect(modelData.ssid, "");
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: !NetworkService.wifiEnabled || (wifiList.count === 0)

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64
                    height: 64
                    radius: 32
                    color: Config.surface1Color

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (!NetworkService.wifiEnabled)
                                return "󰤮";
                            if (NetworkService.scanning)
                                return "󰤩";
                            return "󰤫";
                        }
                        font.family: Config.font
                        font.pixelSize: 28
                        color: Config.subtextColor
                        opacity: 0.5
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (!NetworkService.wifiEnabled)
                            return "Wi-Fi Off";
                        if (NetworkService.scanning)
                            return "Scanning...";
                        return "No networks found";
                    }
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                    opacity: 0.7
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (!NetworkService.wifiEnabled)
                            return "Turn on to see networks";
                        if (NetworkService.scanning)
                            return "Looking for networks";
                        return "Try scanning again";
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
