#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import shlex
import subprocess
from typing import Any


class McpError(RuntimeError):
    pass


def _default_server_command() -> list[str]:
    explicit = os.environ.get("AI_WEB_MCP_COMMAND", "").strip()
    if explicit:
        return shlex.split(explicit)
    script_path = os.path.join(os.path.dirname(__file__), "mcp_web_search_server.py")
    return [os.environ.get("AI_WEB_MCP_PYTHON", "python3"), script_path]


def _write_message(proc: subprocess.Popen, payload: dict) -> None:
    if proc.stdin is None:
        raise McpError("MCP stdin is not available.")
    proc.stdin.write(json.dumps(payload) + "\n")
    proc.stdin.flush()


def _read_message(proc: subprocess.Popen) -> dict[str, Any]:
    if proc.stdout is None:
        raise McpError("MCP stdout is not available.")
    line = proc.stdout.readline()
    if line:
        return json.loads(line)

    stderr_text = ""
    if proc.stderr is not None:
        stderr_text = proc.stderr.read().strip()
    raise McpError(stderr_text or "MCP server exited without a response.")


def call_tool(name: str, arguments: dict[str, Any]) -> dict[str, Any]:
    proc = subprocess.Popen(
        _default_server_command(),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    try:
        _write_message(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "quickshell-ai-chat", "version": "0.1.0"},
                },
            },
        )
        init_resp = _read_message(proc)
        if "error" in init_resp:
            raise McpError(init_resp["error"].get("message", "MCP initialize failed."))

        _write_message(
            proc,
            {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}},
        )
        _write_message(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {"name": name, "arguments": arguments},
            },
        )
        response = _read_message(proc)
        if "error" in response:
            raise McpError(response["error"].get("message", "MCP tool call failed."))
        return response.get("result", {})
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=1)
            except subprocess.TimeoutExpired:
                proc.kill()


def web_search(query: str, max_results: int = 5) -> dict[str, Any]:
    return call_tool("web_search", {"query": query, "max_results": max_results})


def lookup_current_time(query: str) -> dict[str, Any]:
    return call_tool("lookup_current_time", {"query": query})
