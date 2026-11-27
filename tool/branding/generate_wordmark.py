#!/usr/bin/env python3
"""Generate the TokiGo wordmark rasters from the app's own brand spec.

OWNER DECISION (2026-11-27): the new brand mark is the **white TokiGo
wordmark** on the fixed #111111 launch field. There is no red "Go" anywhere in
the branding rasters, and no umbrella in any generated icon or splash asset.
Owner follow-up the same day restored the parasol ONLY on the Home / Onboarding
Packages quick tile, from separate `assets/icon/packages_parasol*` files that
this generator never touches.

The in-app logotype (`lib/core/ui/app_wordmark.dart`) is monochrome and follows
the theme's text colour so it stays legible on white surfaces; the raster
masters below are the fixed white branding artwork used by the launch screens
and by the AI avatar.

Spec (keep in sync with `lib/core/ui/app_wordmark.dart`):

    font          Manrope Variable, weight 800 (ExtraBold)
    tracking      -0.012em      == AppWordmark.trackingEm
    half gap      0.16em        == AppWordmark.gapEm
    branding ink  #FFFFFF (both halves, no brand red)

Writes:
  assets/branding/logo_wordmark.png             light wide master (white ink)
  assets/branding/logo_wordmark_dark.png        dark wide master (white ink)
  assets/icon/app_icon_adaptive_foreground_1024.png       compact white mark
  assets/icon/app_icon_adaptive_dark_foreground_1024.png  compact white mark
  assets/icon/app_icon_adaptive_monochrome_1024.png       compact white mark
  assets/branding/icon_foreground.png            legacy wide-master companion
  assets/branding/icon_foreground_dark.png       legacy wide-master companion

Then compose the splash masters and regenerate the native resources:

    python tool/branding/generate_splash.py
    dart run flutter_native_splash:create

Usage:  python tool/branding/generate_wordmark.py [--check]

`--check` re-renders in memory and fails if the committed PNGs differ.
"""
from __future__ import annotations

import argparse
import io
import os
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# --- canonical brand spec -------------------------------------------------
FONT_PATH = Path("assets/fonts/Manrope-Variable.ttf")
WEIGHT = 800  # FontWeight.w800 == AppTypography.weightExtraBold
TRACKING_EM = -0.012  # AppWordmark.trackingEm
GAP_EM = 0.16  # AppWordmark.gapEm
INK = (0xFF, 0xFF, 0xFF)  # branding ink: white, both halves
GO = (0xFF, 0xFF, 0xFF)  # retired red "Go" — now the same white ink
INK_DARK = (0xFF, 0xFF, 0xFF)
PLATE = (0x11, 0x11, 0x11)  # the fixed splash field behind the mark

# The masters are drawn on a 4x (xxxhdpi) grid so the source PNG equals what
# the widget renders on a xxxhdpi screen.
TARGET_INK_DP = 140.0
SCALE = 4
TARGET_INK_PX = int(TARGET_INK_DP * SCALE)

CANVAS_WIDE = (1024, 360)  # launch_background centers this bitmap
CANVAS_SQUARE = 1024  # compact mark / Android 12 adaptive foreground
MARK_INK_W = 680  # inside the 66% adaptive safe zone
MARK_RADIUS = 220
REFERENCE_PX = 180  # first-pass render used to solve the font size

HALVES = (("Toki", INK), ("Go", GO))
OUT_WIDE = Path("assets/branding/logo_wordmark.png")
OUT_WIDE_DARK = Path("assets/branding/logo_wordmark_dark.png")

# The compact mark overwrites the retired parasol rasters so no stale artwork
# can be restored by an old generator or an old asset reference.
MARK_LIGHT = Path("assets/icon/app_icon_adaptive_foreground_1024.png")
MARK_DARK = Path("assets/icon/app_icon_adaptive_dark_foreground_1024.png")
MARK_MONO = Path("assets/icon/app_icon_adaptive_monochrome_1024.png")
BRAND_ICON_LIGHT = Path("assets/branding/icon_foreground.png")
BRAND_ICON_DARK = Path("assets/branding/icon_foreground_dark.png")

# Legacy, unreferenced raster masters are overwritten too so neither the
# parasol nor the red wordmark can survive in an unused file.
LEGACY_MARKS = (
    Path("assets/branding/app_icon.png"),
    Path("assets/branding/app_icon_dark.png"),
    Path("assets/icon/app_icon_1024.png"),
    Path("assets/icon/app_icon_dark_1024.png"),
    Path("assets/icon/app_icon_ios_dark_1024.png"),
)


def render_half(text: str, font: ImageFont.FreeTypeFont) -> tuple[Image.Image, int]:
    """Render one half as an L-mode mask, cropped to its ink.

    Returns (mask, baseline row inside the crop). Flutter's `letterSpacing`
    lands after every character, so the per-character advance carries it.
    """
    size = font.size
    tracking = TRACKING_EM * size
    pad = size
    canvas = Image.new("L", (pad * 2 + size * len(text) * 2, pad * 3), 0)
    draw = ImageDraw.Draw(canvas)
    x = float(pad)
    origin_y = pad
    for ch in text:
        draw.text((x, origin_y), ch, font=font, fill=255)
        x += font.getlength(ch) + tracking

    bbox = canvas.getbbox()
    if bbox is None:
        raise RuntimeError(f"nothing rendered for {text!r}")
    ascent, _ = font.getmetrics()
    baseline_row = origin_y + ascent - bbox[1]
    return canvas.crop(bbox), baseline_row


def build_wordmark(
    font: ImageFont.FreeTypeFont,
    ink_color: tuple[int, int, int] = INK,
) -> Image.Image:
    """Compose the brand mark: 'Toki' + 0.16em + 'Go', baselines aligned."""
    gap = int(round(GAP_EM * font.size))
    halves = ((HALVES[0][0], ink_color), (HALVES[1][0], ink_color))
    parts = [(render_half(text, font), color) for text, color in halves]

    width = sum(mask.width for (mask, _), _ in parts) + gap * (len(parts) - 1)
    baseline_row = max(row for (_, row), _ in parts)
    height = baseline_row + max(mask.height - row for (mask, row), _ in parts)

    mark = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x = 0
    for (mask, row), color in parts:
        tinted = Image.new("RGBA", mask.size, color + (0,))
        tinted.putalpha(mask)
        mark.alpha_composite(tinted, (x, baseline_row - row))
        x += mask.width + gap
    return mark


def centered(mark: Image.Image, canvas: tuple[int, int]) -> Image.Image:
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    out.alpha_composite(
        mark, ((canvas[0] - mark.width) // 2, (canvas[1] - mark.height) // 2)
    )
    return out


def build_compact_mark(mark: Image.Image) -> Image.Image:
    """The white wordmark on a #111111 plate, replacing the old parasol.

    A dark plate keeps the white brand readable on both light and dark app
    surfaces (Home tiles, AI avatar) and blends into the #111111 launch field
    on Android 12+. The wordmark stays inside the adaptive safe zone.
    """
    bbox = mark.getbbox()
    if bbox is None:
        raise RuntimeError("the wordmark is empty")
    ink_w, ink_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    scale = MARK_INK_W / ink_w
    scaled = mark.resize(
        (round(mark.width * scale), round(mark.height * scale)),
        Image.Resampling.LANCZOS,
    )
    offset_x = round(bbox[0] * scale)
    offset_y = round(bbox[1] * scale)
    scaled_ink = (round(ink_w * scale), round(ink_h * scale))

    out = Image.new("RGBA", (CANVAS_SQUARE, CANVAS_SQUARE), (0, 0, 0, 0))
    plate = Image.new("RGBA", out.size, PLATE + (0,))
    mask = Image.new("L", out.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, CANVAS_SQUARE - 1, CANVAS_SQUARE - 1),
        radius=MARK_RADIUS,
        fill=255,
    )
    plate.putalpha(mask)
    out.alpha_composite(plate)
    out.alpha_composite(
        scaled,
        (
            (CANVAS_SQUARE - scaled_ink[0]) // 2 - offset_x,
            (CANVAS_SQUARE - scaled_ink[1]) // 2 - offset_y,
        ),
    )
    return out


def measure(img: Image.Image) -> dict:
    """Ink bbox + the exact colours, straight off the rendered pixels."""
    bbox = img.getbbox()
    if bbox is None:
        raise RuntimeError("the render is empty")
    crop = img.crop(bbox)
    colors: dict[tuple[int, int, int], int] = {}
    for count, pixel in crop.getcolors(maxcolors=1 << 24):
        if pixel[3] > 200:
            rgb = pixel[:3]
            colors[rgb] = colors.get(rgb, 0) + count
    top = sorted(colors.items(), key=lambda kv: -kv[1])
    return {
        "canvas": img.size,
        "ink": (bbox[2] - bbox[0], bbox[3] - bbox[1]),
        "max_ink": max(
            img.split()[-1].get_flattened_data()
            if hasattr(img.split()[-1], "get_flattened_data")
            else img.split()[-1].getdata()
        ),
        "colors": [(f"#{r:02X}{g:02X}{b:02X}", n) for (r, g, b), n in top[:3]],
    }


def verify(img: Image.Image, label: str) -> dict:
    """Fail loudly if the render keeps the retired red ink or is transparent."""
    stats = measure(img)
    found = {c for c, _ in stats["colors"]}
    want = {f"#{r:02X}{g:02X}{b:02X}" for r, g, b in (INK, GO)}
    print(f"  {label}: canvas={stats['canvas']} ink={stats['ink']} colors={stats['colors']}")
    missing = want - found
    if missing:
        raise SystemExit(f"{label}: white branding ink missing: {missing}")
    if any(c.lower() in {"#ff2d2d", "#ff5c5c"} for c in found):
        raise SystemExit(f"{label}: the retired red wordmark is still present")
    if stats["max_ink"] < 250:
        raise SystemExit(f"{label}: fully transparent pixels at the ink core")
    return stats


def verify_mark(img: Image.Image, label: str) -> dict:
    """The compact mark must carry white ink on the #111111 plate only."""
    stats = measure(img)
    found = {c for c, _ in stats["colors"]}
    want = {"#FFFFFF", "#111111"}
    print(f"  {label}: canvas={stats['canvas']} ink={stats['ink']} colors={stats['colors']}")
    if not want.issubset(found):
        raise SystemExit(f"{label}: expected white ink on the #111111 plate: {found}")
    if any(c.lower() in {"#ff2d2d", "#ff5c5c"} for c in found):
        raise SystemExit(f"{label}: the retired red wordmark is still present")
    return stats


def render_font(size_px: int) -> ImageFont.FreeTypeFont:
    if not FONT_PATH.exists():
        raise SystemExit(f"missing font {FONT_PATH} (run from the repo root)")
    f = ImageFont.truetype(str(FONT_PATH), size_px)
    f.set_variation_by_axes([WEIGHT])
    return f


def solve_font_size() -> int:
    """Font size whose ink is TARGET_INK_PX wide (ink scales linearly)."""
    ref = build_wordmark(render_font(REFERENCE_PX))
    return max(1, int(round(REFERENCE_PX * TARGET_INK_PX / ref.width)))


def build_outputs() -> list[tuple[Path, Image.Image, str]]:
    font = render_font(solve_font_size())
    mark = build_wordmark(font)
    wide = centered(mark, CANVAS_WIDE)
    compact = build_compact_mark(mark)
    print(
        f"brand mark: font {font.size}px ({font.size / SCALE:g}dp) x{SCALE} "
        f"-> ink {mark.width / SCALE:g}x{mark.height / SCALE:g}dp"
    )
    return [
        (OUT_WIDE, wide, "wide"),
        (OUT_WIDE_DARK, wide, "wide"),
        (MARK_LIGHT, compact, "mark"),
        (MARK_DARK, compact, "mark"),
        (MARK_MONO, compact, "mark"),
        (BRAND_ICON_LIGHT, compact, "mark"),
        (BRAND_ICON_DARK, compact, "mark"),
        *((path, compact, "mark") for path in LEGACY_MARKS),
    ]


def generate_all(check: bool = False) -> int:
    outputs = build_outputs()
    for path, img, kind in outputs:
        if check:
            if not path.exists():
                raise SystemExit(f"missing {path}")
            actual = Image.open(path).convert("RGBA")
            if actual.size != img.size or actual.tobytes() != img.tobytes():
                raise SystemExit(
                    f"{path} differs from the brand spec - "
                    "run: python tool/branding/generate_wordmark.py"
                )
            (verify if kind == "wide" else verify_mark)(actual, str(path))
        else:
            _write(path, _encode(img))
            (verify if kind == "wide" else verify_mark)(img, str(path))
    if not check:
        print("now compose the splash: python tool/branding/generate_splash.py")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the committed PNGs match the spec, write nothing",
    )
    return generate_all(check=parser.parse_args().check)


def _write(path: Path, data: bytes) -> None:
    """Write via a sibling temp file + atomic replace (Windows-safe)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), suffix='.tmp')
    try:
        with os.fdopen(fd, 'wb') as handle:
            handle.write(data)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def _encode(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


if __name__ == "__main__":
    sys.exit(main())
