pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "../../quickSettings/"
import "../../../components/"

Item {
    id: root

    signal closeWindow
    signal navigateTo(int page)

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    ColumnLayout {
        id: main
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        // HEADER (Profile and Info)
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Avatar / System Icon
            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: Config.radiusLarge
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Config.surface2Color
                    }
                    GradientStop {
                        position: 1.0
                        color: Config.surface1Color
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰣇"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge
                    color: Config.accentColor
                }
            }

            // Welcome Text
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
                    color: Config.textColor
                    font.family: Config.font
                    font.bold: true
                    font.pixelSize: Config.fontSizeLarge
                }
                Text {
                    text: TimeService.format("ddd, dd MMM")
                    color: Config.subtextColor
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                }
            }

            // Spacer
            Item {
                Layout.fillWidth: true
            }

            // Battery indicator (only shows if battery is present)
            Rectangle {
                visible: BatteryService.hasBattery
                Layout.preferredHeight: 36
                Layout.preferredWidth: batteryContent.implicitWidth + 16
                radius: Config.radius
                color: Config.surface1Color

                RowLayout {
                    id: batteryContent
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: BatteryService.getBatteryIcon()
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeLarge
                        color: {
                            if (BatteryService.isCharging)
                                return Config.successColor;
                            if (BatteryService.percentage < 20)
                                return Config.errorColor;
                            if (BatteryService.percentage < 40)
                                return Config.warningColor;
                            return Config.textColor;
                        }
                    }

                    Text {
                        text: BatteryService.percentage + "%"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: Config.textColor
                    }
                }
            }

            // Theme color
            ActionButton {
                icon: "󰏘"
                textColor: Config.accentColor
                hoverTextColor: Config.accentColor
                onClicked: root.navigateTo(5)  // pageTheme
            }

            // Power Menu
            ClearButton {
                icon: "⏻"

                Layout.preferredWidth: 36
                Layout.preferredHeight: 36

                onClicked: {
                    root.closeWindow();
                    PowerService.showOverlay();
                }
            }
        }

        MediaWidget {
            Layout.fillWidth: true
        }

        // BUTTON GRID
        GridLayout {
            columns: 2
            columnSpacing: 10
            rowSpacing: 10
            Layout.fillWidth: true

            // WI-FI BUTTON — always accessible; shows ethernet info as sublabel when connected
            QuickSettingsTile {
                icon: NetworkService.systemIcon
                label: "Wi-Fi"
                subLabel: {
                    if (NetworkService.ethernetConnected && !NetworkService.wifiEnabled)
                        return (NetworkService.ethernetConnection || "Ethernet") + " (wired)";
                    return NetworkService.statusText;
                }
                active: NetworkService.wifiEnabled || NetworkService.ethernetConnected
                hasDetails: true
                onToggled: NetworkService.toggleWifi()
                onOpenDetails: root.navigateTo(1)  // pageWifi
            }

            // BLUETOOTH BUTTON
            QuickSettingsTile {
                visible: BluetoothService.adapter !== null
                icon: BluetoothService.systemIcon
                label: "Bluetooth"
                subLabel: BluetoothService.statusText
                active: BluetoothService.isPowered
                hasDetails: true
                onToggled: BluetoothService.togglePower()
                onOpenDetails: root.navigateTo(3)  // pageBluetooth
            }

            // Night Light
            QuickSettingsTile {
                icon: BrightnessService.nightLightEnabled ? "󰌵" : "󰌶"
                label: "Night light"
                subLabel: BrightnessService.nightLightEnabled ? (BrightnessService.nightLightTemperature + "K") : "Off"
                active: BrightnessService.nightLightEnabled
                hasDetails: true
                onToggled: BrightnessService.toggleNightLight()
                onOpenDetails: root.navigateTo(4)  // pageNightLight
            }

            // DND (Do Not Disturb)
            QuickSettingsTile {
                Layout.columnSpan: BluetoothService.adapter === null ? 2 : 1
                icon: NotificationService.dndEnabled ? "󰂛" : "󰂚"
                label: "Do not disturb"
                subLabel: NotificationService.dndStatusText
                active: NotificationService.dndEnabled
                hasDetails: true
                onToggled: NotificationService.toggleDnd()
                onOpenDetails: root.navigateTo(6)  // pageDnd
            }
        }

        // SLIDERS
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            Layout.topMargin: 4

            // Audio slider + details button in a row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                QsSlider {
                    Layout.fillWidth: true
                    icon: AudioService.systemIcon
                    value: AudioService.volume
                    onMoved: val => AudioService.setVolume(val)
                    onIconClicked: AudioService.toggleMute()
                }

                ActionButton {
                    icon: "󰒓"
                    baseColor: Config.surface1Color
                    hoverColor: Config.surface2Color
                    textColor: Config.subtextColor
                    onClicked: root.navigateTo(7)  // pageAudio
                }
            }

            // Microphone (only shows if input device available)
            QsSlider {
                visible: AudioService.sourceReady
                icon: AudioService.sourceIcon
                value: AudioService.sourceVolume
                onMoved: val => AudioService.setSourceVolume(val)
                onIconClicked: AudioService.toggleSourceMute()
            }

            // Brightness (only shows if available)
            QsSlider {
                visible: BrightnessService.available
                icon: BrightnessService.icon
                value: BrightnessService.brightness
                onMoved: val => BrightnessService.setBrightness(val)
                onIconClicked: BrightnessService.toggleBrightness()
            }
        }
    }
}
