#!/usr/bin/env python3

from __future__ import annotations

import json
import sys

from mcp_web_tools import lookup_current_time, web_search


PROTOCOL_VERSION = "2024-11-05"


def send(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def ok_response(req_id, result: dict) -> None:
    send({"jsonrpc": "2.0", "id": req_id, "result": result})


def error_response(req_id, code: int, message: str) -> None:
    send(
        {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {"code": code, "message": message},
        }
    )


def render_web_results(query: str, results: list[dict]) -> str:
    lines = [f"Web results for `{query}`:"]
    for index, item in enumerate(results, start=1):
        lines.append(f"\n{index}. {item['title']}")
        lines.append(f"   {item['url']}")
        if item.get("snippet"):
            lines.append(f"   {item['snippet']}")
    return "\n".join(lines)


def render_time_result(item: dict) -> str:
    return (
        f"Current local time in {item['label']}:\n"
        f"- {item['time_12h']} ({item['time_24h']})\n"
        f"- Timezone: {item['timezone']}\n"
        f"- Date: {item['date']}\n"
        f"- UTC offset: {item['offset']}"
    )


def tool_list() -> list[dict]:
    return [
        {
            "name": "web_search",
            "description": "Search the web and return fresh result snippets.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "max_results": {"type": "integer", "minimum": 1, "maximum": 10},
                },
                "required": ["query"],
            },
        },
        {
            "name": "lookup_current_time",
            "description": "Resolve the current time in a named location.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                },
                "required": ["query"],
            },
        },
    ]


def handle_call(name: str, arguments: dict) -> dict:
    if name == "web_search":
        query = str(arguments.get("query", "")).strip()
        max_results = int(arguments.get("max_results", 5))
        results = web_search(query, max_results=max_results)
        if not results:
            return {
                "content": [{"type": "text", "text": f"No web results found for `{query}`."}],
                "structuredContent": {"query": query, "results": []},
                "isError": False,
            }
        return {
            "content": [{"type": "text", "text": render_web_results(query, results)}],
            "structuredContent": {"query": query, "results": results},
            "isError": False,
        }

    if name == "lookup_current_time":
        query = str(arguments.get("query", "")).strip()
        result = lookup_current_time(query)
        if not result:
            return {
                "content": [{"type": "text", "text": f"Could not resolve a time lookup for `{query}`."}],
                "structuredContent": {"query": query, "result": None},
                "isError": True,
            }
        return {
            "content": [{"type": "text", "text": render_time_result(result)}],
            "structuredContent": {"query": query, "result": result},
            "isError": False,
        }

    raise ValueError(f"Unknown tool: {name}")


def main() -> None:
    for raw_line in sys.stdin:
        raw_line = raw_line.strip()
        if not raw_line:
            continue

        try:
            request = json.loads(raw_line)
        except json.JSONDecodeError:
            continue

        req_id = request.get("id")
        method = request.get("method")
        params = request.get("params", {})

        try:
            if method == "initialize":
                ok_response(
                    req_id,
                    {
                        "protocolVersion": PROTOCOL_VERSION,
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "quickshell-web-mcp", "version": "0.1.0"},
                    },
                )
                continue

            if method == "notifications/initialized":
                continue

            if method == "tools/list":
                ok_response(req_id, {"tools": tool_list()})
                continue

            if method == "tools/call":
                name = params.get("name", "")
                arguments = params.get("arguments", {})
                ok_response(req_id, handle_call(name, arguments))
                continue

            error_response(req_id, -32601, f"Method not found: {method}")
        except Exception as exc:
            error_response(req_id, -32000, str(exc))


if __name__ == "__main__":
    main()
