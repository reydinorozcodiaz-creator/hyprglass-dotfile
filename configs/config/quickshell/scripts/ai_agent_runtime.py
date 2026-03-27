#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.parse
import urllib.request
import mcp_client
from zoneinfo import ZoneInfo


WEB_SEARCH_URL = os.environ.get(
    "AI_WEB_SEARCH_URL", "https://html.duckduckgo.com/html/"
)
OPEN_METEO_GEOCODE_URL = "https://geocoding-api.open-meteo.com/v1/search"


def shell_readable_path(path_str: str) -> str:
    return os.path.abspath(os.path.expanduser(path_str.strip()))


def read_path_preview(path_str: str, max_bytes: int = 12000) -> dict:
    path = shell_readable_path(path_str)
    if not os.path.exists(path):
        return {"ok": False, "error": "Path does not exist."}

    if os.path.isfile(path):
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as handle:
                content = handle.read(max_bytes)
            if os.path.getsize(path) > max_bytes:
                content += "\n... (file truncated)"
            ext = os.path.splitext(path)[1].lstrip(".") or "text"
            return {
                "ok": True,
                "path": path,
                "kind": "file",
                "displayName": os.path.basename(path) or path,
                "preview": f"```{ext}\n# {path}\n{content}\n```",
            }
        except Exception as exc:
            return {"ok": False, "error": f"Failed to read file: {exc}"}

    if os.path.isdir(path):
        try:
            entries = []
            for root, dirs, files in os.walk(path):
                dirs[:] = sorted(d for d in dirs if not d.startswith("."))
                rel = os.path.relpath(root, path)
                prefix = "" if rel == "." else rel + "/"
                for name in sorted(files):
                    entries.append(prefix + name)
                    if len(entries) >= 120:
                        break
                if len(entries) >= 120:
                    entries.append("... (truncated)")
                    break
            return {
                "ok": True,
                "path": path,
                "kind": "directory",
                "displayName": os.path.basename(path) or path,
                "preview": "```\n# " + path + "/\n" + "\n".join(entries) + "\n```",
            }
        except Exception as exc:
            return {"ok": False, "error": f"Failed to inspect directory: {exc}"}

    return {"ok": False, "error": "Only files and directories are supported."}


def _strip_html(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"\s+", " ", text)
    return html.unescape(text).strip()


def web_search(query: str, max_results: int = 5) -> list[dict]:
    cleaned_query = (query or "").strip()
    if not cleaned_query:
        return []

    url = WEB_SEARCH_URL + "?" + urllib.parse.urlencode({"q": cleaned_query})
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (X11; Linux x86_64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml",
        },
    )

    with urllib.request.urlopen(req, timeout=20) as resp:
        body = resp.read().decode("utf-8", errors="replace")

    pattern = re.compile(
        r'<a[^>]+class="result__a"[^>]+href="(?P<href>[^"]+)"[^>]*>(?P<title>.*?)</a>'
        r".*?(?:<a[^>]+class=\"result__snippet\"[^>]*>|<div[^>]+class=\"result__snippet\"[^>]*>)"
        r"(?P<snippet>.*?)</(?:a|div)>",
        re.S,
    )

    results = []
    for match in pattern.finditer(body):
        raw_href = html.unescape(match.group("href"))
        parsed_href = urllib.parse.urlparse(raw_href)
        if "duckduckgo.com" in parsed_href.netloc and parsed_href.path.startswith("/l/"):
            target = urllib.parse.parse_qs(parsed_href.query).get("uddg", [""])[0]
            href = urllib.parse.unquote(target) if target else raw_href
        else:
            href = raw_href

        title = _strip_html(match.group("title"))
        snippet = _strip_html(match.group("snippet"))
        if not title or not href:
            continue

        results.append({"title": title, "url": href, "snippet": snippet})
        if len(results) >= max_results:
            break

    return results


def lookup_current_time(query: str) -> dict | None:
    cleaned_query = (query or "").strip()
    if not cleaned_query:
        return None

    match = re.search(
        r"(?:que hora es en|qué hora es en|hora actual en|time in|current time in)\s+(.+)$",
        cleaned_query,
        flags=re.IGNORECASE,
    )
    if not match:
        return None

    location = match.group(1).strip(" ?.")
    if not location:
        return None

    url = OPEN_METEO_GEOCODE_URL + "?" + urllib.parse.urlencode(
        {"name": location, "count": 1, "language": "es", "format": "json"}
    )
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0",
            "Accept": "application/json",
        },
    )

    with urllib.request.urlopen(req, timeout=20) as resp:
        payload = json.loads(resp.read().decode("utf-8", errors="replace"))

    results = payload.get("results") or []
    if not results:
        return None

    place = results[0]
    timezone = place.get("timezone")
    if not timezone:
        return None

    now = datetime.now(ZoneInfo(timezone))
    city = place.get("name", location)
    country = place.get("country", "")
    admin = place.get("admin1", "")
    label_parts = [part for part in (city, admin, country) if part]

    return {
        "query": cleaned_query,
        "location": location,
        "label": ", ".join(label_parts) or location,
        "timezone": timezone,
        "time_24h": now.strftime("%H:%M"),
        "time_12h": now.strftime("%I:%M %p").lstrip("0"),
        "date": now.strftime("%Y-%m-%d"),
        "offset": now.strftime("%z"),
    }


@dataclass
class DependencySpec:
    binary: str
    package_name: str
    reason: str


@dataclass
class ToolSpec:
    name: str
    description: str
    sensitive: bool
    allow_persist: bool = True


class PathPolicy:
    def __init__(self, allowed_roots: list[str], blocked_roots: list[str]):
        self.allowed_roots = [
            Path(shell_readable_path(item)).resolve(strict=False)
            for item in allowed_roots
            if item
        ]
        self.blocked_roots = [
            Path(shell_readable_path(item)).resolve(strict=False)
            for item in blocked_roots
            if item
        ]

    def _is_relative_to(self, path: Path, root: Path) -> bool:
        try:
            path.relative_to(root)
            return True
        except ValueError:
            return False

    def _is_blocked(self, path: Path) -> bool:
        return any(self._is_relative_to(path, root) for root in self.blocked_roots)

    def _is_allowed(self, path: Path) -> bool:
        return any(self._is_relative_to(path, root) for root in self.allowed_roots)

    def _resolve_existing_path(self, path_str: str) -> Path:
        return Path(shell_readable_path(path_str)).resolve(strict=True)

    def _resolve_target_path(self, path_str: str) -> Path:
        path = Path(shell_readable_path(path_str))
        if path.exists():
            return path.resolve(strict=True)

        suffix: list[str] = []
        current = path
        while not current.exists():
            suffix.append(current.name)
            parent = current.parent
            if parent == current:
                return path.resolve(strict=False)
            current = parent

        resolved = current.resolve(strict=True)
        for part in reversed(suffix):
            resolved = resolved / part
        return resolved

    def validate_existing_path(self, path_str: str) -> tuple[bool, str]:
        try:
            path = self._resolve_existing_path(path_str)
        except FileNotFoundError:
            return False, f"Path does not exist: {shell_readable_path(path_str)}"
        if self._is_blocked(path):
            return False, f"Path blocked by policy: {path}"
        if not self._is_allowed(path):
            return False, f"Path outside allowed roots: {path}"
        return True, str(path)

    def validate_target_path(self, path_str: str) -> tuple[bool, str]:
        path = self._resolve_target_path(path_str)
        if self._is_blocked(path):
            return False, f"Path blocked by policy: {path}"
        allowed = any(self._is_relative_to(path, root) for root in self.allowed_roots)
        if not allowed:
            return False, f"Target path outside allowed roots: {path}"
        return True, str(path)


class PackageInstaller:
    def __init__(self):
        self.manager = self._detect_manager()

    def _detect_manager(self):
        if shutil.which("nix"):
            return "nix"
        for name in ("apt-get", "pacman", "dnf", "zypper", "apk"):
            if shutil.which(name):
                return name
        return None

    def is_available(self) -> bool:
        return self.manager is not None

    def describe(self) -> str:
        return self.manager or "none"

    def install(self, packages: list[str]) -> dict:
        if not packages:
            return {"ok": True, "message": "No packages required."}
        if not self.manager:
            return {"ok": False, "error": "No supported package manager found."}

        safe_packages = []
        for package in packages:
            if not re.fullmatch(r"[a-zA-Z0-9+_.@:-]+", package):
                return {"ok": False, "error": f"Unsafe package name blocked: {package}"}
            safe_packages.append(package)

        if self.manager == "nix":
            cmd = ["nix", "profile", "install"] + [
                f"nixpkgs#{pkg}" for pkg in safe_packages
            ]
        elif self.manager == "apt-get":
            prefix = (
                ["pkexec"]
                if shutil.which("pkexec")
                else (["sudo", "-n"] if shutil.which("sudo") else [])
            )
            cmd = prefix + ["apt-get", "install", "-y"] + safe_packages
        elif self.manager == "pacman":
            prefix = (
                ["pkexec"]
                if shutil.which("pkexec")
                else (["sudo", "-n"] if shutil.which("sudo") else [])
            )
            cmd = prefix + ["pacman", "-Sy", "--noconfirm"] + safe_packages
        elif self.manager == "dnf":
            prefix = (
                ["pkexec"]
                if shutil.which("pkexec")
                else (["sudo", "-n"] if shutil.which("sudo") else [])
            )
            cmd = prefix + ["dnf", "install", "-y"] + safe_packages
        elif self.manager == "zypper":
            prefix = (
                ["pkexec"]
                if shutil.which("pkexec")
                else (["sudo", "-n"] if shutil.which("sudo") else [])
            )
            cmd = prefix + ["zypper", "--non-interactive", "install"] + safe_packages
        elif self.manager == "apk":
            prefix = (
                ["pkexec"]
                if shutil.which("pkexec")
                else (["sudo", "-n"] if shutil.which("sudo") else [])
            )
            cmd = prefix + ["apk", "add"] + safe_packages
        else:
            return {
                "ok": False,
                "error": f"Unsupported package manager: {self.manager}",
            }

        if self.manager != "nix" and not cmd[0] in ("pkexec", "sudo"):
            return {
                "ok": False,
                "error": "Installing system packages requires pkexec or sudo.",
            }

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
        except Exception as exc:
            return {"ok": False, "error": f"Install failed to start: {exc}"}

        if result.returncode != 0:
            detail = (result.stderr or result.stdout).strip()
            return {"ok": False, "error": f"Install failed: {detail[:400]}"}

        return {
            "ok": True,
            "message": f"Installed packages with {self.manager}: {', '.join(safe_packages)}",
        }


class AgentRuntime:
    FOLDER_ALIASES = {
        "descarga": ["Descargas", "Downloads"],
        "downloads": ["Downloads", "Descargas"],
        "download": ["Downloads", "Descargas"],
        "descargas": ["Descargas", "Downloads"],
        "documents": ["Documents", "Documentos"],
        "documentos": ["Documentos", "Documents"],
        "desktop": ["Desktop", "Escritorio"],
        "escritorio": ["Escritorio", "Desktop"],
    }

    def __init__(self, request: dict):
        self.request = request
        self.home = Path.home()
        self.dangerous_tools_enabled = bool(request.get("dangerousToolsEnabled", False))
        self.path_policy = PathPolicy(
            request.get("toolAllowedRoots", []),
            request.get("toolBlockedRoots", []),
        )
        self.installer = PackageInstaller()
        self.state_path = Path(
            shell_readable_path("~/.config/quickshell/data/state/assistant/ai_agent_state.json")
        )
        self.state = self._load_state()
        self.tools = {
            "create_folder": ToolSpec(
                "create_folder", "Create a folder in an allowed location.", True
            ),
            "web_search": ToolSpec(
                "web_search", "Search the web and summarize current results.", False
            ),
            "analyze_path": ToolSpec(
                "analyze_path", "Inspect a file or directory preview.", False
            ),
            "list_directory": ToolSpec(
                "list_directory", "List files and folders inside a directory.", False
            ),
            "list_heavy_files": ToolSpec(
                "list_heavy_files", "List the largest files under a directory.", False
            ),
            "check_tool_installed": ToolSpec(
                "check_tool_installed", "Check whether a CLI tool exists.", False
            ),
            "analyze_dependencies_for_task": ToolSpec(
                "analyze_dependencies_for_task",
                "Estimate dependencies for a task.",
                False,
            ),
            "install_package": ToolSpec(
                "install_package",
                "Install a package through a detected package manager.",
                True,
                False,
            ),
            "download_media_from_url": ToolSpec(
                "download_media_from_url",
                "Download a file or media from a URL.",
                True,
                False,
            ),
        }

    def _load_state(self) -> dict:
        if not self.state_path.exists():
            return {"permissions": {}, "pending_request": None}
        try:
            return json.loads(self.state_path.read_text(encoding="utf-8"))
        except Exception:
            return {"permissions": {}, "pending_request": None}

    def _save_state(self) -> None:
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        self.state_path.write_text(json.dumps(self.state, indent=2), encoding="utf-8")

    def _set_pending(self, pending: dict | None) -> None:
        self.state["pending_request"] = pending
        self._save_state()

    def _set_permission(self, action: str, decision: str) -> None:
        self.state.setdefault("permissions", {})[action] = decision
        self._save_state()

    def _decision_for(self, action: str) -> str | None:
        return self.state.get("permissions", {}).get(action)

    def _last_user_text(self) -> str:
        messages = self.request.get("messages", [])
        for msg in reversed(messages):
            if msg.get("role") == "user":
                return msg.get("content", "").strip()
        return ""

    def _parse_permission_reply(self, text: str) -> str | None:
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
        if lowered in (
            "deny",
            "denegar",
            "rechazar",
            "cancelar accion",
            "cancel action",
        ):
            return "deny"
        return None

    def _resolve_special_folder(self, token: str) -> str | None:
        token = token.strip().strip(".")
        if token.startswith("~") or token.startswith("/"):
            return shell_readable_path(token)
        key = token.lower()
        if key in self.FOLDER_ALIASES:
            candidates = [item.lower() for item in self.FOLDER_ALIASES[key]]
            matching_allowed: list[Path] = []
            for root in self.request.get("toolAllowedRoots", []):
                root_path = Path(shell_readable_path(root))
                if root_path.name.lower() in candidates:
                    matching_allowed.append(root_path)

            for root_path in matching_allowed:
                if root_path.exists() and root_path.is_dir():
                    return str(root_path)

            if matching_allowed:
                return str(matching_allowed[0])

            for candidate in self.FOLDER_ALIASES[key]:
                path = self.home / candidate
                if path.exists():
                    return str(path)
            return str(self.home / self.FOLDER_ALIASES[key][0])
        return None

    def _extract_path_like_token(self, text: str) -> str | None:
        sanitized = re.sub(r"https?://[^\s)]+", "", text)
        match = re.search(r"((?:~|/)[^\s,;]+)", sanitized)
        if match:
            return match.group(1)
        return None

    def _extract_url(self, text: str) -> str | None:
        match = re.search(r"(https?://[^\s)]+)", text)
        return match.group(1) if match else None

    def _has_download_verb(self, text: str) -> bool:
        return (
            re.search(r"\b(descarga|descargar|download|baja|bajar)\b", text) is not None
        )

    def _wants_listing(self, text: str) -> bool:
        return any(
            token in text
            for token in (
                "que hay",
                "qué hay",
                "que archivos",
                "qué archivos",
                "que tengo",
                "qué tengo",
                "lista",
                "listar",
                "list",
                "show",
                "muestra",
                "muéstrame",
                "muestrame",
                "enseñame",
                "enséñame",
                "dime",
            )
        )

    def _wants_analysis(self, text: str) -> bool:
        return any(
            token in text
            for token in (
                "analiza",
                "analyze",
                "inspecciona",
                "inspect",
                "revisa",
                "review",
            )
        )

    def _wants_dependency_analysis(self, text: str) -> bool:
        return any(token in text for token in ("dependencias", "dependencies"))

    def _wants_install(self, text: str) -> bool:
        return any(token in text for token in ("instala", "instalar", "install"))

    def _wants_tool_check(self, text: str) -> bool:
        return any(
            token in text
            for token in (
                "comprueba",
                "comprobar",
                "verifica",
                "verificar",
                "esta instalado",
                "está instalado",
                "installed",
                "check if",
            )
        )

    def _wants_web_search(self, text: str) -> bool:
        return any(
            token in text
            for token in (
                "busca en la web",
                "buscar en la web",
                "busca en internet",
                "buscar en internet",
                "search the web",
                "web search",
                "search online",
                "googlea",
                "googlear",
                "busca ",
                "buscar ",
            )
        )

    def _extract_search_query(self, text: str) -> str:
        query = re.sub(
            r"^\s*(busca(?:r)?(?: en (?:la )?(?:web|internet))?|search(?: the web| online)?|googlea(?:r)?)\s+",
            "",
            text,
            flags=re.IGNORECASE,
        ).strip(" :")
        return query or text.strip()

    def _default_user_folder(self, alias: str, fallback: str) -> str:
        resolved = self._resolve_special_folder(alias)
        return resolved or str(self.home / fallback)

    def _resolve_known_folder_path(self, text: str) -> str | None:
        for alias in self.FOLDER_ALIASES:
            if re.search(rf"\b{re.escape(alias)}\b", text.lower()):
                resolved = self._resolve_special_folder(alias)
                if resolved:
                    return resolved
        return None

    def _pending_reply(self, pending: dict) -> dict:
        tool = self.tools.get(pending["tool"])
        options = ["- `permitir una vez`", "- `denegar`"]
        if tool is None or tool.allow_persist:
            options.insert(1, "- `permitir siempre`")
        return {
            "ok": True,
            "content": (
                "There is a pending local action request.\n\n"
                f"Action: `{pending['tool']}`\n"
                f"Summary: {pending['summary']}\n\n"
                "Reply with one of:\n"
                + "\n".join(options)
            ),
        }

    def handle_turn(self) -> dict | None:
        if not self.request.get("agentEnabled", True):
            return None

        user_text = self._last_user_text()
        if not user_text:
            return None

        pending = self.state.get("pending_request")
        if pending:
            decision = self._parse_permission_reply(user_text)
            if decision is None:
                return self._pending_reply(pending)
            return self._resolve_pending(decision, pending)

        plan = self._detect_tool_plan(user_text)
        if plan is None:
            return None
        if plan.get("kind") == "ask":
            return {"ok": True, "content": plan["content"]}
        return self._execute_or_request(plan)

    def _resolve_pending(self, decision: str, pending: dict) -> dict:
        tool = self.tools.get(pending["tool"])
        if decision == "deny":
            self._set_pending(None)
            return {
                "ok": True,
                "content": f"Action denied: `{pending['tool']}` was not executed.",
            }

        if decision == "allow_always" and tool is not None and not tool.allow_persist:
            decision = "allow_once"

        if decision == "allow_always":
            self._set_permission(pending["tool"], "allow_always")

        self._set_pending(None)
        return self._execute_plan(pending["plan"])

    def _execute_or_request(self, plan: dict) -> dict:
        tool_name = plan["tool"]
        tool = self.tools[tool_name]
        if (
            tool_name in ("install_package", "download_media_from_url")
            and not self.dangerous_tools_enabled
        ):
            return {
                "ok": True,
                "content": (
                    "Dangerous local tools are disabled.\n\n"
                    "Enable `Downloads & installs` in the AI settings before trying that action."
                ),
            }
        stored = self._decision_for(tool_name)
        if stored == "allow_always" and not tool.allow_persist:
            stored = None
        if stored == "deny":
            return {
                "ok": True,
                "content": f"Action `{tool_name}` is currently denied by policy.",
            }
        missing = [
            dep
            for dep in self._resolve_dependencies(plan)
            if shutil.which(dep.binary) is None
        ]
        if missing:
            plan = dict(plan)
            plan["missing_dependencies"] = [dep.__dict__ for dep in missing]
            plan["summary"] += "\nMissing dependencies:\n" + "\n".join(
                f"- {dep.binary} ({dep.package_name}): {dep.reason}" for dep in missing
            )
        if (tool.sensitive or missing) and stored != "allow_always":
            self._set_pending(
                {
                    "tool": tool_name,
                    "summary": plan["summary"],
                    "plan": plan,
                }
            )
            return self._pending_reply(self.state["pending_request"])
        return self._execute_plan(plan)

    def _execute_plan(self, plan: dict) -> dict:
        deps = self._resolve_dependencies(plan)
        missing = [dep for dep in deps if shutil.which(dep.binary) is None]
        if missing:
            packages = [dep.package_name for dep in missing]
            install_result = self.installer.install(packages)
            if not install_result.get("ok"):
                return {
                    "ok": True,
                    "content": (
                        "Required dependencies are missing.\n\n"
                        + "\n".join(
                            f"- `{dep.binary}`: {dep.reason}" for dep in missing
                        )
                        + "\n\n"
                        + install_result["error"]
                    ),
                }
        handler = getattr(self, f"_run_{plan['tool']}")
        return handler(plan["args"])

    def _resolve_dependencies(self, plan: dict) -> list[DependencySpec]:
        if plan["tool"] == "download_media_from_url":
            url = plan["args"]["url"]
            host = urllib.parse.urlparse(url).netloc.lower()
            if any(
                domain in host
                for domain in (
                    "youtube.com",
                    "youtu.be",
                    "vimeo.com",
                    "tiktok.com",
                    "instagram.com",
                    "x.com",
                    "twitter.com",
                )
            ):
                return [
                    DependencySpec(
                        "yt-dlp", "yt-dlp", "Needed for media platform downloads."
                    )
                ]
        return []

    def _detect_tool_plan(self, text: str) -> dict | None:
        lowered = text.lower()

        url = self._extract_url(text)
        default_downloads = self._default_user_folder("descargas", "Downloads")
        default_documents = self._default_user_folder("documentos", "Documents")
        default_desktop = self._default_user_folder("escritorio", "Desktop")

        if self._wants_web_search(lowered) and not self._extract_path_like_token(text):
            query = self._extract_search_query(text)
            return {
                "tool": "web_search",
                "args": {"query": query, "limit": 5},
                "summary": f"Search the web for `{query}`.",
            }

        if any(
            token in lowered for token in ("descargas", "downloads")
        ) and self._wants_listing(lowered):
            destination = self._extract_destination(text) or str(
                self.home / "Downloads"
            )
            return {
                "tool": "list_directory",
                "args": {
                    "path": self._extract_destination(text) or default_downloads,
                    "limit": 80,
                },
                "summary": f"List directory contents for `{self._extract_destination(text) or default_downloads}`.",
            }

        if self._wants_listing(lowered) and any(
            token in lowered
            for token in (
                "orden por tamano",
                "orden por tamaño",
                "por tamano",
                "por tamaño",
                "size",
                "tamaño",
                "tamano",
            )
        ):
            base_path = (
                self._extract_path_like_token(text)
                or self._extract_destination(text)
                or default_downloads
            )
            return {
                "tool": "list_heavy_files",
                "args": {"path": base_path, "limit": 12},
                "summary": f"List the largest files under `{base_path}`.",
            }

        if any(
            token in lowered for token in ("documentos", "documents")
        ) and self._wants_listing(lowered):
            destination = self._extract_destination(text) or default_documents
            return {
                "tool": "list_directory",
                "args": {"path": destination, "limit": 80},
                "summary": f"List directory contents for `{destination}`.",
            }

        if any(
            token in lowered for token in ("escritorio", "desktop")
        ) and self._wants_listing(lowered):
            destination = self._extract_destination(text) or default_desktop
            return {
                "tool": "list_directory",
                "args": {"path": destination, "limit": 80},
                "summary": f"List directory contents for `{destination}`.",
            }

        if self._wants_listing(lowered):
            target = self._extract_path_like_token(text) or self._extract_destination(
                text
            )
            if target:
                return {
                    "tool": "list_directory",
                    "args": {"path": target, "limit": 80},
                    "summary": f"List directory contents for `{target}`.",
                }

        if (
            not url
            and self._has_download_verb(lowered)
            and not self._wants_listing(lowered)
        ):
            return {
                "kind": "ask",
                "content": "I need the URL to download. Example: `descarga https://example.com/file.zip en Descargas`.",
            }
        if url and self._has_download_verb(lowered):
            destination = self._extract_destination(text) or default_downloads
            return {
                "tool": "download_media_from_url",
                "args": {"url": url, "destination": destination},
                "summary": f"Download `{url}` into `{destination}`.",
            }

        install_match = re.search(
            r"(?:instala(?:r)?|install)(?: el paquete| package)? ([a-zA-Z0-9+_.@:-]+)",
            lowered,
        )
        if install_match and self._wants_install(lowered):
            package_name = install_match.group(1)
            return {
                "tool": "install_package",
                "args": {"package_name": package_name},
                "summary": f"Install package `{package_name}` using the detected package manager.",
            }

        if self._wants_dependency_analysis(lowered):
            task = re.sub(
                r"^.*?(dependencias|dependencies)(?: para| for)?",
                "",
                text,
                flags=re.IGNORECASE,
            ).strip(" :")
            if not task:
                return {
                    "kind": "ask",
                    "content": "Describe the task so I can analyze required dependencies.",
                }
            return {
                "tool": "analyze_dependencies_for_task",
                "args": {"task": task},
                "summary": f"Analyze dependencies for task: {task}",
            }

        check_match = re.search(
            r"(?:comprueba(?: si)?|comprobar(?: si)?|verifica(?: si)?|verificar(?: si)?|check(?: if)?|is|esta instalado|está instalado)\s+([a-zA-Z0-9+_.-]+)(?:\s+(?:instalado|installed|esta instalado|está instalado))?",
            lowered,
        )
        if check_match and self._wants_tool_check(lowered):
            return {
                "tool": "check_tool_installed",
                "args": {"tool_name": check_match.group(1)},
                "summary": f"Check whether `{check_match.group(1)}` is installed.",
            }

        if any(
            keyword in lowered
            for keyword in (
                "archivos pesados",
                "largest files",
                "heavy files",
                "archivos más pesados",
                "archivos mas pesados",
            )
        ):
            base_path = (
                self._extract_path_like_token(text)
                or self._extract_destination(text)
                or default_downloads
            )
            return {
                "tool": "list_heavy_files",
                "args": {"path": base_path, "limit": 12},
                "summary": f"List the largest files under `{base_path}`.",
            }

        if self._wants_analysis(lowered):
            target = self._extract_path_like_token(text) or self._extract_destination(
                text
            )
            if target:
                return {
                    "tool": "analyze_path",
                    "args": {"path": target},
                    "summary": f"Analyze local path `{target}`.",
                }

        if any(
            keyword in lowered
            for keyword in (
                "crea una carpeta",
                "crear carpeta",
                "create folder",
                "make folder",
                "mkdir",
                "créame una carpeta",
                "creame una carpeta",
                "crea carpeta",
            )
        ) or (
            "carpeta" in lowered
            and any(
                word in lowered
                for word in (
                    "crea",
                    "crear",
                    "créame",
                    "creame",
                    "haz",
                    "make",
                    "create",
                )
            )
        ):
            folder_name, destination = self._extract_folder_request(text)
            if not folder_name:
                return {
                    "kind": "ask",
                    "content": "I need the folder name to create. Example: `crea una carpeta llamada Mods en Descargas`.",
                }
            if not destination:
                return {
                    "kind": "ask",
                    "content": f"I need the destination path for folder `{folder_name}`.",
                }
            return {
                "tool": "create_folder",
                "args": {"folder_name": folder_name, "destination": destination},
                "summary": f"Create folder `{folder_name}` inside `{destination}`.",
            }

        return None

    def _extract_folder_request(self, text: str) -> tuple[str | None, str | None]:
        patterns = [
            r"(?:créame|creame|crea|crear|haz|make|create)(?:me)?\s+(?:una\s+)?(?:carpeta|folder)(?: llamada| named)?\s+['\"]?([^'\"]+?)['\"]?\s+(?:en|inside|in)\s+([^\n]+)$",
            r"(?:carpeta|folder)(?: llamada| named)?\s+['\"]?([^'\"]+?)['\"]?\s+(?:en|inside|in)\s+([^\n]+)$",
            r"(?:mkdir)\s+([^\s]+)\s+(?:en|inside|in)\s+([^\n]+)$",
        ]
        for pattern in patterns:
            match = re.search(pattern, text, flags=re.IGNORECASE)
            if match:
                folder_name = match.group(1).strip()
                destination = self._extract_destination(match.group(2).strip())
                return folder_name, destination
        return None, None

    def _extract_destination(self, text: str) -> str | None:
        token = self._extract_path_like_token(text)
        if token:
            return shell_readable_path(token)

        words = text.strip().strip(".")
        words = re.sub(r"^(la|el|los|las)\s+", "", words, flags=re.IGNORECASE)
        words = re.sub(
            r"^(carpeta|directorio|folder|directory)\s+", "", words, flags=re.IGNORECASE
        )
        resolved = self._resolve_special_folder(words)
        if resolved:
            return resolved

        known = self._resolve_known_folder_path(text)
        if known:
            return known

        bare_match = re.search(
            r"(?:carpeta|directorio|folder|directory)\s+([A-Za-zÁÉÍÓÚáéíóúñÑ._~/-]+)",
            text,
            flags=re.IGNORECASE,
        )
        if bare_match:
            candidate = bare_match.group(1)
            return self._resolve_special_folder(candidate) or shell_readable_path(
                candidate
            )

        match = re.search(
            r"(?:en|inside|in)\s+([A-Za-zÁÉÍÓÚáéíóúñÑ._~/-]+)",
            text,
            flags=re.IGNORECASE,
        )
        if match:
            return self._resolve_special_folder(match.group(1)) or shell_readable_path(
                match.group(1)
            )
        return None

    def _run_create_folder(self, args: dict) -> dict:
        base = Path(args["destination"])
        target = base / args["folder_name"]
        ok, path_or_error = self.path_policy.validate_target_path(str(target))
        if not ok:
            return {"ok": True, "content": path_or_error}
        target = Path(path_or_error)
        try:
            target.mkdir(parents=True, exist_ok=False)
        except FileExistsError:
            return {"ok": True, "content": f"Folder already exists: `{target}`"}
        except Exception as exc:
            return {"ok": True, "content": f"Failed to create folder `{target}`: {exc}"}
        return {"ok": True, "content": f"Folder created successfully: `{target}`"}

    def _run_analyze_path(self, args: dict) -> dict:
        ok, path_or_error = self.path_policy.validate_existing_path(args["path"])
        if not ok:
            return {"ok": True, "content": path_or_error}
        preview = read_path_preview(path_or_error, max_bytes=10000)
        if not preview.get("ok"):
            return {"ok": True, "content": preview["error"]}
        return {
            "ok": True,
            "content": f"Local path analysis for `{path_or_error}`:\n\n{preview['preview']}",
        }

    def _run_list_directory(self, args: dict) -> dict:
        ok, path_or_error = self.path_policy.validate_existing_path(args["path"])
        if not ok:
            return {"ok": True, "content": path_or_error}
        root = Path(path_or_error)
        if root.is_file():
            root = root.parent
        if not root.is_dir():
            return {
                "ok": True,
                "content": (
                    "No pude encontrar una carpeta valida para listar. "
                    "Prueba indicando una ruta de carpeta o una carpeta conocida como Descargas."
                ),
            }
        try:
            entries = sorted(
                root.iterdir(), key=lambda item: (not item.is_dir(), item.name.lower())
            )
        except Exception as exc:
            return {"ok": True, "content": f"Failed to list `{root}`: {exc}"}

        limit = args.get("limit", 80)
        lines = []
        for item in entries[:limit]:
            label = "dir" if item.is_dir() else "file"
            lines.append(f"- `{item.name}` ({label})")
        if len(entries) > limit:
            lines.append(f"- ... and {len(entries) - limit} more")
        if not lines:
            return {"ok": True, "content": f"`{root}` is empty."}
        return {"ok": True, "content": f"Contents of `{root}`:\n\n" + "\n".join(lines)}

    def _run_list_heavy_files(self, args: dict) -> dict:
        ok, path_or_error = self.path_policy.validate_existing_path(args["path"])
        if not ok:
            return {"ok": True, "content": path_or_error}
        root = Path(path_or_error)
        if root.is_file():
            root = root.parent
        if not root.is_dir():
            return {
                "ok": True,
                "content": (
                    "No pude encontrar una carpeta valida para analizar pesos. "
                    "Prueba con algo como: 'archivos pesados en Descargas'."
                ),
            }
        results = []
        try:
            for current_root, _, files in os.walk(root):
                for name in files:
                    full_path = Path(current_root) / name
                    try:
                        size = full_path.stat().st_size
                    except OSError:
                        continue
                    results.append((size, str(full_path)))
        except Exception as exc:
            return {"ok": True, "content": f"Failed to scan `{root}`: {exc}"}
        results.sort(reverse=True)
        lines = [
            f"- `{path}`: {size / (1024 * 1024):.2f} MiB"
            for size, path in results[: args.get("limit", 12)]
        ]
        if not lines:
            return {"ok": True, "content": f"No files found under `{root}`."}
        return {"ok": True, "content": "Largest files found:\n\n" + "\n".join(lines)}

    def _run_check_tool_installed(self, args: dict) -> dict:
        tool_name = args["tool_name"]
        found = shutil.which(tool_name)
        if found:
            return {"ok": True, "content": f"`{tool_name}` is installed at `{found}`."}
        return {
            "ok": True,
            "content": (
                f"`{tool_name}` is not installed.\n\n"
                f"Detected package manager: `{self.installer.describe()}`."
            ),
        }

    def _run_web_search(self, args: dict) -> dict:
        query = args["query"]
        try:
            time_result = mcp_client.lookup_current_time(query)
            time_info = (time_result.get("structuredContent") or {}).get("result")
        except Exception:
            time_info = None

        try:
            response = mcp_client.web_search(query, max_results=int(args.get("limit", 5)))
            results = (response.get("structuredContent") or {}).get("results", [])
        except Exception as exc:
            return {"ok": True, "content": f"MCP web_search failed for `{query}`: {exc}"}

        if not results and not time_info:
            return {
                "ok": True,
                "content": f"MCP web_search returned no results for `{query}`.",
            }

        lines = [f"Web results for `{query}`:"]
        if time_info:
            lines = [
                f"Current time in `{time_info['label']}`:",
                f"- {time_info['time_12h']} ({time_info['time_24h']})",
                f"- Timezone: {time_info['timezone']}",
                f"- Date: {time_info['date']}",
                f"- UTC offset: {time_info['offset']}",
                "",
                f"MCP web results for `{query}`:",
            ]
        for index, item in enumerate(results, start=1):
            lines.append(f"\n{index}. {item['title']}")
            lines.append(f"   {item['url']}")
            if item.get("snippet"):
                lines.append(f"   {item['snippet']}")

        return {"ok": True, "content": "\n".join(lines)}

    def _run_analyze_dependencies_for_task(self, args: dict) -> dict:
        task = args["task"]
        lowered = task.lower()
        guessed = []
        if any(
            word in lowered
            for word in ("download", "descarga", "youtube", "video", "audio", "media")
        ):
            guessed.append(
                DependencySpec(
                    "yt-dlp",
                    "yt-dlp",
                    "Useful for media downloads from supported sites.",
                )
            )
        if any(word in lowered for word in ("json", "jq")):
            guessed.append(
                DependencySpec(
                    "jq", "jq", "Useful for JSON inspection in shell workflows."
                )
            )
        if any(
            word in lowered
            for word in ("archive", "zip", "tar", "descomprimir", "extract")
        ):
            guessed.append(DependencySpec("unzip", "unzip", "Useful for zip archives."))
        if any(word in lowered for word in ("git", "repo", "repository")):
            guessed.append(DependencySpec("git", "git", "Needed for Git repositories."))

        if not guessed:
            return {
                "ok": True,
                "content": (
                    "I could not infer concrete external dependencies for that task.\n\n"
                    "Describe the task with more detail, for example the source type, target format, or required tooling."
                ),
            }

        lines = []
        for dep in guessed:
            present = shutil.which(dep.binary) is not None
            lines.append(
                f"- `{dep.binary}` (`{dep.package_name}`): "
                + ("installed" if present else "missing")
                + f" - {dep.reason}"
            )
        return {
            "ok": True,
            "content": (
                f"Dependency analysis for: {task}\n\n"
                + "\n".join(lines)
                + f"\n\nDetected package manager: `{self.installer.describe()}`."
            ),
        }

    def _run_install_package(self, args: dict) -> dict:
        package_name = args["package_name"]
        result = self.installer.install([package_name])
        if result.get("ok"):
            return {"ok": True, "content": result["message"]}
        return {"ok": True, "content": result["error"]}

    def _run_download_media_from_url(self, args: dict) -> dict:
        url = args["url"]
        destination = args["destination"]
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme not in ("http", "https"):
            return {"ok": True, "content": f"Unsupported URL scheme for `{url}`."}
        ok, path_or_error = self.path_policy.validate_target_path(destination)
        if not ok:
            return {"ok": True, "content": path_or_error}
        destination_dir = Path(path_or_error)
        destination_dir.mkdir(parents=True, exist_ok=True)

        host = urllib.parse.urlparse(url).netloc.lower()
        if any(
            domain in host
            for domain in (
                "youtube.com",
                "youtu.be",
                "vimeo.com",
                "tiktok.com",
                "instagram.com",
                "x.com",
                "twitter.com",
            )
        ):
            cmd = ["yt-dlp", "-P", str(destination_dir), url]
            try:
                result = subprocess.run(
                    cmd, capture_output=True, text=True, timeout=1800
                )
            except Exception as exc:
                return {"ok": True, "content": f"Failed to start yt-dlp: {exc}"}
            if result.returncode != 0:
                detail = (result.stderr or result.stdout).strip()
                return {"ok": True, "content": f"yt-dlp failed: {detail[:500]}"}
            return {
                "ok": True,
                "content": f"Media downloaded with yt-dlp into `{destination_dir}`.",
            }

        filename = Path(urllib.parse.urlparse(url).path).name or "downloaded_file"
        target = destination_dir / filename
        try:
            with (
                urllib.request.urlopen(url, timeout=300) as response,
                open(target, "wb") as handle,
            ):
                shutil.copyfileobj(response, handle)
        except Exception as exc:
            return {"ok": True, "content": f"Failed to download `{url}`: {exc}"}
        return {"ok": True, "content": f"Downloaded `{url}` into `{target}`."}
