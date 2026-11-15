#!/usr/bin/env python3
"""Render 2-city review sheets (6 photos each) — small enough for a vision model."""
import glob
import html
import json
from pathlib import Path

from weasyprint import HTML

HERE = Path(__file__).parent
OUT = HERE / "sheets2"
OUT.mkdir(exist_ok=True)

rows = {}
for f in glob.glob(str(HERE / "slice_*.out.jsonl")):
    for line in open(f):
        r = json.loads(line)
        rows[r["id"]] = r
shortlist = json.loads((HERE / "shortlist.json").read_text())
thumbs = {p.stem: p.name for p in (HERE / "thumbs").glob("*.jpg")}

CSS = """
@page { size: 920px 780px; margin: 0; }
body { font: 10px/1.2 system-ui; margin: 0; background: #fff; color: #111; }
.city { border-bottom: 2px solid #c00; padding: 4px 0; }
h1 { font-size: 13px; margin: 4px 6px; }
grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4px; padding: 4px; }
figure { margin: 0; border: 1px solid #bbb; border-radius: 3px; overflow: hidden; }
img { width: 100%; height: 250px; object-fit: cover; display: block; background: #eee; }
.miss { height: 250px; background: #eee; color: #999; display: flex;
        align-items: center; justify-content: center; }
figcaption { padding: 3px; font-size: 9px; }
code { color: #06c; font-size: 8px; word-break: break-all; }
"""


def card(cid, title, label):
    rec = rows[cid]
    tl = [c["title"] for c in rec["candidates"]]
    src = thumbs.get(f"{cid}__{tl.index(title)}") if title in tl else None
    img = f'<img src="{HERE}/thumbs/{src}"/>' if src else '<div class="miss">no thumb</div>'
    return (f'<figure>{img}<figcaption><b>{label}</b><br>'
            f'<code>{html.escape(title[:62])}</code></figcaption></figure>')


def main():
    ids = sorted(shortlist)
    per = 2
    for n in range(0, len(ids), per):
        batch = ids[n:n + per]
        blocks = []
        for cid in batch:
            rec = rows[cid]
            cells = "".join(card(cid, t, f"#{i}")
                            for i, t in enumerate(shortlist[cid][:3]))
            blocks.append(f'<div class="city"><h1>{cid} — {rec["name"]}, '
                          f'{rec["country"]}</h1><grid>{cells}</grid></div>')
        pdf = OUT / f"pair_{n // per:02d}.pdf"
        HTML(string=f"<style>{CSS}</style>" + "".join(blocks),
              base_url=str(HERE)).write_pdf(str(pdf))
        print("rendered", pdf.name, batch)


if __name__ == "__main__":
    main()
