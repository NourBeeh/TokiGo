"""Fail when a splash screenshot still contains the retired red branding.

Used by the iOS GitHub Action after installing a freshly built simulator app.
A modern white TokiGo wordmark on the fixed #111111 field has no saturated red
pixels; the old umbrella + red "Go" splash does.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


def red_pixels(path: Path) -> int:
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        width, height = rgb.size
        pixels = rgb.load()
        count = 0
        for y in range(height):
            for x in range(width):
                r, g, b = pixels[x, y]
                if r > 140 and r > g * 1.8 and r > b * 1.8:
                    count += 1
    return count


def main() -> int:
    paths = [Path(arg) for arg in sys.argv[1:]]
    if not paths:
        print("usage: python scripts/check_splash_screenshot.py <png> [png ...]")
        return 2

    failed = False
    for path in paths:
        count = red_pixels(path)
        if count:
            failed = True
            print(f"FAIL {path}: {count} retired red pixels")
        else:
            print(f"OK {path}: no retired red pixels")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
