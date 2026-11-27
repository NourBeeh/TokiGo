#!/usr/bin/env python3
"""Compose the native splash masters: the white wordmark only.

OWNER DECISION (2026-11-27): the launch screen is the fixed #111111 field with
the **white TokiGo wordmark** centred; there is no icon tile above it, no
parasol and no red "Go" in either appearance. The owner later restored the
parasol only on the Home Packages quick tile, from separate files.

Android 12+ therefore uses a single compact white wordmark in the icon slot;
the duplicate branding slot below it was removed because it looked like a
second, older splash. Pre-12 Android and iOS use the composed masters below.

Writes:
  assets/branding/logo_splash.png              light composed splash
  assets/branding/logo_splash_dark.png         dark composed splash
  assets/branding/logo_branding.png            Android 12+ light branding
  assets/branding/logo_branding_dark.png       Android 12+ dark branding

Then regenerate the native resources:

    dart run flutter_native_splash:create

Usage:  python tool/branding/generate_splash.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

# --- canonical composition spec -------------------------------------------
CANVAS = (1024, 640)  # 4x: 256x160dp on the device
WORDMARK_INK_W = 640  # 4x: 160dp of real ink

BRANDING_CANVAS = (800, 320)  # Android 12+ branding slot, 200x80dp @4x
BRANDING_INK_W = 640  # 4x: 160dp of real ink

WORDMARK_LIGHT = Path("assets/branding/logo_wordmark.png")
WORDMARK_DARK = Path("assets/branding/logo_wordmark_dark.png")

OUT_LIGHT = Path("assets/branding/logo_splash.png")
OUT_DARK = Path("assets/branding/logo_splash_dark.png")
OUT_BRANDING = Path("assets/branding/logo_branding.png")
OUT_BRANDING_DARK = Path("assets/branding/logo_branding_dark.png")


def _load_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise SystemExit(f"missing {path} (run from the repo root)")
    return Image.open(path).convert("RGBA")


def _scaled_ink(
    path: Path, ink_width: int
) -> tuple[Image.Image, tuple[int, int], tuple[int, int]]:
    """Return the wordmark scaled to `ink_width`, plus ink offset and size."""
    image = _load_rgba(path)
    bbox = image.getbbox()
    if bbox is None:
        raise SystemExit(f"{path}: the wordmark is empty")
    ink_w = bbox[2] - bbox[0]
    ink_h = bbox[3] - bbox[1]
    scale = ink_width / ink_w
    scaled = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    offset = (round(bbox[0] * scale), round(bbox[1] * scale))
    size = (round(ink_w * scale), round(ink_h * scale))
    return scaled, offset, size


def _compose(wordmark_path: Path, out: Path) -> None:
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    wordmark, (ink_x, ink_y), (ink_w, ink_h) = _scaled_ink(
        wordmark_path, WORDMARK_INK_W
    )
    left = (CANVAS[0] - ink_w) // 2 - ink_x
    top = (CANVAS[1] - ink_h) // 2 - ink_y
    canvas.alpha_composite(wordmark, (left, top))
    canvas.save(out, format="PNG", optimize=True)
    print(f"{out}: canvas={CANVAS} wordmark={WORDMARK_INK_W}px")


def _branding(wordmark_path: Path, out: Path) -> None:
    canvas = Image.new("RGBA", BRANDING_CANVAS, (0, 0, 0, 0))
    wordmark, (ink_x, ink_y), (_, ink_h) = _scaled_ink(
        wordmark_path, BRANDING_INK_W
    )
    ink_top = (BRANDING_CANVAS[1] - ink_h) // 2
    wordmark_x = (BRANDING_CANVAS[0] - BRANDING_INK_W) // 2 - ink_x
    canvas.alpha_composite(wordmark, (wordmark_x, ink_top - ink_y))
    canvas.save(out, format="PNG", optimize=True)
    print(f"{out}: canvas={BRANDING_CANVAS} wordmark={BRANDING_INK_W}px")


def main() -> int:
    _compose(WORDMARK_LIGHT, OUT_LIGHT)
    _compose(WORDMARK_DARK, OUT_DARK)
    _branding(WORDMARK_LIGHT, OUT_BRANDING)
    _branding(WORDMARK_DARK, OUT_BRANDING_DARK)
    print("now run: dart run flutter_native_splash:create")
    return 0


if __name__ == "__main__":
    sys.exit(main())
