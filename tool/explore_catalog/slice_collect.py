#!/usr/bin/env python3
"""Collect verified Commons candidates for one slice of the city catalog.

Writes <slice>.out.jsonl. Resume-safe. Never invents metadata.
"""
import argparse
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from commons import Commons  # noqa: E402

ALLOWED_PREFIXES = ("CC BY", "CC0", "Public domain")


def licensed(rec):
    """True when the Commons license is a permissive one we can attribute.

    The API returns concrete versions ('CC BY-SA 3.0', 'CC BY 4.0'), so the
    check is a prefix match against the families we accept. Anything else —
    NC, ND, fair-use, 'Copyright free' — is rejected rather than guessed at.
    """
    name = rec["license"]
    return any(name.startswith(p) for p in ALLOWED_PREFIXES)


def usable(recs):
    out = []
    for r in recs:
        if not licensed(r):
            continue
        if r["mime"] not in ("image/jpeg", "image/png"):
            continue
        if not (r["w"] and r["h"]):
            continue
        if r["w"] < 1400 or r["w"] / r["h"] < 0.8:
            continue
        out.append(r)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("slice_file")
    ap.add_argument("--gap", type=float, default=1.5)
    args = ap.parse_args()

    cities = json.loads((HERE / args.slice_file).read_text())["catalog"]
    out_path = HERE / (Path(args.slice_file).stem + ".out.jsonl")
    done = set()
    if out_path.exists():
        for line in out_path.read_text().splitlines():
            try:
                done.add(json.loads(line)["id"])
            except Exception:  # noqa: BLE001
                pass

    commons = Commons(min_gap=args.gap)
    with out_path.open("a" if done else "w") as fh:
        for city in cities:
            if city["id"] in done:
                print(f"skip {city['id']}", file=sys.stderr, flush=True)
                continue
            titles = []
            for q in city["q"]:
                for hit in commons.search(q, limit=10):
                    if hit["title"] not in titles:
                        titles.append(hit["title"])
                time.sleep(0.3)
            infos = []
            for i in range(0, min(len(titles), 25), 15):
                infos.extend(commons.imageinfo(titles[i:i + 15]))
                time.sleep(0.3)
            keep = usable(infos)[:10]
            fh.write(json.dumps({
                "id": city["id"], "name": city["name"],
                "country": city["country"], "region": city["region"],
                "candidates": keep,
            }, ensure_ascii=False) + "\n")
            fh.flush()
            print(f"{city['id']}: {len(keep)} usable / {len(infos)} info",
                  file=sys.stderr, flush=True)


if __name__ == "__main__":
    main()
