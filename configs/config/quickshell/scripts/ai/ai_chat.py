#!/usr/bin/env python3
"""Thin Orbit bridge for the OpenFang HTTP API."""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.parse
import urllib.request
import subprocess
import re
import os
import shutil
from typing import Iterable, Iterator


DEFAULT_BASE_URL = "http://127.0.0.1:4200"
PREFERRED_AGENT_NAMES = ("General Assistant", "assistant")


def emit(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def normalize_base_url(base_url: str) -> str:
    value = str(base_url or "").strip() or DEFAULT_BASE_URL
    if not value.startswith(("http://", "https://")):
        value = "http://" + value
    return value.rstrip("/")


def auth_headers(api_key: str) -> dict[str, str]:
    headers = {"Accept": "application/json"}
    token = str(api_key or "").strip()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def parse_http_error(exc: urllib.error.HTTPError) -> str:
    body = ""
    try:
        body = exc.read().decode("utf-8", errors="replace")
    except Exception:
        body = ""

    if not body:
        return str(exc)

    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return body

    if isinstance(payload, dict):
        if isinstance(payload.get("error"), dict):
            return str(payload["error"].get("message") or body)
        if payload.get("error"):
            return str(payload["error"])
        if payload.get("message"):
            return str(payload["message"])
    return body


def friendly_network_error(reason) -> str:
    text = str(reason or "").strip()
    lowered = text.lower()

    if (
        "temporary failure in name resolution" in lowered
        or "name resolution" in lowered
    ):
        return (
            "No se pudo resolver el servidor de OpenFang. "
            "Parece un problema de DNS o conectividad de red."
        )
    if "connection refused" in lowered:
        return "OpenFang rechazo la conexion. Verifica que el daemon este activo."
    if "timed out" in lowered or "timeout" in lowered:
        return "La solicitud a OpenFang tardo demasiado y expiro."
    if text:
        return "Error de red con OpenFang: " + text
    return "Error de red desconocido al conectar con OpenFang."


def json_request(
    base_url: str,
    path: str,
    *,
    api_key: str = "",
    method: str = "GET",
    payload: dict | None = None,
    timeout: int = 20,
) -> dict | list:
    headers = auth_headers(api_key)
    data = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")

    request = urllib.request.Request(
        normalize_base_url(base_url) + path,
        data=data,
        headers=headers,
        method=method,
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        raw = response.read().decode("utf-8", errors="replace").strip()

    if not raw:
        return {}
    return json.loads(raw)


def is_agent_ready(agent: dict) -> bool:
    if "ready" in agent:
        return bool(agent.get("ready"))
    return str(agent.get("state", "")).lower() == "running"


def normalize_agent(agent: dict | None) -> dict | None:
    if not agent:
        return None
    return {
        "id": str(agent.get("id", "")).strip(),
        "name": str(agent.get("name", "")).strip(),
        "state": str(agent.get("state", "")).strip(),
        "ready": is_agent_ready(agent),
        "model": str(agent.get("model_name") or agent.get("model", "")).strip(),
        "provider": str(
            agent.get("model_provider") or agent.get("provider", "")
        ).strip(),
    }


def resolve_agent(
    agents: list[dict], requested_id: str = "", requested_name: str = ""
) -> dict | None:
    exact_id = str(requested_id or "").strip()
    exact_name = str(requested_name or "").strip().casefold()

    if exact_id:
        for agent in agents:
            if str(agent.get("id", "")).strip() == exact_id:
                return agent

    if exact_name:
        for agent in agents:
            if str(agent.get("name", "")).strip().casefold() == exact_name:
                return agent

    for preferred_name in PREFERRED_AGENT_NAMES:
        for agent in agents:
            if str(agent.get("name", "")).strip() == preferred_name and is_agent_ready(
                agent
            ):
                return agent

    for agent in agents:
        if is_agent_ready(agent):
            return agent

    return agents[0] if agents else None


def iter_sse_events(response: Iterable[bytes]) -> Iterator[tuple[str, str]]:
    event_name = "message"
    data_lines: list[str] = []

    for raw in response:
        line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
        if line == "":
            if data_lines:
                yield event_name, "\n".join(data_lines)
            event_name = "message"
            data_lines = []
            continue

        if line.startswith(":"):
            continue
        if line.startswith("event:"):
            event_name = line[6:].strip() or "message"
            continue
        if line.startswith("data:"):
            data_lines.append(line[5:].lstrip())

    if data_lines:
        yield event_name, "\n".join(data_lines)


def list_agents(request: dict) -> list[dict]:
    payload = json_request(
        request.get("baseUrl", DEFAULT_BASE_URL),
        "/api/agents",
        api_key=request.get("apiKey", ""),
    )
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    return []


def handle_status(request: dict) -> None:
    base_url = normalize_base_url(request.get("baseUrl", DEFAULT_BASE_URL))
    api_key = request.get("apiKey", "")

    health = json_request(base_url, "/api/health", api_key=api_key)
    status = json_request(base_url, "/api/status", api_key=api_key)
    raw_agents = list_agents(request)
    selected = resolve_agent(
        raw_agents,
        requested_id=request.get("agentId", ""),
        requested_name=request.get("agentName", ""),
    )
    agents = [normalize_agent(agent) for agent in raw_agents]
    agents = [agent for agent in agents if agent is not None]
    agents.sort(key=lambda agent: (not agent["ready"], agent["name"].lower()))

    emit(
        {
            "ok": True,
            "connected": True,
            "baseUrl": base_url,
            "version": str(
                health.get("version") or status.get("version") or ""
            ).strip(),
            "status": str(health.get("status") or status.get("status") or "ok").strip(),
            "agentCount": len(agents),
            "agents": agents,
            "selectedAgent": normalize_agent(selected),
        }
    )


def _stream_request(base_url: str, path: str, api_key: str, payload: dict):
    headers = auth_headers(api_key)
    headers["Accept"] = "text/event-stream"
    headers["Content-Type"] = "application/json"
    return urllib.request.urlopen(
        urllib.request.Request(
            base_url + path,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST",
        ),
        timeout=180,
    )


def handle_chat(request: dict) -> None:
    message = str(request.get("message", "")).strip()
    if not message:
        emit({"type": "done", "ok": False, "error": "No se envio ningun mensaje."})
        return

    base_url = normalize_base_url(request.get("baseUrl", DEFAULT_BASE_URL))
    api_key = request.get("apiKey", "")
    raw_agents = list_agents(request)
    raw_agent = resolve_agent(
        raw_agents,
        requested_id=request.get("agentId", ""),
        requested_name=request.get("agentName", ""),
    )
    agent = normalize_agent(raw_agent)

    if agent is None:
        emit(
            {
                "type": "done",
                "ok": False,
                "error": "OpenFang no devolvio agentes disponibles para Orbit.",
            }
        )
        return

    if not agent["ready"]:
        emit(
            {
                "type": "done",
                "ok": False,
                "error": "El agente seleccionado en OpenFang no esta listo.",
                "agent": agent,
            }
        )
        return

    emit({"type": "start", "agent": agent})

    chunks: list[str] = []
    usage = {}

    with _stream_request(
        base_url,
        f"/api/agents/{urllib.parse.quote(agent['id'])}/message/stream",
        api_key,
        {"message": message},
    ) as response:
        for event_name, data in iter_sse_events(response):
            if not data:
                continue

            try:
                payload = json.loads(data)
            except json.JSONDecodeError:
                payload = {"content": data}

            if event_name in ("chunk", "text_delta"):
                text = str(payload.get("content", ""))
                if text:
                    chunks.append(text)
                    emit({"type": "delta", "content": text})
                continue

            if event_name == "done":
                if isinstance(payload.get("usage"), dict):
                    usage = payload["usage"]
                text = str(payload.get("content", ""))
                if text and not chunks:
                    chunks.append(text)
                    emit({"type": "delta", "content": text})
                continue

            if event_name == "error":
                emit(
                    {
                        "type": "done",
                        "ok": False,
                        "error": str(
                            payload.get("error") or payload.get("content") or data
                        ),
                        "agent": agent,
                    }
                )
                return

            if event_name == "thinking":
                emit({"type": "thinking"})

    content = "".join(chunks)
    if content.strip() == "":
        emit(
            {
                "type": "done",
                "ok": False,
                "error": "OpenFang devolvio una respuesta vacia.",
                "agent": agent,
                "usage": usage,
            }
        )
        return

    emit(
        {
            "type": "done",
            "ok": True,
            "content": content,
            "agent": agent,
            "usage": usage,
        }
    )


def _resolve_agent_or_emit_error(request: dict) -> tuple[str, str, dict | None]:
    base_url = normalize_base_url(request.get("baseUrl", DEFAULT_BASE_URL))
    api_key = request.get("apiKey", "")
    raw_agents = list_agents(request)
    raw_agent = resolve_agent(
        raw_agents,
        requested_id=request.get("agentId", ""),
        requested_name=request.get("agentName", ""),
    )
    agent = normalize_agent(raw_agent)
    if agent is None:
        emit(
            {"ok": False, "error": "No se encontro el agente de OpenFang seleccionado."}
        )
    return base_url, api_key, agent


def handle_stop(request: dict) -> None:
    base_url, api_key, agent = _resolve_agent_or_emit_error(request)
    if agent is None:
        return
    response = json_request(
        base_url,
        f"/api/agents/{urllib.parse.quote(agent['id'])}/stop",
        api_key=api_key,
        method="POST",
        payload={},
    )
    emit({"ok": True, "agent": agent, "response": response})


def handle_reset_session(request: dict) -> None:
    base_url, api_key, agent = _resolve_agent_or_emit_error(request)
    if agent is None:
        return
    response = json_request(
        base_url,
        f"/api/agents/{urllib.parse.quote(agent['id'])}/session/reset",
        api_key=api_key,
        method="POST",
        payload={},
    )
    emit({"ok": True, "agent": agent, "response": response})


def remove_ansi(text: str) -> str:
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    return ansi_escape.sub('', text)


def strip_goose_header(text: str) -> str:
    lines = text.splitlines()
    start_idx = 0
    for i, line in enumerate(lines[:15]):
        if "goose is ready" in line.lower() or "____)" in line:
            start_idx = i + 1
    
    while start_idx < len(lines) and not lines[start_idx].strip():
        start_idx += 1
        
    if start_idx >= len(lines):
        return text
    return "\n".join(lines[start_idx:])


def handle_goose_chat(request: dict) -> None:
    message = str(request.get("message", "")).strip()
    if not message:
        emit({"type": "done", "ok": False, "error": "No se envio ningun mensaje a Goose."})
        return

    session_id = str(request.get("sessionId", "")).strip()
    emit({"type": "start", "agent": {"name": "Goose", "id": "goose", "ready": True}})
    emit({"type": "delta", "content": "> [!NOTE]\n> *(Goose está analizando las instrucciones y herramientas...)*\n"})
    emit({"type": "thinking"})

    try:
        goose_bin = shutil.which("goose") or os.path.expanduser("~/.local/bin/goose")
        args = [goose_bin, "run"]
        if session_id:
            args.extend(["--name", session_id])
            args.append("--resume")
        else:
            args.append("--resume")
            
        args.extend(["--text", message])

        proc = subprocess.run(args, capture_output=True, text=True, timeout=300)
        output = proc.stdout.strip()
        stderr = proc.stderr.strip()
        
        # Si la sesion no existe aun, goose fallará al intentar resumir.
        # Quitamos --resume y lo volvemos a intentar para CREAR la sesión.
        if proc.returncode != 0 and session_id and "No session found with name" in stderr:
            args.remove("--resume")
            proc = subprocess.run(args, capture_output=True, text=True, timeout=300)
            output = proc.stdout.strip()
            stderr = proc.stderr.strip()

        if not output and stderr:
            output = stderr

        clean_output = remove_ansi(output)
        clean_output = strip_goose_header(clean_output)

        if proc.returncode != 0 and not clean_output:
            emit({"type": "start", "agent": {"name": "Goose", "id": "goose", "ready": True}})
            emit(
                {
                    "type": "done",
                    "ok": False,
                    "error": f"Goose fallo con codigo {proc.returncode}\n{clean_output}",
                }
            )
            return

        emit({"type": "start", "agent": {"name": "Goose", "id": "goose", "ready": True}})
        emit({"type": "done", "ok": True, "content": clean_output})
    except Exception as e:
        emit({"type": "start", "agent": {"name": "Goose", "id": "goose", "ready": True}})
        emit({"type": "done", "ok": False, "error": f"Error ejecutando Goose: {e}"})


def handle_goose_status(request: dict) -> None:
    emit(
        {
            "ok": True,
            "connected": True,
            "baseUrl": "local",
            "version": "goose CLI",
            "status": "ok",
            "agentCount": 1,
            "agents": [
                {
                    "id": "goose",
                    "name": "Goose Native",
                    "ready": True,
                    "state": "running",
                }
            ],
            "selectedAgent": {
                "id": "goose",
                "name": "Goose Native",
                "ready": True,
                "state": "running",
            },
        }
    )


def handle_goose_stop(request: dict) -> None:
    emit({"ok": True})


def handle_goose_reset(request: dict) -> None:
    emit({"ok": True})


def main() -> None:
    raw = sys.stdin.readline()
    try:
        request = json.loads(raw)
    except json.JSONDecodeError as exc:
        emit({"ok": False, "error": f"Invalid JSON input: {exc}"})
        sys.exit(1)

    command = str(request.get("command", "status")).strip().lower()
    engine = str(request.get("engine", "openfang")).strip().lower()

    try:
        if engine == "goose":
            if command == "status":
                handle_goose_status(request)
                return
            if command == "chat":
                handle_goose_chat(request)
                return
            if command == "stop":
                handle_goose_stop(request)
                return
            if command == "reset_session":
                handle_goose_reset(request)
                return
            emit({"ok": False, "error": f"Unknown command for goose: {command}"})
            return

        if command == "status":
            handle_status(request)
            return
        if command == "chat":
            handle_chat(request)
            return
        if command == "stop":
            handle_stop(request)
            return
        if command == "reset_session":
            handle_reset_session(request)
            return
        emit({"ok": False, "error": f"Unknown command: {command}"})
    except urllib.error.HTTPError as exc:
        error_text = f"HTTP {exc.code}: {parse_http_error(exc)}"
        if command == "chat":
            emit({"type": "done", "ok": False, "error": error_text})
        else:
            emit({"ok": False, "error": error_text})
    except urllib.error.URLError as exc:
        error_text = friendly_network_error(exc.reason)
        if command == "chat":
            emit({"type": "done", "ok": False, "error": error_text})
        else:
            emit({"ok": False, "error": error_text})
    except Exception as exc:
        if command == "chat":
            emit({"type": "done", "ok": False, "error": str(exc)})
        else:
            emit({"ok": False, "error": str(exc)})


if __name__ == "__main__":
    main()
