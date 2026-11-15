#!/usr/bin/env python3
"""Robust Commons fetcher: REST search first, Action API fallback.

Both endpoints are rate-limited; this module serializes access through one
process and backs off on 429. Usage:
    f = Commons()
    for c in f.search("Eiffel Tower", limit=6): ...
    info = f.imageinfo(["File:..."])
"""
import json
import random
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

UA = ("TokiGo-asset-catalog/1.0 (bundled city imagery research; "
      "https://github.com/NourBeeh/TokiGo)")


class Commons:
    def __init__(self, min_gap=1.6):
        self.min_gap = min_gap
        self._last = 0.0

    def _throttle(self):
        wait = self.min_gap - (time.time() - self._last)
        if wait > 0:
            time.sleep(wait)
        self._last = time.time()

    def _get(self, url, tries=8):
        delay = 3.0
        for attempt in range(tries):
            self._throttle()
            req = urllib.request.Request(url, headers={
                "User-Agent": UA,
                "Accept": "application/json",
            })
            try:
                with urllib.request.urlopen(req, timeout=45) as r:
                    return json.load(r)
            except urllib.error.HTTPError as exc:
                if exc.code == 429:
                    print(f"  429, backing off {delay:.0f}s", file=sys.stderr)
                    time.sleep(delay + random.uniform(0, 2))
                    delay = min(delay * 1.7, 120)
                    continue
                print(f"  HTTP {exc.code}", file=sys.stderr)
                time.sleep(delay)
                delay = min(delay * 1.7, 120)
            except Exception as exc:  # noqa: BLE001
                print(f"  {exc}", file=sys.stderr)
                time.sleep(delay)
                delay = min(delay * 1.7, 120)
        raise RuntimeError(f"failed: {url}")

    def search(self, query, limit=8):
        """File-namespace search via REST; returns list of page dicts."""
        q = urllib.parse.quote(query)
        url = (f"https://commons.wikimedia.org/w/rest.php/v1/search/page"
               f"?q={q}&limit={limit}&filter=File:")
        try:
            data = self._get(url)
        except RuntimeError as exc:
            print(f"  search failed {query}: {exc}", file=sys.stderr)
            return []
        out = []
        for p in data.get("pages", []):
            key = p.get("key") or p.get("title") or ""
            if not key.startswith("File:"):
                continue
            thumb = p.get("thumbnail") or {}
            out.append({
                "title": key,
                "mime": thumb.get("mimetype"),
                "w": thumb.get("width"),
                "h": thumb.get("height"),
                "excerpt": re.sub(r"<[^>]+>", " ", p.get("excerpt") or "")[:200],
            })
        return out

    def imageinfo(self, titles, width=1000):
        """Action API imageinfo with license/author/size/thumb."""
        params = {
            "action": "query", "format": "json", "formatversion": "2",
            "prop": "imageinfo", "iiprop": "url|size|extmetadata|mime",
            "iiurlwidth": str(width), "titles": "|".join(titles),
        }
        url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
        try:
            data = self._get(url)
        except RuntimeError as exc:
            print(f"  imageinfo failed: {exc}", file=sys.stderr)
            return []
        out = []
        for page in data.get("query", {}).get("pages", []):
            ii = (page.get("imageinfo") or [{}])[0]
            em = ii.get("extmetadata", {})

            def meta(k, em=em):
                return re.sub(r"<[^>]+>", "", str(em.get(k, {}).get("value", ""))).strip()

            out.append({
                "title": page.get("title"),
                "mime": ii.get("mime"),
                "w": ii.get("width"), "h": ii.get("height"),
                "thumb": ii.get("thumburl"),
                "file": ii.get("descriptionurl"),
                "license": meta("LicenseShortName"),
                "artist": meta("Artist"),
                "desc": meta("ImageDescription")[:250],
            })
        return out

    def _download_bytes(self, url):
        """Fetch a file's bytes, throttled and with the same retry policy."""
        delay = 3.0
        for _ in range(6):
            self._throttle()
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            try:
                with urllib.request.urlopen(req, timeout=90) as r:
                    return r.read()
            except Exception as exc:  # noqa: BLE001
                print(f"  download failed: {exc}", file=sys.stderr)
                time.sleep(delay)
                delay = min(delay * 1.7, 90)
        raise RuntimeError(f"download failed: {url}")

    def download(self, url, dest):
        self._throttle()
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=90) as r, open(dest, "wb") as fh:
            fh.write(r.read())
        return dest
