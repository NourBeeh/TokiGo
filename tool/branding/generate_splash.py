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

# The icon tile's fill MUST equal the splash page's background colour.
#
# Owner decision (2026-11): the launch page paints #111111 behind the artwork,
# so a pure-black tile reads as a darker "plate" floating on the page — a visible
# rectangle around the logo. The tile therefore carries the page colour, and the
# only edge the mark has is its hairline border.
PAGE_FIELD = (0x11, 0x11, 0x11)

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
    """The icon inside a squircle tile filled with the splash page's colour.

    The icon masters are OPAQUE squares whose field is a solid colour
    (#000000 for the dark mark), so compositing them as-is would paint a black
    plate on the #111111 launch page. The field is therefore converted to
    transparency and the squircle is filled with [PAGE_FIELD] instead — the
    artwork keeps its exact glyph, proportions and rounded shape, and the tile
    becomes invisible against the page. Only the hairline border remains as an
    edge.
    """
    icon = _load_rgba(path).resize(
        (ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS
    )
    # Key the icon's solid field to transparent, keeping the glyph.
    icon = _key_field_to_transparent(icon)
    mask = Image.new("L", (ICON_SIZE, ICON_SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, ICON_SIZE - 1, ICON_SIZE - 1),
        radius=ICON_RADIUS,
        fill=255,
    )
    # Multiply the keyed alpha by the squircle mask (putalpha would REPLACE the
    # alpha and undo the field keying).
    icon = _apply_mask(icon, mask)

    # Fill the squircle with the PAGE colour before compositing the glyph, so
    # the tile is invisible against the splash page (no plate, no halo).
    tile = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), PAGE_FIELD + (255,))
    tile.putalpha(mask)
    tile.alpha_composite(icon)
    ImageDraw.Draw(tile).rounded_rectangle(
        (0, 0, ICON_SIZE - 1, ICON_SIZE - 1),
        radius=ICON_RADIUS,
        outline=border + (255,),
        width=ICON_BORDER,
    )
    return tile


def _apply_mask(icon: Image.Image, mask: Image.Image) -> Image.Image:
    """Multiply the icon's alpha by [mask], preserving the keyed transparency."""
    out = icon.copy()
    src = icon.load()
    m = mask.load()
    dst = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            scale = m[x, y] / 255.0
            dst[x, y] = (r, g, b, round(a * scale))
    return out


def _key_field_to_transparent(icon: Image.Image) -> Image.Image:
    """Make an opaque icon master's flat field transparent.

    The field is the colour of the corner pixel (the masters are a flat field
    plus one glyph colour). Every pixel within a small tolerance of it becomes
    transparent; the glyph keeps its full alpha. This is what lets the page's
    own #111111 show through the tile.
    """
    field: tuple[int, int, int] = icon.getpixel((0, 0))[:3]  # type: ignore[index]
    keyed = icon.copy()
    pixels = keyed.load()
    for y in range(keyed.height):
        for x in range(keyed.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if (
                abs(r - field[0]) <= 8
                and abs(g - field[1]) <= 8
                and abs(b - field[2]) <= 8
            ):
                pixels[x, y] = (r, g, b, 0)
    return keyed


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
