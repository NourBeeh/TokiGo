#!/usr/bin/env python3
"""Rank candidates per city, hardened against the failures the visual pass found.

The first ranking was fooled by filenames: a Chi-Rho carving named
"Chrisme Colosseum Rome Italy.jpg" outranked the real Colosseum because the
title contains "Colosseum". Metadata alone cannot tell a landmark from a
carving, a security camera or a museum interior — so this ranking is only a
SHORTLISTING tool, and every pick still goes through visual review.

Hard penalties (strong signals of a non-landmark file):
  carvings / reliefs / inscriptions / mosaics / chi-rho / chrisme
  security cameras, scaffolding, construction
  interiors, museum displays, models/dioramas
  paintings, engravings, lithographs, maps, posters
  close-ups and detail crops of objects
"""
import glob
import json
import re
from pathlib import Path

HERE = Path(__file__).parent

BAD = re.compile(
    r"\b(chrisme|chi-?rho|relief|carving|carved|inscription|mosaic|fresco|"
    r"security camera|cc tv|cctv|camera|scaffold|construction|crane|"
    r"interior|intern|inside|museum|diorama|model of|maquette|"
    r"paint|lithograph|engrav|etching|woodcut|poster|map |plan of|"
    r"close-?up|detail of|crop|macro|texture|pattern|"
    r"banner|logo|icon|diagram|ticket|menu|sign |"
    r"parking|taxi|car |bus |traffic|protest|politician|obama|"
    r"statue of liberty.*(model|replica)|replica)\b", re.I)

GOOD = re.compile(
    r"\b(pyramid|sphinx|colosseum|coliseum|eiffel|skyline|cathedral|"
    r"mosque|temple|palace|castle|bridge|harbour|harbor|opera house|"
    r"acropolis|parthenon|forum|pantheon|basilica|church|monument|"
    r"square|plaza|canal|river|waterfront|corniche|beach|lagoon|market|"
    r"medina|bazaar|ruins|citadel|fort|skyscraper|downtown|marina|dome|"
    r"minaret|bell tower|clock tower|arch|tower|mountain|lake|fjord|"
    r"waterfall|gardens|park|panorama|aerial|view of|view from)\b", re.I)


def rank(cid, c):
    lic = c["license"]
    lic_score = 0 if (lic.startswith("CC0") or lic.startswith("Public domain")) \
        else (1 if lic.startswith("CC BY") else 2)
    text = f"{c.get('desc', '')} {c['title']}"
    name = cid.replace("_", " ")
    words = [w for w in re.findall(r"[a-z]{4,}", name.lower())]
    name_hit = any(w in text.lower() for w in words)
    bad = bool(BAD.search(text))
    good = bool(GOOD.search(text))
    w = c["w"]
    size_score = 0 if 1600 <= w <= 6000 else (1 if w > 6000 else 2)
    ratio = w / c["h"] if c["h"] else 1
    ratio_score = 0 if 1.0 <= ratio <= 2.2 else 1
    return (bad, 0 if good else 1, lic_score, 0 if name_hit else 1,
            size_score, ratio_score)


def main():
    rows = {}
    for f in glob.glob(str(HERE / "slice_*.out.jsonl")):
        for line in open(f):
            r = json.loads(line)
            rows[r["id"]] = r
    shortlist = {}
    for cid, rec in rows.items():
        ordered = sorted(rec["candidates"], key=lambda c: rank(cid, c))
        shortlist[cid] = [c["title"] for c in ordered[:3]]
    (HERE / "shortlist.json").write_text(
        json.dumps(shortlist, ensure_ascii=False, indent=1))
    print("shortlisted", len(shortlist))
    for cid in ("rome", "cairo", "paris", "istanbul", "rio_de_janeiro"):
        print(cid, "->", [t[:52] for t in shortlist[cid]])


if __name__ == "__main__":
    main()
