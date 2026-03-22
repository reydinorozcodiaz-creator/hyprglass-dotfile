#!/usr/bin/env python3
"""
GitHub Copilot OAuth helper for Quickshell AI Station.
Uses only Python stdlib (urllib, json).

Commands (via argv[1]):
  device_code   — Start device flow. Prints JSON: {device_code, user_code, verification_uri, expires_in, interval}
  poll <device_code> <interval>  — Poll for OAuth token. Prints JSON: {ok, token} or {ok:false, error}
  copilot_token <oauth_token>    — Exchange OAuth token for a short-lived Copilot API token.
                                   Prints JSON: {ok, token, expires_at}
"""

import json
import sys
import time
import urllib.request
import urllib.error
import urllib.parse

# GitHub OAuth App credentials for Copilot access.
# These are the well-known public client IDs used by open-source Copilot clients.
# They are intentionally public (client_secret is not required for device flow).
GITHUB_CLIENT_ID = "Iv1.b507a08c87ecfe98"  # GitHub CLI / Copilot app client ID

DEVICE_CODE_URL    = "https://github.com/login/device/code"
TOKEN_URL          = "https://github.com/login/oauth/access_token"
COPILOT_TOKEN_URL  = "https://api.github.com/copilot_internal/v2/token"


def _post(url: str, data: dict, headers: dict = None) -> dict:
    body = urllib.parse.urlencode(data).encode()
    h = {"Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded"}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, data=body, headers=h, method="POST")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def _get(url: str, token: str) -> dict:
    req = urllib.request.Request(url, headers={
        "Authorization": f"token {token}",
        "Accept": "application/json",
    })
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def cmd_device_code():
    result = _post(DEVICE_CODE_URL, {
        "client_id": GITHUB_CLIENT_ID,
        "scope": "",  # Copilot doesn't need extra scopes beyond the app grant
    })
    if "device_code" not in result:
        print(json.dumps({"ok": False, "error": result.get("error_description", str(result))}))
        return
    print(json.dumps({
        "ok": True,
        "device_code":       result["device_code"],
        "user_code":         result["user_code"],
        "verification_uri":  result.get("verification_uri", "https://github.com/login/device"),
        "expires_in":        result.get("expires_in", 900),
        "interval":          result.get("interval", 5),
    }))


def cmd_poll(device_code: str, interval: int):
    result = _post(TOKEN_URL, {
        "client_id":   GITHUB_CLIENT_ID,
        "device_code": device_code,
        "grant_type":  "urn:ietf:params:oauth:grant-type:device_code",
    })
    error = result.get("error", "")
    if error == "authorization_pending":
        print(json.dumps({"ok": False, "pending": True}))
    elif error == "slow_down":
        print(json.dumps({"ok": False, "pending": True, "slow_down": True}))
    elif error:
        print(json.dumps({"ok": False, "error": result.get("error_description", error)}))
    elif "access_token" in result:
        print(json.dumps({"ok": True, "token": result["access_token"]}))
    else:
        print(json.dumps({"ok": False, "error": "Unexpected response: " + str(result)}))


def cmd_copilot_token(oauth_token: str):
    try:
        result = _get(COPILOT_TOKEN_URL, oauth_token)
        token = result.get("token")
        if not token:
            print(json.dumps({"ok": False, "error": "No Copilot token in response. Check your Copilot subscription."}))
            return
        print(json.dumps({
            "ok":         True,
            "token":      token,
            "expires_at": result.get("expires_at", 0),
        }))
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = e.read().decode()
        except Exception:
            pass
        if e.code == 401:
            print(json.dumps({"ok": False, "error": "OAuth token invalid or expired. Please re-authorize."}))
        elif e.code == 403:
            print(json.dumps({"ok": False, "error": "No active Copilot subscription on this account."}))
        else:
            print(json.dumps({"ok": False, "error": f"HTTP {e.code}: {body or str(e)}"}))
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if cmd == "device_code":
            cmd_device_code()
        elif cmd == "poll":
            device_code = sys.argv[2]
            interval    = int(sys.argv[3]) if len(sys.argv) > 3 else 5
            cmd_poll(device_code, interval)
        elif cmd == "copilot_token":
            oauth_token = sys.argv[2]
            cmd_copilot_token(oauth_token)
        else:
            print(json.dumps({"ok": False, "error": f"Unknown command: {cmd}"}))
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))
