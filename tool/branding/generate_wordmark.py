#!/usr/bin/env python3
"""Generate the TokiGo wordmark rasters from the app's own brand spec.

The splash drawables are *generated* Android resources (flutter_native_splash),
and the in-app logotype is text (`lib/core/ui/app_wordmark.dart`). For both to
stay identical, the raster must be produced with the exact same font, weight,
tracking, gap and colours the widget renders. This script is that bridge: it
draws "TokiGo" with the bundled Manrope variable font and writes the light and
dark masters that `pubspec.yaml` feeds to flutter_native_splash.

Canonical spec (keep in sync with `lib/core/ui/app_wordmark.dart` and
`lib/core/theme/app_colors.dart`):

    font          Manrope Variable, weight 800 (ExtraBold)
    tracking      -0.012em      == AppWordmark.trackingEm  (Home's -0.3px @25px)
    half gap      0.16em        == AppWordmark.gapEm       (Home's 4dp @25px)
    "Toki" ink    #111111       == AppColors.wordmarkInk   (== AppColors.brand)
    "Go" ink      #FF2D2D       == AppColors.brandRed

Because tracking and gap are em-based, the mark is scale-invariant: the raster
drawn at 45dp/4x is pixel-for-pixel the same mark the widget renders at 25dp.

Writes:
  assets/branding/logo_wordmark.png           pre-Android-12 splash master
                                              (xxxhdpi = 4x, wide canvas)
  assets/branding/logo_wordmark_android12.png Android 12+ splash master
                                              (xxxhdpi = 4x, square canvas,
                                               mark inside the system safe
                                               circle - Android masks the
                                               outer third of the icon)
  assets/branding/logo_wordmark_dark.png      dark-mode wide master, white ink
  assets/branding/logo_wordmark_android12_dark.png
                                              dark-mode square master

Then regenerate the drawables:

    dart run flutter_native_splash:create

Usage:  python tool/branding/generate_wordmark.py [--check]

`--check` re-renders in memory and fails if the committed PNGs differ (use it
from CI when the brand spec or the font is touched).
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
INK = (0x11, 0x11, 0x11)  # AppColors.wordmarkInk
INK_DARK = (0xFF, 0xFF, 0xFF)
GO = (0xFF, 0x2D, 0x2D)  # AppColors.brandRed

# The masters are drawn on a 4x (xxxhdpi) grid so the source PNG equals what
# the widget renders on a xxxhdpi screen. The pre-12 splash has always shown the
# mark 140dp wide; keep that footprint.
TARGET_INK_DP = 140.0
SCALE = 4
TARGET_INK_PX = int(TARGET_INK_DP * SCALE)

CANVAS_WIDE = (1024, 360)  # pre-12: launch_background centers this bitmap
CANVAS_SQUARE = (1024, 1024)  # android 12+: adaptive-icon spec, 2/3 visible
SAFE_CIRCLE_FRACTION = 66 / 108  # guaranteed-visible circle of an adaptive icon
REFERENCE_PX = 180  # first-pass render used to solve the font size

HALVES = (("Toki", INK), ("Go", GO))
OUT_WIDE = Path("assets/branding/logo_wordmark.png")
OUT_SQUARE = Path("assets/branding/logo_wordmark_android12.png")
OUT_WIDE_DARK = Path("assets/branding/logo_wordmark_dark.png")
OUT_SQUARE_DARK = Path("assets/branding/logo_wordmark_android12_dark.png")


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
    halves = ((HALVES[0][0], ink_color), HALVES[1])
    parts = [(render_half(text, font), color) for text, color in halves]

    width = sum(mask.width for (mask, _), _ in parts) + gap * (len(parts) - 1)
    # Baseline sits at max(baseline_row) so no half can be clipped at the top.
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


def measure(img: Image.Image) -> dict:
    """Ink bbox + the exact colours, straight off the rendered pixels."""
    bbox = img.getbbox()
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
        "max_ink": max(img.split()[-1].getdata()),
        "colors": [(f"#{r:02X}{g:02X}{b:02X}", n) for (r, g, b), n in top[:3]],
    }


def verify(
    img: Image.Image,
    label: str,
    safe_circle: bool = False,
    ink_color: tuple[int, int, int] = INK,
) -> dict:
    """Fail loudly if the render is not the brand spec."""
    stats = measure(img)
    found = {c for c, _ in stats["colors"]}
    want = {
        f"#{r:02X}{g:02X}{b:02X}"
        for r, g, b in (ink_color, GO)
    }
    print(
        f"  {label}: canvas={stats['canvas']} ink={stats['ink']} "
        f"colors={stats['colors']}"
    )
    missing = want - found
    if missing:
        raise SystemExit(f"{label}: brand colours missing from the render: {missing}")
    if stats["max_ink"] < 250:
        raise SystemExit(f"{label}: fully transparent pixels at the ink core")
    if safe_circle:
        w, h = stats["ink"]
        safe = min(img.size) * SAFE_CIRCLE_FRACTION
        if (w**2 + h**2) ** 0.5 > safe:
            raise SystemExit(
                f"{label}: ink {w}x{h} pokes outside the adaptive-icon safe "
                f"circle ({safe:.0f}px) - Android 12+ would clip the mark"
            )
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the committed PNGs match the spec, write nothing",
    )
    args = parser.parse_args()

    font = render_font(solve_font_size())
    mark = build_wordmark(font)
    wide = centered(mark, CANVAS_WIDE)
    square = centered(mark, CANVAS_SQUARE)
    dark_mark = build_wordmark(font, ink_color=INK_DARK)
    wide_dark = centered(dark_mark, CANVAS_WIDE)
    square_dark = centered(dark_mark, CANVAS_SQUARE)
    print(
        f"brand mark: font {font.size}px ({font.size / SCALE:g}dp) x{SCALE} "
        f"-> ink {mark.width / SCALE:g}x{mark.height / SCALE:g}dp"
    )

    if args.check:
        outputs = (
            (OUT_WIDE, wide, INK, False),
            (OUT_SQUARE, square, INK, True),
            (OUT_WIDE_DARK, wide_dark, INK_DARK, False),
            (OUT_SQUARE_DARK, square_dark, INK_DARK, True),
        )
        for path, expected, ink_color, safe_circle in outputs:
            if not path.exists():
                raise SystemExit(f"missing {path}")
            actual = Image.open(path).convert("RGBA")
            if (
                actual.size != expected.size
                or actual.tobytes() != expected.tobytes()
            ):
                raise SystemExit(
                    f"{path} differs from the brand spec - "
                    "run: python tool/branding/generate_wordmark.py"
                )
            verify(
                actual,
                str(path),
                safe_circle=safe_circle,
                ink_color=ink_color,
            )
        print("brand rasters match the spec")
        return 0

    outputs = (
        (OUT_WIDE, wide, INK, False),
        (OUT_SQUARE, square, INK, True),
        (OUT_WIDE_DARK, wide_dark, INK_DARK, False),
        (OUT_SQUARE_DARK, square_dark, INK_DARK, True),
    )
    for path, img, ink_color, safe_circle in outputs:
        _write(path, _encode(img))
        verify(
            img,
            str(path),
            safe_circle=safe_circle,
            ink_color=ink_color,
        )
    print("now regenerate the Android drawables: dart run flutter_native_splash:create")
    return 0


def _write(path: Path, data: bytes) -> None:
    """Write via a sibling temp file + atomic replace.

    A plain `open(path, 'wb')` can fail with EINVAL on Windows when a filter
    driver (AV / sync client) holds the existing file; the replace path does not.
    """
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
