.pragma library

function _escapeHtml(text) {
    return String(text || "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
}

function renderInline(text, accentColor, codeBgColor, subtextColor) {
    return _escapeHtml(text || "")
        .replace(
            /(https?:\/\/[^\s<]+)/g,
            '<a href="$1" style="color:' + accentColor + ';text-decoration:none;">$1</a>'
        )
        .replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")
        .replace(/\*(.+?)\*/g, "<i>$1</i>")
        .replace(
            /`([^`\n]+)`/g,
            '<code style="font-family:monospace;background-color:' + codeBgColor
                + ';padding:0 4px;border-radius:3px;">$1</code>'
        )
        .replace(/^### (.+)$/gm, "<b>$1</b>")
        .replace(/^## (.+)$/gm, "<b>$1</b>")
        .replace(/^# (.+)$/gm, "<b>$1</b>")
        .replace(
            /^> (.+)$/gm,
            '<font color="' + subtextColor + '">│ $1</font>'
        )
        .replace(/\n/g, "<br/>");
}

function _pushParagraph(parts, lines) {
    const text = lines.join("\n").trim();
    if (!text)
        return;
    parts.push({ type: "paragraph", text: text });
}

function _pushQuote(parts, lines) {
    const text = lines.join("\n").replace(/^>\s?/gm, "").trim();
    if (!text)
        return;
    parts.push({ type: "quote", text: text });
}

function _pushList(parts, items, ordered) {
    if (!items.length)
        return;
    parts.push({
        type: ordered ? "ordered_list" : "bullet_list",
        items: items.slice(),
    });
}

function _splitTableRow(line) {
    let text = String(line || "").trim();
    if (!text)
        return [];
    if (text.startsWith("|"))
        text = text.slice(1);
    if (text.endsWith("|"))
        text = text.slice(0, -1);
    return text.split("|").map(cell => cell.trim());
}

function _isTableSeparatorCell(cell) {
    return /^:?-{3,}:?$/.test(String(cell || "").trim());
}

function _isTableSeparatorLine(line) {
    const cells = _splitTableRow(line);
    return cells.length > 0 && cells.every(_isTableSeparatorCell);
}

function _normalizeTableRows(rows, columnCount) {
    return rows.map(function(row) {
        const copy = row.slice(0, columnCount);
        while (copy.length < columnCount)
            copy.push("");
        return copy;
    });
}

function _pushTable(parts, headers, rows) {
    if (!headers.length)
        return;
    parts.push({
        type: "table",
        headers: headers,
        rows: _normalizeTableRows(rows, headers.length),
    });
}

function _parseTextBlocks(text) {
    const parts = [];
    const lines = String(text || "").split("\n");

    let paragraph = [];
    let quote = [];
    let listItems = [];
    let orderedItems = [];

    function flushAll() {
        _pushParagraph(parts, paragraph);
        paragraph = [];
        _pushQuote(parts, quote);
        quote = [];
        _pushList(parts, listItems, false);
        listItems = [];
        _pushList(parts, orderedItems, true);
        orderedItems = [];
    }

    for (let i = 0; i < lines.length; ++i) {
        const line = lines[i];
        const trimmed = line.trim();

        if (trimmed === "") {
            flushAll();
            continue;
        }

        if (trimmed.indexOf("|") !== -1
                && i + 1 < lines.length
                && _isTableSeparatorLine(lines[i + 1])) {
            flushAll();

            const headers = _splitTableRow(trimmed);
            const rows = [];
            i += 2;

            while (i < lines.length) {
                const rowLine = String(lines[i] || "");
                const rowTrimmed = rowLine.trim();
                if (!rowTrimmed || rowTrimmed.indexOf("|") === -1 || _isTableSeparatorLine(rowTrimmed)) {
                    i -= 1;
                    break;
                }
                rows.push(_splitTableRow(rowTrimmed));
                i += 1;
            }

            _pushTable(parts, headers, rows);
            continue;
        }

        if (/^>\s?/.test(trimmed)) {
            _pushParagraph(parts, paragraph);
            paragraph = [];
            _pushList(parts, listItems, false);
            listItems = [];
            _pushList(parts, orderedItems, true);
            orderedItems = [];
            quote.push(trimmed);
            continue;
        }

        if (/^[-*]\s+/.test(trimmed)) {
            _pushParagraph(parts, paragraph);
            paragraph = [];
            _pushQuote(parts, quote);
            quote = [];
            _pushList(parts, orderedItems, true);
            orderedItems = [];
            listItems.push(trimmed.replace(/^[-*]\s+/, ""));
            continue;
        }

        if (/^\d+\.\s+/.test(trimmed)) {
            _pushParagraph(parts, paragraph);
            paragraph = [];
            _pushQuote(parts, quote);
            quote = [];
            _pushList(parts, listItems, false);
            listItems = [];
            orderedItems.push(trimmed.replace(/^\d+\.\s+/, ""));
            continue;
        }

        flushAll();
        paragraph.push(trimmed);
    }

    flushAll();
    return parts;
}

function parseMessageParts(content, webContext) {
    const out = [];
    const source = String(content || "");
    const regex = /```([^\n`]*)\n?([\s\S]*?)```/g;
    let last = 0;
    let match = null;

    while ((match = regex.exec(source)) !== null) {
        if (match.index > last) {
            const prefix = source.slice(last, match.index);
            out.push.apply(out, _parseTextBlocks(prefix));
        }

        out.push({
            type: "code",
            lang: match[1] || "text",
            content: String(match[2] || "").trimEnd(),
        });
        last = match.index + match[0].length;
    }

    if (last < source.length)
        out.push.apply(out, _parseTextBlocks(source.slice(last)));

    if (webContext && webContext.used) {
        out.push({
            type: "web_context",
            query: webContext.query || "",
            time: webContext.time || null,
            sources: webContext.sources || [],
        });
    }

    if (!out.length)
        out.push({ type: "paragraph", text: "" });

    return out;
}

function displayUrl(url) {
    const value = String(url || "").trim();
    if (!value)
        return "";

    try {
        const parsed = new URL(value);
        const host = parsed.host || value;
        if (!parsed.pathname || parsed.pathname === "/")
            return host;

        const cleanPath = parsed.pathname.replace(/\/+$/, "");
        const lastSegment = cleanPath.split("/").filter(Boolean).pop() || "";
        if (!lastSegment)
            return host;
        return host + " / " + (lastSegment.length > 22 ? lastSegment.slice(0, 22) + "..." : lastSegment);
    } catch (e) {
        return value.length > 40 ? value.slice(0, 40) + "..." : value;
    }
}
