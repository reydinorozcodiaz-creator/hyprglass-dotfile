pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "../../modules/tools/orbit/OrbitMessageParts.js" as OrbitMessageParts
import "./AiSessionUtils.js" as AiSessionUtils

Singleton {
    id: root

    readonly property string bridgeScriptPath: Qt.resolvedUrl("../../scripts/ai/ai_chat.py").toString().replace("file://", "")

    property string activeBackend: StateService.get("ai.activeEngine", "openfang")
    readonly property bool isGoose: activeBackend === "goose"
    property string gooseSessionId: StateService.get("ai.gooseSessionId", "orbit_1")

    property string openfangBaseUrl: StateService.get("ai.openfangBaseUrl", Quickshell.env("QS_OPENFANG_URL") || "http://127.0.0.1:4200")
    property string openfangApiKey: SecretsService.get("ai.openfangApiKey", Quickshell.env("QS_OPENFANG_API_KEY") || "")
    property string openfangAgentId: StateService.get("ai.openfangAgentId", "")
    property string openfangAgentName: StateService.get("ai.openfangAgentName", "")

    property bool windowVisible: false
    property bool settingsOpen: false
    readonly property bool storesReady: !SecretsService.isLoading && !AiHistoryService.isLoading

    readonly property bool isLoading: chatProc.running
    readonly property bool isRefreshingBackend: statusProc.running

    property string connectionState: "idle"
    property string connectionError: ""
    property string backendVersion: ""
    property string backendStatus: ""
    property var availableAgents: []
    property var activeAgent: null

    readonly property bool needsSetup: isGoose ? false : (openfangBaseUrl.trim() === "" || !activeAgent || activeAgent.ready !== true)
    readonly property bool showSettings: settingsOpen || needsSetup
    readonly property string activeAgentDisplayName: {
        if (isGoose) return "Goose";
        if (!activeAgent) return "Sin agente";
        if (activeAgent.name && activeAgent.name !== "unnamed") return activeAgent.name;
        if (activeAgent.id && activeAgent.id !== "unnamed") return activeAgent.id;
        return "OpenFang";
    }
    readonly property string activeAgentModelLabel: {
        if (isGoose) return "Local Native";
        if (!activeAgent)
            return "";

        const parts = [];
        if (activeAgent.model)
            parts.push(activeAgent.model);
        if (activeAgent.provider)
            parts.push(activeAgent.provider);
        return parts.join(" · ");
    }
    readonly property string backendStatusLabel: {
        if (isGoose) return "Goose CLI (Activo)";
        if (connectionState === "connected") {
            let text = "OpenFang";
            if (backendVersion !== "")
                text += " " + backendVersion;
            return text;
        }
        if (connectionError !== "")
            return connectionError;
        if (isRefreshingBackend)
            return "Conectando con OpenFang...";
        return "OpenFang no disponible";
    }

    onActiveBackendChanged: {
        if (storesReady) {
            clearHistory(true);
            refreshBackendState(true);
        }
    }

    property bool stoppedByUser: false
    property string lastError: ""
    property string lastUserPrompt: AiHistoryService.get("lastUserPrompt", "")
    property string draftMessage: AiHistoryService.get("draftMessage", "")
    property string historyAgentId: AiHistoryService.get("activeAgentId", "")

    property var messages: AiHistoryService.get("messages", [])
    property string currentAssistantContent: ""
    property int approxContextTokens: 0

    property string _pendingStatusPayload: ""
    property string _pendingPayload: ""
    property string _pendingStopPayload: ""
    property string _pendingResetPayload: ""
    property string _chatStderr: ""
    property string _statusStderr: ""
    property string _stopStderr: ""
    property string _resetStderr: ""
    property bool _chatFinished: false
    property bool _messagesDirty: false
    property bool _draftDirty: false
    property var _messagePartsCache: ({})
    property string _lastSendSignature: ""
    property double _lastSendTimestamp: 0

    function refreshBackendState(force) {
        force = force === undefined ? false : force;
        if (!storesReady || isRefreshingBackend)
            return;

        if (isGoose) {
            connectionState = "connected";
            connectionError = "";
            availableAgents = [{
                id: "goose",
                name: "Goose Native",
                ready: true,
                state: "running"
            }];
            activeAgent = availableAgents[0];
            return;
        }

        if (!force && connectionState === "connected" && availableAgents.length > 0)
            return;

        if (openfangBaseUrl.trim() === "") {
            connectionState = "error";
            connectionError = "Configura la URL de OpenFang para continuar.";
            availableAgents = [];
            activeAgent = null;
            return;
        }

        connectionError = "";
        _pendingStatusPayload = JSON.stringify({
            engine: activeBackend,
            command: "status",
            baseUrl: openfangBaseUrl,
            apiKey: openfangApiKey,
            agentId: openfangAgentId,
            agentName: openfangAgentName,
        });
        statusProc.running = true;
    }

    function openWindow() {
        windowVisible = true;
        refreshBackendState(true);
    }

    function closeWindow() {
        windowVisible = false;
        closeSettings();
    }

    function toggleWindow() {
        if (windowVisible)
            closeWindow();
        else
            openWindow();
    }

    function openSettings() {
        settingsOpen = true;
        windowVisible = true;
        refreshBackendState(true);
    }

    function closeSettings() {
        settingsOpen = false;
    }

    function saveConfig() {
        StateService.set("ai.activeEngine", activeBackend);
        StateService.set("ai.openfangBaseUrl", openfangBaseUrl);
        StateService.set("ai.openfangAgentId", openfangAgentId);
        StateService.set("ai.openfangAgentName", openfangAgentName);
        SecretsService.set("ai.openfangApiKey", openfangApiKey);
        closeSettings();
        refreshBackendState(true);
    }

    function assistantLabel(message) {
        return AiSessionUtils.assistantLabel(message, activeAgentDisplayName);
    }

    function quoteText(text) {
        const cleaned = String(text || "").trim();
        if (cleaned === "")
            return "";
        return cleaned.split("\n").map(line => line === "" ? ">" : "> " + line).join("\n");
    }

    function orbitPlaceholder() {
        if (isGoose)
            return "Pide a Goose que haga algo en tu entorno...";
        if (!activeAgent || activeAgent.ready !== true)
            return "Configura un agente de OpenFang en los ajustes...";
        return "Escribe tu mensaje para " + activeAgentDisplayName + "...";
    }

    function messagePartsFor(message) {
        const msg = message || {};
        const key = JSON.stringify({
            messageType: msg.messageType || "",
            content: msg.content || "",
        });
        if (_messagePartsCache[key] !== undefined)
            return _messagePartsCache[key];

        const parts = OrbitMessageParts.parseMessageParts(msg.content || "", null);
        if (Object.keys(_messagePartsCache).length > 200)
            _messagePartsCache = ({});
        _messagePartsCache[key] = parts;
        return parts;
    }

    function _findAgent(agentId) {
        for (let i = 0; i < availableAgents.length; i++) {
            if (availableAgents[i].id === agentId)
                return availableAgents[i];
        }
        return null;
    }

    function _recomputeContextTokens() {
        approxContextTokens = AiSessionUtils.recomputeContextTokens(messages);
    }

    function _storeMessagesNow() {
        if (!AiHistoryService.isLoading) {
            AiHistoryService.set("messages", messages);
            AiHistoryService.set("activeAgentId", openfangAgentId);
            historyAgentId = openfangAgentId;
        }
        _messagesDirty = false;
    }

    function _storeDraftNow() {
        if (!AiHistoryService.isLoading)
            AiHistoryService.set("draftMessage", draftMessage);
        _draftDirty = false;
    }

    function _persistMessages(immediate) {
        _recomputeContextTokens();
        if (immediate) {
            messagesPersistTimer.stop();
            _storeMessagesNow();
            return;
        }
        _messagesDirty = true;
        messagesPersistTimer.restart();
    }

    function _persistDraft(immediate) {
        if (immediate) {
            draftPersistTimer.stop();
            _storeDraftNow();
            return;
        }
        _draftDirty = true;
        draftPersistTimer.restart();
    }

    function flushPendingPersistence() {
        if (_draftDirty) {
            draftPersistTimer.stop();
            _storeDraftNow();
        }
        if (_messagesDirty) {
            messagesPersistTimer.stop();
            _storeMessagesNow();
        }
    }

    function _refreshSecrets() {
        openfangApiKey = SecretsService.get("ai.openfangApiKey", Quickshell.env("QS_OPENFANG_API_KEY") || "");
    }

    function _refreshHistory() {
        messages = AiHistoryService.get("messages", []);
        lastUserPrompt = AiHistoryService.get("lastUserPrompt", "");
        draftMessage = AiHistoryService.get("draftMessage", "");
        historyAgentId = AiHistoryService.get("activeAgentId", "");
    }

    function _syncHistoryAgent() {
        if (openfangAgentId === "" || historyAgentId === "" || openfangAgentId === historyAgentId)
            return;

        messages = [];
        currentAssistantContent = "";
        lastUserPrompt = "";
        lastError = "";
        AiHistoryService.set("lastUserPrompt", "");
        _persistMessages(true);
    }

    function setDraftMessage(text) {
        draftMessage = text || "";
        _persistDraft(false);
    }

    function clearDraftMessage() {
        draftMessage = "";
        _persistDraft(true);
    }

    function _appendUiMessage(content, role, extra) {
        const timeStr = Qt.formatTime(new Date(), "hh:mm");
        messages = AiSessionUtils.appendMessage(messages, content, role, extra, timeStr);
        _persistMessages(true);
    }

    function _applyResolvedAgent(agent, clearLocalHistory) {
        clearLocalHistory = clearLocalHistory === undefined ? false : clearLocalHistory;
        if (!agent) {
            activeAgent = null;
            return;
        }

        const nextAgent = {
            id: agent.id || "",
            name: agent.name || "",
            state: agent.state || "",
            ready: agent.ready === true,
            model: agent.model || "",
            provider: agent.provider || "",
        };
        const changed = openfangAgentId !== nextAgent.id;

        activeAgent = nextAgent;
        openfangAgentId = nextAgent.id;
        openfangAgentName = nextAgent.name;
        StateService.set("ai.openfangAgentId", openfangAgentId);
        StateService.set("ai.openfangAgentName", openfangAgentName);

        if (changed && clearLocalHistory) {
            clearHistory(false);
        } else {
            _syncHistoryAgent();
        }
    }

    function selectAgent(agentId) {
        const agent = _findAgent(agentId);
        if (!agent)
            return;
        _applyResolvedAgent(agent, true);
    }

    function _sendSignature(text) {
        return (openfangAgentId || openfangAgentName || "") + "::" + (text || "");
    }

    function _appendStreamingPlaceholder() {
        const timeStr = Qt.formatTime(new Date(), "hh:mm");
        messages = messages.concat([{
            role: "assistant",
            messageType: "assistant_text",
            content: "",
            time: timeStr,
            streaming: true,
            agentName: activeAgent ? activeAgent.name : "",
            model: activeAgentModelLabel,
        }]);
        _persistMessages(true);
    }

    function _startChatTurn(prompt) {
        const normalizedPrompt = String(prompt || "").trim();
        if (normalizedPrompt === "")
            return;
        if ((isLoading && !stoppedByUser))
            return;
        if (!isGoose && (!activeAgent || activeAgent.ready !== true))
            return;

        const signature = _sendSignature(normalizedPrompt);
        const nowMs = Date.now();
        if (signature === _lastSendSignature && (nowMs - _lastSendTimestamp) < 900)
            return;
        _lastSendSignature = signature;
        _lastSendTimestamp = nowMs;

        _appendUiMessage(normalizedPrompt, "user", { messageType: "user" });

        stoppedByUser = false;
        lastError = "";
        connectionError = "";
        currentAssistantContent = "";
        lastUserPrompt = normalizedPrompt;
        clearDraftMessage();
        AiHistoryService.set("lastUserPrompt", lastUserPrompt);

        _appendStreamingPlaceholder();
        _chatFinished = false;
        _pendingPayload = JSON.stringify({
            engine: activeBackend,
            sessionId: gooseSessionId,
            command: "chat",
            baseUrl: openfangBaseUrl,
            apiKey: openfangApiKey,
            agentId: openfangAgentId,
            agentName: openfangAgentName,
            message: normalizedPrompt,
        });
        chatProc.running = true;
    }

    function sendMessage(text) {
        const normalizedText = String(text || "").trim();
        if (normalizedText === "")
            return;

        if (!isGoose && (!activeAgent || activeAgent.ready !== true)) {
            lastError = "No hay un agente listo en OpenFang para responder.";
            openSettings();
            refreshBackendState(true);
            return;
        }

        _startChatTurn(normalizedText);
    }

    function retryLastMessage() {
        if (isLoading || lastUserPrompt.trim() === "")
            return;
        if (!isGoose && (!activeAgent || activeAgent.ready !== true)) {
            lastError = "El agente seleccionado en OpenFang no esta listo.";
            openSettings();
            return;
        }
        _startChatTurn(lastUserPrompt);
    }

    function _removeStreamingPlaceholder() {
        if (messages.length === 0)
            return;
        const last = messages[messages.length - 1];
        if (last.role === "assistant" && (last.streaming || last.content === "")) {
            messages = messages.slice(0, messages.length - 1);
            _persistMessages(true);
        }
    }

    function _updateStreamingAssistant(content, done, extra) {
        currentAssistantContent = content;
        messages = AiSessionUtils.updateStreamingAssistant(messages, content, done, extra);
        _persistMessages(done === true);
    }

    function _finishAssistantError(errorText) {
        _removeStreamingPlaceholder();
        currentAssistantContent = "";
        lastError = errorText;
        if ((errorText || "").trim() !== "") {
            _appendUiMessage(errorText, "assistant", {
                messageType: "error_notice",
                title: "Error de Orbit",
                icon: "󰅙",
            });
        }
    }

    function _handleChatLine(data) {
        if (!data)
            return;

        let resp = null;
        try {
            resp = JSON.parse(data);
        } catch (e) {
            return;
        }

        if (resp.type === "start") {
            currentAssistantContent = "";
            if (resp.agent)
                _applyResolvedAgent(resp.agent, false);
            return;
        }

        if (resp.type === "thinking")
            return;

        if (resp.type === "delta") {
            currentAssistantContent += resp.content || "";
            _updateStreamingAssistant(currentAssistantContent, false, null);
            return;
        }

        if (resp.type === "done") {
            _chatFinished = true;
            if (resp.agent)
                _applyResolvedAgent(resp.agent, false);

            if (resp.ok) {
                const content = resp.content || currentAssistantContent;
                if (!content || String(content).trim() === "") {
                    _finishAssistantError("OpenFang devolvio una respuesta vacia.");
                    return;
                }
                _updateStreamingAssistant(content, true, {
                    agentName: resp.agent && resp.agent.name ? resp.agent.name : activeAgentDisplayName,
                    model: resp.agent && resp.agent.model
                        ? resp.agent.model + (resp.agent.provider ? " · " + resp.agent.provider : "")
                        : activeAgentModelLabel,
                });
                currentAssistantContent = "";
            } else {
                _finishAssistantError(resp.error || "OpenFang devolvio un error desconocido.");
            }
        }
    }

    function _requestStopRemote() {
        if (!activeAgent || stopProc.running)
            return;

        _pendingStopPayload = JSON.stringify({
            engine: activeBackend,
            sessionId: gooseSessionId,
            command: "stop",
            baseUrl: openfangBaseUrl,
            apiKey: openfangApiKey,
            agentId: openfangAgentId,
            agentName: openfangAgentName,
        });
        stopProc.running = true;
    }

    function stopGeneration() {
        stoppedByUser = true;
        if (chatProc.running)
            chatProc.running = false;
        _requestStopRemote();
    }

    function _resetRemoteSession() {
        if (!activeAgent || resetProc.running)
            return;

        _pendingResetPayload = JSON.stringify({
            engine: activeBackend,
            sessionId: gooseSessionId,
            command: "reset_session",
            baseUrl: openfangBaseUrl,
            apiKey: openfangApiKey,
            agentId: openfangAgentId,
            agentName: openfangAgentName,
        });
        resetProc.running = true;
    }

    function clearHistory(resetRemote) {
        resetRemote = resetRemote === undefined ? true : resetRemote;
        messages = [];
        currentAssistantContent = "";
        lastError = "";
        stoppedByUser = false;
        lastUserPrompt = "";
        AiHistoryService.set("lastUserPrompt", "");
        _persistMessages(true);
        if (resetRemote) {
            _resetRemoteSession();
            gooseSessionId = "orbit_" + Date.now();
            StateService.set("ai.gooseSessionId", gooseSessionId);
        }
    }

    onMessagesChanged: _recomputeContextTokens()

    onStoresReadyChanged: {
        if (!storesReady)
            return;
        _refreshSecrets();
        _refreshHistory();
        _recomputeContextTokens();
        refreshBackendState(true);
    }

    onWindowVisibleChanged: {
        if (!windowVisible) {
            flushPendingPersistence();
            closeSettings();
            return;
        }
        refreshBackendState(true);
    }

    Connections {
        target: SecretsService
        function onStateLoaded() {
            root._refreshSecrets();
        }
    }

    Connections {
        target: AiHistoryService
        function onStateLoaded() {
            root._refreshHistory();
            root._recomputeContextTokens();
        }
    }

    Component.onCompleted: {
        windowVisible = false;
        settingsOpen = false;
        if (storesReady) {
            _refreshSecrets();
            _refreshHistory();
            _recomputeContextTokens();
            refreshBackendState(true);
        }
    }

    Timer {
        id: draftPersistTimer
        interval: 350
        repeat: false
        onTriggered: root._storeDraftNow()
    }

    Timer {
        id: messagesPersistTimer
        interval: 700
        repeat: false
        onTriggered: root._storeMessagesNow()
    }

    Process {
        id: chatProc
        command: ["python3", root.bridgeScriptPath]
        stdinEnabled: true
        running: false
        stdout: SplitParser { onRead: data => root._handleChatLine(data) }
        stderr: SplitParser { onRead: data => root._chatStderr += data + "\n" }

        onStarted: {
            root._chatStderr = "";
            chatProc.write(root._pendingPayload + "\n");
        }

        onExited: {
            if (root.stoppedByUser) {
                root.stoppedByUser = false;
                root._requestStopRemote();
                if (root.currentAssistantContent)
                    root._updateStreamingAssistant(root.currentAssistantContent, true, { agentName: root.activeAgentDisplayName, model: root.activeAgentModelLabel });
                else {
                    root._removeStreamingPlaceholder();
                    root.lastError = "La generacion se detuvo.";
                }
                root.currentAssistantContent = "";
                root._chatFinished = false;
                return;
            }

            if (!root._chatFinished) {
                const err = root._chatStderr.trim();
                root._finishAssistantError(err !== "" ? err : "No hubo respuesta de OpenFang.");
            }

            root._chatFinished = false;
            root.currentAssistantContent = "";
        }
    }

    Process {
        id: statusProc
        command: ["python3", root.bridgeScriptPath]
        stdinEnabled: true
        running: false
        stdout: StdioCollector { id: statusStdout; waitForEnd: true }
        stderr: SplitParser { onRead: data => root._statusStderr += data + "\n" }

        onStarted: {
            root._statusStderr = "";
            statusProc.write(root._pendingStatusPayload + "\n");
        }

        onExited: {
            const raw = statusStdout.text.trim();
            if (!raw) {
                root.connectionState = "error";
                root.connectionError = root._statusStderr.trim() || "OpenFang no respondio.";
                root.availableAgents = [];
                root.activeAgent = null;
                return;
            }

            try {
                const resp = JSON.parse(raw);
                if (!resp.ok) {
                    root.connectionState = "error";
                    root.connectionError = resp.error || "No se pudo leer el estado de OpenFang.";
                    root.availableAgents = [];
                    root.activeAgent = null;
                    return;
                }

                root.connectionState = resp.connected ? "connected" : "error";
                root.connectionError = "";
                root.backendVersion = resp.version || "";
                root.backendStatus = resp.status || "";
                root.availableAgents = resp.agents || [];
                if (resp.selectedAgent)
                    root._applyResolvedAgent(resp.selectedAgent, false);
                else
                    root.activeAgent = null;
            } catch (e) {
                root.connectionState = "error";
                root.connectionError = root._statusStderr.trim() || "No se pudo interpretar la respuesta de OpenFang.";
                root.availableAgents = [];
                root.activeAgent = null;
            }
        }
    }

    Process {
        id: stopProc
        command: ["python3", root.bridgeScriptPath]
        stdinEnabled: true
        running: false
        stdout: StdioCollector { id: stopStdout; waitForEnd: true }
        stderr: SplitParser { onRead: data => root._stopStderr += data + "\n" }

        onStarted: {
            root._stopStderr = "";
            stopProc.write(root._pendingStopPayload + "\n");
        }

        onExited: {
            const raw = stopStdout.text.trim();
            if (!raw)
                return;
            try {
                const resp = JSON.parse(raw);
                if (!resp.ok)
                    root.lastError = resp.error || root.lastError;
            } catch (e) {
            }
        }
    }

    Process {
        id: resetProc
        command: ["python3", root.bridgeScriptPath]
        stdinEnabled: true
        running: false
        stdout: StdioCollector { id: resetStdout; waitForEnd: true }
        stderr: SplitParser { onRead: data => root._resetStderr += data + "\n" }

        onStarted: {
            root._resetStderr = "";
            resetProc.write(root._pendingResetPayload + "\n");
        }

        onExited: {
            const raw = resetStdout.text.trim();
            if (!raw)
                return;
            try {
                const resp = JSON.parse(raw);
                if (!resp.ok)
                    root.lastError = resp.error || root.lastError;
            } catch (e) {
            }
        }
    }
}
