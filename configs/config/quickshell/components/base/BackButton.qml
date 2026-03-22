pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config

Button {
    id: root

    // --- Properties ---
    property string iconText: ""        // The icon (text)
    property string tooltipText: "Volver" // Tooltip text on hover
    property int size: 40                // Button size

    // --- Fine Tuning (Offsets) ---
    // Use if the font icon is not visually centered
    property real iconOffsetX: -2
    property real iconOffsetY: 0

    // --- Layout ---
    implicitWidth: size
    implicitHeight: size
    Layout.preferredWidth: size
    Layout.preferredHeight: size    
    scale: 1
    // --- Background ---
    background: Rectangle {
        radius: root.height / 2 // Ensures a perfect circle

        // Color changes on hover
        color: root.hovered ? Config.surface2Color : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    // --- Tooltip ---
    ToolTip.visible: root.hovered && root.tooltipText !== ""
    ToolTip.text: root.tooltipText
    ToolTip.delay: 500
    
    onClicked: pulseAnimation.start()

    // Icon display
    contentItem: Text {
        id: iconLabel
        anchors.centerIn: parent
        text: root.iconText
        font.family: Config.font
        font.pixelSize: Config.fontSizeLarge
        color: Config.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        x: root.iconOffsetX
        y: root.iconOffsetY
    }

    SequentialAnimation {
        id: pulseAnimation

        NumberAnimation {
            target: iconLabel
            property: "scale"
            to: 1.3
            duration: 150
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: iconLabel
            property: "scale"
            to: 1
            duration: 150
            easing.type: Easing.InQuad
        }
    }
}
