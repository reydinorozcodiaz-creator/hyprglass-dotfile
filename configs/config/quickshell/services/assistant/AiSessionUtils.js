.pragma library

function estimateTokensForText(text) {
    return Math.ceil(String(text || "").length / 4);
}

function recomputeContextTokens(messages) {
    let total = 0;
    for (const msg of messages || [])
        total += estimateTokensForText(msg.content || "");
    return total;
}

function appendMessage(messages, content, role, extra, timeStr) {
    return (messages || []).concat([Object.assign({
        role: role || "assistant",
        content: content,
        time: timeStr,
    }, extra || {})]);
}

function updateStreamingAssistant(messages, content, done, extra) {
    if (!messages || messages.length === 0)
        return messages || [];

    const next = messages.slice();
    const index = next.length - 1;
    const last = Object.assign({}, next[index]);
    if (last.role !== "assistant")
        return next;

    last.content = content;
    last.streaming = !done;
    if (done && extra)
        Object.assign(last, extra);
    next[index] = last;
    return next;
}

function assistantLabel(message, fallbackAgentName) {
    const msg = message || {};
    const agentName = String(msg.agentName || fallbackAgentName || "").trim();
    return agentName !== "" ? agentName : "OpenFang";
}
