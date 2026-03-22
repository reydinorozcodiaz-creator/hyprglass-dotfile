#!/usr/bin/env python3

from __future__ import annotations

from datetime import datetime
import html
import json
import re
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo


WEB_SEARCH_URL = "https://html.duckduckgo.com/html/"
OPEN_METEO_GEOCODE_URL = "https://geocoding-api.open-meteo.com/v1/search"


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
        headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"},
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
