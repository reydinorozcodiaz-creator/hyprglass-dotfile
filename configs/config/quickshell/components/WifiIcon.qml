pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.config

Text {
    id: root

    font.family: Config.font
    font.pixelSize: Config.fontSizeIconSmall
    font.bold: true
    color: Config.textColor

    text: NetworkService.systemIcon
}
