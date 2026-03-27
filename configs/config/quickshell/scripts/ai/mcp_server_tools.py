from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.parse
import urllib.request

from common_paths import read_path_preview, shell_readable_path
from common_web import lookup_current_time, web_search


DEFAULT_DOCS_DOMAINS = {
    "quickshell": ["quickshell.outfoxxed.me"],
    "qt": ["doc.qt.io"],
    "qml": ["doc.qt.io"],
    "hyprland": ["wiki.hyprland.org"],
    "openai": ["platform.openai.com", "help.openai.com", "openai.com"],
    "python": ["docs.python.org"],
    "mdn": ["developer.mozilla.org"],
    "git": ["git-scm.com"],
    "github": ["docs.github.com"],
    "gemini": ["ai.google.dev", "developers.google.com"],
}

ALL_DOCS_DOMAINS = sorted(
    {
        domain
        for values in DEFAULT_DOCS_DOMAINS.values()
        for domain in values
    }
)


def _tool_result(text: str, structured: dict | None = None, is_error: bool = False) -> dict:
    return {
        "content": [{"type": "text", "text": text}],
        "structuredContent": structured or {},
        "isError": is_error,
    }


def _limit_text(text: str, max_chars: int = 12000) -> str:
    value = str(text or "")
    if len(value) <= max_chars:
        return value
    return value[:max_chars] + "\n... (truncated)"


def _strip_html_document(body: str) -> str:
    text = re.sub(r"(?is)<(script|style|noscript).*?>.*?</\\1>", " ", body)
    text = re.sub(r"(?is)<br\\s*/?>", "\n", text)
    text = re.sub(r"(?is)</p\\s*>", "\n\n", text)
    text = re.sub(r"(?is)<[^>]+>", " ", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _fetch_text(url: str, max_bytes: int = 24000) -> tuple[str, str, str]:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/123 Safari/537.36",
            "Accept": "text/html,application/json,text/plain;q=0.9,*/*;q=0.8",
        },
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        payload = resp.read(max_bytes).decode("utf-8", errors="replace")
        content_type = resp.headers.get("Content-Type", "")

    title = ""
    if "html" in content_type.lower():
        title_match = re.search(r"(?is)<title[^>]*>(.*?)</title>", payload)
        if title_match:
            title = re.sub(r"\s+", " ", title_match.group(1)).strip()
        payload = _strip_html_document(payload)

    return title, payload, content_type


def _resolve_path(path_str: str) -> Path:
    return Path(shell_readable_path(path_str or ".")).resolve(strict=False)


def _run_command(cmd: list[str], cwd: str | None = None, timeout: int = 20) -> tuple[bool, str]:
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError:
        return False, f"Command not found: {cmd[0]}"
    except Exception as exc:
        return False, str(exc)

    output = (result.stdout or "").strip()
    error = (result.stderr or "").strip()
    if result.returncode != 0:
        return False, error or output or f"Command failed with code {result.returncode}"
    return True, output or error


def _git_repo_root(path_str: str) -> tuple[bool, str]:
    path = _resolve_path(path_str)
    cwd = str(path if path.is_dir() else path.parent)
    return _run_command(["git", "-C", cwd, "rev-parse", "--show-toplevel"])


def _render_web_results(prefix: str, query: str, results: list[dict]) -> str:
    lines = [f"{prefix} for `{query}`:"]
    for index, item in enumerate(results, start=1):
        lines.append(f"\n{index}. {item.get('title', 'Untitled')}")
        lines.append(f"   {item.get('url', '')}")
        if item.get("snippet"):
            lines.append(f"   {item['snippet']}")
    return "\n".join(lines)


def _battery_status() -> dict:
    root = Path("/sys/class/power_supply")
    batteries = []
    if root.exists():
        for item in sorted(root.glob("BAT*")):
            try:
                capacity = (item / "capacity").read_text(encoding="utf-8").strip()
                status = (item / "status").read_text(encoding="utf-8").strip()
                batteries.append(
                    {
                        "name": item.name,
                        "capacity": capacity,
                        "status": status,
                    }
                )
            except Exception:
                continue
    return {"available": bool(batteries), "batteries": batteries}


def _network_status() -> dict:
    if shutil.which("nmcli") is None:
        return {"available": False, "error": "nmcli not available"}

    ok_general, general = _run_command(
        ["nmcli", "-t", "-f", "STATE,CONNECTIVITY", "general"],
        timeout=10,
    )
    ok_devices, devices = _run_command(
        ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"],
        timeout=10,
    )
    return {
        "available": ok_general or ok_devices,
        "general": general if ok_general else "",
        "devices": devices if ok_devices else "",
        "error": "" if (ok_general or ok_devices) else general or devices,
    }


def _audio_status() -> dict:
    if shutil.which("wpctl") is None:
        return {"available": False, "error": "wpctl not available"}
    ok_volume, volume = _run_command(
        ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
        timeout=10,
    )
    ok_mic, mic = _run_command(
        ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"],
        timeout=10,
    )
    return {
        "available": ok_volume or ok_mic,
        "sink": volume if ok_volume else "",
        "source": mic if ok_mic else "",
        "error": "" if (ok_volume or ok_mic) else volume or mic,
    }


def _bluetooth_status() -> dict:
    if shutil.which("bluetoothctl") is None:
        return {"available": False, "error": "bluetoothctl not available"}
    ok_show, show = _run_command(["bluetoothctl", "show"], timeout=10)
    ok_devices, devices = _run_command(
        ["bluetoothctl", "devices", "Connected"],
        timeout=10,
    )
    return {
        "available": ok_show or ok_devices,
        "adapter": show if ok_show else "",
        "connected": devices if ok_devices else "",
        "error": "" if (ok_show or ok_devices) else show or devices,
    }


def _package_stats() -> dict:
    if shutil.which("pacman") is None:
        return {
            "available": False,
            "packageManager": "",
            "totalInstalled": 0,
            "nativeInstalled": 0,
            "aurInstalled": 0,
            "aurPackages": [],
            "error": "pacman not available",
        }

    ok_total, total_output = _run_command(["pacman", "-Qq"], timeout=20)
    ok_native, native_output = _run_command(["pacman", "-Qnq"], timeout=20)
    ok_aur, aur_output = _run_command(["pacman", "-Qqm"], timeout=20)
    if not (ok_total and ok_native and ok_aur):
        return {
            "available": False,
            "packageManager": "pacman",
            "totalInstalled": 0,
            "nativeInstalled": 0,
            "aurInstalled": 0,
            "aurPackages": [],
            "error": total_output if not ok_total else native_output if not ok_native else aur_output,
        }

    total_packages = [line.strip() for line in total_output.splitlines() if line.strip()]
    native_packages = [line.strip() for line in native_output.splitlines() if line.strip()]
    aur_packages = [line.strip() for line in aur_output.splitlines() if line.strip()]
    return {
        "available": True,
        "packageManager": "pacman",
        "totalInstalled": len(total_packages),
        "nativeInstalled": len(native_packages),
        "aurInstalled": len(aur_packages),
        "aurPackages": aur_packages,
        "error": "",
    }


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
                "properties": {"query": {"type": "string"}},
                "required": ["query"],
            },
        },
        {
            "name": "read_path",
            "description": "Read a local file or preview a local directory.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "max_bytes": {"type": "integer", "minimum": 256, "maximum": 50000},
                },
                "required": ["path"],
            },
        },
        {
            "name": "search_codebase",
            "description": "Search text in a local codebase using ripgrep when available.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "pattern": {"type": "string"},
                    "root": {"type": "string"},
                    "max_results": {"type": "integer", "minimum": 1, "maximum": 200},
                },
                "required": ["pattern"],
            },
        },
        {
            "name": "list_directory",
            "description": "List files and folders inside a directory.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "max_entries": {"type": "integer", "minimum": 1, "maximum": 300},
                    "include_hidden": {"type": "boolean"},
                },
                "required": ["path"],
            },
        },
        {
            "name": "git_status",
            "description": "Show git status for a repository.",
            "inputSchema": {
                "type": "object",
                "properties": {"path": {"type": "string"}},
            },
        },
        {
            "name": "git_diff",
            "description": "Show git diff for a repository or path.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "ref": {"type": "string"},
                    "max_chars": {"type": "integer", "minimum": 500, "maximum": 30000},
                },
            },
        },
        {
            "name": "git_log",
            "description": "Show recent git commits.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "max_entries": {"type": "integer", "minimum": 1, "maximum": 50},
                },
            },
        },
        {
            "name": "search_docs",
            "description": "Search official documentation domains.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "product": {"type": "string"},
                    "max_results": {"type": "integer", "minimum": 1, "maximum": 10},
                },
                "required": ["query"],
            },
        },
        {
            "name": "fetch_url",
            "description": "Fetch a URL and extract readable text content.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "url": {"type": "string"},
                    "max_bytes": {"type": "integer", "minimum": 512, "maximum": 50000},
                },
                "required": ["url"],
            },
        },
        {
            "name": "read_logs",
            "description": "Read quickshell logs or systemd user journal logs.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "source": {
                        "type": "string",
                        "enum": ["quickshell", "journal_user", "journal_service"],
                    },
                    "lines": {"type": "integer", "minimum": 1, "maximum": 500},
                    "unit": {"type": "string"},
                },
            },
        },
        {
            "name": "get_system_status",
            "description": "Read safe local system status like battery, audio, network, or bluetooth.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "target": {
                        "type": "string",
                        "enum": ["overview", "battery", "network", "audio", "bluetooth"],
                    }
                },
            },
        },
        {
            "name": "get_package_stats",
            "description": "Read local pacman and AUR package counts.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "scope": {
                        "type": "string",
                        "enum": ["overview", "aur"],
                    }
                },
            },
        },
    ]


def handle_call(name: str, arguments: dict) -> dict:
    if name == "web_search":
        query = str(arguments.get("query", "")).strip()
        max_results = int(arguments.get("max_results", 5))
        results = web_search(query, max_results=max_results)
        if not results:
            return _tool_result(
                f"No web results found for `{query}`.",
                {"query": query, "results": []},
            )
        return _tool_result(
            _render_web_results("Web results", query, results),
            {"query": query, "results": results},
        )

    if name == "lookup_current_time":
        query = str(arguments.get("query", "")).strip()
        result = lookup_current_time(query)
        if not result:
            return _tool_result(
                f"Could not resolve a time lookup for `{query}`.",
                {"query": query, "result": None},
                True,
            )
        text = (
            f"Current local time in {result['label']}:\n"
            f"- {result['time_12h']} ({result['time_24h']})\n"
            f"- Timezone: {result['timezone']}\n"
            f"- Date: {result['date']}\n"
            f"- UTC offset: {result['offset']}"
        )
        return _tool_result(text, {"query": query, "result": result})

    if name == "read_path":
        path = str(arguments.get("path", "")).strip()
        preview = read_path_preview(path, max_bytes=int(arguments.get("max_bytes", 12000)))
        if not preview.get("ok"):
            return _tool_result(preview.get("error", "Unable to read path."), preview, True)
        return _tool_result(
            f"Preview for `{preview['path']}`:\n\n{preview['preview']}",
            preview,
        )

    if name == "search_codebase":
        pattern = str(arguments.get("pattern", "")).strip()
        root = _resolve_path(arguments.get("root", "."))
        max_results = max(1, min(200, int(arguments.get("max_results", 60))))
        if not pattern:
            return _tool_result("Missing search pattern.", {"pattern": pattern}, True)
        if not root.exists():
            return _tool_result(f"Root path does not exist: `{root}`.", {"root": str(root)}, True)

        if shutil.which("rg"):
            cmd = [
                "rg",
                "-n",
                "--hidden",
                "--color",
                "never",
                "--max-count",
                str(max_results),
                "-g",
                "!.git",
                "-g",
                "!node_modules",
                pattern,
                str(root),
            ]
            ok, output = _run_command(cmd, timeout=20)
        else:
            ok, output = _run_command(
                ["grep", "-RIn", pattern, str(root)],
                timeout=20,
            )

        if not ok and "Command failed with code 1" not in output:
            return _tool_result(output, {"pattern": pattern, "root": str(root)}, True)

        lines = [line for line in output.splitlines() if line.strip()][:max_results]
        if not lines:
            return _tool_result(
                f"No codebase matches found for `{pattern}` in `{root}`.",
                {"pattern": pattern, "root": str(root), "matches": []},
            )
        return _tool_result(
            "Codebase matches:\n\n" + "\n".join(lines),
            {"pattern": pattern, "root": str(root), "matches": lines},
        )

    if name == "list_directory":
        path = _resolve_path(arguments.get("path", "."))
        max_entries = max(1, min(300, int(arguments.get("max_entries", 120))))
        include_hidden = bool(arguments.get("include_hidden", False))
        if not path.exists():
            return _tool_result(f"Path does not exist: `{path}`.", {"path": str(path)}, True)
        if path.is_file():
            path = path.parent
        if not path.is_dir():
            return _tool_result(f"Not a directory: `{path}`.", {"path": str(path)}, True)

        entries = []
        for item in sorted(path.iterdir(), key=lambda current: (not current.is_dir(), current.name.lower())):
            if not include_hidden and item.name.startswith("."):
                continue
            entries.append(
                {
                    "name": item.name,
                    "kind": "directory" if item.is_dir() else "file",
                }
            )
            if len(entries) >= max_entries:
                break

        lines = [f"- `{item['name']}` ({item['kind']})" for item in entries]
        if not lines:
            lines = [f"`{path}` is empty."]
        return _tool_result(
            f"Contents of `{path}`:\n\n" + "\n".join(lines),
            {"path": str(path), "entries": entries},
        )

    if name == "git_status":
        ok_root, repo_root = _git_repo_root(arguments.get("path", "."))
        if not ok_root:
            return _tool_result(repo_root, {"path": arguments.get("path", ".")}, True)
        ok, output = _run_command(["git", "-C", repo_root, "status", "--short", "--branch"])
        if not ok:
            return _tool_result(output, {"repo": repo_root}, True)
        return _tool_result(
            f"Git status for `{repo_root}`:\n\n{output or 'Working tree clean.'}",
            {"repo": repo_root, "status": output},
        )

    if name == "git_diff":
        ok_root, repo_root = _git_repo_root(arguments.get("path", "."))
        if not ok_root:
            return _tool_result(repo_root, {"path": arguments.get("path", ".")}, True)
        ref = str(arguments.get("ref", "")).strip()
        max_chars = max(500, min(30000, int(arguments.get("max_chars", 12000))))
        cmd = ["git", "-C", repo_root, "diff", "--stat", "--patch", "--unified=2"]
        if ref:
            cmd.append(ref)
        ok, output = _run_command(cmd, timeout=30)
        if not ok:
            return _tool_result(output, {"repo": repo_root, "ref": ref}, True)
        text = _limit_text(output or "No diff.", max_chars=max_chars)
        return _tool_result(
            f"Git diff for `{repo_root}`:\n\n{text}",
            {"repo": repo_root, "ref": ref, "diff": text},
        )

    if name == "git_log":
        ok_root, repo_root = _git_repo_root(arguments.get("path", "."))
        if not ok_root:
            return _tool_result(repo_root, {"path": arguments.get("path", ".")}, True)
        max_entries = max(1, min(50, int(arguments.get("max_entries", 10))))
        ok, output = _run_command(
            ["git", "-C", repo_root, "log", "--oneline", "--decorate", "-n", str(max_entries)],
            timeout=20,
        )
        if not ok:
            return _tool_result(output, {"repo": repo_root}, True)
        return _tool_result(
            f"Recent commits for `{repo_root}`:\n\n{output}",
            {"repo": repo_root, "log": output.splitlines()},
        )

    if name == "search_docs":
        query = str(arguments.get("query", "")).strip()
        product = str(arguments.get("product", "")).strip().lower()
        max_results = int(arguments.get("max_results", 5))
        domains = DEFAULT_DOCS_DOMAINS.get(product, ALL_DOCS_DOMAINS)
        results = web_search(query, max_results=max_results, domains=domains)
        if not results:
            return _tool_result(
                f"No documentation results found for `{query}`.",
                {"query": query, "product": product, "domains": domains, "results": []},
            )
        return _tool_result(
            _render_web_results("Documentation results", query, results),
            {"query": query, "product": product, "domains": domains, "results": results},
        )

    if name == "fetch_url":
        url = str(arguments.get("url", "")).strip()
        if not url:
            return _tool_result("Missing URL.", {"url": url}, True)
        try:
            title, text, content_type = _fetch_text(
                url,
                max_bytes=int(arguments.get("max_bytes", 24000)),
            )
        except Exception as exc:
            return _tool_result(f"Failed to fetch `{url}`: {exc}", {"url": url}, True)

        snippet = _limit_text(text, 12000)
        header = f"Fetched `{url}`"
        if title:
            header += f"\nTitle: {title}"
        if content_type:
            header += f"\nContent-Type: {content_type}"
        return _tool_result(
            header + "\n\n" + snippet,
            {
                "url": url,
                "title": title,
                "contentType": content_type,
                "text": snippet,
            },
        )

    if name == "read_logs":
        source = str(arguments.get("source", "quickshell")).strip()
        lines = max(1, min(500, int(arguments.get("lines", 80))))
        if source == "quickshell":
            ok, output = _run_command(["qs", "log", "-t", str(lines)], timeout=20)
        elif source == "journal_user":
            ok, output = _run_command(
                ["journalctl", "--user", "-n", str(lines), "--no-pager"],
                timeout=20,
            )
        elif source == "journal_service":
            unit = str(arguments.get("unit", "")).strip()
            if not unit:
                return _tool_result(
                    "Missing systemd user unit name.",
                    {"source": source},
                    True,
                )
            ok, output = _run_command(
                ["journalctl", "--user", "-u", unit, "-n", str(lines), "--no-pager"],
                timeout=20,
            )
        else:
            return _tool_result(f"Unsupported log source: `{source}`.", {"source": source}, True)
        if not ok:
            return _tool_result(output, {"source": source}, True)
        trimmed = _limit_text(output, 12000)
        return _tool_result(
            f"Logs from `{source}`:\n\n{trimmed}",
            {"source": source, "logs": trimmed},
        )

    if name == "get_system_status":
        target = str(arguments.get("target", "overview")).strip() or "overview"
        battery = _battery_status()
        network = _network_status()
        audio = _audio_status()
        bluetooth = _bluetooth_status()

        data = {
            "battery": battery,
            "network": network,
            "audio": audio,
            "bluetooth": bluetooth,
        }
        if target != "overview":
            data = {target: data.get(target, {})}

        lines = []
        if target in ("overview", "battery"):
            if battery.get("available"):
                for item in battery["batteries"]:
                    lines.append(
                        f"Battery {item['name']}: {item['capacity']}% · {item['status']}"
                    )
            else:
                lines.append("Battery: unavailable")
        if target in ("overview", "network"):
            if network.get("available"):
                if network.get("general"):
                    lines.append("Network general: " + network["general"])
                if network.get("devices"):
                    lines.append("Network devices:\n" + network["devices"])
            else:
                lines.append("Network: unavailable")
        if target in ("overview", "audio"):
            if audio.get("available"):
                if audio.get("sink"):
                    lines.append("Audio sink: " + audio["sink"])
                if audio.get("source"):
                    lines.append("Audio source: " + audio["source"])
            else:
                lines.append("Audio: unavailable")
        if target in ("overview", "bluetooth"):
            if bluetooth.get("available"):
                if bluetooth.get("adapter"):
                    lines.append("Bluetooth adapter:\n" + bluetooth["adapter"])
                if bluetooth.get("connected"):
                    lines.append("Bluetooth connected:\n" + bluetooth["connected"])
            else:
                lines.append("Bluetooth: unavailable")

        return _tool_result(
            "\n\n".join(lines),
            {"target": target, "status": data},
        )

    if name == "get_package_stats":
        scope = str(arguments.get("scope", "overview")).strip() or "overview"
        stats = _package_stats()
        if not stats.get("available"):
            return _tool_result(
                stats.get("error", "Package stats unavailable."),
                stats,
                True,
            )

        aur_packages = stats.get("aurPackages", [])
        lines = []
        if scope == "aur":
            lines.append(f"AUR packages installed: {stats['aurInstalled']}")
        else:
            lines.extend(
                [
                    f"Package manager: {stats['packageManager']}",
                    f"Total installed packages: {stats['totalInstalled']}",
                    f"Official/native packages: {stats['nativeInstalled']}",
                    f"AUR/foreign packages: {stats['aurInstalled']}",
                ]
            )
        if aur_packages:
            lines.append("Sample AUR packages: " + ", ".join(aur_packages[:12]))
        else:
            lines.append("No AUR packages were detected.")

        return _tool_result(
            "\n".join(lines),
            stats,
        )

    raise ValueError(f"Unknown tool: {name}")
