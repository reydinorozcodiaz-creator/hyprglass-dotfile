pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import qs.config
import qs.services
import qs.components

QsPopupWindow {
    id: root

    popupWidth: 420
    popupMaxHeight: 700
    anchorSide: "right"
    moduleName: "Orbit"
    contentImplicitHeight: showSettings
        ? Math.min(settingsFlick.contentHeight + 8, 680)
        : popupMaxHeight - 32

    readonly property bool showSettings: AiService.showSettings
    property bool followLatest: true
    readonly property var inputFieldItem: inputField

    Component.onCompleted: {
        root.visible = AiService.windowVisible;
    }

    onVisibleChanged: {
        if (visible !== AiService.windowVisible) {
            if (visible)
                AiService.openWindow();
            else
                AiService.closeWindow();
        }

        if (visible && !showSettings) {
            Qt.callLater(() => {
                if (root.inputFieldItem) {
                    root.inputFieldItem.text = AiService.draftMessage;
                    root.inputFieldItem.forceActiveFocus();
                }
            });
        }
    }

    Connections {
        target: AiService

        function onWindowVisibleChanged() {
            if (root.visible !== AiService.windowVisible)
                root.visible = AiService.windowVisible;
        }

        function onDraftMessageChanged() {
            if (!inputField.activeFocus && inputField.text !== AiService.draftMessage)
                inputField.text = AiService.draftMessage;
        }

        function onMessagesChanged() {
            if (root.followLatest)
                Qt.callLater(() => root.scrollToLatest());
        }

        function onIsLoadingChanged() {
            if (AiService.isLoading) {
                root.followLatest = true;
                Qt.callLater(() => root.scrollToLatest());
            }
        }
    }

    function scrollToLatest() {
        messageList.positionViewAtEnd();
    }

    function updateFollowLatest() {
        if (messageList.contentHeight <= messageList.height || messageList.atYEnd) {
            root.followLatest = true;
            return;
        }
        if (messageList.dragging || messageList.flicking) {
            root.followLatest = false;
            return;
        }
        var distance = messageList.contentHeight - (messageList.contentY + messageList.height);
        // Solo seguir el scroll si estamos a menos de 40px del fondo real
        root.followLatest = distance < 40;
    }

    function runCmd(cmd) {
        openProc.command = cmd;
        openProc.running = true;
    }

    function runFilePickerAndInsert() {
        // Try zenity first, fall back to kdialog
        filePickerProc.command = [
            "bash", "-c",
            "zenity --file-selection --title='Seleccionar archivo' 2>/dev/null || kdialog --getopenfilename 2>/dev/null"
        ];
        filePickerProc.running = true;
    }

    function pasteFromClipboard() {
        pasteProc.command = ["bash", "-c", "wl-paste --no-newline 2>/dev/null || xclip -o 2>/dev/null"];
        pasteProc.running = true;
    }

    function quoteMessage(text) {
        const quoted = AiService.quoteText(text);
        if (quoted === "")
            return;

        const next = inputField.text.trim() === ""
            ? quoted + "\n\n"
            : inputField.text + "\n\n" + quoted + "\n\n";
        inputField.text = next;
        AiService.setDraftMessage(next);
        inputField.cursorPosition = inputField.length;
        inputField.forceActiveFocus();
    }

    function sendCurrentMessage() {
        const text = inputField.text.trim();
        if (text === "" || (AiService.isLoading && !AiService.stoppedByUser))
            return;

        root.followLatest = true;
        inputField.text = "";
        AiService.clearDraftMessage();
        AiService.sendMessage(text);
        Qt.callLater(() => root.scrollToLatest());
    }

    function agentMeta(agent) {
        if (!agent)
            return "";
        const parts = [];
        if (agent.model)
            parts.push(agent.model);
        if (agent.provider)
            parts.push(agent.provider);
        return parts.join(" · ");
    }

    Flickable {
        id: settingsFlick
        anchors.fill: parent
        visible: root.showSettings
        readonly property real contentPadding: 14
        contentWidth: width
        contentHeight: settingsCol.implicitHeight + 24
        clip: true
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 8
        }

        ColumnLayout {
            id: settingsCol
            x: 0
            width: settingsFlick.width - settingsFlick.contentPadding
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "󱜚"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIcon + 6
                    color: Config.accentColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: "Orbit  ·  OpenFang"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeLarge + 2
                        font.bold: true
                        color: Config.textColor
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Orbit ahora es un frontend puro conectado solo a OpenFang."
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                        opacity: 0.72
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Config.surface1Color; opacity: 0.6 }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "MOTOR DE IA"
                    font.family: Config.font
                    font.pixelSize: 10
                    font.bold: true
                    color: Config.subtextColor
                    opacity: 0.45
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: Config.radius
                        color: AiService.activeBackend === "openfang" ? Config.surface2Color : Config.surface0Color
                        border.width: 1
                        border.color: AiService.activeBackend === "openfang" ? Config.accentColor : Qt.alpha(Config.surface2Color, 0.4)

                        Text {
                            anchors.centerIn: parent
                            text: "OpenFang"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: AiService.activeBackend === "openfang"
                            color: AiService.activeBackend === "openfang" ? Config.textColor : Config.subtextColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AiService.activeBackend = "openfang"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: Config.radius
                        color: AiService.activeBackend === "goose" ? Config.surface2Color : Config.surface0Color
                        border.width: 1
                        border.color: AiService.activeBackend === "goose" ? Config.accentColor : Qt.alpha(Config.surface2Color, 0.4)

                        Text {
                            anchors.centerIn: parent
                            text: "Goose"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: AiService.activeBackend === "goose"
                            color: AiService.activeBackend === "goose" ? Config.textColor : Config.subtextColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AiService.activeBackend = "goose"
                        }
                    }
                }
                
                Text {
                    Layout.fillWidth: true
                    text: AiService.activeBackend === "goose" 
                        ? "Goose procesara comandos para automatizar desarrollo y tareas nativas."
                        : "OpenFang proveera endpoints HTTP para interactuar con LLMs (Ej. LM Studio)."
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall - 2
                    color: Config.subtextColor
                    opacity: 0.7
                    wrapMode: Text.Wrap
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Config.surface1Color; opacity: 0.6 }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "ESTADO DEL BACKEND"
                    font.family: Config.font
                    font.pixelSize: 10
                    font.bold: true
                    color: Config.subtextColor
                    opacity: 0.45
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: Config.radius
                    implicitHeight: statusCol.implicitHeight + 20
                    color: AiService.connectionState === "connected"
                        ? Qt.alpha(Config.successColor, 0.08)
                        : Qt.alpha(Config.errorColor, 0.08)
                    border.width: 1
                    border.color: AiService.connectionState === "connected"
                        ? Qt.alpha(Config.successColor, 0.22)
                        : Qt.alpha(Config.errorColor, 0.22)

                    ColumnLayout {
                        id: statusCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: AiService.connectionState === "connected" ? "󰄬" : "󰅙"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeIconSmall
                                color: AiService.connectionState === "connected" ? Config.successColor : Config.errorColor
                            }

                            Text {
                                Layout.fillWidth: true
                                text: AiService.backendStatusLabel
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                font.bold: true
                                color: Config.textColor
                                wrapMode: Text.Wrap
                            }

                            Spinner {
                                running: AiService.isRefreshingBackend
                                size: Config.fontSizeSmall
                                color: Config.subtextColor
                                visible: AiService.isRefreshingBackend
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: AiService.activeAgent
                                ? "Agente actual: " + AiService.activeAgentDisplayName + (AiService.activeAgentModelLabel !== "" ? "  ·  " + AiService.activeAgentModelLabel : "")
                                : "Aun no hay un agente listo seleccionado en OpenFang."
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall - 1
                            color: Config.subtextColor
                            opacity: 0.78
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: !AiService.isGoose

                Text {
                    text: "URL DE OPENFANG"
                    font.family: Config.font
                    font.pixelSize: 10
                    font.bold: true
                    color: Config.subtextColor
                    opacity: 0.45
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: Config.radius
                    color: Config.surface0Color
                    border.width: urlField.activeFocus ? 1.5 : 1
                    border.color: urlField.activeFocus ? Config.accentColor : Qt.alpha(Config.surface2Color, 0.4)

                    TextInput {
                        id: urlField
                        anchors.fill: parent
                        anchors.margins: 14
                        text: AiService.openfangBaseUrl
                        onTextEdited: AiService.openfangBaseUrl = text
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.textColor

                        Text {
                            anchors.fill: parent
                            text: "http://127.0.0.1:4200"
                            font: urlField.font
                            color: Config.subtextColor
                            opacity: 0.3
                            visible: urlField.text === ""
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: !AiService.isGoose

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "API KEY"
                        font.family: Config.font
                        font.pixelSize: 10
                        font.bold: true
                        color: Config.subtextColor
                        opacity: 0.45
                    }

                    Text {
                        text: "opcional"
                        font.family: Config.font
                        font.pixelSize: 9
                        color: Config.subtextColor
                        opacity: 0.35
                        leftPadding: 4
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: keyField.echoMode === TextInput.Password ? "Mostrar" : "Ocultar"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.accentColor
                        opacity: 0.78

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: keyField.echoMode = keyField.echoMode === TextInput.Password
                                ? TextInput.Normal
                                : TextInput.Password
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: Config.radius
                    color: Config.surface0Color
                    border.width: keyField.activeFocus ? 1.5 : 1
                    border.color: keyField.activeFocus ? Config.accentColor : Qt.alpha(Config.surface2Color, 0.4)

                    TextInput {
                        id: keyField
                        anchors.fill: parent
                        anchors.margins: 14
                        text: AiService.openfangApiKey
                        onTextEdited: AiService.openfangApiKey = text
                        echoMode: TextInput.Password
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.textColor

                        Text {
                            anchors.fill: parent
                            text: "Bearer opcional de OpenFang"
                            font: keyField.font
                            color: Config.subtextColor
                            opacity: 0.3
                            visible: keyField.text === ""
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: !AiService.isGoose

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "AGENTE OPENFANG"
                        font.family: Config.font
                        font.pixelSize: 10
                        font.bold: true
                        color: Config.subtextColor
                        opacity: 0.45
                    }

                    Item { Layout.fillWidth: true }

                    Spinner {
                        running: AiService.isRefreshingBackend
                        size: Config.fontSizeSmall
                        color: Config.subtextColor
                        visible: AiService.isRefreshingBackend
                    }

                    Text {
                        text: "Recargar"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.accentColor
                        opacity: 0.78

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AiService.refreshBackendState(true)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: Config.radius
                    implicitHeight: agentsCol.implicitHeight + 20
                    color: Config.surface0Color
                    border.width: 1
                    border.color: Qt.alpha(Config.surface2Color, 0.35)

                    ColumnLayout {
                        id: agentsCol
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        anchors.rightMargin: 14
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            visible: !AiService.isRefreshingBackend && AiService.availableAgents.length === 0
                            text: AiService.connectionError !== ""
                                ? AiService.connectionError
                                : "OpenFang no devolvio agentes listos para Orbit."
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: AiService.connectionError !== "" ? Config.errorColor : Config.subtextColor
                            wrapMode: Text.Wrap
                        }

                        Repeater {
                            model: AiService.availableAgents

                            delegate: Rectangle {
                                id: agentCard
                                required property var modelData

                                Layout.fillWidth: true
                                implicitHeight: 68
                                radius: Config.radius
                                color: AiService.activeAgent && AiService.activeAgent.id === modelData.id
                                    ? Qt.alpha(Config.accentColor, 0.12)
                                    : Config.surface1Color
                                border.width: 1
                                border.color: AiService.activeAgent && AiService.activeAgent.id === modelData.id
                                    ? Qt.alpha(Config.accentColor, 0.34)
                                    : Qt.alpha(Config.surface2Color, 0.3)

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AiService.selectAgent(agentCard.modelData.id)
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            Layout.fillWidth: true
                                            text: (agentCard.modelData.name && agentCard.modelData.name !== "unnamed") ? agentCard.modelData.name : ((agentCard.modelData.id && agentCard.modelData.id !== "unnamed") ? agentCard.modelData.id : "OpenFang")
                                            font.family: Config.font
                                            font.pixelSize: Config.fontSizeSmall
                                            font.bold: true
                                            color: Config.textColor
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            radius: 9
                                            height: 18
                                            width: stateLabel.implicitWidth + 10
                                            color: agentCard.modelData.ready === true
                                                ? Qt.alpha(Config.successColor, 0.14)
                                                : Qt.alpha(Config.errorColor, 0.14)

                                            Text {
                                                id: stateLabel
                                                anchors.centerIn: parent
                                                text: agentCard.modelData.ready === true ? "listo" : (agentCard.modelData.state || "no listo")
                                                font.family: Config.font
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: agentCard.modelData.ready === true ? Config.successColor : Config.errorColor
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.agentMeta(agentCard.modelData)
                                        font.family: Config.font
                                        font.pixelSize: 10
                                        color: Config.subtextColor
                                        opacity: 0.8
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 46
                radius: Config.radius
                color: saveMouse.containsMouse ? Config.accentColor : Qt.alpha(Config.accentColor, 0.82)

                MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AiService.saveConfig();
                        Qt.callLater(() => inputField.forceActiveFocus());
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Guardar y abrir Orbit  →"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    color: Config.textReverseColor
                }
            }
        }
    }

    ColumnLayout {
        id: chatCol
        anchors.fill: parent
        spacing: 0
        visible: !root.showSettings

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            Layout.topMargin: 4
            spacing: 6

            Text {
                text: "󱜚"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon + 2
                color: Config.accentColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: "Orbit"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    font.bold: true
                    color: Config.textColor
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: AiService.activeAgentDisplayName + (AiService.activeAgentModelLabel !== "" ? "  ·  " + AiService.activeAgentModelLabel : "")
                    font.family: Config.font
                    font.pixelSize: 11
                    color: Config.subtextColor
                    opacity: 0.68
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // READY badge — visible when connected and not loading
            Rectangle {
                visible: AiService.connectionState === "connected" && !AiService.isLoading
                height: 22
                width: readyBadgeRow.implicitWidth + 16
                radius: 11
                color: Qt.alpha(Config.successColor, 0.12)
                border.width: 1
                border.color: Qt.alpha(Config.successColor, 0.3)

                Row {
                    id: readyBadgeRow
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: Config.successColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "READY"
                        font.family: Config.font
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 0.5
                        color: Config.successColor
                    }
                }
            }

            Rectangle {
                visible: AiService.isLoading
                width: 28
                height: 28
                radius: Config.radius
                color: stopHover.containsMouse ? Qt.alpha(Config.errorColor, 0.22) : Qt.alpha(Config.errorColor, 0.10)
                border.width: 1
                border.color: Qt.alpha(Config.errorColor, 0.35)

                Text {
                    anchors.centerIn: parent
                    text: "󰚌"
                    font.family: Config.font
                    font.pixelSize: 11
                    color: Config.errorColor
                }

                MouseArea {
                    id: stopHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AiService.stopGeneration()
                }
            }

            ActionButton {
                icon: "󰑐"
                baseColor: "transparent"
                hoverColor: Config.surface1Color
                textColor: Config.subtextColor
                visible: !AiService.isLoading && AiService.lastUserPrompt !== ""
                onClicked: AiService.retryLastMessage()
            }

            ActionButton {
                icon: "󰃢"
                baseColor: "transparent"
                hoverColor: Config.surface1Color
                textColor: Config.subtextColor
                visible: AiService.messages.length > 0 && !AiService.isLoading
                onClicked: AiService.clearHistory()
            }

            ActionButton {
                icon: "󰒓"
                baseColor: "transparent"
                hoverColor: Config.surface1Color
                textColor: Config.subtextColor
                onClicked: AiService.openSettings()
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Config.surface1Color; opacity: 0.5 }

        ListView {
            id: messageList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            topMargin: 10
            bottomMargin: 10
            model: AiService.messages
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            onContentYChanged: root.updateFollowLatest()
            onHeightChanged: root.updateFollowLatest()
            onMovementEnded: root.updateFollowLatest()
            onContentHeightChanged: {
                root.updateFollowLatest();
                // No forzar el scroll si el usuario está arrastrando o la lista está en inercia (flicking)
                if (root.followLatest && !messageList.dragging && !messageList.flicking)
                    Qt.callLater(() => root.scrollToLatest());
            }

            Item {
                anchors.fill: parent
                visible: AiService.messages.length === 0 && !AiService.isLoading

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 18
                    width: parent.width - 34

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󱜚"
                        font.family: Config.font
                        font.pixelSize: 52
                        color: Config.subtextColor
                        opacity: 0.14
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: AiService.activeAgent && AiService.activeAgent.ready === true
                            ? "Orbit esta conectado a OpenFang"
                            : "Orbit necesita un agente listo"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeLarge + 3
                        font.bold: true
                        color: Config.textColor
                        opacity: 0.78
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: AiService.activeAgent && AiService.activeAgent.ready === true
                            ? "Escribe un mensaje para empezar a chatear con " + AiService.activeAgentDisplayName + "."
                            : "Abre los ajustes y selecciona un backend/agente disponible en OpenFang."
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                        opacity: 0.55
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        height: 38
                        width: emptySettingsLabel.implicitWidth + 24
                        radius: Config.radius
                        color: Config.surface1Color

                        Text {
                            id: emptySettingsLabel
                            anchors.centerIn: parent
                            text: "Abrir ajustes"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: true
                            color: Config.textColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AiService.openSettings()
                        }
                    }
                }
            }

            delegate: Item {
                id: msgItem
                required property var modelData

                readonly property bool isUser: modelData.role === "user"
                readonly property string messageType: modelData.messageType || (isUser ? "user" : "assistant_text")
                readonly property bool isErrorNotice: messageType === "error_notice"
                readonly property string assistantText: String(modelData.content || "")
                width: messageList.width
                height: contentColumn.implicitHeight + 16

                HoverHandler { id: msgHover }

                Column {
                    id: contentColumn
                    width: parent.width
                    spacing: 6
                    anchors.top: parent.top
                    anchors.topMargin: 8

                    Item {
                        visible: msgItem.isUser
                        width: parent.width
                        height: userColumn.implicitHeight

                        Column {
                            id: userColumn
                            width: parent.width
                            spacing: 4

                            // Full-width user bubble — OpenFang style
                            Rectangle {
                                id: userBubble
                                width: parent.width
                                implicitHeight: userTxt.implicitHeight + 24
                                radius: Config.radiusLarge
                                color: Qt.alpha(Config.accentColor, 0.1)
                                border.width: 1
                                border.color: Qt.alpha(Config.accentColor, 0.28)

                                Text {
                                    id: userTxt
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    anchors.topMargin: 12
                                    anchors.bottomMargin: 12
                                    text: msgItem.modelData.content
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    color: Config.textColor
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    lineHeight: 1.5
                                }
                            }

                            Text {
                                visible: (msgItem.modelData.time || "") !== ""
                                text: msgItem.modelData.time || ""
                                font.family: Config.font
                                font.pixelSize: 9
                                color: Config.subtextColor
                                opacity: 0.35
                                horizontalAlignment: Text.AlignRight
                                width: parent.width
                            }
                        }
                    }

                    RowLayout {
                        visible: !msgItem.isUser
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            width: 28
                            height: 28
                            radius: 14
                            color: msgItem.isErrorNotice
                                ? Qt.alpha(Config.errorColor, 0.12)
                                : Qt.alpha(Config.accentColor, 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: msgItem.modelData.icon || (msgItem.isErrorNotice ? "󰅙" : "󱜚")
                                font.family: Config.font
                                font.pixelSize: 13
                                color: msgItem.isErrorNotice ? Config.errorColor : Config.accentColor
                            }
                        }

                        Column {
                            id: assistantContent
                            Layout.fillWidth: true
                            spacing: 6

                            ColumnLayout {
                                width: assistantContent.width
                                spacing: 3

                                Text {
                                    width: assistantContent.width
                                    text: msgItem.modelData.title
                                        || (msgItem.isErrorNotice ? "Error de Orbit" : AiService.assistantLabel(msgItem.modelData))
                                    font.family: Config.font
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: msgItem.isErrorNotice ? Config.errorColor : Config.accentColor
                                    opacity: 0.85
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        text: msgItem.modelData.model || AiService.activeAgentModelLabel
                                        font.family: Config.font
                                        font.pixelSize: 10
                                        color: Config.subtextColor
                                        opacity: 0.55
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        visible: text !== ""
                                    }

                                    Text {
                                        text: msgItem.modelData.time || ""
                                        font.family: Config.font
                                        font.pixelSize: 10
                                        color: Config.subtextColor
                                        opacity: 0.35
                                        visible: text !== ""
                                    }
                                }
                            }

                            Rectangle {
                                width: assistantContent.width
                                radius: Config.radiusLarge
                                color: msgItem.isErrorNotice
                                    ? Qt.alpha(Config.errorColor, 0.08)
                                    : Qt.alpha(Config.surface0Color, 0.96)
                                border.width: 1
                                border.color: msgItem.isErrorNotice
                                    ? Qt.alpha(Config.errorColor, 0.26)
                                    : Qt.alpha(Config.surface2Color, 0.32)
                                implicitHeight: assistantCardColumn.implicitHeight + 20

                                Column {
                                    id: assistantCardColumn
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    OrbitMessageParts {
                                        width: assistantCardColumn.width
                                        content: msgItem.modelData.content || ""
                                        webContext: null
                                        parts: AiService.messagePartsFor(msgItem.modelData)
                                        onOpenLink: url => root.runCmd(["xdg-open", url])
                                        onCopyText: text => root.runCmd(["bash", "-c", "printf '%s' " + JSON.stringify(text) + " | wl-copy"])
                                    }
                                }
                            }

                            Row {
                                visible: (msgItem.modelData.content || "") !== ""
                                spacing: 4
                                height: 28
                                opacity: msgHover.hovered ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Rectangle {
                                    width: copyRow.implicitWidth + 14
                                    height: 24
                                    radius: 12
                                    color: copyHover.containsMouse ? Config.surface1Color : Config.surface0Color
                                    border.width: 1
                                    border.color: Qt.alpha(Config.surface2Color, 0.4)

                                    Row {
                                        id: copyRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: "󰆏"
                                            font.family: Config.font
                                            font.pixelSize: 10
                                            color: Config.subtextColor
                                        }

                                        Text {
                                            text: "Copiar"
                                            font.family: Config.font
                                            font.pixelSize: 10
                                            color: Config.subtextColor
                                        }
                                    }

                                    MouseArea {
                                        id: copyHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.runCmd(["bash", "-c", "printf '%s' " + JSON.stringify(msgItem.modelData.content) + " | wl-copy"])
                                    }
                                }

                                Rectangle {
                                    width: quoteRow.implicitWidth + 14
                                    height: 24
                                    radius: 12
                                    color: quoteHover.containsMouse ? Config.surface1Color : Config.surface0Color
                                    border.width: 1
                                    border.color: Qt.alpha(Config.surface2Color, 0.4)

                                    Row {
                                        id: quoteRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: "󰘍"
                                            font.family: Config.font
                                            font.pixelSize: 10
                                            color: Config.subtextColor
                                        }

                                        Text {
                                            text: "Citar"
                                            font.family: Config.font
                                            font.pixelSize: 10
                                            color: Config.subtextColor
                                        }
                                    }

                                    MouseArea {
                                        id: quoteHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.quoteMessage(msgItem.modelData.content)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignRight
            // Mostrar solo si el contenido es más grande que la vista Y estamos a más de 100px del final
            visible: (messageList.contentHeight > messageList.height) && (messageList.contentHeight - messageList.contentY - messageList.height > 100)
            height: 30
            width: jumpRow.implicitWidth + 20
            radius: 15
            color: Qt.alpha(Config.surface0Color, 0.96)
            border.width: 1
            border.color: Qt.alpha(Config.accentColor, 0.24)

            Row {
                id: jumpRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "󰁝"
                    font.family: Config.font
                    font.pixelSize: 11
                    color: Config.accentColor
                }

                Text {
                    text: "Ir al final"
                    font.family: Config.font
                    font.pixelSize: 10
                    font.bold: true
                    color: Config.textColor
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.scrollToLatest()
            }
        }

        Item {
            Layout.fillWidth: true
            height: visible ? 52 : 0
            visible: AiService.isLoading && !AiService.stoppedByUser

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: Qt.alpha(Config.accentColor, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: "󱜚"
                        font.family: Config.font
                        font.pixelSize: 13
                        color: Config.accentColor
                    }
                }

                Rectangle {
                    width: 60
                    height: 34
                    radius: Config.radius
                    color: Config.surface0Color

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Repeater {
                            model: 3

                            delegate: Rectangle {
                                id: dot
                                required property int index
                                width: 7
                                height: 7
                                radius: 3.5
                                color: Config.accentColor
                                opacity: 0.7

                                SequentialAnimation on y {
                                    loops: Animation.Infinite
                                    running: AiService.isLoading
                                    PauseAnimation { duration: dot.index * 160 }
                                    NumberAnimation { to: -5; duration: 240; easing.type: Easing.OutCubic }
                                    NumberAnimation { to: 0; duration: 240; easing.type: Easing.InCubic }
                                    PauseAnimation { duration: (2 - dot.index) * 160 }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 6
            implicitHeight: errTxt.implicitHeight + 18
            radius: Config.radius
            color: Qt.alpha(Config.errorColor, 0.10)
            border.width: 1
            border.color: Qt.alpha(Config.errorColor, 0.35)
            visible: AiService.lastError !== ""

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "󰀪"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.errorColor
                }

                Text {
                    id: errTxt
                    Layout.fillWidth: true
                    text: AiService.lastError
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.errorColor
                    wrapMode: Text.Wrap
                }

                Text {
                    visible: !AiService.isLoading && AiService.lastUserPrompt !== ""
                    text: "Reintentar"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.accentColor

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AiService.retryLastMessage()
                    }
                }

                Text {
                    text: "✕"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.errorColor
                    opacity: 0.65

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AiService.lastError = ""
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: composerColumn.implicitHeight + 20
                radius: Config.radiusLarge
                color: Qt.alpha(Config.surface0Color, 0.96)
                // Orange border always visible — stronger on focus (OpenFang style)
                border.width: 1.5
                border.color: inputField.activeFocus
                    ? Config.accentColor
                    : Qt.alpha(Config.accentColor, 0.32)

                ColumnLayout {
                    id: composerColumn
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Attachment button — opens file picker and inserts path into input
                        Rectangle {
                            id: attachBtn
                            width: 32
                            height: 32
                            radius: 8
                            color: attachHover.containsMouse
                                ? Qt.alpha(Config.accentColor, 0.18)
                                : Qt.alpha(Config.surface1Color, 0.7)
                            border.width: 1
                            border.color: attachHover.containsMouse
                                ? Qt.alpha(Config.accentColor, 0.4)
                                : Qt.alpha(Config.surface2Color, 0.35)

                            Text {
                                anchors.centerIn: parent
                                text: "󰁦"
                                font.family: Config.font
                                font.pixelSize: 15
                                color: attachHover.containsMouse ? Config.accentColor : Config.subtextColor
                                opacity: attachHover.containsMouse ? 1.0 : 0.65
                            }

                            MouseArea {
                                id: attachHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runFilePickerAndInsert()
                            }

                            ToolTip {
                                visible: attachHover.containsMouse
                                text: "Adjuntar archivo"
                                delay: 600
                            }
                        }

                        // Paste clipboard button
                        Rectangle {
                            id: pasteBtn
                            width: 32
                            height: 32
                            radius: 8
                            color: pasteHover.containsMouse
                                ? Qt.alpha(Config.accentColor, 0.18)
                                : Qt.alpha(Config.surface1Color, 0.7)
                            border.width: 1
                            border.color: pasteHover.containsMouse
                                ? Qt.alpha(Config.accentColor, 0.4)
                                : Qt.alpha(Config.surface2Color, 0.35)

                            Text {
                                anchors.centerIn: parent
                                text: "󰍬"
                                font.family: Config.font
                                font.pixelSize: 15
                                color: pasteHover.containsMouse ? Config.accentColor : Config.subtextColor
                                opacity: pasteHover.containsMouse ? 1.0 : 0.65
                            }

                            MouseArea {
                                id: pasteHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pasteFromClipboard()
                            }

                            ToolTip {
                                visible: pasteHover.containsMouse
                                text: "Pegar portapapeles"
                                delay: 600
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(Math.max(34, inputField.contentHeight), 104)
                            clip: true

                            TextEdit {
                                id: inputField
                                anchors.fill: parent
                                anchors.rightMargin: 10
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.textColor
                                wrapMode: Text.Wrap
                                verticalAlignment: TextEdit.AlignVCenter
                                enabled: !AiService.isLoading || AiService.stoppedByUser
                                text: AiService.draftMessage
                                clip: true
                                onTextChanged: AiService.setDraftMessage(text)

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Return && !(event.modifiers & Qt.ShiftModifier)) {
                                        event.accepted = true;
                                        root.sendCurrentMessage();
                                    }
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 2
                                anchors.rightMargin: 14
                                text: AiService.orbitPlaceholder()
                                font: inputField.font
                                color: Config.subtextColor
                                opacity: 0.4
                                visible: inputField.text === ""
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                                clip: true
                            }
                        }

                        Rectangle {
                            width: 38
                            height: 38
                            radius: 19
                            color: AiService.isLoading
                                ? (sendHover.containsMouse ? Qt.alpha(Config.errorColor, 0.85) : Qt.alpha(Config.errorColor, 0.65))
                                : (inputField.text.trim() !== ""
                                    ? (sendHover.containsMouse ? Qt.lighter(Config.accentColor, 1.1) : Config.accentColor)
                                    : Qt.alpha(Config.accentColor, 0.22))

                            Text {
                                anchors.centerIn: parent
                                text: AiService.isLoading ? "󰚌" : "󰒊"
                                font.family: Config.font
                                font.pixelSize: 14
                                color: AiService.isLoading
                                    ? Config.errorColor
                                    : (inputField.text.trim() !== "" ? Config.textReverseColor : Qt.alpha(Config.accentColor, 0.45))
                            }

                            MouseArea {
                                id: sendHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (AiService.isLoading)
                                        AiService.stopGeneration();
                                    else
                                        root.sendCurrentMessage();
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Model pill — OpenFang style
                        Rectangle {
                            height: 22
                            width: modelPillRow.implicitWidth + 16
                            radius: 11
                            color: Qt.alpha(Config.surface1Color, 0.9)
                            border.width: 1
                            border.color: Qt.alpha(Config.surface2Color, 0.4)

                            Row {
                                id: modelPillRow
                                anchors.centerIn: parent
                                spacing: 5

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: AiService.connectionState === "connected" ? Config.successColor : Qt.alpha(Config.subtextColor, 0.4)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: AiService.activeAgentModelLabel !== ""
                                        ? AiService.activeAgentModelLabel
                                        : (AiService.connectionState === "connected"
                                            ? AiService.activeAgentDisplayName
                                            : "OpenFang")
                                    font.family: Config.font
                                    font.pixelSize: 10
                                    color: Config.subtextColor
                                    maximumLineCount: 1
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: inputField.text.trim() !== ""
                            text: "Limpiar"
                            font.family: Config.font
                            font.pixelSize: 10
                            color: Config.subtextColor
                            opacity: clearDraftMouse.containsMouse ? 0.9 : 0.55

                            MouseArea {
                                id: clearDraftMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    inputField.text = "";
                                    AiService.clearDraftMessage();
                                    inputField.forceActiveFocus();
                                }
                            }
                        }

                        Text {
                            text: "/ para comandos"
                            font.family: Config.font
                            font.pixelSize: 10
                            color: Config.subtextColor
                            opacity: 0.28
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Enter envia  ·  Shift+Enter nueva linea"
                font.family: Config.font
                font.pixelSize: 10
                color: Config.subtextColor
                opacity: 0.25
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Process {
        id: openProc
        running: false
    }

    // File picker process: inserts selected path into input field
    Process {
        id: filePickerProc
        running: false
        stdout: StdioCollector { id: filePickerOut; waitForEnd: true }

        onExited: {
            const path = filePickerOut.text.trim();
            if (path === "")
                return;
            const current = inputField.text;
            const sep = current.trim() === "" ? "" : "\n";
            const next = current + sep + "[archivo: " + path + "]";
            inputField.text = next;
            AiService.setDraftMessage(next);
            inputField.cursorPosition = inputField.length;
            inputField.forceActiveFocus();
        }
    }

    // Paste clipboard process: inserts clipboard text into input field
    Process {
        id: pasteProc
        running: false
        stdout: StdioCollector { id: pasteOut; waitForEnd: true }

        onExited: {
            const text = pasteOut.text.trim();
            if (text === "")
                return;
            const current = inputField.text;
            const sep = current.trim() === "" ? "" : "\n";
            const next = current + sep + text;
            inputField.text = next;
            AiService.setDraftMessage(next);
            inputField.cursorPosition = inputField.length;
            inputField.forceActiveFocus();
        }
    }
}
