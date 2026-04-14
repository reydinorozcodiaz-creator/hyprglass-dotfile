#!/usr/bin/env python3

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


VAR_RE = re.compile(r"^(\$[A-Za-z0-9_]+)\s*=\s*(.+)$")
BIND_RE = re.compile(r"^(bind[a-z]*)\s*=\s*(.+)$", re.IGNORECASE)


def read_text(path: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def strip_inline_comment(text: str) -> str:
    if "#" in text:
        text = text.split("#", 1)[0]
    return text.rstrip()


def clean_section_title(text: str) -> str:
    title = re.sub(r"^#+\s*", "", text).strip()
    title = re.sub(r"\s*#+\s*$", "", title).strip()
    title = re.sub(r"^[-\s]+", "", title).strip()
    title = re.sub(r"[-\s]+$", "", title).strip()
    title = re.sub(r"\s+", " ", title)
    return title or "Other"


def parse_variables(*texts: str) -> dict[str, str]:
    raw_vars: dict[str, str] = {"$HOME": str(Path.home())}

    for text in texts:
        for raw_line in text.splitlines():
            line = strip_inline_comment(raw_line).strip()
            match = VAR_RE.match(line)
            if match:
                raw_vars[match.group(1)] = match.group(2).strip()

    resolved: dict[str, str] = {}

    def resolve_value(value: str, stack: set[str]) -> str:
        def repl(match: re.Match[str]) -> str:
            name = match.group(0)
            if name not in raw_vars:
                return name
            if name in stack:
                return raw_vars[name]
            return resolve_value(raw_vars[name], stack | {name})

        return re.sub(r"\$[A-Za-z0-9_]+", repl, value)

    for key, value in raw_vars.items():
        resolved[key] = resolve_value(value, {key})

    return resolved


def split_bind_fields(spec: str) -> list[str]:
    fields: list[str] = []
    current: list[str] = []
    commas = 0

    for ch in spec:
        if ch == "," and commas < 3:
            fields.append("".join(current).strip())
            current = []
            commas += 1
        else:
            current.append(ch)

    fields.append("".join(current).strip())
    while len(fields) < 4:
        fields.append("")
    return fields


def resolve_variables(text: str, variables: dict[str, str]) -> str:
    def repl(match: re.Match[str]) -> str:
        name = match.group(0)
        return variables.get(name, name)

    return re.sub(r"\$[A-Za-z0-9_]+", repl, text)


def format_key_token(token: str) -> str:
    raw = token.strip()
    if not raw:
        return ""

    aliases = {
        "super": "Super",
        "alt": "Alt",
        "ctrl": "Ctrl",
        "control": "Ctrl",
        "shift": "Shift",
        "return": "Return",
        "enter": "Enter",
        "tab": "Tab",
        "print": "Print",
        "left": "Left",
        "right": "Right",
        "up": "Up",
        "down": "Down",
        "mouse_down": "Mouse Wheel Down",
        "mouse_up": "Mouse Wheel Up",
        "mouse:272": "Mouse Left",
        "mouse:273": "Mouse Right",
        "xf86audioraisevolume": "Volume Up",
        "xf86audiolowervolume": "Volume Down",
        "xf86audiomute": "Volume Mute",
        "xf86monbrightnessup": "Brightness Up",
        "xf86monbrightnessdown": "Brightness Down",
    }

    lower = raw.lower()
    if lower in aliases:
        return aliases[lower]
    if re.fullmatch(r"f\d+", raw, re.IGNORECASE):
        return raw.upper()
    if len(raw) == 1:
        return raw.upper()
    return raw


def format_shortcut(modifiers: str, key: str, variables: dict[str, str]) -> str:
    resolved_modifiers = resolve_variables(modifiers, variables)
    resolved_key = resolve_variables(key, variables)
    parts = [format_key_token(token) for token in resolved_modifiers.split() if token.strip()]
    if resolved_key:
        parts.append(format_key_token(resolved_key))
    return " + ".join(parts) if parts else "Unbound"


def shorten_path(text: str) -> str:
    home = str(Path.home())
    return text.replace(home, "~")


def action_label(dispatcher: str) -> str:
    labels = {
        "exec": "Exec",
        "global": "Global",
        "killactive": "Kill active",
        "exit": "Exit Hyprland",
        "togglefloating": "Toggle floating",
        "pseudo": "Pseudo",
        "togglesplit": "Toggle split",
        "cyclenext": "Cycle next",
        "workspace": "Workspace",
        "movefocus": "Move focus",
        "fullscreen": "Fullscreen",
        "movetoworkspace": "Move to workspace",
        "togglespecialworkspace": "Toggle special workspace",
        "movewindow": "Move window",
        "resizewindow": "Resize window",
    }
    return labels.get(dispatcher.lower(), dispatcher)


def format_action(dispatcher: str, argument: str, variables: dict[str, str]) -> str:
    resolved_argument = shorten_path(resolve_variables(argument, variables))
    label = action_label(dispatcher)
    return f"{label}: {resolved_argument}" if resolved_argument else label


def icon_for_title(title: str) -> str:
    lower = title.lower()
    if any(word in lower for word in ("app", "rofi", "launcher")):
        return "󰀻"
    if "window" in lower:
        return "󰖯"
    if "workspace" in lower:
        return "󰍹"
    if "volume" in lower or "brightness" in lower:
        return "󰎈"
    if "theme" in lower or "wallpaper" in lower:
        return "󰸉"
    if "clipboard" in lower:
        return "󰅍"
    if "lock" in lower:
        return "󰌾"
    return "󰌌"


def parse_bind_line(bind_type: str, spec: str, variables: dict[str, str]) -> dict[str, str] | None:
    fields = split_bind_fields(strip_inline_comment(spec).strip())
    if len(fields) < 3:
        return None

    modifiers = fields[0] if len(fields) > 0 else ""
    key = fields[1] if len(fields) > 1 else ""
    dispatcher = fields[2] if len(fields) > 2 else ""
    argument = fields[3] if len(fields) > 3 else ""

    return {
        "keys": format_shortcut(modifiers, key, variables),
        "action": format_action(dispatcher, argument, variables),
        "rawAction": dispatcher + (f", {argument}" if argument else ""),
        "bindType": bind_type,
    }


def parse_sections(text: str, variables: dict[str, str]) -> list[dict[str, object]]:
    sections: list[dict[str, object]] = []
    pending_comments: list[str] = []
    current_section: dict[str, object] | None = None

    def flush_section() -> None:
        nonlocal current_section
        if current_section and current_section["keybinds"]:
            sections.append(current_section)
        current_section = None

    for raw_line in text.splitlines():
        trimmed = raw_line.strip()

        if not trimmed:
            flush_section()
            pending_comments = []
            continue

        if trimmed.startswith("#"):
            pending_comments.append(clean_section_title(trimmed))
            continue

        match = BIND_RE.match(trimmed)
        if not match:
            continue

        if current_section is None:
            title = pending_comments[0] if pending_comments else "Other"
            current_section = {
                "title": title,
                "icon": icon_for_title(title),
                "keybinds": [],
            }

        entry = parse_bind_line(match.group(1), match.group(2), variables)
        if entry:
            current_section["keybinds"].append(entry)

        pending_comments = []

    flush_section()
    return sections


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print("usage: parse-hypr-keybinds.py <hyprland.conf> <10-defaults.conf> <70-keybinds.conf>", file=sys.stderr)
        return 2

    main_text = read_text(argv[1])
    defaults_text = read_text(argv[2])
    keybinds_text = read_text(argv[3])
    variables = parse_variables(main_text, defaults_text)
    sections = parse_sections(keybinds_text, variables)
    print(json.dumps(sections, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
