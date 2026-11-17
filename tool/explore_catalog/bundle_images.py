#!/usr/bin/env python3
"""Download and optimize the chosen Explore city photo into the app bundle.

For each catalog city:
  1. fetch the chosen Commons file at a bounded width (default 1000px) — the
     card shows ~324dp wide, so 1000px covers a 3x device with headroom;
  2. center-crop to the card's photo aspect ratio (1.3, matching
     HomeCardDimensions.destinationMediaAspectRatio) so BoxFit.cover has
     nothing to crop at render time;
  3. encode as WebP at a quality that keeps the file in the 100-180KB band
     without visible artefacts;
  4. write assets/explore/cities/<id>.webp.

Never invents an image: a city whose file cannot be fetched is reported and
left unbundled, and the catalog integrity test then fails loudly.
"""
import argparse
import json
import sys
from io import BytesIO
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from commons import Commons  # noqa: E402

# The Home destination card's photo ratio (width / height).
CARD_ASPECT = 1.3


def crop_to_aspect(img: Image.Image, aspect: float) -> Image.Image:
    """Center-crop to `aspect`, growing the short side if needed."""
    w, h = img.size
    current = w / h
    if abs(current - aspect) < 0.01:
        return img
    if current > aspect:
        new_w = round(h * aspect)
        left = (w - new_w) // 2
        return img.crop((left, 0, left + new_w, h))
    new_h = round(w / aspect)
    top = (h - new_h) // 2
    return img.crop((0, top, w, top + new_h))


def encode_webp(img: Image.Image, target_bytes: int, quality: int = 82) -> bytes:
    """Encode WebP, lowering quality until the target size is met.

    The target is a band, not a hard ceiling: quality never drops below 70,
    because an artefact-ridden landmark is worse than a slightly larger file.
    """
    if img.mode not in ("RGB", "L"):
        img = img.convert("RGB")
    for q in (quality, quality - 6, quality - 12, quality - 18, 70):
        buf = BytesIO()
        img.save(buf, format="WEBP", quality=q, method=6)
        data = buf.getvalue()
        if len(data) <= target_bytes or q <= 70:
            return data
    return data


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True,
                    help="verified manifest JSON (from gen.py)")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--width", type=int, default=1000)
    ap.add_argument("--target-kb", type=int, default=165)
    ap.add_argument("--gap", type=float, default=1.4)
    args = ap.parse_args()

    manifest = json.loads(Path(args.manifest).read_text())
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    commons = Commons(min_gap=args.gap)

    results = []
    for entry in manifest["images"]:
        cid = entry["cityId"]
        dest = out_dir / f"{cid}.webp"
        try:
            raw = commons._download_bytes(entry["downloadUrl"])
            img = Image.open(BytesIO(raw))
            img = crop_to_aspect(img, CARD_ASPECT)
            if img.width > args.width:
                img = img.resize((args.width, round(img.height * args.width / img.width)),
                                 Image.LANCZOS)
            data = encode_webp(img, args.target_kb * 1024)
            dest.write_bytes(data)
            results.append({"cityId": cid, "file": dest.name,
                            "bytes": len(data), "w": img.width, "h": img.height})
            print(f"{cid}: {len(data)/1024:.1f} KB  {img.width}x{img.height}")
        except Exception as exc:  # noqa: BLE001
            print(f"{cid}: FAILED {exc}")
            results.append({"cityId": cid, "error": str(exc)})

    ok = [r for r in results if "bytes" in r]
    print(f"\nbundled {len(ok)}/{len(results)}")
    if ok:
        total = sum(r["bytes"] for r in ok)
        print(f"total: {total/1024/1024:.2f} MB, mean {total/len(ok)/1024:.1f} KB")


if __name__ == "__main__":
    main()
