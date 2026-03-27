pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import qs.config
import qs.services
import "../../components/"

QsPopupWindow {
    id: root

    popupWidth:    420
    popupMaxHeight: 700
    anchorSide:    "right"
    moduleName:    "Orbit"
    contentImplicitHeight: showSettings ? Math.min(settingsFlick.contentHeight + 8, 680) : 680

    readonly property bool showSettings: AiService.showSettings
    property bool showModelPicker: false
    property bool showAttachPanel: false
    property bool followLatest: true

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
            inputField.text = AiService.draftMessage;
            inputField.forceActiveFocus();
            showModelPicker = false;
        }
        if (!visible) {
            showAttachPanel = false;
            showModelPicker = false;
        }
    }

    Connections {
        target: AiService
        function onWindowVisibleChanged() {
            if (root.visible !== AiService.windowVisible)
                root.visible = AiService.windowVisible;
        }
        function onPendingAttachmentsChanged() {
            if (AiService.pendingAttachments.length > 0 && root.showAttachPanel)
                attachPathField.text = "";
        }
        function onDraftMessageChanged() {
            if (!inputField.activeFocus && inputField.text !== AiService.draftMessage)
                inputField.text = AiService.draftMessage;
        }
        function onMessagesChanged() {
            if (root.followLatest || AiService.isLoading)
                Qt.callLater(() => root.scrollToLatest());
        }
        function onIsLoadingChanged() {
            if (AiService.isLoading)
                Qt.callLater(() => root.scrollToLatest());
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────
    function modelLabelForMessage(message) {
        return message.model || AiService.model;
    }

    function scrollToLatest() {
        messageList.positionViewAtEnd();
        root.followLatest = true;
    }

    function updateFollowLatest() {
        const distance = messageList.contentHeight - (messageList.contentY + messageList.height);
        root.followLatest = distance < 72;
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

    function runCmd(cmd) {
        openProc.command = cmd;
        openProc.running = true;
    }

    function sendCurrentMessage() {
        const txt = inputField.text.trim();
        if ((txt === "" && AiService.pendingAttachments.length === 0)
                || (AiService.isLoading && !AiService.stoppedByUser)) return;
        root.followLatest = true;
        inputField.text = "";
        AiService.clearDraftMessage();
        AiService.sendMessage(txt);
    }

    // ╔══════════════════════════════════════════════════════════════════════╗
    // ║  SETTINGS PANEL                                                      ║
    // ╚══════════════════════════════════════════════════════════════════════╝
    Flickable {
        id: settingsFlick
        anchors.fill: parent
        visible: root.showSettings
        contentWidth: width
        contentHeight: settingsCol.implicitHeight + 24
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: settingsCol
            width: settingsFlick.width
            spacing: 16

            // Header
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Text {
                    text: "󱜚"; font.family: Config.font
                    font.pixelSize: Config.fontSizeIcon + 6; color: Config.accentColor
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text {
                        text: "Orbit  —  Configuracion"
                        font.family: Config.font; font.pixelSize: Config.fontSizeLarge + 2
                        font.bold: true; color: Config.textColor
                    }
                    Text {
                        text: "Configura tu proveedor para activar Orbit"
                        font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor; opacity: 0.6
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Config.surface1Color; opacity: 0.6 }

            // ── Provider selector ─────────────────────────────────────────
            ColumnLayout { Layout.fillWidth: true; spacing: 10
                Text {
                    text: "PROVEEDOR"; font.family: Config.font; font.pixelSize: 10
                    font.bold: true; color: Config.subtextColor; opacity: 0.45
                }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Repeater {
                        model: [
                            { id: "openai",   icon: "",  label: "OpenAI"   },
                            { id: "gemini",   icon: "",  label: "Gemini"   },
                            { id: "copilot",  icon: "", label: "Copilot"  },
                            { id: "zeroclaw", icon: "",  label: "ZeroClaw" }
                        ]
                        delegate: Rectangle {
                            id: provCard
                            required property var modelData
                            Layout.fillWidth: true; height: 68; radius: Config.radiusLarge
                            color: AiService.provider === provCard.modelData.id
                                ? Qt.alpha(Config.accentColor, 0.14) : Config.surface0Color
                            border.width: AiService.provider === provCard.modelData.id ? 1.5 : 1
                            border.color: AiService.provider === provCard.modelData.id
                                ? Config.accentColor : Qt.alpha(Config.surface2Color, 0.4)
                            Behavior on color { ColorAnimation { duration: Config.animDurationShort } }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AiService.selectProvider(provCard.modelData.id)
                            }
                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 5
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: provCard.modelData.icon
                                    font.family: Config.font; font.pixelSize: Config.fontSizeIconSmall + 2
                                    color: AiService.provider === provCard.modelData.id
                                        ? Config.accentColor : Config.subtextColor
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: provCard.modelData.label
                                    font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                                    font.bold: AiService.provider === provCard.modelData.id
                                    color: AiService.provider === provCard.modelData.id
                                        ? Config.accentColor : Config.textColor
                                }
                            }
                        }
                    }
                }
            }

            // ── Model selector ────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                visible: (AiService.provider !== "copilot" || AiService.copilotOAuthToken !== "") && AiService.provider !== "zeroclaw"

                RowLayout { Layout.fillWidth: true
                    Text {
                        text: "MODELO"; font.family: Config.font; font.pixelSize: 10
                        font.bold: true; color: Config.subtextColor; opacity: 0.45
                    }
                    Item { Layout.fillWidth: true }
                    Spinner {
                        running: AiService.isFetchingModels; size: Config.fontSizeSmall
                        color: Config.subtextColor; visible: AiService.isFetchingModels
                    }
                }

                // Error / empty state
                Rectangle {
                    Layout.fillWidth: true; height: 38; radius: Config.radius
                    visible: !AiService.isFetchingModels && AiService.availableModels.length === 0
                    color: AiService.modelsError !== "" ? Qt.alpha(Config.errorColor, 0.1) : Config.surface0Color
                    border.width: 1
                    border.color: AiService.modelsError !== "" ? Qt.alpha(Config.errorColor, 0.35) : "transparent"
                    Text {
                        anchors { fill: parent; margins: 10 }
                        text: AiService.modelsError !== ""
                            ? "⚠  " + AiService.modelsError
                            : "Aun no hay modelos cargados"
                        font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                        color: AiService.modelsError !== "" ? Config.errorColor : Config.subtextColor
                        opacity: 0.8; wrapMode: Text.Wrap
                    }
                }

                OrbitModelPicker {
                    Layout.fillWidth: true
                    visible: AiService.availableModels.length > 0
                    models: AiService.availableModels
                    selectedModel: AiService.model
                    provider: AiService.provider
                    loading: AiService.isFetchingModels
                    title: "Selecciona el modelo"
                    maxHeight: 200
                    onRefreshRequested: AiService.fetchModels()
                    onModelSelected: modelId => AiService.selectModel(modelId)
                }
            }

            // ── System prompt ─────────────────────────────────────────────
            ColumnLayout { Layout.fillWidth: true; spacing: 10
                RowLayout { Layout.fillWidth: true
                    Text {
                        text: "INSTRUCCION BASE"; font.family: Config.font; font.pixelSize: 10
                        font.bold: true; color: Config.subtextColor; opacity: 0.45
                    }
                    Text {
                        text: "opcional"; font.family: Config.font; font.pixelSize: 9
                        color: Config.subtextColor; opacity: 0.35
                        leftPadding: 4
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(72, sysField.implicitHeight + 20)
                    radius: Config.radius; color: Config.surface0Color
                    border.width: sysField.activeFocus ? 1.5 : 1
                    border.color: sysField.activeFocus ? Config.accentColor : Qt.alpha(Config.surface2Color, 0.4)
                    Behavior on border.color { ColorAnimation { duration: Config.animDurationShort } }
                    TextEdit {
                        id: sysField
                        anchors { fill: parent; margins: 12 }
                        text: AiService.systemPrompt
                        onTextChanged: AiService.systemPrompt = text
                        font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                        color: Config.textColor; wrapMode: Text.Wrap
                        Text {
                            anchors.fill: parent; text: "Eres un copiloto util para el shell…"
                            font: sysField.font; color: Config.subtextColor; opacity: 0.3
                            visible: sysField.text === ""
                        }
                    }
                }
            }

            // ── API key ───────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                visible: AiService.provider !== "copilot" && AiService.provider !== "zeroclaw"
                RowLayout { Layout.fillWidth: true
                    Text {
                        text: "CLAVE API"; font.family: Config.font; font.pixelSize: 10
                        font.bold: true; color: Config.subtextColor; opacity: 0.45
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: keyField.echoMode === TextInput.Password ? "Mostrar" : "Ocultar"
                        font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                        color: Config.accentColor; opacity: 0.75
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: keyField.echoMode = keyField.echoMode === TextInput.Password
                                ? TextInput.Normal : TextInput.Password
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 44; radius: Config.radius
                    color: Config.surface0Color
                    border.width: keyField.activeFocus ? 1.5 : 1
                    border.color: keyField.activeFocus ? Config.accentColor : Qt.alpha(Config.surface2Color, 0.4)
                    Behavior on border.color { ColorAnimation { duration: Config.animDurationShort } }
                    TextInput {
                        id: keyField
                        anchors { fill: parent; margins: 14 }
                        text: AiService.apiKey; onTextEdited: AiService.apiKey = text
                        echoMode: TextInput.Password
                        font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                        color: Config.textColor
                        Text {
                            anchors.fill: parent; text: "sk-…  or  AIzaSy…"
                            font: keyField.font; color: Config.subtextColor; opacity: 0.3
                            visible: keyField.text === ""
                        }
                    }
                }
            }

            // ── Copilot OAuth ─────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                visible: AiService.provider === "copilot"

                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: Config.radius
                    visible: AiService.copilotOAuthToken !== "" && !AiService.copilotAuthInProgress
                    color: Qt.alpha(Config.successColor, 0.1)
                    border.width: 1; border.color: Qt.alpha(Config.successColor, 0.35)
                    RowLayout {
                        anchors { fill: parent; margins: 14 }
                            spacing: 10
                        Text { text: "󰄬"; font.family: Config.font
                            font.pixelSize: Config.fontSizeIconSmall; color: Config.successColor }
                        Text {
                            Layout.fillWidth: true; text: "Autorizado con GitHub Copilot"
                            font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                            font.bold: true; color: Config.textColor
                        }
                        Text {
                            text: "Cerrar sesion"
                            font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                            color: Config.errorColor; opacity: soMouse.containsMouse ? 1.0 : 0.7
                            MouseArea {
                                id: soMouse; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: AiService.copilotSignOut()
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 10
                    visible: AiService.copilotAuthInProgress
                    Text {
                        Layout.fillWidth: true
                        text: "Abre el siguiente enlace e introduce el codigo para autorizar:"
                        font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor; wrapMode: Text.Wrap
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 76; radius: Config.radiusLarge
                        color: Config.surface0Color; border.width: 1
                        border.color: Qt.alpha(Config.accentColor, 0.3)
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 5
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: AiService.copilotUserCode
                                font.family: Config.font; font.pixelSize: 28; font.bold: true
                                color: Config.accentColor
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: AiService.copilotVerifyUri
                                font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                                color: Config.subtextColor; opacity: 0.6
                            }
                        }
                    }
                    RowLayout { Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            Layout.fillWidth: true; height: 40; radius: Config.radius
                            color: cp2Mouse.containsMouse ? Config.surface2Color : Config.surface1Color
                            Behavior on color { ColorAnimation { duration: Config.animDurationShort } }
                            MouseArea {
                                id: cp2Mouse; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.runCmd(["bash", "-c",
                                    "printf '%s' " + JSON.stringify(AiService.copilotUserCode) + " | wl-copy"])
                            }
                            Text { anchors.centerIn: parent; text: "󰆏  Copiar codigo"
                                font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                                color: Config.textColor }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 40; radius: Config.radius
                            color: Config.accentColor
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.runCmd(["xdg-open", AiService.copilotVerifyUri])
                            }
                            Text { anchors.centerIn: parent; text: "  Open browser"
                                font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                                font.bold: true; color: Config.textReverseColor }
                        }
                    }
                    RowLayout { Layout.fillWidth: true
                        Spinner { running: true; size: Config.fontSizeSmall; color: Config.subtextColor }
                        Text {
                            Layout.fillWidth: true; text: "Esperando autorizacion…"
                            font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor; opacity: 0.6; leftPadding: 6
                        }
                        Text {
                            text: "Cancelar"; font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                            color: Config.errorColor; opacity: 0.8
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: AiService.copilotCancelAuth()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 46; radius: Config.radius
                    visible: !AiService.copilotAuthInProgress && AiService.copilotOAuthToken === ""
                    color: authMouse.containsMouse ? Config.accentColor : Qt.alpha(Config.accentColor, 0.82)
                    Behavior on color { ColorAnimation { duration: Config.animDurationShort } }
                    MouseArea {
                        id: authMouse; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: AiService.copilotStartAuth()
                    }
                    RowLayout { anchors.centerIn: parent; spacing: 8
                        Text { text: "󰊤"; font.family: Config.font
                            font.pixelSize: Config.fontSizeIconSmall; color: Config.textReverseColor }
                        Text { text: "Entrar con GitHub"
                            font.family: Config.font; font.pixelSize: Config.fontSizeNormal
                            font.bold: true; color: Config.textReverseColor }
                    }
                }
            }

            // ── ZeroClaw config ───────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 12
                visible: AiService.provider === "zeroclaw"

                // Sub-provider
                ColumnLayout { Layout.fillWidth: true; spacing: 8
                    Text {
                        text: "PROVEEDOR DEL AGENTE"; font.family: Config.font; font.pixelSize: 10
                        font.bold: true; color: Config.subtextColor; opacity: 0.45
                    }
                    Flow { Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: [
                                { id: "copilot",    label: "Copilot"    },
                                { id: "openai",     label: "OpenAI"     },
                                { id: "gemini",     label: "Gemini"     },
                                { id: "ollama",     label: "Ollama"     },
                                { id: "openrouter", label: "OpenRouter" }
                            ]
                            delegate: Rectangle {
                                id: zcProv
                                required property var modelData
                                height: 30; width: zcProvLbl.implicitWidth + 20; radius: Config.radius
                                color: AiService.zerowclawSubProvider === zcProv.modelData.id
                                    ? Qt.alpha(Config.accentColor, 0.14) : Config.surface0Color
                                border.width: 1
                                border.color: AiService.zerowclawSubProvider === zcProv.modelData.id
                                    ? Config.accentColor : Qt.alpha(Config.surface2Color, 0.4)
                                Behavior on color { ColorAnimation { duration: Config.animDurationShort } }
                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: AiService.zerowclawSubProvider = zcProv.modelData.id
                                }
                                Text {
                                    id: zcProvLbl; anchors.centerIn: parent
                                    text: zcProv.modelData.label
                                    font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                                    font.bold: AiService.zerowclawSubProvider === zcProv.modelData.id
                                    color: AiService.zerowclawSubProvider === zcProv.modelData.id
                                        ? Config.accentColor : Config.textColor
                                }
                            }
                        }
                    }
                }

                // Autonomy level
                ColumnLayout { Layout.fillWidth: true; spacing: 8
                    Text {
                        text: "NIVEL DE AUTONOMIA"; font.family: Config.font; font.pixelSize: 10
                        font.bold: true; color: Config.subtextColor; opacity: 0.45
                    }
                    RowLayout { Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: [
                                { id: "read_only",  label: "Solo lectura", desc: "Solo archivos" },
                                { id: "supervised", label: "Supervisado",  desc: "Preguntar antes" },
                                { id: "full",       label: "Completo",     desc: "Autonomo" }
                            ]
                            delegate: Rectangle {
                                id: zcAuto
                                required property var modelData
                                Layout.fillWidth: true; height: 52; radius: Config.radius
                                color: AiService.zerowclawAutonomy === zcAuto.modelData.id
                                    ? Qt.alpha(Config.accentColor, 0.14) : Config.surface0Color
                                border.width: 1
                                border.color: AiService.zerowclawAutonomy === zcAuto.modelData.id
                                    ? Config.accentColor : Qt.alpha(Config.surface2Color, 0.4)
                                Behavior on color { ColorAnimation { duration: Config.animDurationShort } }
                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: AiService.zerowclawAutonomy = zcAuto.modelData.id
                                }
                                ColumnLayout { anchors.centerIn: parent; spacing: 3
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: zcAuto.modelData.label
                                        font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                                        font.bold: AiService.zerowclawAutonomy === zcAuto.modelData.id
                                        color: AiService.zerowclawAutonomy === zcAuto.modelData.id
                                            ? Config.accentColor : Config.textColor
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: zcAuto.modelData.desc
                                        font.family: Config.font; font.pixelSize: 9
                                        color: Config.subtextColor; opacity: 0.5
                                    }
                                }
                            }
                        }
                    }
                }

                // Model (free-form)
                ColumnLayout { Layout.fillWidth: true; spacing: 8
                    Text {
                        text: "MODELO"; font.family: Config.font; font.pixelSize: 10
                        font.bold: true; color: Config.subtextColor; opacity: 0.45
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 44; radius: Config.radius
                        color: Config.surface0Color
                        border.width: zcModelField.activeFocus ? 1.5 : 1
                        border.color: zcModelField.activeFocus ? Config.accentColor : Qt.alpha(Config.surface2Color, 0.4)
                        Behavior on border.color { ColorAnimation { duration: Config.animDurationShort } }
                        TextInput {
                            id: zcModelField
                            anchors { fill: parent; margins: 14 }
                            text: AiService.model; onTextEdited: AiService.selectModel(text)
                            font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                            color: Config.textColor
                            Text {
                                anchors.fill: parent; text: "ej. gpt-4o, claude-3.7-sonnet…"
                                font: zcModelField.font; color: Config.subtextColor; opacity: 0.3
                                visible: zcModelField.text === ""
                            }
                        }
                    }
                }

                // Info box
            Rectangle {
                Layout.fillWidth: true; radius: Config.radius
                implicitHeight: zcInfoTxt.implicitHeight + 20
                color: Qt.alpha(Config.accentColor, 0.06)
                border.width: 1; border.color: Qt.alpha(Config.accentColor, 0.2)
                    Text {
                        id: zcInfoTxt
                        anchors { fill: parent; margins: 12 }
                        text: "ZeroClaw gestiona su propia autenticacion.\nEjecuta: zeroclaw auth login --provider <provider>"
                        font.family: Config.font; font.pixelSize: Config.fontSizeSmall - 1
                        color: Config.subtextColor; opacity: 0.7; wrapMode: Text.Wrap
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 10

                Text {
                    text: "HERRAMIENTAS Y SEGURIDAD"; font.family: Config.font; font.pixelSize: 10
                    font.bold: true; color: Config.subtextColor; opacity: 0.45
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: safetyCol.implicitHeight + 20
                    radius: Config.radius
                    color: Config.surface0Color
                    border.width: 1
                    border.color: Qt.alpha(Config.surface2Color, 0.4)

                    ColumnLayout {
                        id: safetyCol
                        anchors { fill: parent; margins: 10 }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "Herramientas del agente"
                                font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                                color: Config.textColor
                            }
                            QsSwitch {
                                checked: AiService.agentEnabled
                                onToggled: AiService.agentEnabled = checked
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "Busqueda web"
                                font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                                color: Config.textColor
                            }
                            QsSwitch {
                                checked: AiService.webSearchEnabled
                                onToggled: AiService.webSearchEnabled = checked
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "Descargas e instalaciones"
                                font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                                color: Config.textColor
                            }
                            QsSwitch {
                                checked: AiService.dangerousToolsEnabled
                                onToggled: AiService.dangerousToolsEnabled = checked
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Las descargas y las instalaciones estan desactivadas por defecto y siempre requieren aprobacion explicita."
                            font.family: Config.font; font.pixelSize: Config.fontSizeSmall - 1
                            color: Config.subtextColor
                            opacity: 0.65
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            // ── Save / Start button ───────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; Layout.bottomMargin: 6; height: 46; radius: Config.radius
                visible: AiService.provider !== "copilot" || AiService.copilotOAuthToken !== "" || AiService.provider === "zeroclaw"
                color: stMouse.containsMouse ? Config.accentColor : Qt.alpha(Config.accentColor, 0.82)
                Behavior on color { ColorAnimation { duration: Config.animDurationShort } }
                MouseArea {
                    id: stMouse; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AiService.saveConfig();
                        Qt.callLater(() => inputField.forceActiveFocus());
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: (AiService.provider === "copilot" || AiService.provider === "zeroclaw")
                          ? "Abrir Orbit  →" : "Guardar y abrir Orbit  →"
                    font.family: Config.font; font.pixelSize: Config.fontSizeNormal
                    font.bold: true; color: Config.textReverseColor
                }
            }
        }
    }

    // ╔══════════════════════════════════════════════════════════════════════╗
    // ║  CHAT PANEL                                                          ║
    // ╚══════════════════════════════════════════════════════════════════════╝
    ColumnLayout {
        id: chatCol
        anchors.fill: parent
        spacing: 0
        visible: !root.showSettings

        // ─ Header ───────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Layout.bottomMargin: 8; Layout.topMargin: 4

            Text { text: "󱜚"; font.family: Config.font
                font.pixelSize: Config.fontSizeIcon + 2; color: Config.accentColor }

            ColumnLayout { spacing: 2
                Text {
                    text: "Orbit"
                    font.family: Config.font; font.pixelSize: Config.fontSizeLarge
                    font.bold: true; color: Config.textColor
                }
                // Clickable model line → opens inline picker
                Rectangle {
                    height: 18
                    Layout.preferredWidth: mdlPill.implicitWidth + 14
                    Layout.maximumWidth: mdlPill.implicitWidth + 14
                    radius: 9; clip: true
                    color: mdlPillMouse.containsMouse
                        ? Qt.alpha(Config.accentColor, 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: Config.animDurationShort } }
                    MouseArea {
                        id: mdlPillMouse; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showModelPicker = !root.showModelPicker
                    }
                    Row {
                        id: mdlPill
                        anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Text {
                            text: {
                                const p = AiService.provider;
                                if (p === "copilot")  return "GitHub Copilot";
                                if (p === "zeroclaw") return "ZeroClaw";
                                return p.charAt(0).toUpperCase() + p.slice(1);
                            }
                            font.family: Config.font; font.pixelSize: 11
                            color: Config.subtextColor; opacity: 0.6
                        }
                        Text { text: "·"; font.family: Config.font; font.pixelSize: 11
                            color: Config.subtextColor; opacity: 0.35 }
                        Text {
                            text: AiService.model
                            font.family: Config.font; font.pixelSize: 11
                            color: Config.subtextColor; opacity: 0.6
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Stop button (only while loading)
            Rectangle {
                visible: AiService.isLoading
                width: 28; height: 28; radius: Config.radius
                color: stopHov.containsMouse
                    ? Qt.alpha(Config.errorColor, 0.22) : Qt.alpha(Config.errorColor, 0.10)
                border.width: 1; border.color: Qt.alpha(Config.errorColor, 0.35)
                Behavior on color { ColorAnimation { duration: Config.animDurationShort } }
                Text { anchors.centerIn: parent; text: "󰚌"
                    font.family: Config.font; font.pixelSize: 11; color: Config.errorColor }
                MouseArea {
                    id: stopHov; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: AiService.stopGeneration()
                }
            }

            ActionButton {
                icon: "󰑐"; baseColor: "transparent"
                hoverColor: Config.surface1Color; textColor: Config.subtextColor
                visible: !AiService.isLoading && AiService.lastUserPrompt !== ""
                onClicked: AiService.retryLastMessage()
            }
            ActionButton {
                icon: "󰘖"; baseColor: "transparent"
                hoverColor: Config.surface1Color; textColor: Config.subtextColor
                visible: AiService.messages.length > 14 && !AiService.isLoading
                onClicked: AiService.compactConversation()
            }
            ActionButton {
                icon: "󰃢"; baseColor: "transparent"
                hoverColor: Config.surface1Color; textColor: Config.subtextColor
                visible: AiService.messages.length > 0 && !AiService.isLoading
                onClicked: AiService.clearHistory()
            }
            ActionButton {
                icon: "󰒓"; baseColor: "transparent"
                hoverColor: Config.surface1Color; textColor: Config.subtextColor
                onClicked: {
                    AiService.openSettings();
                    root.showModelPicker = false;
                }
            }
        }

        OrbitModeTabs {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            modes: AiService.orbitModes
            currentMode: AiService.orbitMode
            onModeSelected: mode => AiService.setOrbitMode(mode)
        }

        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            spacing: 6

            ActionButton {
                text: AiService.webSearchEnabled ? "Web activa" : "Web inactiva"
                size: 24
                baseColor: AiService.webSearchEnabled
                    ? Qt.alpha(Config.accentColor, 0.14)
                    : Config.surface0Color
                hoverColor: AiService.webSearchEnabled
                    ? Qt.alpha(Config.accentColor, 0.22)
                    : Config.surface1Color
                textColor: AiService.webSearchEnabled ? Config.accentColor : Config.subtextColor
                hoverTextColor: AiService.webSearchEnabled ? Config.accentColor : Config.textColor
                onClicked: AiService.toggleWebSearch()
            }

            Rectangle {
                height: 24
                width: tokenChipRow.implicitWidth + 18
                radius: 12
                color: Config.surface0Color
                border.width: 1
                border.color: Qt.alpha(Config.surface2Color, 0.28)

                Row {
                    id: tokenChipRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "Contexto"
                        font.family: Config.font
                        font.pixelSize: 10
                        color: Config.subtextColor
                    }

                    Text {
                        text: "~" + AiService.approxContextTokens + " tok"
                        font.family: Config.font
                        font.pixelSize: 10
                        font.bold: true
                        color: Config.textColor
                    }
                }
            }

            Rectangle {
                visible: AiService.pendingAttachments.length > 0
                height: 24
                width: attachChipRow.implicitWidth + 18
                radius: 12
                color: Qt.alpha(Config.warningColor, 0.10)
                border.width: 1
                border.color: Qt.alpha(Config.warningColor, 0.22)

                Row {
                    id: attachChipRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "Adjuntos"
                        font.family: Config.font
                        font.pixelSize: 10
                        color: Config.warningColor
                    }

                    Text {
                        text: AiService.pendingAttachments.length
                        font.family: Config.font
                        font.pixelSize: 10
                        font.bold: true
                        color: Config.textColor
                    }
                }
            }

        }

        // ─ Inline model picker ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; Layout.bottomMargin: 8
            visible: root.showModelPicker && AiService.availableModels.length > 0
            implicitHeight: inlinePicker.implicitHeight
            radius: Config.radius
            color: "transparent"
            border.width: 0

            OrbitModelPicker {
                id: inlinePicker
                anchors.fill: parent
                models: AiService.availableModels
                selectedModel: AiService.model
                provider: AiService.provider
                loading: AiService.isFetchingModels
                title: "Seleccionar modelo"
                maxHeight: 230
                compact: true
                onRefreshRequested: AiService.fetchModels()
                onModelSelected: modelId => {
                    AiService.selectModel(modelId);
                    root.showModelPicker = false;
                }
            }
        }

        // Close picker when clicking elsewhere
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true; z: 1
            visible: root.showModelPicker
            MouseArea {
                anchors.fill: parent
                onClicked: root.showModelPicker = false
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Config.surface1Color; opacity: 0.5 }

        // ─ Message list ──────────────────────────────────────────────────────
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
                if (root.followLatest || AiService.isLoading)
                    Qt.callLater(() => root.scrollToLatest());
            }

            Item {
                anchors.fill: parent
                visible: AiService.messages.length === 0 && !AiService.isLoading

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 20
                    width: parent.width - 34

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

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
                            text: "Orbit esta listo"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeLarge + 3
                            font.bold: true
                            color: Config.textColor
                            opacity: 0.72
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Usa acciones, contexto o comandos para empezar"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                            opacity: 0.42
                        }
                    }

                    OrbitQuickActions {
                        Layout.fillWidth: true
                        actions: AiService.orbitQuickActions
                        onActionRequested: actionId => {
                            AiService.triggerOrbitAction(actionId);
                            inputField.text = AiService.draftMessage;
                            inputField.cursorPosition = inputField.length;
                            inputField.forceActiveFocus();
                        }
                    }
                }
            }

            delegate: Item {
                id: msgItem
                required property var modelData
                required property int index
                readonly property bool isUser: modelData.role === "user"
                readonly property bool isCompactedNote: modelData.compacted === true
                readonly property string messageType: modelData.messageType || (isUser ? "user" : "assistant_text")
                readonly property bool isActionResult: messageType === "action_result"
                readonly property bool isSystemNotice: messageType === "system_notice"
                readonly property string assistantText: String(modelData.content || "")
                readonly property bool hasAssistantContent: assistantText.replace(/\s+/g, "") !== ""
                readonly property bool shouldShowAssistantCard: hasAssistantContent
                    || (!!(modelData.webContext && modelData.webContext.used) && !modelData.streaming)
                width: messageList.width
                height: contentColumn.implicitHeight + 16

                HoverHandler { id: msgHover }

                Column {
                    id: contentColumn
                    width: parent.width
                    spacing: 6
                    anchors.top: parent.top
                    anchors.topMargin: 8

                    Rectangle {
                        visible: msgItem.isCompactedNote
                        width: parent.width
                        radius: Config.radius
                        color: Qt.alpha(Config.warningColor, 0.08)
                        border.width: 1
                        border.color: Qt.alpha(Config.warningColor, 0.18)
                        implicitHeight: compactedText.implicitHeight + 18

                        Text {
                            id: compactedText
                            anchors.fill: parent
                            anchors.margins: 10
                            text: msgItem.modelData.content
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                            wrapMode: Text.Wrap
                        }
                    }

                    Item {
                        visible: msgItem.isUser
                        width: parent.width
                        height: userColumn.implicitHeight

                        Column {
                            id: userColumn
                            anchors.right: parent.right
                            spacing: 4
                            width: userBubble.width

                            Rectangle {
                                id: userBubble
                                width: Math.min(msgItem.width * 0.84, Math.max(140, userTxt.implicitWidth + 28))
                                implicitHeight: userTxt.implicitHeight + 20
                                radius: Config.radiusLarge
                                color: Config.accentColor

                                Text {
                                    id: userTxt
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    anchors.topMargin: 10
                                    anchors.bottomMargin: 10
                                    text: msgItem.modelData.content
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    color: Config.textReverseColor
                                    wrapMode: Text.Wrap
                                    lineHeight: 1.5
                                }
                            }

                            Flow {
                                width: userBubble.width
                                spacing: 6
                                visible: (msgItem.modelData.attachments || []).length > 0

                                Repeater {
                                    model: msgItem.modelData.attachments || []
                                    delegate: Rectangle {
                                        required property var modelData
                                        height: 24
                                        width: userAttachRow.implicitWidth + 16
                                        radius: 12
                                        color: Qt.alpha(Config.textReverseColor, 0.12)
                                        border.width: 1
                                        border.color: Qt.alpha(Config.textReverseColor, 0.18)

                                        Row {
                                            id: userAttachRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                text: modelData.kind === "directory" ? "󰉋" : "󰈔"
                                                font.family: Config.font
                                                font.pixelSize: 10
                                                color: Config.textColor
                                            }

                                            Text {
                                                text: modelData.displayName
                                                font.family: Config.font
                                                font.pixelSize: 10
                                                color: Config.textColor
                                            }
                                        }
                                    }
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
                                width: userBubble.width
                            }
                        }

                        Row {
                            anchors.right: userColumn.left
                            anchors.rightMargin: 6
                            anchors.top: userColumn.top
                            spacing: 4
                            opacity: msgHover.hovered && !AiService.isLoading ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Rectangle {
                                width: editBtnRow.implicitWidth + 14
                                height: 24
                                radius: 12
                                color: editBtnH.containsMouse ? Config.surface1Color : Config.surface0Color
                                border.width: 1
                                border.color: Qt.alpha(Config.surface2Color, 0.4)
                                Behavior on color { ColorAnimation { duration: Config.animDurationShort } }

                                Row {
                                    id: editBtnRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "󰏫"
                                        font.family: Config.font
                                        font.pixelSize: 10
                                        color: Config.subtextColor
                                    }

                                    Text {
                                        text: "Editar"
                                        font.family: Config.font
                                        font.pixelSize: 10
                                        color: Config.subtextColor
                                    }
                                }

                                MouseArea {
                                    id: editBtnH
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const txt = msgItem.modelData.content;
                                        AiService.truncateFrom(msgItem.index);
                                        inputField.text = txt;
                                        AiService.setDraftMessage(txt);
                                        inputField.cursorPosition = inputField.length;
                                        inputField.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        visible: !msgItem.isUser && !msgItem.isCompactedNote && msgItem.shouldShowAssistantCard
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            width: 28
                            height: 28
                            radius: 14
                            color: msgItem.isActionResult
                                ? Qt.alpha(Config.successColor, 0.12)
                                : (msgItem.isSystemNotice
                                    ? Qt.alpha(Config.warningColor, 0.12)
                                    : Qt.alpha(Config.accentColor, 0.12))

                            Text {
                                anchors.centerIn: parent
                                text: msgItem.modelData.icon
                                    || (msgItem.isActionResult ? "󰐕" : (msgItem.isSystemNotice ? "󰋼" : "󱜚"))
                                font.family: Config.font
                                font.pixelSize: 13
                                color: msgItem.isActionResult
                                    ? Config.successColor
                                    : (msgItem.isSystemNotice ? Config.warningColor : Config.accentColor)
                            }
                        }

                        Column {
                            id: assistantContent
                            Layout.fillWidth: true
                            spacing: 6

                            Row {
                                spacing: 8

                                Text {
                                    text: msgItem.modelData.title
                                        || (msgItem.isActionResult
                                            ? "Accion local"
                                            : (msgItem.isSystemNotice
                                                ? "Orbit"
                                                : AiService.providerLabel(msgItem.modelData.provider || AiService.provider)))
                                    font.family: Config.font
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: msgItem.isActionResult
                                        ? Config.successColor
                                        : (msgItem.isSystemNotice ? Config.warningColor : Config.accentColor)
                                    opacity: 0.85
                                }

                                Text {
                                    text: msgItem.isActionResult || msgItem.isSystemNotice
                                        ? AiService.orbitModeLabel(msgItem.modelData.mode || AiService.orbitMode)
                                        : root.modelLabelForMessage(msgItem.modelData)
                                    font.family: Config.font
                                    font.pixelSize: 10
                                    color: Config.subtextColor
                                    opacity: 0.55
                                }

                                Text {
                                    text: msgItem.modelData.time || ""
                                    font.family: Config.font
                                    font.pixelSize: 10
                                    color: Config.subtextColor
                                    opacity: 0.35
                                }

                                Rectangle {
                                    visible: !!(msgItem.modelData.webContext && msgItem.modelData.webContext.used)
                                    height: 18
                                    width: webUsedRow.implicitWidth + 10
                                    radius: 9
                                    color: Qt.alpha(Config.accentColor, 0.12)
                                    border.width: 1
                                    border.color: Qt.alpha(Config.accentColor, 0.22)

                                    Row {
                                        id: webUsedRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: "󰖟"
                                            font.family: Config.font
                                            font.pixelSize: 9
                                            color: Config.accentColor
                                        }

                                        Text {
                                            text: "Web verificada"
                                            font.family: Config.font
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: Config.accentColor
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: assistantContent.width
                                radius: Config.radiusLarge
                                color: msgItem.isActionResult
                                    ? Qt.alpha(Config.successColor, 0.08)
                                    : (msgItem.isSystemNotice
                                        ? Qt.alpha(Config.warningColor, 0.08)
                                        : Qt.alpha(Config.surface0Color, 0.96))
                                border.width: 1
                                border.color: msgItem.isActionResult
                                    ? Qt.alpha(Config.successColor, 0.26)
                                    : (msgItem.isSystemNotice
                                        ? Qt.alpha(Config.warningColor, 0.26)
                                        : Qt.alpha(Config.surface2Color, 0.32))
                                implicitHeight: assistantCardColumn.implicitHeight + 20

                                Column {
                                    id: assistantCardColumn
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    OrbitMessageParts {
                                        width: assistantCardColumn.width
                                        content: msgItem.modelData.content || ""
                                        webContext: msgItem.modelData.webContext || null
                                        parts: AiService.messagePartsFor(msgItem.modelData)
                                        onOpenLink: url => root.runCmd(["xdg-open", url])
                                        onCopyText: text => root.runCmd(["bash", "-c",
                                            "printf '%s' " + JSON.stringify(text) + " | wl-copy"])
                                    }
                                }
                            }

                            Row {
                                spacing: 4
                                height: 28
                                opacity: msgHover.hovered ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Rectangle {
                                    width: copyFullRow.implicitWidth + 14
                                    height: 24
                                    radius: 12
                                    color: cpBtnH.containsMouse ? Config.surface1Color : Config.surface0Color
                                    border.width: 1
                                    border.color: Qt.alpha(Config.surface2Color, 0.4)
                                    Behavior on color { ColorAnimation { duration: Config.animDurationShort } }

                                    Row {
                                        id: copyFullRow
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
                                        id: cpBtnH
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.runCmd(["bash", "-c",
                                            "printf '%s' " + JSON.stringify(msgItem.modelData.content) + " | wl-copy"])
                                    }
                                }

                                Rectangle {
                                    width: quoteRow.implicitWidth + 14
                                    height: 24
                                    radius: 12
                                    color: quoteBtnH.containsMouse ? Config.surface1Color : Config.surface0Color
                                    border.width: 1
                                    border.color: Qt.alpha(Config.surface2Color, 0.4)
                                    Behavior on color { ColorAnimation { duration: Config.animDurationShort } }

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
                                        id: quoteBtnH
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
            visible: !root.followLatest && AiService.messages.length > 2
            height: 30
            width: jumpLatestRow.implicitWidth + 20
            radius: 15
            color: Qt.alpha(Config.surface0Color, 0.96)
            border.width: 1
            border.color: Qt.alpha(Config.accentColor, 0.24)

            Row {
                id: jumpLatestRow
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

        // ─ Animated typing indicator ─────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            height: visible ? 52 : 0
            visible: AiService.isLoading && !AiService.stoppedByUser

            Row {
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                spacing: 10

                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: Qt.alpha(Config.accentColor, 0.12)
                    Text { anchors.centerIn: parent; text: "󱜚"
                        font.family: Config.font; font.pixelSize: 13; color: Config.accentColor }
                }

                Rectangle {
                    width: 60; height: 34; radius: Config.radius; color: Config.surface0Color
                    Row {
                        anchors.centerIn: parent; spacing: 6
                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                id: dot
                                required property int index
                                width: 7; height: 7; radius: 3.5
                                color: Config.accentColor; opacity: 0.7
                                SequentialAnimation on y {
                                    loops: Animation.Infinite
                                    running: AiService.isLoading
                                    PauseAnimation   { duration: dot.index * 160 }
                                    NumberAnimation  { to: -5; duration: 240; easing.type: Easing.OutCubic }
                                    NumberAnimation  { to:  0; duration: 240; easing.type: Easing.InCubic }
                                    PauseAnimation   { duration: (2 - dot.index) * 160 }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─ Error banner ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; Layout.topMargin: 6
            implicitHeight: errTxt.implicitHeight + 18; radius: Config.radius
            color: Qt.alpha(Config.errorColor, 0.10)
            border.width: 1; border.color: Qt.alpha(Config.errorColor, 0.35)
            visible: AiService.lastError !== ""
            RowLayout {
                anchors { fill: parent; margins: 10 }
                            spacing: 8
                Text { text: "󰀪"; font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall; color: Config.errorColor }
                Text {
                    id: errTxt; Layout.fillWidth: true; text: AiService.lastError
                    font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                    color: Config.errorColor; wrapMode: Text.Wrap
                }
                Text {
                    visible: !AiService.isLoading && AiService.lastUserPrompt !== ""
                    text: "Reintentar"
                    font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                    color: Config.accentColor
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AiService.retryLastMessage()
                    }
                }
                Text {
                    text: "✕"; font.family: Config.font; font.pixelSize: Config.fontSizeSmall
                    color: Config.errorColor; opacity: 0.65
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: AiService.lastError = ""
                    }
                }
            }
        }

        // ─ Input area ────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true; Layout.topMargin: 10; spacing: 4

            Rectangle {
                Layout.fillWidth: true
                visible: AiService.pendingAttachments.length > 0
                radius: Config.radius
                color: Qt.alpha(Config.accentColor, 0.06)
                border.width: 1
                border.color: Qt.alpha(Config.accentColor, 0.22)
                implicitHeight: attachFlow.implicitHeight + 18

                Flow {
                    id: attachFlow
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 6

                    Repeater {
                        model: AiService.pendingAttachments
                        delegate: Rectangle {
                            id: attachedChip
                            required property var modelData
                            required property int index
                            height: 28
                            width: chipRow.implicitWidth + 18
                            radius: 14
                            color: Config.surface0Color
                            border.width: 1
                            border.color: Qt.alpha(Config.surface2Color, 0.35)

                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: attachedChip.modelData.kind === "directory" ? "󰉋" : "󰈔"
                                    font.family: Config.font
                                    font.pixelSize: 11
                                    color: Config.accentColor
                                }

                                Text {
                                    text: attachedChip.modelData.displayName
                                    font.family: Config.font
                                    font.pixelSize: 10
                                    color: Config.textColor
                                }

                                Text {
                                    text: "✕"
                                    font.family: Config.font
                                    font.pixelSize: 10
                                    color: Config.subtextColor
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: AiService.removeAttachment(attachedChip.index)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.showAttachPanel
                radius: Config.radius
                color: Config.surface0Color
                border.width: 1
                border.color: Qt.alpha(Config.surface2Color, 0.35)
                implicitHeight: attachCol.implicitHeight + 20

                ColumnLayout {
                    id: attachCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Adjuntar archivo o carpeta local"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: true
                            color: Config.textColor
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "✕"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showAttachPanel = false
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: Config.radius
                        color: Config.surface1Color
                        border.width: attachPathField.activeFocus ? 1.5 : 1
                        border.color: attachPathField.activeFocus
                            ? Config.accentColor
                            : Qt.alpha(Config.surface2Color, 0.3)

                        TextInput {
                            id: attachPathField
                            anchors.fill: parent
                            anchors.margins: 12
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.textColor

                            Text {
                                anchors.fill: parent
                                text: "~/project/file.ts or /abs/path"
                                font: attachPathField.font
                                color: Config.subtextColor
                                opacity: 0.35
                                visible: attachPathField.text === ""
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return) {
                                    event.accepted = true;
                                    AiService.requestAttachment(attachPathField.text);
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 120
                            height: 34
                            radius: Config.radius
                            color: addAttachMouse.containsMouse ? Config.accentColor : Qt.alpha(Config.accentColor, 0.82)
                            MouseArea {
                                id: addAttachMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AiService.requestAttachment(attachPathField.text)
                            }
                            Text {
                                anchors.centerIn: parent
                                text: AiService.isInspectingAttachment ? "Inspeccionando..." : "Agregar contexto"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                font.bold: true
                                color: Config.textReverseColor
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 88
                            height: 34
                            radius: Config.radius
                            color: clearAttachMouse.containsMouse ? Config.surface2Color : Config.surface1Color
                            visible: AiService.pendingAttachments.length > 0
                            MouseArea {
                                id: clearAttachMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AiService.clearAttachments()
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "Limpiar"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.textColor
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: AiService.attachmentsError !== ""
                        text: AiService.attachmentsError
                        font.family: Config.font
                        font.pixelSize: 10
                        color: Config.errorColor
                        wrapMode: Text.Wrap
                    }

                    Repeater {
                        model: AiService.pendingAttachments
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            visible: root.showAttachPanel
                            radius: Config.radius
                            color: Config.blueDarkColor
                            border.width: 1
                            border.color: Qt.alpha(Config.surface2Color, 0.3)
                            implicitHeight: previewTxt.implicitHeight + 16

                            Text {
                                id: previewTxt
                                anchors.fill: parent
                                anchors.margins: 8
                                text: modelData.preview
                                font.family: "monospace"
                                font.pixelSize: 9
                                color: Config.textColor
                                wrapMode: Text.Wrap
                                maximumLineCount: 8
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: composerColumn.implicitHeight + 18
                radius: Config.radiusLarge; color: Qt.alpha(Config.surface0Color, 0.96)
                border.width: inputField.activeFocus ? 1.5 : 1
                border.color: inputField.activeFocus
                    ? Config.accentColor : Qt.alpha(Config.surface2Color, 0.4)
                Behavior on border.color { ColorAnimation { duration: Config.animDurationShort } }

                ColumnLayout {
                    id: composerColumn
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 36
                            height: 36
                            radius: 18
                            color: attachBtn.containsMouse || root.showAttachPanel
                                ? Config.surface1Color : Qt.alpha(Config.surface1Color, 0.18)
                            border.width: 1
                            border.color: root.showAttachPanel
                                ? Qt.alpha(Config.accentColor, 0.26)
                                : Qt.alpha(Config.surface2Color, 0.3)

                            Text {
                                anchors.centerIn: parent
                                text: "󰈔"
                                font.family: Config.font
                                font.pixelSize: 13
                                color: root.showAttachPanel ? Config.accentColor : Config.subtextColor
                            }

                            MouseArea {
                                id: attachBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.showAttachPanel = !root.showAttachPanel;
                                    if (root.showAttachPanel)
                                        attachPathField.forceActiveFocus();
                                    else
                                        inputField.forceActiveFocus();
                                }
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

                                Keys.onPressed: (event) => {
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
                                opacity: 0.46
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
                                ? (sndH.containsMouse ? Qt.alpha(Config.errorColor, 0.28) : Qt.alpha(Config.errorColor, 0.14))
                                : ((inputField.text.trim() !== "" || AiService.pendingAttachments.length > 0)
                                    ? (sndH.containsMouse ? Config.accentColor : Qt.alpha(Config.accentColor, 0.85))
                                    : Qt.alpha(Config.accentColor, 0.22))
                            Behavior on color { ColorAnimation { duration: Config.animDurationShort } }

                            Text {
                                anchors.centerIn: parent
                                text: AiService.isLoading ? "󰚌" : "󰒊"
                                font.family: Config.font
                                font.pixelSize: 13
                                color: AiService.isLoading
                                    ? Config.errorColor
                                    : ((inputField.text.trim() !== "" || AiService.pendingAttachments.length > 0)
                                        ? Config.textReverseColor : Config.subtextColor)
                            }

                            MouseArea {
                                id: sndH
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

                        Rectangle {
                            height: 22
                            width: webComposerRow.implicitWidth + 14
                            radius: 11
                            color: webComposerMouse.containsMouse
                                ? (AiService.webSearchEnabled
                                    ? Qt.alpha(Config.accentColor, 0.14)
                                    : Config.surface1Color)
                                : "transparent"

                            Row {
                                id: webComposerRow
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: AiService.webSearchEnabled ? "Busqueda web activa" : "Busqueda web inactiva"
                                    font.family: Config.font
                                    font.pixelSize: 10
                                    color: AiService.webSearchEnabled ? Config.accentColor : Config.subtextColor
                                    opacity: 0.9
                                }
                            }

                            MouseArea {
                                id: webComposerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AiService.toggleWebSearch()
                            }
                        }

                        Text {
                            visible: AiService.pendingAttachments.length > 0
                            text: "· " + AiService.pendingAttachments.length + " contexto"
                            font.family: Config.font
                            font.pixelSize: 10
                            color: Config.warningColor
                            opacity: 0.85
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: inputField.text.trim() !== ""
                            text: "Limpiar borrador"
                            font.family: Config.font
                            font.pixelSize: 10
                            color: Config.subtextColor
                            opacity: clearDraftMouse.containsMouse ? 0.9 : 0.65

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
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "~" + AiService.approxContextTokens + " tokens en el contexto local  ·  "
                    + (AiService.webSearchEnabled ? "Web activa y obligatoria para consultas en tiempo real  ·  " : "")
                    + "/launcher /clipboard /settings /power /resumir  ·  "
                    + "Enter envia  ·  Shift+Enter nueva linea  ·  El borrador se guarda automaticamente"
                font.family: Config.font; font.pixelSize: 10
                color: Config.subtextColor; opacity: 0.25
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // ── Helper process (wl-copy / xdg-open) ──────────────────────────────────
    Process { id: openProc; running: false }
}
