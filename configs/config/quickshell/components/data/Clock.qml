pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.components
import qs.services
import qs.config

BarButton {
    id: root

    contentItem: timeText

    Text {
        id: timeText
        anchors.centerIn: parent
        text: TimeService.format("hh:mm")

        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        font.bold: true

        color: Config.textColor
    }

    ToolTip.visible: root.hovered
    ToolTip.text: TimeService.format("dddd, MMMM d, yyyy")
    ToolTip.delay: 500
}
