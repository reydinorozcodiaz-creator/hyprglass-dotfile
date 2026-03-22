#!/usr/bin/env python3
import json
import os
import subprocess
import sys

STATE_FILE = os.path.expanduser("~/.config/quickshell/state.json")

def load_pinned():
    try:
        with open(STATE_FILE, "r") as f:
            data = json.load(f)
            return set(data.get("clipboard", {}).get("pinned", []))
    except Exception:
        return set()

def main():
    pinned_texts = load_pinned()
    if not pinned_texts:
        # If nothing is pinned, fast path is just 'cliphist wipe'
        subprocess.run(["cliphist", "wipe"], check=False)
        return

    try:
        # Get list of all clipboard entries
        result = subprocess.run(["cliphist", "list"], capture_output=True, text=True, check=True)
        lines = result.stdout.strip().split("\n")
    except Exception as e:
        print(f"Error reading cliphist: {e}", file=sys.stderr)
        return

    for line in lines:
        if not line:
            continue
        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue
        text = parts[1]
        
        # If the text is not in the pinned list, delete it
        if text not in pinned_texts:
            try:
                # cliphist delete expects the full line (id + tab + text) from stdin
                subprocess.run(
                    ["cliphist", "delete"],
                    input=line,
                    text=True,
                    check=False
                )
            except Exception as e:
                print(f"Error deleting entry: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
