pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "../../modules/tools/orbit/OrbitMessageParts.js" as OrbitMessageParts
import "./AiSessionUtils.js" as AiSessionUtils

Singleton {
    id: root

    property string provider: StateService.get("ai.provider", "openai")
    property string model: StateService.get("ai.model", "gpt-4o-mini")
    property string apiKey: SecretsService.get("ai.apiKey", Quickshell.env("QS_AI_API_KEY") || "")
    property string systemPrompt: StateService.get("ai.systemPrompt", "")

    property string copilotOAuthToken: SecretsService.get("ai.copilotOAuthToken", Quickshell.env("QS_COPILOT_OAUTH_TOKEN") || "")
    property string copilotApiToken: SecretsService.get("ai.copilotApiToken", "")
    property int copilotApiTokenExpiry: SecretsService.get("ai.copilotApiTokenExpiry", 0)

    property string zerowclawSubProvider: StateService.get("ai.zcSubProvider", "copilot")
    property string zerowclawAutonomy: StateService.get("ai.zcAutonomy", "supervised")
    property bool agentEnabled: StateService.get("ai.agentEnabled", true)
    property bool webSearchEnabled: StateService.get("ai.webSearchEnabled", false)
    property bool dangerousToolsEnabled: StateService.get("ai.dangerousToolsEnabled", false)
    property string orbitMode: StateService.get("ai.orbitMode", "ask")
    property var toolAllowedRoots: StateService.get("ai.toolAllowedRoots", [
        Quickshell.env("HOME") + "/Downloads",
        Quickshell.env("HOME") + "/Documents",
        Quickshell.env("HOME") + "/Desktop",
        Quickshell.env("HOME") + "/.config/quickshell",
    ])
    property var toolBlockedRoots: StateService.get("ai.toolBlockedRoots", [
        "/etc",
        "/usr",
        "/bin",
        "/sbin",
        "/boot",
        "/root",
        "/dev",
        "/proc",
        "/sys",
        "/run",
        "/var/lib",
        Quickshell.env("HOME") + "/.ssh",
        Quickshell.env("HOME") + "/.gnupg",
    ])

    property bool windowVisible: false
    property bool settingsOpen: false
    readonly property bool storesReady: !SecretsService.isLoading && !AiHistoryService.isLoading && !AiCacheService.isLoading
    readonly property var orbitModes: [
        { id: "ask", label: "Preguntar", icon: "󰭹" },
        { id: "act", label: "Actuar", icon: "󰐕" },
        { id: "launch", label: "Abrir", icon: "󰀻" },
        { id: "context", label: "Contexto", icon: "󰋽" }
    ]
    readonly property var orbitQuickActions: [
        { id: "open_launcher", icon: "󰀻", title: "Abrir app", subtitle: "Lanzador contextual", mode: "launch" },
        { id: "use_clipboard", icon: "󰅌", title: "Usar portapapeles", subtitle: "Abrir historial y reutilizar contexto", mode: "context" },
        { id: "explain_attachment", icon: "󰈙", title: "Explicar adjunto", subtitle: "Preparar un resumen del contexto local", mode: "context" },
        { id: "summarize_context", icon: "󰦨", title: "Resumir contexto", subtitle: "Enviar un resumen guiado del contexto actual", mode: "context" },
        { id: "open_settings", icon: "󰒓", title: "Ajustes de Orbit", subtitle: "Proveedor, modelo y herramientas", mode: "act" },
        { id: "power_menu", icon: "󰐥", title: "Accion rapida", subtitle: "Abrir el panel de energia", mode: "act" }
    ]
    readonly property bool needsSetup: {
        if (provider === "zeroclaw")
            return model.trim() === "";
        if (provider === "copilot")
            return copilotOAuthToken === "";
        return apiKey.trim() === "";
    }
    readonly property bool showSettings: needsSetup || settingsOpen
    readonly property var orbitContextItems: {
        const items = [];

        items.push({
            id: "mode",
            icon: "󰘦",
            label: "Modo",
            value: root.orbitModeLabel(orbitMode),
        });
        items.push({
            id: "provider",
            icon: "󰭹",
            label: "Modelo",
            value: provider + " / " + model,
        });

        if (pendingAttachments.length > 0) {
            items.push({
                id: "attachments",
                icon: "󰈔",
                label: "Adjuntos",
                value: String(pendingAttachments.length),
            });
        }

        if (webSearchEnabled) {
            items.push({
                id: "web",
                icon: "󰖟",
                label: "Web",
                value: "Activa",
            });
        }

        items.push({
            id: "tokens",
            icon: "󰞁",
            label: "Contexto",
            value: "~" + approxContextTokens + " tok",
        });

        return items;
    }

    readonly property bool isLoading: chatProc.running
    readonly property bool isFetchingModels: modelsProc.running
    readonly property bool isInspectingAttachment: inspectProc.running
    readonly property bool isFetchingMcpTools: mcpToolsProc.running

    property bool stoppedByUser: false
    property string lastError: ""
    property string lastUserPrompt: AiHistoryService.get("lastUserPrompt", "")
    property var lastUserAttachments: AiHistoryService.get("lastUserAttachments", [])
    property string draftMessage: AiHistoryService.get("draftMessage", "")

    property var availableModels: AiCacheService.get("availableModels", [])
    property string modelsError: ""
    property var availableMcpTools: []
    property string mcpToolsError: ""

    property var messages: AiHistoryService.get("messages", [])
    property var pendingAttachments: []
    property string attachmentsError: ""
    property string currentAssistantContent: ""
    property int approxContextTokens: 0

    property bool copilotAuthInProgress: false
    property string copilotUserCode: ""
    property string copilotVerifyUri: "https://github.com/login/device"
    property string copilotDeviceCode: ""
    property int copilotPollInterval: 5

    property string _pendingPayload: ""
    property string _pendingModelsPayload: ""
    property string _pendingInspectPayload: ""
    property string _pendingMcpToolsPayload: ""
    property string _chatStderr: ""
    property string _modelsStderr: ""
    property string _inspectStderr: ""
    property string _mcpToolsStderr: ""
    property bool _chatFinished: false
    property bool _chatHadSuccess: false
    property bool _messagesDirty: false
    property bool _draftDirty: false
    property var _messagePartsCache: ({})
    property string _lastSendSignature: ""
    property double _lastSendTimestamp: 0

    function ensureModelsLoaded(force) {
        force = force === undefined ? false : force;
        if (!storesReady || provider === "zeroclaw" || isFetchingModels)
            return;

        const key = _credentialForProvider(provider);
        if (!key)
            return;

        if (!force && availableModels.length > 0)
            return;

        _fetchModelsFor(provider, key);
    }

    function openWindow() {
        windowVisible = true;
        ensureModelsLoaded();
    }

    function closeWindow() {
        windowVisible = false;
        closeSettings();
    }

    function toggleWindow() {
        windowVisible = !windowVisible;
    }

    function openSettings() {
        settingsOpen = true;
        windowVisible = true;
        ensureModelsLoaded();
        ensureMcpToolsLoaded();
    }

    function closeSettings() {
        settingsOpen = false;
    }

    function _credentialForProvider(targetProvider) {
        return targetProvider === "copilot" ? copilotOAuthToken : apiKey;
    }

    function orbitModeLabel(mode) {
        return AiSessionUtils.orbitModeLabel(mode);
    }

    function providerLabel(providerId) {
        if (providerId === "copilot")
            return "GitHub Copilot";
        if (providerId === "zeroclaw")
            return "ZeroClaw";
        if (!providerId || providerId.length === 0)
            return "AI";
        return providerId.charAt(0).toUpperCase() + providerId.slice(1);
    }

    function quoteText(text) {
        const cleaned = String(text || "").trim();
        if (cleaned === "")
            return "";

        const quoted = cleaned.split("\n").map(line => line === "" ? ">" : "> " + line).join("\n");
        return quoted;
    }

    function orbitPlaceholder() {
        return AiSessionUtils.orbitPlaceholder(orbitMode);
    }

    function setOrbitMode(mode) {
        const next = mode === "act" || mode === "launch" || mode === "context"
            ? mode
            : "ask";
        orbitMode = next;
        StateService.set("ai.orbitMode", orbitMode);
    }

    function triggerOrbitAction(actionId) {
        switch (actionId) {
        case "open_launcher":
            _resolveOrbitCommand("/launcher");
            return;
        case "use_clipboard":
            _resolveOrbitCommand("/clipboard");
            return;
        case "open_settings":
            _resolveOrbitCommand("/settings");
            return;
        case "power_menu":
            _resolveOrbitCommand("/power");
            return;
        case "summarize_context":
            setOrbitMode("context");
            if (pendingAttachments.length > 0)
                sendMessage("/resumir");
            else
                setDraftMessage("Resume el contexto disponible, indica vacios y sugiere el siguiente paso.");
            return;
        case "explain_attachment":
            setOrbitMode("context");
            if (pendingAttachments.length > 0)
                setDraftMessage("Explica el contexto adjunto, resume sus riesgos y propone mejoras concretas.");
            else
                setDraftMessage("Explica el archivo o carpeta que voy a adjuntar, resume lo importante y marca riesgos.");
            openWindow();
            return;
        default:
            console.warn("[Orbit] Unknown action:", actionId);
        }
    }

    function _resetAvailableModels() {
        availableModels = [];
        modelsError = "";
        if (!AiCacheService.isLoading)
            AiCacheService.set("availableModels", []);
    }

    function selectProvider(providerId) {
        if (!providerId || provider === providerId)
            return;
        provider = providerId;
        _resetAvailableModels();
    }

    function selectModel(modelId) {
        if (!modelId)
            return;
        model = modelId;
    }

    function _supportedModelIds() {
        return AiSessionUtils.supportedModelIds(availableModels);
    }

    function hasSupportedCurrentModel() {
        return AiSessionUtils.hasSupportedCurrentModel(provider, model, availableModels);
    }

    function ensureSupportedModel() {
        if (provider === "zeroclaw")
            return model.trim() !== "";

        const ids = _supportedModelIds();
        if (ids.length === 0)
            return model.trim() !== "";

        if (ids.includes(model))
            return true;

        model = ids[0];
        modelsError = "Orbit corrigio el modelo seleccionado porque no era compatible con el proveedor activo.";
        return true;
    }

    function _sendSignature(text, attachments) {
        return AiSessionUtils.sendSignature(provider, model, orbitMode, text, attachments);
    }

    function _estimateTokensForText(text) {
        return AiSessionUtils.estimateTokensForText(text);
    }

    function messagePartsFor(message) {
        const msg = message || {};
        const key = JSON.stringify({
            messageType: msg.messageType || "",
            content: msg.content || "",
            webContext: msg.webContext || null,
        });
        if (_messagePartsCache[key] !== undefined)
            return _messagePartsCache[key];

        const parts = OrbitMessageParts.parseMessageParts(
            msg.content || "",
            msg.webContext || null
        );
        if (Object.keys(_messagePartsCache).length > 200)
            _messagePartsCache = ({});
        _messagePartsCache[key] = parts;
        return parts;
    }

    function _storeMessagesNow() {
        if (!AiHistoryService.isLoading)
            AiHistoryService.set("messages", messages);
        _messagesDirty = false;
    }

    function _storeDraftNow() {
        if (!AiHistoryService.isLoading)
            AiHistoryService.set("draftMessage", draftMessage);
        _draftDirty = false;
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
        apiKey = SecretsService.get("ai.apiKey", Quickshell.env("QS_AI_API_KEY") || "");
        copilotOAuthToken = SecretsService.get("ai.copilotOAuthToken", Quickshell.env("QS_COPILOT_OAUTH_TOKEN") || "");
        copilotApiToken = SecretsService.get("ai.copilotApiToken", "");
        copilotApiTokenExpiry = SecretsService.get("ai.copilotApiTokenExpiry", 0);
    }

    function _refreshHistory() {
        messages = AiHistoryService.get("messages", []);
        lastUserPrompt = AiHistoryService.get("lastUserPrompt", "");
        lastUserAttachments = AiHistoryService.get("lastUserAttachments", []);
        draftMessage = AiHistoryService.get("draftMessage", "");
    }

    function _refreshCache() {
        availableModels = AiCacheService.get("availableModels", []);
    }

    function _recomputeContextTokens() {
        approxContextTokens = AiSessionUtils.recomputeContextTokens(messages, pendingAttachments);
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

    function _appendOrbitMessage(content, messageType, extra) {
        const timeStr = Qt.formatTime(new Date(), "hh:mm");
        messages = AiSessionUtils.appendOrbitMessage(
            messages,
            provider,
            model,
            orbitMode,
            content,
            messageType,
            extra,
            timeStr
        );
        _persistMessages(true);
    }

    function _mergeLastAssistantMetadata(extra) {
        messages = AiSessionUtils.mergeLastAssistantMetadata(messages, extra);
        _persistMessages(true);
    }

    function _orbitModeSystemMessage() {
        return AiSessionUtils.orbitModeSystemMessage(orbitMode);
    }

    function _resolveOrbitCommand(text) {
        const trimmed = (text || "").trim();
        if (!trimmed.startsWith("/"))
            return { handled: false, replacementText: trimmed };

        const spaceIndex = trimmed.indexOf(" ");
        const command = (spaceIndex === -1 ? trimmed : trimmed.slice(0, spaceIndex)).toLowerCase();
        const argument = spaceIndex === -1 ? "" : trimmed.slice(spaceIndex + 1).trim();

        switch (command) {
        case "/launcher":
        case "/abrir":
            setOrbitMode("launch");
            _appendOrbitMessage("Orbit abrio el lanzador de aplicaciones.", "action_result", {
                title: "Lanzador",
                icon: "󰀻",
            });
            closeWindow();
            LauncherService.show();
            return { handled: true, replacementText: "" };
        case "/clipboard":
        case "/portapapeles":
            setOrbitMode("context");
            _appendOrbitMessage("Orbit abrio el historial del portapapeles.", "action_result", {
                title: "Portapapeles",
                icon: "󰅌",
            });
            closeWindow();
            ClipboardService.show();
            return { handled: true, replacementText: "" };
        case "/settings":
        case "/ajustes":
            openSettings();
            _appendOrbitMessage("Orbit abrio la configuracion del modulo.", "action_result", {
                title: "Configuracion",
                icon: "󰒓",
            });
            return { handled: true, replacementText: "" };
        case "/power":
        case "/energia":
            setOrbitMode("act");
            _appendOrbitMessage("Orbit abrio el menu de energia.", "action_result", {
                title: "Energia",
                icon: "󰐥",
            });
            closeWindow();
            PowerService.showOverlay();
            return { handled: true, replacementText: "" };
        case "/clear":
        case "/limpiar":
            clearHistory();
            lastError = "";
            return { handled: true, replacementText: "" };
        case "/context":
        case "/contexto":
            setOrbitMode("context");
            _appendOrbitMessage("Orbit cambio al modo Contexto.", "system_notice", {
                title: "Modo activo",
                icon: "󰋽",
            });
            return { handled: true, replacementText: "" };
        case "/attach":
        case "/adjuntar":
            if (argument === "") {
                lastError = "Debes indicar una ruta para adjuntar contexto.";
            } else {
                requestAttachment(argument);
            }
            return { handled: true, replacementText: "" };
        case "/summarize":
        case "/resumir":
            return {
                handled: false,
                replacementText: argument !== ""
                    ? "Resume este contexto y destaca acciones concretas:\n\n" + argument
                    : "Resume el contexto adjunto y destaca lo importante.",
            };
        default:
            return { handled: false, replacementText: trimmed };
        }
    }

    function _buildHistory(userText, attachments) {
        const timeStr = Qt.formatTime(new Date(), "hh:mm");
        const built = AiSessionUtils.buildHistory(
            messages,
            userText,
            attachments,
            orbitMode,
            systemPrompt,
            timeStr
        );
        messages = built.updatedMessages;
        _persistMessages(true);

        return {
            timeStr: timeStr,
            history: built.history,
            userText: built.userText,
            attachments: built.attachments,
        };
    }

    function setDraftMessage(text) {
        draftMessage = text || "";
        _persistDraft(false);
    }

    function clearDraftMessage() {
        draftMessage = "";
        _persistDraft(true);
    }

    function toggleWebSearch() {
        webSearchEnabled = !webSearchEnabled;
        StateService.set("ai.webSearchEnabled", webSearchEnabled);
    }

    function sendMessage(text) {
        const resolved = _resolveOrbitCommand(text);
        if (resolved.handled)
            return;

        const normalizedText = resolved.replacementText.trim() !== ""
            ? resolved.replacementText.trim()
            : (pendingAttachments.length > 0 ? "Revisa el contexto local adjunto y resume lo importante." : "");

        if ((isLoading && !stoppedByUser) || normalizedText === "")
            return;

        const attachments = pendingAttachments.slice();
        if (provider === "copilot" && availableModels.length === 0 && copilotOAuthToken !== "") {
            if (!isFetchingModels)
                fetchModels();
            lastError = "Orbit esta cargando los modelos compatibles de GitHub Copilot. Intenta de nuevo en un momento.";
            return;
        }
        if (!ensureSupportedModel()) {
            lastError = "No hay un modelo valido seleccionado para este proveedor.";
            return;
        }

        const signature = _sendSignature(normalizedText, attachments);
        const nowMs = Date.now();
        if (signature === _lastSendSignature && (nowMs - _lastSendTimestamp) < 900)
            return;
        _lastSendSignature = signature;
        _lastSendTimestamp = nowMs;

        const built = _buildHistory(normalizedText, attachments);

        stoppedByUser = false;
        lastError = "";
        currentAssistantContent = "";
        lastUserPrompt = built.userText;
        lastUserAttachments = attachments.map(item => item.path);
        pendingAttachments = [];
        attachmentsError = "";
        clearDraftMessage();

        AiHistoryService.set("lastUserPrompt", lastUserPrompt);
        AiHistoryService.set("lastUserAttachments", lastUserAttachments);

        root._chatFinished = false;
        root._chatHadSuccess = false;
        root._pendingPayload = JSON.stringify({
            command: "chat",
            stream: true,
            provider: provider,
            model: model,
            apiKey: provider === "copilot" ? copilotOAuthToken : apiKey,
            copilotToken: copilotApiToken,
            copilotTokenExpiry: copilotApiTokenExpiry,
            zcSubProvider: zerowclawSubProvider,
            zcAutonomy: zerowclawAutonomy,
            messages: built.history,
            attachments: attachments.map(item => item.path),
            webSearchEnabled: webSearchEnabled,
            agentEnabled: agentEnabled,
            dangerousToolsEnabled: dangerousToolsEnabled,
            toolAllowedRoots: toolAllowedRoots,
            toolBlockedRoots: toolBlockedRoots,
        });

        messages = messages.concat([{
            role: "assistant",
            messageType: "assistant_text",
            content: "",
            time: built.timeStr,
            streaming: true,
            provider: provider,
            model: model,
            webContext: null,
        }]);
        _persistMessages(true);

        chatProc.running = true;
    }

    function retryLastMessage() {
        if (isLoading || lastUserPrompt.trim() === "")
            return;

        const attachments = lastUserAttachments.map(path => ({ path: path }));
        if (provider === "copilot" && availableModels.length === 0 && copilotOAuthToken !== "") {
            if (!isFetchingModels)
                fetchModels();
            lastError = "Orbit esta cargando los modelos compatibles de GitHub Copilot. Intenta de nuevo en un momento.";
            return;
        }
        if (!ensureSupportedModel()) {
            lastError = "No hay un modelo valido seleccionado para este proveedor.";
            return;
        }
        const built = _buildHistory(lastUserPrompt, attachments);

        stoppedByUser = false;
        lastError = "";
        currentAssistantContent = "";
        root._chatFinished = false;
        root._chatHadSuccess = false;
        root._pendingPayload = JSON.stringify({
            command: "chat",
            stream: true,
            provider: provider,
            model: model,
            apiKey: provider === "copilot" ? copilotOAuthToken : apiKey,
            copilotToken: copilotApiToken,
            copilotTokenExpiry: copilotApiTokenExpiry,
            zcSubProvider: zerowclawSubProvider,
            zcAutonomy: zerowclawAutonomy,
            messages: built.history,
            attachments: lastUserAttachments,
            webSearchEnabled: webSearchEnabled,
            agentEnabled: agentEnabled,
            dangerousToolsEnabled: dangerousToolsEnabled,
            toolAllowedRoots: toolAllowedRoots,
            toolBlockedRoots: toolBlockedRoots,
        });

        messages = messages.concat([{
            role: "assistant",
            messageType: "assistant_text",
            content: "",
            time: built.timeStr,
            streaming: true,
            provider: provider,
            model: model,
            webContext: null,
        }]);
        _persistMessages(true);

        chatProc.running = true;
    }

    function stopGeneration() {
        stoppedByUser = true;
        if (chatProc.running)
            chatProc.running = false;
    }

    function clearHistory() {
        messages = [];
        currentAssistantContent = "";
        lastError = "";
        stoppedByUser = false;
        lastUserPrompt = "";
        lastUserAttachments = [];
        AiHistoryService.set("lastUserPrompt", "");
        AiHistoryService.set("lastUserAttachments", []);
        _persistMessages(true);
    }

    function truncateFrom(index) {
        messages = messages.slice(0, index);
        lastError = "";
        stoppedByUser = false;
        _persistMessages(true);
    }

    function saveConfig() {
        StateService.set("ai.provider", provider);
        StateService.set("ai.model", model);
        StateService.set("ai.systemPrompt", systemPrompt);
        StateService.set("ai.zcSubProvider", zerowclawSubProvider);
        StateService.set("ai.zcAutonomy", zerowclawAutonomy);
        StateService.set("ai.agentEnabled", agentEnabled);
        StateService.set("ai.webSearchEnabled", webSearchEnabled);
        StateService.set("ai.dangerousToolsEnabled", dangerousToolsEnabled);
        StateService.set("ai.toolAllowedRoots", toolAllowedRoots);
        StateService.set("ai.toolBlockedRoots", toolBlockedRoots);
        SecretsService.set("ai.apiKey", apiKey);
        closeSettings();

        const key = _credentialForProvider(provider);
        if (provider !== "zeroclaw" && key)
            _fetchModelsFor(provider, key);
    }

    function _fetchModelsFor(targetProvider, key) {
        if (modelsProc.running)
            return;

        modelsError = "";
        root._pendingModelsPayload = JSON.stringify({
            command: "fetch_models",
            provider: targetProvider,
            apiKey: key,
            copilotToken: copilotApiToken,
            copilotTokenExpiry: copilotApiTokenExpiry,
        });
        modelsProc.running = true;
    }

    function ensureMcpToolsLoaded(force) {
        force = force === undefined ? false : force;
        if (mcpToolsProc.running)
            return;
        if (!force && availableMcpTools.length > 0 && mcpToolsError === "")
            return;

        mcpToolsError = "";
        root._pendingMcpToolsPayload = JSON.stringify({
            command: "list_mcp_tools",
        });
        mcpToolsProc.running = true;
    }

    function fetchMcpTools() {
        ensureMcpToolsLoaded(true);
    }

    function fetchModels() {
        const key = _credentialForProvider(provider);
        if (!key) {
            modelsError = "No hay credenciales configuradas.";
            return;
        }
        ensureModelsLoaded(true);
    }

    function requestAttachment(pathText) {
        const path = (pathText || "").trim();
        if (isInspectingAttachment)
            return;
        if (path === "") {
            attachmentsError = "Primero indica una ruta de archivo o carpeta.";
            return;
        }

        attachmentsError = "";
        root._pendingInspectPayload = JSON.stringify({
            command: "inspect_path",
            path: path,
            toolAllowedRoots: toolAllowedRoots,
            toolBlockedRoots: toolBlockedRoots,
        });
        inspectProc.running = true;
    }

    function removeAttachment(index) {
        const next = pendingAttachments.slice();
        next.splice(index, 1);
        pendingAttachments = next;
        _recomputeContextTokens();
    }

    function clearAttachments() {
        pendingAttachments = [];
        attachmentsError = "";
        _recomputeContextTokens();
    }

    function compactConversation() {
        if (messages.length <= 12)
            return;
        const keep = messages.slice(Math.max(messages.length - 12, 0));
        messages = [{
            role: "assistant",
            messageType: "system_notice",
            content: "La conversacion anterior se compacto localmente para mantener el contexto enfocado.",
            time: Qt.formatTime(new Date(), "hh:mm"),
            compacted: true,
        }].concat(keep);
        _persistMessages(true);
    }

    function copilotStartAuth() {
        copilotAuthInProgress = false;
        copilotUserCode = "";
        copilotDeviceCode = "";
        authProc.command = [
            "python3",
            Qt.resolvedUrl("../../scripts/ai/copilot_auth.py").toString().replace("file://", ""),
            "device_code"
        ];
        authProc.running = true;
    }

    function copilotCancelAuth() {
        copilotAuthInProgress = false;
        copilotUserCode = "";
        copilotDeviceCode = "";
        pollTimer.stop();
    }

    function copilotSignOut() {
        copilotOAuthToken = "";
        copilotApiToken = "";
        copilotApiTokenExpiry = 0;
        availableModels = [];
        SecretsService.remove("ai.copilotOAuthToken");
        SecretsService.remove("ai.copilotApiToken");
        SecretsService.remove("ai.copilotApiTokenExpiry");
        AiCacheService.set("availableModels", []);
        openSettings();
    }

    function _updateStreamingAssistant(content, done) {
        currentAssistantContent = content;
        messages = AiSessionUtils.updateStreamingAssistant(messages, content, done);
        _persistMessages(done === true);
    }

    function _finishAssistantError(errorText) {
        if (messages.length > 0) {
            const last = messages[messages.length - 1];
            if (last.role === "assistant" && (last.streaming || last.content === "")) {
                messages = messages.slice(0, messages.length - 1);
                _persistMessages(true);
            }
        }
        currentAssistantContent = "";
        lastError = errorText;
        if ((errorText || "").trim() !== "") {
            _appendOrbitMessage(errorText, "error_notice", {
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
            return;
        }

        if (resp.type === "delta") {
            currentAssistantContent += resp.content || "";
            _updateStreamingAssistant(currentAssistantContent, false);
            return;
        }

        if (resp.type === "done") {
            root._chatFinished = true;
            if (resp.copilotToken) {
                root.copilotApiToken = resp.copilotToken;
                root.copilotApiTokenExpiry = resp.copilotTokenExpiry || 0;
                SecretsService.set("ai.copilotApiToken", resp.copilotToken);
                SecretsService.set("ai.copilotApiTokenExpiry", resp.copilotTokenExpiry || 0);
            }

            if (resp.ok) {
                const content = resp.content || currentAssistantContent;
                if (!content) {
                    _finishAssistantError("El modelo devolvio una respuesta vacia.");
                    return;
                }
                root._chatHadSuccess = true;
                _updateStreamingAssistant(content, true);
                if (resp.webContext)
                    _mergeLastAssistantMetadata({ webContext: resp.webContext });
                currentAssistantContent = "";
            } else {
                if (resp.webContext && messages.length > 0)
                    _mergeLastAssistantMetadata({ webContext: resp.webContext });
                if (resp.needsReauth) {
                    root.copilotApiToken = "";
                    SecretsService.remove("ai.copilotApiToken");
                    SecretsService.remove("ai.copilotApiTokenExpiry");
                }
                _finishAssistantError(resp.error || "Ocurrio un error desconocido.");
            }
        }
    }

    onProviderChanged: {
        _resetAvailableModels();
        StateService.set("ai.provider", provider);
        if ((windowVisible || settingsOpen) && needsSetup)
            openSettings();
        else if (windowVisible || showSettings)
            ensureModelsLoaded();
    }
    onModelChanged: {
        StateService.set("ai.model", model);
        lastError = "";
    }
    onOrbitModeChanged: StateService.set("ai.orbitMode", orbitMode)

    onMessagesChanged: _recomputeContextTokens()
    onStoresReadyChanged: {
        if (storesReady) {
            _refreshSecrets();
            _refreshHistory();
            _refreshCache();
            _recomputeContextTokens();
            if ((windowVisible || settingsOpen) && needsSetup)
                openSettings();
            else if (windowVisible || showSettings) {
                ensureModelsLoaded();
                ensureMcpToolsLoaded();
            }
        }
    }
    onWindowVisibleChanged: {
        if (!windowVisible) {
            flushPendingPersistence();
            closeSettings();
        } else if (showSettings) {
            ensureMcpToolsLoaded();
        }
    }

    Connections {
        target: SecretsService
        function onStateLoaded() {
            root._refreshSecrets();
            if ((root.windowVisible || root.settingsOpen) && root.needsSetup)
                root.openSettings();
        }
    }

    Connections {
        target: AiHistoryService
        function onStateLoaded() {
            root._refreshHistory();
            root._recomputeContextTokens();
        }
    }

    Connections {
        target: AiCacheService
        function onStateLoaded() {
            root._refreshCache();
        }
    }

    Component.onCompleted: {
        windowVisible = false;
        settingsOpen = false;
        StateService.remove("ai.settingsOpen");
        if (storesReady) {
            _refreshSecrets();
            _refreshHistory();
            _refreshCache();
        }
        _recomputeContextTokens();
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
        command: ["python3", Qt.resolvedUrl("../../scripts/ai/ai_chat.py").toString().replace("file://", "")]
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
                if (root.currentAssistantContent)
                    root._updateStreamingAssistant(root.currentAssistantContent, true);
                else
                    root._finishAssistantError("La generacion se detuvo.");
                root.currentAssistantContent = "";
                return;
            }

            if (!root._chatFinished) {
                const err = root._chatStderr.trim();
                root._finishAssistantError(err !== "" ? err : "No hubo respuesta del backend.");
            }
            root._chatFinished = false;
            root._chatHadSuccess = false;
            root.currentAssistantContent = "";
        }
    }

    Process {
        id: modelsProc
        command: ["python3", Qt.resolvedUrl("../../scripts/ai/ai_chat.py").toString().replace("file://", "")]
        stdinEnabled: true
        running: false
        stdout: StdioCollector { id: modelsStdout; waitForEnd: true }
        stderr: SplitParser { onRead: data => root._modelsStderr += data + "\n" }

        onStarted: {
            root._modelsStderr = "";
            modelsProc.write(root._pendingModelsPayload + "\n");
        }

        onExited: {
            const raw = modelsStdout.text.trim();
            if (!raw) {
                root.modelsError = root._modelsStderr.trim() || "No hubo respuesta del endpoint de modelos.";
                return;
            }

            try {
                const resp = JSON.parse(raw);
                if (resp.ok) {
                    root.availableModels = resp.models || [];
                    AiCacheService.set("availableModels", root.availableModels);
                    if (resp.copilotToken) {
                        root.copilotApiToken = resp.copilotToken;
                        root.copilotApiTokenExpiry = resp.copilotTokenExpiry || 0;
                        SecretsService.set("ai.copilotApiToken", resp.copilotToken);
                        SecretsService.set("ai.copilotApiTokenExpiry", resp.copilotTokenExpiry || 0);
                    }
                    const ids = root.availableModels.map(m => m.id);
                    if (ids.length > 0 && !ids.includes(root.model))
                        root.model = ids[0];
                } else {
                    root.modelsError = resp.error || "No se pudieron obtener los modelos.";
                }
            } catch (e) {
                root.modelsError = root._modelsStderr.trim() || "No se pudo interpretar la respuesta de modelos.";
            }
        }
    }

    Process {
        id: inspectProc
        command: ["python3", Qt.resolvedUrl("../../scripts/ai/ai_chat.py").toString().replace("file://", "")]
        stdinEnabled: true
        running: false
        stdout: StdioCollector { id: inspectStdout; waitForEnd: true }
        stderr: SplitParser { onRead: data => root._inspectStderr += data + "\n" }

        onStarted: {
            root._inspectStderr = "";
            inspectProc.write(root._pendingInspectPayload + "\n");
        }

        onExited: {
            const raw = inspectStdout.text.trim();
            if (!raw) {
                root.attachmentsError = root._inspectStderr.trim() || "No hubo respuesta al inspeccionar la ruta.";
                return;
            }

            try {
                const resp = JSON.parse(raw);
                if (!resp.ok) {
                    root.attachmentsError = resp.error || "No se pudo inspeccionar la ruta.";
                    return;
                }

                const next = pendingAttachments.slice();
                if (next.some(item => item.path === resp.path)) {
                    root.attachmentsError = "Esa ruta ya esta adjunta.";
                    return;
                }

                next.push({
                    path: resp.path,
                    kind: resp.kind,
                    preview: resp.preview || "",
                    displayName: resp.displayName || resp.path,
                });
                pendingAttachments = next;
                attachmentsError = "";
                _recomputeContextTokens();
            } catch (e) {
                root.attachmentsError = root._inspectStderr.trim() || "No se pudo interpretar la vista previa del adjunto.";
            }
        }
    }

    Process {
        id: mcpToolsProc
        command: ["python3", Qt.resolvedUrl("../../scripts/ai/ai_chat.py").toString().replace("file://", "")]
        stdinEnabled: true
        running: false
        stdout: StdioCollector { id: mcpToolsStdout; waitForEnd: true }
        stderr: SplitParser { onRead: data => root._mcpToolsStderr += data + "\n" }

        onStarted: {
            root._mcpToolsStderr = "";
            mcpToolsProc.write(root._pendingMcpToolsPayload + "\n");
        }

        onExited: {
            const raw = mcpToolsStdout.text.trim();
            if (!raw) {
                root.mcpToolsError = root._mcpToolsStderr.trim() || "No hubo respuesta del servidor MCP.";
                return;
            }

            try {
                const resp = JSON.parse(raw);
                if (!resp.ok) {
                    root.availableMcpTools = [];
                    root.mcpToolsError = resp.error || "No se pudieron listar las herramientas MCP.";
                    return;
                }

                root.availableMcpTools = resp.tools || [];
                root.mcpToolsError = "";
            } catch (e) {
                root.availableMcpTools = [];
                root.mcpToolsError = root._mcpToolsStderr.trim() || "No se pudo interpretar la respuesta de MCP.";
            }
        }
    }

    Process {
        id: authProc
        running: false
        stdout: StdioCollector { id: authStdout; waitForEnd: true }
        stderr: SplitParser { onRead: data => console.error("[AiService:Auth] " + data) }

        onExited: {
            const raw = authStdout.text.trim();
            try {
                const resp = JSON.parse(raw);
                if (resp.ok) {
                    root.copilotDeviceCode = resp.device_code;
                    root.copilotUserCode = resp.user_code;
                    root.copilotVerifyUri = resp.verification_uri;
                    root.copilotPollInterval = resp.interval || 5;
                    root.copilotAuthInProgress = true;
                    pollTimer.interval = (resp.interval || 5) * 1000;
                    pollTimer.start();
                } else {
                    root.lastError = resp.error || "No se pudo iniciar la autorizacion con GitHub.";
                }
            } catch (e) {
                root.lastError = "No se pudo interpretar la respuesta de autenticacion.";
            }
        }
    }

    Process {
        id: pollProc
        running: false
        stdout: StdioCollector { id: pollStdout; waitForEnd: true }
        stderr: SplitParser { onRead: data => console.error("[AiService:Poll] " + data) }

        onExited: {
            const raw = pollStdout.text.trim();
            try {
                const resp = JSON.parse(raw);
                if (resp.ok) {
                    root.copilotOAuthToken = resp.token;
                    SecretsService.set("ai.copilotOAuthToken", resp.token);
                    root.copilotAuthInProgress = false;
                    root.copilotUserCode = "";
                    pollTimer.stop();
                    fetchModels();
                } else if (!resp.pending) {
                    root.lastError = resp.error || "La autorizacion fallo.";
                    root.copilotAuthInProgress = false;
                    pollTimer.stop();
                }
                if (resp.slow_down)
                    pollTimer.interval = Math.min(pollTimer.interval + 5000, 30000);
            } catch (e) {
                root.lastError = "No se pudo interpretar la respuesta de autorizacion.";
                pollTimer.stop();
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 5000
        repeat: true
        running: false

        onTriggered: {
            if (!root.copilotAuthInProgress || pollProc.running)
                return;
            pollProc.command = [
                "python3",
                Qt.resolvedUrl("../../scripts/ai/copilot_auth.py").toString().replace("file://", ""),
                "poll", root.copilotDeviceCode, String(root.copilotPollInterval)
            ];
            pollProc.running = true;
        }
    }
}
