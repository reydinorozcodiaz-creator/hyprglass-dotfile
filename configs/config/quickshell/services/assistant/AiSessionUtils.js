.pragma library

function orbitModeLabel(mode) {
    switch (mode) {
    case "act":
        return "Actuar";
    case "launch":
        return "Abrir";
    case "context":
        return "Contexto";
    default:
        return "Preguntar";
    }
}

function orbitPlaceholder(mode) {
    switch (mode) {
    case "act":
        return "Pide una accion, usa un slash command o lanza una herramienta del shell...";
    case "launch":
        return "Busca una app, abre una accion o escribe /launcher...";
    case "context":
        return "Adjunta contexto, resume archivos o escribe /resumir...";
    default:
        return "Pregunta, pega codigo, usa /launcher o adjunta contexto local...";
    }
}

function supportedModelIds(availableModels) {
    return (availableModels || []).map(item => item.id);
}

function hasSupportedCurrentModel(provider, model, availableModels) {
    if (provider === "zeroclaw")
        return String(model || "").trim() !== "";

    const ids = supportedModelIds(availableModels);
    if (ids.length === 0)
        return String(model || "").trim() !== "";
    return ids.includes(model);
}

function sendSignature(provider, model, orbitMode, text, attachments) {
    const attachmentKey = (attachments || []).map(item => item.path || "").join("|");
    return provider + "::" + model + "::" + orbitMode + "::" + (text || "") + "::" + attachmentKey;
}

function estimateTokensForText(text) {
    return Math.ceil(String(text || "").length / 4);
}

function recomputeContextTokens(messages, pendingAttachments) {
    let total = 0;
    for (const msg of messages || [])
        total += estimateTokensForText(msg.content || "");
    for (const item of pendingAttachments || [])
        total += estimateTokensForText(item.preview || "");
    return total;
}

function appendOrbitMessage(messages, provider, model, orbitMode, content, messageType, extra, timeStr) {
    const payload = extra || {};
    return (messages || []).concat([Object.assign({
        role: "assistant",
        messageType: messageType || "system_notice",
        content: content,
        time: timeStr,
        provider: provider,
        model: model,
        mode: orbitMode,
    }, payload)]);
}

function mergeLastAssistantMetadata(messages, extra) {
    if (!messages || messages.length === 0)
        return messages || [];

    const next = messages.slice();
    const index = next.length - 1;
    const last = Object.assign({}, next[index]);
    if (last.role !== "assistant")
        return next;

    next[index] = Object.assign(last, extra || {});
    return next;
}

function orbitModeSystemMessage(orbitMode) {
    switch (orbitMode) {
    case "act":
        return "Orbit esta en modo Actuar. Prioriza pasos concretos, herramientas y resultados accionables.";
    case "launch":
        return "Orbit esta en modo Abrir. Prioriza lanzar apps, abrir paneles y usar atajos del shell cuando aplique.";
    case "context":
        return "Orbit esta en modo Contexto. Prioriza archivos adjuntos, contexto local y resumenes estructurados.";
    default:
        return "";
    }
}

function buildHistory(messages, userText, attachments, orbitMode, systemPrompt, timeStr) {
    const normalizedAttachments = (attachments || []).map(item => ({
        path: item.path || "",
        kind: item.kind || "file",
        displayName: item.displayName || item.path || "",
    }));
    const userMsg = {
        role: "user",
        messageType: "user",
        content: String(userText || "").trim(),
        time: timeStr,
        attachments: normalizedAttachments,
        mode: orbitMode,
    };
    const updated = (messages || []).concat([userMsg]);

    const trimmed = [];
    let budget = 12000;
    for (let i = updated.length - 1; i >= 0; --i) {
        const msg = updated[i];
        const cost = String(msg.content || "").length + 48;
        if (trimmed.length > 0 && budget - cost < 0)
            break;
        trimmed.unshift({ role: msg.role, content: msg.content });
        budget -= cost;
    }

    const systemEntries = [];
    const sysMsg = String(systemPrompt || "").trim();
    const modeMsg = orbitModeSystemMessage(orbitMode);
    if (sysMsg)
        systemEntries.push({ role: "system", content: sysMsg });
    if (modeMsg)
        systemEntries.push({ role: "system", content: modeMsg });

    return {
        updatedMessages: updated,
        history: systemEntries.concat(trimmed),
        userText: userMsg.content,
        attachments: attachments || [],
    };
}

function updateStreamingAssistant(messages, content, done) {
    if (!messages || messages.length === 0)
        return messages || [];

    const next = messages.slice();
    const index = next.length - 1;
    const last = Object.assign({}, next[index]);
    if (last.role !== "assistant")
        return next;

    last.content = content;
    last.streaming = !done;
    next[index] = last;
    return next;
}
