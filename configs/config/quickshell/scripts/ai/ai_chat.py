#!/usr/bin/env python3
"""
AI Chat backend for Quickshell AI Station.

Commands:
  - chat
  - fetch_models
  - inspect_path
  - list_mcp_tools

The backend emits a single JSON object for non-streaming commands.
For streaming chat commands it emits newline-delimited JSON events:
  {"type":"start"}
  {"type":"delta","content":"..."}
  {"type":"done","ok":true,"content":"..."}
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Callable, Iterator

import ai_agent_runtime as agent_runtime
import mcp_client
from common_paths import read_path_preview


COPILOT_TOKEN_URL = "https://api.github.com/copilot_internal/v2/token"
COPILOT_CHAT_URL = "https://api.githubcopilot.com/chat/completions"
COPILOT_MODELS_URL = "https://api.githubcopilot.com/models"
OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"
OPENAI_MODELS_URL = "https://api.openai.com/v1/models"
GEMINI_MODELS_URL = "https://generativelanguage.googleapis.com/v1beta/models"
LOCAL_AGENT_BASE_URL = os.environ.get("ASSISTANT_AGENT_URL", "http://127.0.0.1:8765")
LOCAL_AGENT_STATE_PATH = os.path.expanduser(
    "~/.config/quickshell/data/state/assistant/assistant_agent_bridge_state.json"
)
LOCAL_AGENT_AUTOSTART = os.environ.get("ASSISTANT_AGENT_AUTOSTART", "1") == "1"
LOCAL_AGENT_PROJECT_DIR = os.path.expanduser("~/.config/quickshell/assistant_agent")
LOCAL_AGENT_UVICORN = os.environ.get(
    "ASSISTANT_AGENT_UVICORN",
    os.path.join(LOCAL_AGENT_PROJECT_DIR, ".venv", "bin", "uvicorn"),
)

COPILOT_PREMIUM_MODELS = {
    "claude-3.5-sonnet",
    "claude-3.7-sonnet",
    "claude-3-opus",
    "o1",
    "o1-mini",
    "o3-mini",
    "o1-preview",
    "gemini-1.5-pro",
    "gemini-2.0-pro",
}

COPILOT_USER_AGENT = "GitHubCopilotChat/0.22.4"
COPILOT_HEADERS_BASE = {
    "User-Agent": COPILOT_USER_AGENT,
    "Copilot-Integration-Id": "vscode-chat",
    "Editor-Version": "vscode/1.90.0",
    "Accept": "application/json",
}


def emit(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def append_attachments(messages: list, attachments: list[str]) -> list:
    if not attachments:
        return messages

    previews = []
    for path in attachments[:4]:
        info = read_path_preview(path, max_bytes=14000)
        if info.get("ok"):
            previews.append(info["preview"])

    if not previews:
        return messages

    out = [dict(msg) for msg in messages]
    for index in range(len(out) - 1, -1, -1):
        if out[index].get("role") == "user":
            out[index]["content"] = (
                out[index].get("content", "").rstrip()
                + "\n\nAttached local context:\n"
                + "\n\n".join(previews)
            )
            break
    return out


def append_web_results(messages: list, query: str, results: list[dict]) -> list:
    if not results:
        return messages

    rendered = ["Fresh web results for this request:"]
    for index, item in enumerate(results, start=1):
        rendered.append(f"{index}. {item.get('title', 'Untitled')}")
        rendered.append(f"   URL: {item.get('url', '')}")
        snippet = (item.get("snippet") or "").strip()
        if snippet:
            rendered.append(f"   Snippet: {snippet}")

    out = [dict(msg) for msg in messages]
    for index in range(len(out) - 1, -1, -1):
        if out[index].get("role") == "user":
            out[index]["content"] = (
                out[index].get("content", "").rstrip()
                + "\n\n"
                + f"Web search query: {query}\n"
                + "\n".join(rendered)
            )
            break
    return out


def query_needs_live_web(query: str) -> bool:
    lowered = (query or "").lower()
    if not lowered.strip():
        return False

    live_markers = (
        " hoy",
        " hoy?",
        "ahora",
        "actual",
        "actualizado",
        "en vivo",
        "último",
        "ultimo",
        "latest",
        "today",
        "current",
        "right now",
        "this morning",
    )
    financial_markers = (
        "trm",
        "dolar",
        "dólar",
        "usd",
        "precio",
        "tasa de cambio",
        "exchange rate",
        "btc",
        "bitcoin",
        "eur",
        "euro",
    )
    news_markers = ("noticia", "noticias", "news", "weather", "clima", "temperatura")

    return any(marker in lowered for marker in live_markers) and (
        any(marker in lowered for marker in financial_markers)
        or any(marker in lowered for marker in news_markers)
    )


def query_needs_live_time(query: str) -> bool:
    lowered = (query or "").strip().lower()
    if not lowered:
        return False

    return bool(
        re.search(
            r"(que hora es en|qué hora es en|hora actual en|time in|current time in)\s+\S+",
            lowered,
        )
    )


def query_explicitly_requests_web(query: str) -> bool:
    lowered = " " + (query or "").strip().lower() + " "
    if not lowered.strip():
        return False

    markers = (
        " busca ",
        " buscar ",
        " buscame ",
        " búscame ",
        " googlea ",
        " google ",
        " web ",
        " internet ",
        " en la web ",
        " en internet ",
        " con fuentes ",
        " dame fuentes ",
        " cita ",
        " citame ",
        " cítame ",
        " source ",
        " sources ",
    )
    return any(marker in lowered for marker in markers)


def query_is_small_talk(query: str) -> bool:
    lowered = (query or "").strip().lower()
    if not lowered:
        return False

    lowered = re.sub(r"[!?.,;:()]+", "", lowered)
    small_talk = {
        "hola",
        "hola!",
        "buenas",
        "buenos dias",
        "buen día",
        "buen dia",
        "buenas tardes",
        "buenas noches",
        "hey",
        "hi",
        "hello",
        "ola",
        "gracias",
        "ok",
        "oki",
        "vale",
        "thanks",
    }
    return lowered in small_talk


def query_should_use_web_tools(query: str) -> bool:
    if query_is_small_talk(query):
        return False

    return (
        query_needs_live_web(query)
        or query_needs_live_time(query)
        or query_explicitly_requests_web(query)
    )


def _tool_names(tools: list[dict]) -> set[str]:
    names = set()
    for tool in tools or []:
        name = str(tool.get("name", "")).strip()
        if name:
            names.add(name)
    return names


def extract_web_context(query: str, search_result: dict | None, time_result: dict | None) -> dict:
    results = []
    if search_result:
        results = (search_result.get("structuredContent") or {}).get("results", []) or []

    time_info = None
    if time_result:
        time_info = (time_result.get("structuredContent") or {}).get("result")

    return {
        "query": query,
        "sources": [
            {
                "title": item.get("title", "Sin titulo"),
                "url": item.get("url", ""),
                "snippet": (item.get("snippet") or "").strip(),
            }
            for item in results[:5]
        ],
        "time": time_info,
        "used": bool(results or time_info),
    }


def append_live_time(messages: list, time_info: dict) -> list:
    if not time_info:
        return messages

    block = (
        "Live time lookup:\n"
        f"- Location: {time_info.get('label', time_info.get('location', 'unknown'))}\n"
        f"- Local time: {time_info.get('time_12h')} ({time_info.get('time_24h')})\n"
        f"- Timezone: {time_info.get('timezone')}\n"
        f"- Date: {time_info.get('date')}\n"
        f"- UTC offset: {time_info.get('offset')}"
    )

    out = [dict(msg) for msg in messages]
    for index in range(len(out) - 1, -1, -1):
        if out[index].get("role") == "user":
            out[index]["content"] = out[index].get("content", "").rstrip() + "\n\n" + block
            break
    return out


def prepend_live_web_instruction(
    messages: list[dict], require_live_web: bool, web_context: dict
) -> list[dict]:
    if not web_context.get("used"):
        return messages

    instruction = (
        "Usa los resultados web y/o la hora en vivo incluidos en el contexto para responder. "
        "Si hay fuentes disponibles, menciona solo las mas utiles y no las enumeres si no aportan valor. "
        "No respondas diciendo que el usuario consulte sitios externos si ya se incluyeron resultados frescos."
    )
    if require_live_web:
        instruction += (
            " Esta consulta dependia de datos en tiempo real, asi que debes basarte en esa informacion verificada."
        )

    return [{"role": "system", "content": instruction}] + [dict(msg) for msg in messages]


def parse_http_error(exc: urllib.error.HTTPError) -> str:
    body = ""
    try:
        body = exc.read().decode()
        err_data = json.loads(body)
        if isinstance(err_data.get("error"), dict):
            return err_data["error"].get("message") or body
        return body
    except Exception:
        return body or str(exc)


def friendly_network_error(reason) -> str:
    text = str(reason or "").strip()
    lowered = text.lower()

    if "temporary failure in name resolution" in lowered or "name resolution" in lowered:
        return (
            "No se pudo resolver el servidor del proveedor. "
            "Parece un problema de DNS o conectividad de red."
        )
    if "connection refused" in lowered:
        return "La conexion fue rechazada por el servicio remoto."
    if "timed out" in lowered or "timeout" in lowered:
        return "La solicitud tardo demasiado y expiro."
    if text:
        return "Error de red: " + text
    return "Error de red desconocido."


def iter_sse_events(response) -> Iterator[str]:
    for raw in response:
        line = raw.decode("utf-8", errors="replace").strip()
        if not line.startswith("data:"):
            continue
        data = line[5:].strip()
        if data == "[DONE]":
            break
        yield data


def _last_user_text(messages: list[dict]) -> str:
    for msg in reversed(messages):
        if msg.get("role") == "user":
            return str(msg.get("content", "")).strip()
    return ""


def _parse_permission_reply(text: str) -> str | None:
    lowered = text.lower().strip()
    if lowered in (
        "allow once",
        "permitir una vez",
        "autorizar una vez",
        "aprobar una vez",
    ):
        return "allow_once"
    if lowered in (
        "allow always",
        "permitir siempre",
        "autorizar siempre",
        "aprobar siempre",
    ):
        return "allow_always"
    if lowered in ("deny", "denegar", "rechazar", "cancelar accion", "cancel action"):
        return "deny"
    return None


class LocalAgentBridge:
    def __init__(self, request: dict) -> None:
        self.request = request
        self.session_id = str(request.get("sessionId", "quickshell-default"))
        self.provider = str(request.get("provider", "local"))

    def handle_turn(self) -> dict | None:
        if not self.request.get("agentEnabled", True):
            return None

        user_text = _last_user_text(self.request.get("messages", []))
        if not user_text:
            return None

        state = self._load_state()
        pending = state.get("pending")
        if pending:
            decision = _parse_permission_reply(user_text)
            if decision is None:
                return {
                    "ok": True,
                    "content": (
                        "Hay una accion local pendiente de autorizacion.\n\n"
                        f"Accion: `{pending.get('tool', 'unknown')}`\n"
                        "Responde con una opcion:\n"
                        "- `permitir una vez`\n"
                        "- `permitir siempre`\n"
                        "- `denegar`"
                    ),
                }

            self._clear_pending(state)

            if decision == "deny":
                self._post(
                    "/permissions/deny",
                    {
                        "session_id": self.session_id,
                        "scope": "deny",
                        "tool_name": pending.get("tool"),
                        "path": pending.get("path"),
                        "reason": "Denied from quickshell chat",
                    },
                )
                return {
                    "ok": True,
                    "content": f"Accion denegada: `{pending.get('tool', 'unknown')}`.",
                }

            approve_scope = (
                "allow_once" if decision == "allow_once" else "allow_for_tool"
            )
            self._post(
                "/permissions/approve",
                {
                    "session_id": self.session_id,
                    "scope": approve_scope,
                    "tool_name": pending.get("tool"),
                    "path": pending.get("path"),
                    "reason": "Approved from quickshell chat",
                },
            )

            original_message = pending.get("original_message", "")
            original_context = pending.get("optional_context", {})
            response = self._post_chat(original_message, original_context)
            return self._render_response(
                response, state, original_message, original_context
            )

        response = self._post_chat(user_text, {})
        return self._render_response(response, state, user_text, {})

    def _post_chat(self, message: str, optional_context: dict) -> dict:
        return self._post(
            "/chat/message",
            {
                "session_id": self.session_id,
                "provider": self.provider,
                "message": message,
                "optional_context": optional_context,
            },
        )

    def _post(self, path: str, payload: dict) -> dict:
        result = self._post_once(path, payload)
        if "_bridge_error" not in result:
            return result

        if not self._ensure_backend_ready():
            return result

        return self._post_once(path, payload)

    def _post_once(self, path: str, payload: dict) -> dict:
        req = urllib.request.Request(
            url=LOCAL_AGENT_BASE_URL + path,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json", "Accept": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                return json.loads(resp.read().decode())
        except Exception as exc:
            return {"_bridge_error": str(exc)}

    def _ensure_backend_ready(self) -> bool:
        if self._backend_alive():
            return True
        if not LOCAL_AGENT_AUTOSTART:
            return False
        if not self._start_backend():
            return False
        for _ in range(12):
            if self._backend_alive():
                return True
            time.sleep(0.2)
        return False

    def _backend_alive(self) -> bool:
        try:
            req = urllib.request.Request(
                url=LOCAL_AGENT_BASE_URL + "/health",
                headers={"Accept": "application/json"},
                method="GET",
            )
            with urllib.request.urlopen(req, timeout=1.0) as resp:
                data = json.loads(resp.read().decode())
                return resp.status == 200 and data.get("status") == "ok"
        except Exception:
            return False

    def _start_backend(self) -> bool:
        if not os.path.exists(LOCAL_AGENT_UVICORN):
            return False
        if not os.path.isdir(LOCAL_AGENT_PROJECT_DIR):
            return False

        parsed = urllib.parse.urlparse(LOCAL_AGENT_BASE_URL)
        host = parsed.hostname or "127.0.0.1"
        port = str(parsed.port or 8765)
        try:
            subprocess.Popen(
                [
                    LOCAL_AGENT_UVICORN,
                    "app.main:app",
                    "--host",
                    host,
                    "--port",
                    port,
                ],
                cwd=LOCAL_AGENT_PROJECT_DIR,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            return True
        except Exception:
            return False

    def _render_response(
        self,
        response: dict,
        state: dict,
        user_message: str,
        optional_context: dict,
    ) -> dict | None:
        if "_bridge_error" in response:
            return None

        status = response.get("status")
        if status == "success":
            payload = response.get("payload", {})
            if payload.get("intent") == "text_response":
                return None
            result = payload.get("result")
            if result:
                return {
                    "ok": True,
                    "content": response.get("message", "Accion local completada.")
                    + "\n\n```json\n"
                    + json.dumps(result, ensure_ascii=False, indent=2)
                    + "\n```",
                }
            return {
                "ok": True,
                "content": response.get("message", "Accion local completada."),
            }

        if status == "needs_permission":
            pending_action = response.get("pending_action", {})
            pending = {
                "tool": pending_action.get("tool"),
                "path": (pending_action.get("args") or {}).get("path"),
                "original_message": user_message,
                "optional_context": optional_context,
            }
            state["pending"] = pending
            self._save_state(state)
            return {
                "ok": True,
                "content": (
                    f"La accion `{pending.get('tool', 'unknown')}` requiere permiso.\n\n"
                    "Responde con:\n"
                    "- `permitir una vez`\n"
                    "- `permitir siempre`\n"
                    "- `denegar`"
                ),
            }

        if status == "needs_dependency_install":
            deps = response.get("detected_dependencies", {})
            missing = [
                item.get("name")
                for item in deps.get("required", [])
                if not item.get("installed", False)
            ]
            suffix = (
                "\n".join(f"- `{item}`" for item in missing)
                if missing
                else "- sin detalle"
            )
            return {
                "ok": True,
                "content": (
                    "Faltan dependencias para ejecutar la accion:\n"
                    + suffix
                    + "\n\nInstala los paquetes y vuelve a intentarlo."
                ),
            }

        if status == "needs_input":
            return {
                "ok": True,
                "content": response.get("message", "Falta informacion para continuar."),
            }

        return {
            "ok": True,
            "content": response.get(
                "message", "El backend local devolvio un error controlado."
            ),
        }

    def _load_state(self) -> dict:
        if not os.path.exists(LOCAL_AGENT_STATE_PATH):
            return {"pending": None}
        try:
            with open(LOCAL_AGENT_STATE_PATH, "r", encoding="utf-8") as handle:
                return json.load(handle)
        except Exception:
            return {"pending": None}

    def _save_state(self, state: dict) -> None:
        os.makedirs(os.path.dirname(LOCAL_AGENT_STATE_PATH), exist_ok=True)
        with open(LOCAL_AGENT_STATE_PATH, "w", encoding="utf-8") as handle:
            json.dump(state, handle, ensure_ascii=False, indent=2)

    def _clear_pending(self, state: dict) -> None:
        state["pending"] = None
        self._save_state(state)


class ProviderBase:
    def fetch_models(self, request: dict) -> dict:
        raise NotImplementedError

    def chat(self, request: dict, emit_chunk: Callable[[str], None]) -> dict:
        raise NotImplementedError


class OpenAIProvider(ProviderBase):
    def fetch_models(self, request: dict) -> dict:
        api_key = request.get("apiKey", "")
        req = urllib.request.Request(
            OPENAI_MODELS_URL,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Accept": "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode())

        chat_prefixes = ("gpt-4", "gpt-3.5", "o1", "o3", "o4")
        models = [
            {"id": item["id"], "name": item["id"]}
            for item in sorted(
                data.get("data", []), key=lambda x: x.get("created", 0), reverse=True
            )
            if any(item["id"].startswith(prefix) for prefix in chat_prefixes)
            and not any(
                x in item["id"]
                for x in (
                    "instruct",
                    "vision",
                    "audio",
                    "tts",
                    "whisper",
                    "embed",
                    "search",
                    "davinci",
                    "babbage",
                    "ada",
                    "curie",
                )
            )
        ]
        return {"ok": True, "models": models}

    def chat(self, request: dict, emit_chunk: Callable[[str], None]) -> dict:
        payload = {
            "model": request.get("model"),
            "messages": request.get("messages", []),
            "max_tokens": 2048,
            "stream": bool(request.get("stream", False)),
        }
        req = urllib.request.Request(
            OPENAI_CHAT_URL,
            data=json.dumps(payload).encode(),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {request.get('apiKey', '')}",
            },
            method="POST",
        )

        content_parts = []
        with urllib.request.urlopen(req, timeout=180) as resp:
            if payload["stream"]:
                emit({"type": "start"})
                for event in iter_sse_events(resp):
                    chunk = json.loads(event)
                    delta = (
                        chunk.get("choices", [{}])[0].get("delta", {}).get("content")
                        or ""
                    )
                    if delta:
                        content_parts.append(delta)
                        emit_chunk(delta)
                return {"ok": True, "content": "".join(content_parts)}

            data = json.loads(resp.read().decode())

        choices = data.get("choices", [])
        if not choices:
            raise ValueError("Empty choices in OpenAI response.")
        content = choices[0].get("message", {}).get("content")
        if content is None:
            finish = choices[0].get("finish_reason", "")
            raise ValueError(f"Empty response (finish_reason: {finish or 'unknown'}).")
        return {"ok": True, "content": content}


class GeminiProvider(ProviderBase):
    def fetch_models(self, request: dict) -> dict:
        api_key = request.get("apiKey", "")
        url = f"{GEMINI_MODELS_URL}?key={urllib.parse.quote(api_key)}&pageSize=50"
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode())

        models = []
        for item in data.get("models", []):
            methods = item.get("supportedGenerationMethods", [])
            if "generateContent" not in methods:
                continue
            model_id = item["name"].replace("models/", "")
            if not model_id.startswith("gemini"):
                continue
            models.append(
                {
                    "id": model_id,
                    "name": item.get("displayName", model_id),
                }
            )
        return {"ok": True, "models": models}

    def chat(self, request: dict, emit_chunk: Callable[[str], None]) -> dict:
        api_key = request.get("apiKey", "")
        model = request.get("model")
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={urllib.parse.quote(api_key)}"

        system_parts = []
        contents = []
        for msg in request.get("messages", []):
            role = msg.get("role")
            text = msg.get("content", "")
            if role == "system":
                if text:
                    system_parts.append({"text": text})
                continue

            target_role = "model" if role == "assistant" else "user"
            if contents and contents[-1]["role"] == target_role:
                contents[-1]["parts"][0]["text"] += "\n" + text
            else:
                contents.append(
                    {
                        "role": target_role,
                        "parts": [{"text": text}],
                    }
                )

        payload = {
            "contents": contents,
            "generationConfig": {"maxOutputTokens": 2048},
        }
        if system_parts:
            payload["systemInstruction"] = {"parts": system_parts}

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = json.loads(resp.read().decode())

        candidates = data.get("candidates", [])
        if not candidates:
            raise ValueError("Empty candidates in Gemini response.")
        parts = candidates[0].get("content", {}).get("parts", [])
        text = "".join(part.get("text", "") for part in parts)
        if not text:
            raise ValueError("Empty text in Gemini response.")
        return {"ok": True, "content": text}


def refresh_copilot_token(oauth_token: str) -> tuple[str, int]:
    req = urllib.request.Request(
        COPILOT_TOKEN_URL,
        headers={
            "Authorization": f"token {oauth_token}",
            "Accept": "application/json",
            "User-Agent": COPILOT_USER_AGENT,
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read().decode())
    token = data.get("token")
    if not token:
        raise ValueError("No Copilot token in response.")
    return token, data.get("expires_at", 0)


class CopilotProvider(ProviderBase):
    def fetch_models(self, request: dict) -> dict:
        oauth_token = request.get("apiKey", "")
        cached_token = request.get("copilotToken", "")
        cached_expiry = int(request.get("copilotTokenExpiry", 0))

        if not cached_token or time.time() > (cached_expiry - 60):
            cached_token, cached_expiry = refresh_copilot_token(oauth_token)

        req = urllib.request.Request(
            COPILOT_MODELS_URL,
            headers={**COPILOT_HEADERS_BASE, "Authorization": f"Bearer {cached_token}"},
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode())

        models = []
        for item in data.get("data", []):
            model_id = item.get("id", "")
            if not model_id:
                continue
            policy = item.get("policy", {})
            is_premium = policy.get("terms") == "premium" or any(
                model_id.startswith(prefix) for prefix in COPILOT_PREMIUM_MODELS
            )
            models.append(
                {
                    "id": model_id,
                    "name": item.get("name", model_id),
                    "vendor": item.get("vendor", ""),
                    "preview": item.get("preview", False),
                    "premium": is_premium,
                }
            )
        return {
            "ok": True,
            "models": models,
            "copilotToken": cached_token,
            "copilotTokenExpiry": cached_expiry,
        }

    def chat(self, request: dict, emit_chunk: Callable[[str], None]) -> dict:
        oauth_token = request.get("apiKey", "")
        cached_token = request.get("copilotToken", "")
        cached_expiry = int(request.get("copilotTokenExpiry", 0))

        if not cached_token or time.time() > (cached_expiry - 60):
            try:
                cached_token, cached_expiry = refresh_copilot_token(oauth_token)
            except urllib.error.HTTPError as exc:
                if exc.code in (401, 403):
                    return {
                        "ok": False,
                        "error": "Copilot auth expired. Please re-authorize.",
                        "needsReauth": True,
                    }
                raise

        payload = {
            "model": request.get("model"),
            "messages": request.get("messages", []),
            "max_tokens": 2048,
            "stream": bool(request.get("stream", False)),
        }
        req = urllib.request.Request(
            COPILOT_CHAT_URL,
            data=json.dumps(payload).encode(),
            headers={
                **COPILOT_HEADERS_BASE,
                "Authorization": f"Bearer {cached_token}",
                "Content-Type": "application/json",
            },
            method="POST",
        )

        content_parts = []
        with urllib.request.urlopen(req, timeout=180) as resp:
            if payload["stream"]:
                emit({"type": "start"})
                for event in iter_sse_events(resp):
                    chunk = json.loads(event)
                    delta = (
                        chunk.get("choices", [{}])[0].get("delta", {}).get("content")
                        or ""
                    )
                    if delta:
                        content_parts.append(delta)
                        emit_chunk(delta)
                return {
                    "ok": True,
                    "content": "".join(content_parts),
                    "copilotToken": cached_token,
                    "copilotTokenExpiry": cached_expiry,
                }

            raw = resp.read().decode()

        data = json.loads(raw)
        choices = data.get("choices", [])
        if not choices:
            return {"ok": False, "error": "Empty choices in Copilot response."}

        choice = choices[0]
        content = choice.get("message", {}).get("content")
        finish = choice.get("finish_reason", "")
        if not content:
            if finish == "content_filter":
                return {
                    "ok": False,
                    "error": "Response blocked by Copilot content filter.",
                }
            return {
                "ok": False,
                "error": f"Empty response from Copilot (finish_reason: {finish or 'unknown'}).",
            }

        return {
            "ok": True,
            "content": content,
            "copilotToken": cached_token,
            "copilotTokenExpiry": cached_expiry,
        }


class ZeroClawProvider(ProviderBase):
    def fetch_models(self, request: dict) -> dict:
        return {"ok": True, "models": []}

    def chat(self, request: dict, emit_chunk: Callable[[str], None]) -> dict:
        messages = request.get("messages", [])
        history_parts = []
        for msg in messages[:-1]:
            role = msg.get("role")
            if role == "system":
                history_parts.append(f"System: {msg.get('content', '')}")
            elif role == "assistant":
                history_parts.append(f"Assistant: {msg.get('content', '')}")
            else:
                history_parts.append(f"User: {msg.get('content', '')}")

        last_content = messages[-1]["content"]
        if history_parts:
            full_message = (
                "<conversation_history>\n"
                + "\n\n".join(history_parts)
                + "\n</conversation_history>\n\n"
                + last_content
            )
        else:
            full_message = last_content

        cmd = [
            "zeroclaw",
            "agent",
            "-m",
            full_message,
            "--memory-backend",
            "none",
            "--autonomy-level",
            request.get("zcAutonomy", "supervised"),
        ]
        if request.get("zcSubProvider"):
            cmd += ["--provider", request["zcSubProvider"]]
        if request.get("model"):
            cmd += ["--model", request["model"]]

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        except FileNotFoundError:
            return {
                "ok": False,
                "error": "zeroclaw binary not found. Install from zeroclaw.net",
            }
        except subprocess.TimeoutExpired:
            return {"ok": False, "error": "ZeroClaw timed out after 180 seconds."}

        ansi = re.compile(r"\x1b\[[0-9;]*[mGKHFJ]")
        timestamp = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")
        clean_lines = [
            ansi.sub("", line)
            for line in result.stdout.splitlines()
            if not timestamp.match(ansi.sub("", line))
        ]
        content = "\n".join(clean_lines).strip()
        if not content:
            err = ansi.sub("", result.stdout + result.stderr).strip()
            return {
                "ok": False,
                "error": ("Empty response from ZeroClaw. " + err[:300]).strip(),
            }
        return {"ok": True, "content": content}


PROVIDERS = {
    "openai": OpenAIProvider(),
    "gemini": GeminiProvider(),
    "copilot": CopilotProvider(),
    "zeroclaw": ZeroClawProvider(),
}


def handle_fetch_models(request: dict) -> None:
    provider_name = request.get("provider", "openai").lower()
    provider = PROVIDERS.get(provider_name)
    if provider is None:
        emit({"ok": False, "error": f"Unknown provider: {provider_name}"})
        return
    if provider_name != "zeroclaw" and not request.get("apiKey", ""):
        emit({"ok": False, "error": "No credentials configured."})
        return
    emit(provider.fetch_models(request))


def handle_inspect_path(request: dict) -> None:
    policy = agent_runtime.PathPolicy(
        request.get("toolAllowedRoots", []),
        request.get("toolBlockedRoots", []),
    )
    ok, path_or_error = policy.validate_existing_path(request.get("path", ""))
    if not ok:
        emit({"ok": False, "error": path_or_error})
        return
    emit(agent_runtime.read_path_preview(path_or_error))


def handle_list_mcp_tools(request: dict) -> None:
    del request
    with mcp_client.McpSession() as session:
        tools = session.list_tools()

    normalized = []
    for tool in tools:
        normalized.append(
            {
                "name": str(tool.get("name", "")).strip(),
                "description": str(tool.get("description", "")).strip(),
                "inputSchema": tool.get("inputSchema") or {},
            }
        )

    emit({"ok": True, "tools": normalized})


def handle_chat(request: dict) -> None:
    messages = request.get("messages", [])
    if not messages:
        emit({"type": "done", "ok": False, "error": "No messages provided."})
        return

    agent_result = LocalAgentBridge(request).handle_turn()
    if agent_result is None:
        agent_result = agent_runtime.AgentRuntime(request).handle_turn()
    if agent_result is not None:
        emit({"type": "done", **agent_result})
        return

    provider_name = request.get("provider", "openai").lower()
    provider = PROVIDERS.get(provider_name)
    if provider is None:
        emit(
            {"type": "done", "ok": False, "error": f"Unknown provider: {provider_name}"}
        )
        return

    if provider_name not in ("copilot", "zeroclaw") and not request.get("apiKey", ""):
        emit({"type": "done", "ok": False, "error": "No API key configured."})
        return

    if provider_name == "copilot" and not request.get("apiKey", ""):
        emit(
            {
                "type": "done",
                "ok": False,
                "error": "Not authorized with GitHub. Open settings and authorize first.",
                "needsReauth": True,
            }
        )
        return

    request = dict(request)
    request["messages"] = append_attachments(messages, request.get("attachments", []))

    web_context = {"query": "", "sources": [], "time": None, "used": False}
    if request.get("webSearchEnabled", False):
        query = _last_user_text(request["messages"])
        web_context["query"] = query
        require_live_web = query_needs_live_web(query) or query_needs_live_time(query)
        should_use_web_tools = query_should_use_web_tools(query)
        available_tools: set[str] = set()
        mcp_error = ""

        if should_use_web_tools:
            try:
                with mcp_client.McpSession() as mcp_session:
                    available_tools = _tool_names(mcp_session.list_tools())

                    time_result = None
                    time_error = ""
                    time_info = None
                    if query_needs_live_time(query) and "lookup_current_time" in available_tools:
                        try:
                            time_result = mcp_session.call_tool(
                                "lookup_current_time",
                                {"query": query},
                            )
                            time_info = (time_result.get("structuredContent") or {}).get("result")
                        except Exception as exc:
                            time_info = None
                            time_error = str(exc)
                    else:
                        time_error = (
                            "MCP tool `lookup_current_time` is not available."
                            if query_needs_live_time(query)
                            else ""
                        )
                    if time_info:
                        request["messages"] = append_live_time(request["messages"], time_info)

                    search_result = None
                    search_error = ""
                    results = []
                    if (
                        query_needs_live_web(query) or query_explicitly_requests_web(query)
                    ) and "web_search" in available_tools:
                        try:
                            search_result = mcp_session.call_tool(
                                "web_search",
                                {"query": query, "max_results": 5},
                            )
                            results = (
                                (search_result.get("structuredContent") or {}).get("results", [])
                            )
                        except Exception as exc:
                            results = []
                            search_error = str(exc)
                    elif query_needs_live_web(query) or query_explicitly_requests_web(query):
                        search_error = "MCP tool `web_search` is not available."
                    if results:
                        request["messages"] = append_web_results(request["messages"], query, results)

                    web_context = extract_web_context(query, search_result, time_result)
                    if require_live_web and not web_context.get("used"):
                        reasons = [
                            item
                            for item in (search_error, time_error, mcp_error)
                            if item
                        ]
                        suffix = reasons[0] if reasons else "No hubo resultados frescos disponibles."
                        emit(
                            {
                                "type": "done",
                                "ok": False,
                                "error": (
                                    "Orbit no pudo verificar esta consulta en tiempo real por MCP. "
                                    + "Activa un servidor MCP con web search funcional o vuelve a intentarlo.\n\n"
                                    + suffix
                                ),
                                "webContext": web_context,
                            }
                        )
                        return
            except Exception as exc:
                mcp_error = str(exc)
                if require_live_web or query_explicitly_requests_web(query):
                    emit(
                        {
                            "type": "done",
                            "ok": False,
                            "error": (
                                "Orbit no pudo iniciar el servidor MCP para web search.\n\n"
                                + mcp_error
                            ),
                            "webContext": web_context,
                        }
                    )
                    return
        request["messages"] = prepend_live_web_instruction(
            request["messages"], require_live_web, web_context
        )

    def emit_chunk(text: str) -> None:
        emit({"type": "delta", "content": text})

    result = provider.chat(request, emit_chunk)
    if request.get("stream", False):
        emit({"type": "done", "webContext": web_context, **result})
    else:
        emit({**result, "webContext": web_context})


def main() -> None:
    raw = sys.stdin.readline()
    try:
        request = json.loads(raw)
    except json.JSONDecodeError as exc:
        emit({"ok": False, "error": f"Invalid JSON input: {exc}"})
        sys.exit(1)

    command = request.get("command", "chat")

    try:
        if command == "fetch_models":
            handle_fetch_models(request)
            return
        if command == "inspect_path":
            handle_inspect_path(request)
            return
        if command == "list_mcp_tools":
            handle_list_mcp_tools(request)
            return
        if command == "chat":
            handle_chat(request)
            return
        emit({"ok": False, "error": f"Unknown command: {command}"})

    except urllib.error.HTTPError as exc:
        error_text = f"HTTP {exc.code}: {parse_http_error(exc)}"
        lowered = error_text.lower()
        if "model is not supported" in lowered or "requested model is not supported" in lowered:
            provider_name = request.get("provider", "").lower()
            if provider_name == "copilot":
                error_text = (
                    "El modelo actual no es compatible con GitHub Copilot. "
                    "Recarga la lista de modelos o deja que Orbit seleccione uno valido."
                )
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
    except (KeyError, IndexError) as exc:
        error_text = f"Unexpected API response: {exc}"
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
