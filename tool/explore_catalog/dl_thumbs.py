#!/usr/bin/env python3
"""Download the thumbnails that failed during the first pass (429s)."""
import glob
import json
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from commons import Commons  # noqa: E402

rows = {}
for f in glob.glob(str(HERE / "slice_*.out.jsonl")):
    for line in open(f):
        r = json.loads(line)
        rows[r["id"]] = r
shortlist = json.loads((HERE / "shortlist.json").read_text())
have = {os.path.basename(f)[:-4] for f in (HERE / "thumbs").glob("*.jpg")}

want = []
for cid, titles in shortlist.items():
    rec = rows[cid]
    tl = [c["title"] for c in rec["candidates"]]
    for t in titles:
        if t in tl:
            idx = tl.index(t)
            key = f"{cid}__{idx}"
            if key not in have:
                cand = rec["candidates"][idx]
                want.append((key, cand["thumb"].split("?")[0]))
print("to fetch:", len(want), file=sys.stderr)

commons = Commons(min_gap=1.2)
done = 0
for key, url in want:
    dest = HERE / "thumbs" / f"{key}.jpg"
    if dest.exists():
        continue
    try:
        dest.write_bytes(commons._download_bytes(url))
        done += 1
    except Exception as exc:  # noqa: BLE001
        print("fail", key, exc, file=sys.stderr)
    time.sleep(0.2)
print("downloaded:", done, file=sys.stderr)
