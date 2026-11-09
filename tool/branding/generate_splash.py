#!/usr/bin/env python3
"""Compose the native splash masters: the app icon above the wordmark.

The native splash takes one centred bitmap per appearance, so the icon and
the app name have to be baked into a single transparent PNG:

    light  ->  white icon (black parasol)  +  dark "TokiGo" wordmark
    dark   ->  black icon (white parasol)  +  white "TokiGo" wordmark

The icon is rounded like a launcher icon and carries a hairline border so a
white icon still reads on the white splash canvas. The border is deliberately
absent from the launcher icon itself -- it exists only to separate the splash
tile from the splash background.

Android 12+ cannot show a name under the system splash icon, so its branding
slot gets a wordmark-only 800x320 master (the platform renders it at the
bottom of the splash). Pre-12 Android and iOS use the composed masters.

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

from PIL import Image, ImageDraw

# --- canonical composition spec -------------------------------------------
CANVAS = (1024, 640)  # 4x: 256x160dp on the device
ICON_SIZE = 384  # 4x: 96dp
ICON_TOP = 32
ICON_RADIUS = 86  # ~22.5% of the tile, the iOS/Android squircle feel
ICON_BORDER = 2  # 4x: 0.5dp hairline
GAP = 80  # 4x: 20dp between the icon and the wordmark
WORDMARK_INK_W = 512  # 4x: 128dp of real ink

BRANDING_CANVAS = (800, 320)  # Android 12+ branding slot, 200x80dp @4x
BRANDING_INK_W = 640  # 4x: 160dp of real ink

LIGHT_BORDER = (0xE4, 0xE4, 0xE7)
DARK_BORDER = (0x2A, 0x2A, 0x2E)

ICON_LIGHT = Path("assets/icon/app_icon_1024.png")
ICON_DARK = Path("assets/icon/app_icon_dark_1024.png")
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


def _rounded_icon(path: Path, border: tuple[int, int, int]) -> Image.Image:
    icon = _load_rgba(path).resize(
        (ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS
    )
    mask = Image.new("L", (ICON_SIZE, ICON_SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, ICON_SIZE - 1, ICON_SIZE - 1),
        radius=ICON_RADIUS,
        fill=255,
    )
    icon.putalpha(mask)

    tile = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    tile.alpha_composite(icon)
    ImageDraw.Draw(tile).rounded_rectangle(
        (0, 0, ICON_SIZE - 1, ICON_SIZE - 1),
        radius=ICON_RADIUS,
        outline=border + (255,),
        width=ICON_BORDER,
    )
    return tile


def _compose(icon_path: Path, wordmark_path: Path, border, out: Path) -> None:
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))

    icon = _rounded_icon(icon_path, border)
    icon_x = (CANVAS[0] - ICON_SIZE) // 2
    canvas.alpha_composite(icon, (icon_x, ICON_TOP))

    wordmark, (ink_x, ink_y), _ = _scaled_ink(wordmark_path, WORDMARK_INK_W)
    ink_top = ICON_TOP + ICON_SIZE + GAP
    wordmark_x = (CANVAS[0] - WORDMARK_INK_W) // 2 - ink_x
    canvas.alpha_composite(wordmark, (wordmark_x, ink_top - ink_y))

    canvas.save(out, format="PNG", optimize=True)
    print(f"{out}: canvas={CANVAS} icon={ICON_SIZE}px wordmark={WORDMARK_INK_W}px")


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
    _compose(ICON_LIGHT, WORDMARK_LIGHT, LIGHT_BORDER, OUT_LIGHT)
    _compose(ICON_DARK, WORDMARK_DARK, DARK_BORDER, OUT_DARK)
    _branding(WORDMARK_LIGHT, OUT_BRANDING)
    _branding(WORDMARK_DARK, OUT_BRANDING_DARK)
    print("now run: dart run flutter_native_splash:create")
    return 0


if __name__ == "__main__":
    sys.exit(main())
