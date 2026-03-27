#!/usr/bin/env python3

from __future__ import annotations

import json
import sys

from mcp_server_tools import handle_call, tool_list


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
                        "serverInfo": {"name": "quickshell-local-mcp", "version": "0.2.0"},
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
