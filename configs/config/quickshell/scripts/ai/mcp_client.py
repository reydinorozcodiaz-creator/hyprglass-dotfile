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


class McpSession:
    def __init__(self, command: list[str] | None = None) -> None:
        self.command = command or _default_server_command()
        self.proc: subprocess.Popen | None = None
        self._next_id = 1
        self._initialized = False

    def __enter__(self) -> "McpSession":
        self.start()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def start(self) -> None:
        if self.proc is not None:
            return

        self.proc = subprocess.Popen(
            self.command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.initialize()

    def close(self) -> None:
        if self.proc is None:
            return

        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=1)
            except subprocess.TimeoutExpired:
                self.proc.kill()

        if self.proc.stdin is not None:
            self.proc.stdin.close()
        if self.proc.stdout is not None:
            self.proc.stdout.close()
        if self.proc.stderr is not None:
            self.proc.stderr.close()

        self.proc = None
        self._initialized = False

    def _require_proc(self) -> subprocess.Popen:
        if self.proc is None:
            raise McpError("MCP session is not running.")
        return self.proc

    def _request(self, method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        proc = self._require_proc()
        req_id = self._next_id
        self._next_id += 1

        payload = {
            "jsonrpc": "2.0",
            "id": req_id,
            "method": method,
            "params": params or {},
        }
        _write_message(proc, payload)
        return self._read_response(req_id)

    def _notify(self, method: str, params: dict[str, Any] | None = None) -> None:
        proc = self._require_proc()
        _write_message(
            proc,
            {
                "jsonrpc": "2.0",
                "method": method,
                "params": params or {},
            },
        )

    def _read_response(self, req_id: int) -> dict[str, Any]:
        proc = self._require_proc()
        while True:
            message = _read_message(proc)
            if message.get("id") != req_id:
                continue
            if "error" in message:
                raise McpError(
                    message["error"].get("message", f"MCP request failed: {req_id}")
                )
            return message.get("result", {})

    def initialize(self) -> dict[str, Any]:
        if self._initialized:
            return {}

        result = self._request(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "quickshell-ai-chat", "version": "0.1.0"},
            },
        )
        self._notify("notifications/initialized", {})
        self._initialized = True
        return result

    def list_tools(self) -> list[dict[str, Any]]:
        result = self._request("tools/list", {})
        tools = result.get("tools", [])
        return tools if isinstance(tools, list) else []

    def has_tool(self, name: str) -> bool:
        tools = self.list_tools()
        return any(str(tool.get("name", "")).strip() == name for tool in tools)

    def call_tool(self, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        return self._request(
            "tools/call",
            {"name": name, "arguments": arguments},
        )


def list_tools() -> list[dict[str, Any]]:
    with McpSession() as session:
        return session.list_tools()


def has_tool(name: str) -> bool:
    with McpSession() as session:
        return session.has_tool(name)


def call_tool(name: str, arguments: dict[str, Any]) -> dict[str, Any]:
    with McpSession() as session:
        return session.call_tool(name, arguments)


def web_search(query: str, max_results: int = 5) -> dict[str, Any]:
    return call_tool("web_search", {"query": query, "max_results": max_results})


def lookup_current_time(query: str) -> dict[str, Any]:
    return call_tool("lookup_current_time", {"query": query})
