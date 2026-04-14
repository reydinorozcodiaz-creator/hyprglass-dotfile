pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: root

    property bool showing: false

    visible: showing

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "qs_modules"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"

    function toggle() {
        showing = !showing;
    }

    function hide() {
        showing = false;
    }

    onShowingChanged: {
        if (showing)
            HyprKeybindsService.reload();
    }

    // Click on background closes
    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    // Keyboard shortcuts
    Shortcut {
        sequences: ["Escape"]
        onActivated: root.hide()
    }

    // Content card
    Rectangle {
        id: content

        anchors.centerIn: parent
        width: 560
        height: Math.min(680, root.height - 80)

        radius: Config.radiusLarge
        color: Config.backgroundTransparentColor
        border.color: Qt.alpha(Config.accentColor, 0.2)
        border.width: 1

        // Entry animation
        scale: root.showing ? 1.0 : 0.95
        opacity: root.showing ? 1.0 : 0

        Behavior on scale {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        // Stop click-through
        MouseArea {
            anchors.fill: parent
            onClicked: event => event.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: Config.radius
                    color: Qt.alpha(Config.accentColor, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: "󰌌"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeLarge
                        color: Config.accentColor
                    }
                }

                Text {
                    text: "Keybinds"
                    color: Config.textColor
                    font.bold: true
                    font.pixelSize: Config.fontSizeLarge
                    Layout.fillWidth: true
                }

                ActionButton {
                    icon: "󰅖"
                    textColor: Config.subtextColor
                    hoverTextColor: Config.errorColor
                    onClicked: root.hide()
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Config.surface1Color
            }

            // Scrollable sections
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: sections.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: sections
                    width: parent.width
                    spacing: 14

                    Repeater {
                        model: HyprKeybindsService.sections

                        delegate: KeybindSection {
                            required property var modelData

                            title: modelData.title
                            icon: modelData.icon
                            keybinds: modelData.keybinds
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: HyprKeybindsService.sections.length === 0 ? 120 : 0
                        visible: HyprKeybindsService.sections.length === 0

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: HyprKeybindsService.isLoading
                                ? "Cargando atajos desde Hyprland..."
                                : (HyprKeybindsService.lastError || "No se encontraron binds en 70-keybinds.conf.")
                            color: Config.subtextColor
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                        }
                    }

                    Item {
                        Layout.preferredHeight: 4
                    }
                }
            }
        }
    }

    // ======================================================================
    // Inline component: section with title + keybind rows
    // ======================================================================
    component KeybindSection: ColumnLayout {
        property string title: ""
        property string icon: ""
        property var keybinds: []

        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.accentColor
            }

            Text {
                text: title
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                font.bold: true
                color: Config.textColor
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.alignment: Qt.AlignVCenter
                color: Config.surface1Color
            }
        }

        Repeater {
            model: keybinds

            delegate: Rectangle {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Config.radiusSmall
                color: index % 2 === 0 ? Config.surface0Color : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: modelData.keys
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        font.bold: true
                        color: Config.accentColor
                        Layout.preferredWidth: 220
                        elide: Text.ElideRight
                    }

                    Text {
                        text: modelData.action
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.subtextColor
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
