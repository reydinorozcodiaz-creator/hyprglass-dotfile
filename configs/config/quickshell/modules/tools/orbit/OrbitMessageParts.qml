pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import "OrbitMessageParts.js" as MessageParts

Column {
    id: root

    property string content: ""
    property var webContext: null
    property var parts: MessageParts.parseMessageParts(content, webContext)
    property color cardColor: Qt.alpha(Config.surface0Color, 0.96)

    signal openLink(string url)
    signal copyText(string text)

    width: parent ? parent.width : implicitWidth
    spacing: 10

    function richText(text) {
        return MessageParts.renderInline(
            text,
            Config.accentColor,
            "rgba(255,255,255,0.08)",
            Config.subtextColor
        );
    }

    Repeater {
        model: root.parts

        delegate: Item {
            id: partItem

            required property var modelData

            width: root.width
            implicitHeight: loader.implicitHeight

            Loader {
                id: loader
                width: parent.width
                sourceComponent: {
                    switch (partItem.modelData.type) {
                    case "table":
                        return tablePart;
                    case "web_context":
                        return webContextPart;
                    case "code":
                        return codePart;
                    case "quote":
                        return quotePart;
                    case "bullet_list":
                    case "ordered_list":
                        return listPart;
                    default:
                        return paragraphPart;
                    }
                }
            }

            Component {
                id: paragraphPart

                Text {
                    width: loader.width
                    textFormat: Text.RichText
                    text: root.richText(partItem.modelData.text || "")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.textColor
                    wrapMode: Text.Wrap
                    lineHeight: 1.6
                    onLinkActivated: url => root.openLink(url)
                }
            }

            Component {
                id: quotePart

                Rectangle {
                    width: loader.width
                    radius: Config.radius
                    color: Qt.alpha(Config.surface1Color, 0.72)
                    border.width: 1
                    border.color: Qt.alpha(Config.surface2Color, 0.22)
                    implicitHeight: quoteText.implicitHeight + 16

                    Text {
                        id: quoteText
                        anchors.fill: parent
                        anchors.margins: 8
                        textFormat: Text.RichText
                        text: root.richText(partItem.modelData.text || "")
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                        wrapMode: Text.Wrap
                        lineHeight: 1.6
                        onLinkActivated: url => root.openLink(url)
                    }
                }
            }

            Component {
                id: listPart

                Column {
                    width: loader.width
                    spacing: 6

                    Repeater {
                        model: partItem.modelData.items || []

                        delegate: Row {
                            required property var modelData
                            required property int index

                            width: parent.width
                            spacing: 8

                            Text {
                                text: partItem.modelData.type === "ordered_list"
                                    ? (index + 1) + "."
                                    : "•"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.accentColor
                            }

                            Text {
                                width: parent.width - 20
                                textFormat: Text.RichText
                                text: root.richText(modelData)
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.textColor
                                wrapMode: Text.Wrap
                                lineHeight: 1.55
                                onLinkActivated: url => root.openLink(url)
                            }
                        }
                    }
                }
            }

            Component {
                id: tablePart

                Rectangle {
                    width: loader.width
                    radius: Config.radius
                    color: Qt.alpha(Config.surface1Color, 0.48)
                    border.width: 1
                    border.color: Qt.alpha(Config.surface2Color, 0.26)
                    implicitHeight: tableFlick.implicitHeight + 16

                    readonly property int columnCount: Math.max(1, (partItem.modelData.headers || []).length)
                    readonly property real tableContentWidth: Math.max(
                        loader.width - 16,
                        columnCount * 132 + Math.max(0, columnCount - 1) * 6
                    )
                    readonly property real cellWidth: Math.max(
                        120,
                        (tableContentWidth - Math.max(0, columnCount - 1) * 6) / columnCount
                    )

                    Flickable {
                        id: tableFlick
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        interactive: contentWidth > width
                        contentWidth: tableColumn.width
                        contentHeight: tableColumn.implicitHeight
                        implicitHeight: tableColumn.implicitHeight

                        Column {
                            id: tableColumn
                            width: Math.max(tableFlick.width, tablePart.tableContentWidth)
                            spacing: 6

                            Row {
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: partItem.modelData.headers || []

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: tablePart.cellWidth
                                        color: Qt.alpha(Config.accentColor, 0.16)
                                        radius: Config.radiusSmall
                                        border.width: 1
                                        border.color: Qt.alpha(Config.accentColor, 0.24)
                                        implicitHeight: headerText.implicitHeight + 14

                                        Text {
                                            id: headerText
                                            anchors.fill: parent
                                            anchors.margins: 7
                                            textFormat: Text.RichText
                                            text: root.richText(modelData)
                                            font.family: Config.font
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: Config.textColor
                                            wrapMode: Text.Wrap
                                            lineHeight: 1.4
                                            onLinkActivated: url => root.openLink(url)
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: partItem.modelData.rows || []

                                delegate: Row {
                                    required property var modelData
                                    width: tableColumn.width
                                    spacing: 6

                                    Repeater {
                                        model: modelData

                                        delegate: Rectangle {
                                            required property var modelData
                                            width: tablePart.cellWidth
                                            color: Qt.alpha(Config.surface0Color, 0.94)
                                            radius: Config.radiusSmall
                                            border.width: 1
                                            border.color: Qt.alpha(Config.surface2Color, 0.18)
                                            implicitHeight: cellText.implicitHeight + 14

                                            Text {
                                                id: cellText
                                                anchors.fill: parent
                                                anchors.margins: 7
                                                textFormat: Text.RichText
                                                text: root.richText(modelData)
                                                font.family: Config.font
                                                font.pixelSize: 10
                                                color: Config.textColor
                                                wrapMode: Text.Wrap
                                                lineHeight: 1.45
                                                onLinkActivated: url => root.openLink(url)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: codePart

                Rectangle {
                    width: loader.width
                    radius: Config.radius
                    color: Config.blueDarkColor
                    border.width: 1
                    border.color: Qt.alpha(Config.surface2Color, 0.45)
                    implicitHeight: codeLayout.implicitHeight + 20

                    ColumnLayout {
                        id: codeLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: partItem.modelData.lang || "code"
                                font.family: Config.font
                                font.pixelSize: 10
                                font.bold: true
                                color: Config.subtextColor
                                opacity: 0.55
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                id: codeCopyLbl
                                property bool wasCopied: false
                                text: wasCopied ? "Copiado" : "󰆏 Copiar"
                                font.family: Config.font
                                font.pixelSize: 10
                                color: wasCopied ? Config.successColor : Config.subtextColor
                                opacity: codeCopyMouse.containsMouse || wasCopied ? 1.0 : 0.48
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                MouseArea {
                                    id: codeCopyMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.copyText(partItem.modelData.content || "");
                                        codeCopyLbl.wasCopied = true;
                                        codeCopyTimer.restart();
                                    }
                                }

                                Timer {
                                    id: codeCopyTimer
                                    interval: 1800
                                    onTriggered: codeCopyLbl.wasCopied = false
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: partItem.modelData.content || ""
                            font.family: "monospace"
                            font.pixelSize: Config.fontSizeSmall - 1
                            color: Config.textColor
                            wrapMode: Text.Wrap
                            lineHeight: 1.45
                            textFormat: Text.PlainText
                        }
                    }
                }
            }

            Component {
                id: webContextPart

                Rectangle {
                    width: loader.width
                    radius: Config.radius
                    color: Qt.alpha(Config.surface1Color, 0.55)
                    border.width: 1
                    border.color: Qt.alpha(Config.surface2Color, 0.24)
                    implicitHeight: webInfoCol.implicitHeight + 16

                    Column {
                        id: webInfoCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Row {
                            spacing: 6

                            Text {
                                text: "󰖟"
                                font.family: Config.font
                                font.pixelSize: 10
                                color: Config.accentColor
                            }

                            Text {
                                text: "Fuentes consultadas"
                                font.family: Config.font
                                font.pixelSize: 10
                                font.bold: true
                                color: Config.textColor
                            }
                        }

                        Text {
                            visible: !!partItem.modelData.query
                            width: parent.width
                            text: "Consulta: " + partItem.modelData.query
                            font.family: Config.font
                            font.pixelSize: 10
                            color: Config.subtextColor
                            wrapMode: Text.Wrap
                            opacity: 0.82
                        }

                        Text {
                            visible: !!(partItem.modelData.time && partItem.modelData.time.time_24h)
                            width: parent.width
                            text: "Hora local: "
                                + partItem.modelData.time.time_24h
                                + " · "
                                + (partItem.modelData.time.label
                                    || partItem.modelData.time.location
                                    || partItem.modelData.time.timezone)
                            font.family: Config.font
                            font.pixelSize: 10
                            color: Config.subtextColor
                            wrapMode: Text.Wrap
                            opacity: 0.82
                        }

                        Repeater {
                            model: MessageParts.groupSources(partItem.modelData.sources || [])

                            delegate: Rectangle {
                                required property var modelData

                                width: webInfoCol.width
                                radius: Config.radiusSmall
                                color: Qt.alpha(Config.surface0Color, 0.92)
                                border.width: 1
                                border.color: Qt.alpha(Config.surface2Color, 0.22)
                                implicitHeight: sourceGroupCol.implicitHeight + 12

                                Column {
                                    id: sourceGroupCol
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 6

                                    Row {
                                        spacing: 6

                                        Rectangle {
                                            height: 18
                                            width: domainLabel.implicitWidth + 12
                                            radius: 9
                                            color: Qt.alpha(Config.accentColor, 0.12)
                                            border.width: 1
                                            border.color: Qt.alpha(Config.accentColor, 0.2)

                                            Text {
                                                id: domainLabel
                                                anchors.centerIn: parent
                                                text: modelData.host || "otras"
                                                font.family: Config.font
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: Config.accentColor
                                            }
                                        }

                                        Text {
                                            text: (modelData.items || []).length + " fuente" + (((modelData.items || []).length === 1) ? "" : "s")
                                            font.family: Config.font
                                            font.pixelSize: 9
                                            color: Config.subtextColor
                                            opacity: 0.8
                                        }
                                    }

                                    Repeater {
                                        model: modelData.items || []

                                        delegate: Column {
                                            required property var modelData

                                            width: parent.width
                                            spacing: 3

                                            Text {
                                                width: parent.width
                                                text: modelData.title || modelData.url || "Fuente"
                                                font.family: Config.font
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Config.textColor
                                                wrapMode: Text.Wrap
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.snippet || ""
                                                visible: text !== ""
                                                font.family: Config.font
                                                font.pixelSize: 10
                                                color: Config.subtextColor
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: "Abrir fuente · " + MessageParts.displayUrl(modelData.url || "")
                                                visible: text !== ""
                                                font.family: Config.font
                                                font.pixelSize: 9
                                                color: Config.accentColor
                                                wrapMode: Text.NoWrap
                                                elide: Text.ElideMiddle
                                                maximumLineCount: 1

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.openLink(modelData.url || "")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
