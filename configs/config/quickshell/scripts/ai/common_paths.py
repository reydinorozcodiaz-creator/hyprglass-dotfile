from __future__ import annotations

import os


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
