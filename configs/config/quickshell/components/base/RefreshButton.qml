pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

Rectangle {
    id: root

    property bool loading: false
    property int size: 36
    property string tooltipText: "Actualizar"

    signal clicked

    implicitWidth: size
    implicitHeight: size
    Layout.preferredWidth: size
    Layout.preferredHeight: size
    radius: Config.radius
    scale: 1

    color: {
        if (root.loading)
            return Config.accentColor;
        if (mouseArea.containsMouse)
            return Config.surface2Color;
        return Config.surface1Color;
    }

    Behavior on color {
        ColorAnimation { duration: Config.animDurationShort }
    }

    // Refresh Icon (visible when NOT loading)
    Text {
        id: refreshIcon
        anchors.centerIn: parent
        text: "󰑐"
        font.family: Config.font
        font.pixelSize: Config.fontSizeIcon
        color: Config.textColor
        visible: !root.loading
        scale: 1

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }
    }

    // Spinner (visible when loading)
    Spinner {
        anchors.centerIn: parent
        running: root.loading
        size: Config.fontSizeIcon
        color: Config.textReverseColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            pulseAnimation.start()
            root.clicked()
        }
    }

    SequentialAnimation {
        id: pulseAnimation
        
        NumberAnimation {
            target: refreshIcon
            property: "scale"
            to: 1.3
            duration: 150
            easing.type: Easing.OutQuad
        }
        
        NumberAnimation {
            target: refreshIcon
            property: "scale"
            to: 1
            duration: 150
            easing.type: Easing.InQuad
        }
    }
}
