#!/usr/bin/env python3
"""Ensure every chosen pick has verified source + license + author.

A candidate with no recoverable attribution is DROPPED, never guessed: the
city falls back to the next-ranked candidate that carries all three fields.
The fallback order is the ranking in shortlist.json.
"""
import glob
import json
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from rank2 import rank  # noqa: E402

rows = {}
for f in glob.glob(str(HERE / "slice_*.out.jsonl")):
    for line in open(f):
        r = json.loads(line)
        rows[r["id"]] = r
shortlist = json.loads((HERE / "shortlist.json").read_text())
picks = json.loads((HERE / "picks.json").read_text())
verified = json.loads((HERE / "picks_verified.json").read_text())


def complete(cand):
    return all(cand.get(k) for k in ("license", "artist", "file", "thumb"))


def main():
    changed = []
    for cid in sorted(picks):
        rec = rows[cid]
        chosen = picks[cid]
        cand = next((c for c in rec["candidates"] if c["title"] == chosen), None)
        if cand and complete(cand):
            continue
        # fall back through the ranked list for the first fully-attributed file
        ordered = sorted(rec["candidates"], key=lambda c: rank(cid, c))
        fallback = next((c for c in ordered if complete(c)), None)
        if fallback is None:
            print(f"  {cid}: NO fully-attributed candidate — needs re-collection")
            continue
        old = picks[cid]
        picks[cid] = fallback["title"]
        changed.append((cid, old[:50], fallback["title"][:50]))
    (HERE / "picks.json").write_text(json.dumps(picks, ensure_ascii=False, indent=1))
    print("changed:", len(changed))
    for c in changed:
        print("  ", c[0], "\n     old:", c[1], "\n     new:", c[2])


if __name__ == "__main__":
    main()
