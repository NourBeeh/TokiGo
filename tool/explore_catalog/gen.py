#!/usr/bin/env python3
"""Generate the Dart Explore catalog data + JSON asset manifest.

Inputs:
  --cities      cities.json          catalog definition (id/name/country/region/queries)
  --candidates  slice_*.out.jsonl    verified Commons metadata per city
  --picks       picks.json           city id -> chosen candidate title
  --out         destination .dart    (generated catalog)
  --out-manifest destination JSON    (bundled asset manifest)

Emits ONLY facts present in the candidate records: license short name, author,
source file URL, description. Refuses to emit a city whose chosen candidate is
not in the verified candidate set, so a fabricated license or source cannot
enter the app.
"""
import argparse
import json
import re
from pathlib import Path

MOODS = {
    "cairo": ["city", "nature"], "luxor": ["nature"], "aswan": ["nature"],
    "sharm_el_sheikh": ["beach"], "hurghada": ["beach"],
    "alexandria": ["beach", "city"], "marrakech": ["city", "shopping"],
    "casablanca": ["city", "beach"], "fes": ["city", "shopping"],
    "tunis": ["city", "beach"], "istanbul": ["city", "shopping"],
    "goreme": ["nature"], "dubai": ["city", "shopping", "beach"],
    "abu_dhabi": ["city"], "doha": ["city", "shopping"],
    "muscat": ["city", "beach"], "amman": ["city"], "petra": ["nature"],
    "paris": ["city", "shopping"], "nice": ["beach", "city"],
    "lyon": ["city"], "rome": ["city"], "venice": ["city", "honeymoon"],
    "milan": ["city", "shopping"], "florence": ["city"],
    "naples": ["city", "beach"], "barcelona": ["city", "beach"],
    "madrid": ["city", "shopping"], "seville": ["city"],
    "lisbon": ["city", "beach"], "porto": ["city"],
    "london": ["city", "shopping"], "edinburgh": ["city", "nature"],
    "amsterdam": ["city"], "prague": ["city"], "vienna": ["city"],
    "berlin": ["city"], "munich": ["city", "snow"],
    "zurich": ["city", "snow"], "athens": ["city", "beach"],
    "santorini": ["beach", "honeymoon"], "reykjavik": ["nature"],
    "oslo": ["city", "nature"], "stockholm": ["city"],
    "copenhagen": ["city"], "helsinki": ["city", "snow"],
    "budapest": ["city"], "tokyo": ["city", "shopping"],
    "kyoto": ["city", "nature"], "osaka": ["city", "shopping"],
    "seoul": ["city", "shopping"],
    "bangkok": ["city", "shopping", "beach"],
    "singapore": ["city", "shopping"], "denpasar": ["beach", "nature"],
    "jakarta": ["city"], "kuala_lumpur": ["city", "shopping"],
    "hong_kong": ["city", "shopping"], "shanghai": ["city", "shopping"],
    "beijing": ["city"], "agra": ["city"], "new_delhi": ["city"],
    "male": ["beach", "honeymoon"], "colombo": ["city", "beach"],
    "kathmandu": ["nature"], "new_york": ["city", "shopping"],
    "los_angeles": ["city", "beach"], "san_francisco": ["city"],
    "miami": ["beach", "city"], "las_vegas": ["city", "shopping"],
    "honolulu": ["beach", "nature"], "cancun": ["beach"],
    "mexico_city": ["city"], "havana": ["city", "beach"],
    "panama_city": ["city", "beach"], "rio_de_janeiro": ["beach", "city"],
    "sao_paulo": ["city"], "buenos_aires": ["city"], "lima": ["city"],
    "cusco": ["nature"], "cartagena": ["beach", "city"],
    "santiago": ["city", "nature"], "cape_town": ["nature", "beach"],
    "johannesburg": ["city"], "nairobi": ["nature"],
    "zanzibar_city": ["beach"], "port_louis": ["beach"],
    "sydney": ["city", "beach"], "melbourne": ["city"],
    "brisbane": ["city", "beach"], "queenstown": ["nature", "snow"],
    "auckland": ["city", "nature"], "suva": ["beach", "nature"],
}
AUDIENCES = {
    "santorini": ["honeymoon"], "venice": ["honeymoon"], "male": ["honeymoon"],
    "cancun": ["youth"], "dubai": ["families"], "paris": ["families"],
    "rome": ["families"], "london": ["families"], "tokyo": ["families"],
    "new_york": ["families"], "sydney": ["families"],
    "copenhagen": ["families"], "rio_de_janeiro": ["youth"],
    "bangkok": ["youth"], "lisbon": ["youth"], "barcelona": ["youth"],
    "amsterdam": ["youth"], "prague": ["youth"], "budapest": ["youth"],
    "las_vegas": ["youth"], "miami": ["youth"], "nairobi": ["youth"],
    "cusco": ["youth"], "queenstown": ["youth"], "cairo": ["families"],
    "istanbul": ["families"], "athens": ["families"], "oslo": ["families"],
    "helsinki": ["families"], "zurich": ["families"],
}


def dart_string(value: str) -> str:
    """Escape a value for a Dart single-quoted string literal.

    Newlines and other control characters are flattened to spaces: a raw
    newline inside a literal silently terminates it and turns the rest of the
    description into code.
    """
    v = value.replace("\\", "\\\\").replace("'", "\\'")
    v = "".join(c if ord(c) >= 32 else " " for c in v)
    v = " ".join(v.split())
    return "'" + v + "'"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cities", required=True)
    ap.add_argument("--candidates", nargs="+", required=True)
    ap.add_argument("--picks", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--out-manifest", required=True)
    args = ap.parse_args()

    cities = json.loads(Path(args.cities).read_text())["catalog"]
    picks = json.loads(Path(args.picks).read_text())

    by_title = {}
    for path in args.candidates:
        p = Path(path)
        if not p.exists():
            continue
        for line in p.read_text().splitlines():
            rec = json.loads(line)
            for cand in rec.get("candidates", []):
                by_title[cand["title"]] = (rec, cand)

    entries, problems = [], []
    for city in cities:
        cid = city["id"]
        title = picks.get(cid)
        if not title:
            problems.append(f"{cid}: no pick recorded")
            continue
        hit = by_title.get(title)
        if hit is None:
            problems.append(f"{cid}: pick not in verified candidates")
            continue
        rec, cand = hit
        if rec["id"] != cid:
            problems.append(f"{cid}: pick belongs to {rec['id']}")
            continue
        missing = [f for f in ("license", "artist", "file", "thumb", "w", "h")
                   if not cand.get(f)]
        if missing:
            problems.append(f"{cid}: pick missing {missing}")
            continue
        entries.append({"city": city, "cand": cand})

    if problems:
        print("PROBLEMS:")
        for p in problems:
            print("  " + p)
        raise SystemExit(1)

    lines = [
        "// GENERATED FILE — do not edit by hand.",
        "// Regenerate with tool/explore_catalog/generate_catalog.py.",
        "//",
        "// Each entry carries the VERIFIED photo metadata for its own bundled",
        "// asset (license, author, source). The full record — including the",
        "// source file URL the image was downloaded from — lives in",
        "// assets/explore/cities/manifest.json.",
        "library;",
        "",
        "import 'package:tokigo/features/home/domain/explore_catalog.dart';",
        "",
        "/// The complete Explore catalog, in display order.",
        "const List<ExploreCity> kExploreCities = <ExploreCity>[",
    ]
    for e in entries:
        c, cand = e["city"], e["cand"]
        cid = c["id"]
        lines.append("  ExploreCity(")
        lines.append(f"    id: {dart_string(cid)},")
        lines.append(f"    name: {dart_string(c['name'])},")
        lines.append(f"    country: {dart_string(c['country'])},")
        lines.append(f"    region: {dart_string(c['region'])},")
        lines.append(f"    asset: 'assets/explore/cities/{cid}.webp',")
        if cand.get("desc"):
            lines.append(f"    subtitle: {dart_string(cand['desc'][:80])},")
        moods = MOODS.get(cid, [])
        if moods:
            lines.append("    tags: <String>["
                         + ", ".join(dart_string(m) for m in moods) + "],")
        auds = AUDIENCES.get(cid, [])
        if auds:
            lines.append("    audiences: <String>["
                         + ", ".join(dart_string(a) for a in auds) + "],")
        lines.append(f"    imageCredit: {dart_string(cand['artist'])},")
        lines.append(f"    imageLicense: {dart_string(cand['license'])},")
        lines.append(f"    imageSource: {dart_string(cand['file'])},")
        lines.append("  ),")
    lines.append("];")
    Path(args.out).write_text("\n".join(lines) + "\n")

    manifest = {
        "schema": "tokigo.explore-images.v1",
        "licenseNote": (
            "Licenses are the Wikimedia Commons license attached to the source "
            "file at the recorded URL. Attribution is shown on the city page."),
        "images": [{
            "cityId": e["city"]["id"],
            "city": e["city"]["name"],
            "country": e["city"]["country"],
            "asset": f"assets/explore/cities/{e['city']['id']}.webp",
            "source": e["cand"]["file"],
            "sourceTitle": e["cand"]["title"],
            "author": e["cand"]["artist"],
            "license": e["cand"]["license"],
            "description": e["cand"].get("desc", ""),
            "sourceWidth": e["cand"]["w"],
            "sourceHeight": e["cand"]["h"],
            "downloadUrl": e["cand"]["thumb"],
        } for e in entries],
    }
    Path(args.out_manifest).write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1) + "\n")
    print(f"wrote {len(entries)} entries -> {args.out}")


if __name__ == "__main__":
    main()
