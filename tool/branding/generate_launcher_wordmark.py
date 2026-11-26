#!/usr/bin/env python3
"""Generate the OUTSIDE-app icon: the TokiGo wordmark, not the parasol.

The parasol assets in `assets/icon/app_icon_*` are the in-app brand mark (Home
action tiles, AI avatar) and the splash artwork. They are deliberately left
untouched. This script owns a separate set of launcher-only masters, consumed by
`flutter_launcher_icons` through `pubspec.yaml`:

    Android  legacy launcher   -> black field + white TokiGo wordmark
    Android  adaptive          -> transparent foreground, same white wordmark
    Android  themed (mono)     -> white wordmark silhouette
    iOS      primary launcher  -> black field + white TokiGo wordmark
    iOS 18   dark appearance    -> transparent master, same white wordmark

The two alternate icon catalogs registered in Info.plist are refreshed from the
same dark master, so switching alternates cannot resurrect the old parasol.

The letterforms come straight from the Home header's spec, mirrored from
`lib/core/ui/app_wordmark.dart` via `generate_wordmark.py`: Manrope Variable at
weight 800, -1.2% tracking, 0.16em gap. The launcher deliberately drops the
Home header's brand red — "Toki" and "Go" share one ink colour — while the
in-app wordmark keeps its red "Go". The glyph outlines are lifted from the
bundled font with fontTools so the SVG masters stay vector.

Three canvases are emitted because the platforms have different safe areas:

  assets/icon/launcher_wordmark.svg                 opaque light master
  assets/icon/launcher_wordmark_dark.svg            opaque dark master
  assets/icon/launcher_wordmark_ios_dark.svg        iOS 18 dark, transparent
  assets/icon/launcher_wordmark_adaptive.svg        Android light foreground
  assets/icon/launcher_wordmark_adaptive_dark.svg   Android night foreground
  assets/icon/launcher_wordmark_adaptive_mono.svg   Android 13+ themed icon

Then render the PNG masters and rebuild the native resources:

    python tool/branding/generate_launcher_wordmark.py
    dart run flutter_launcher_icons
    python tool/branding/sync_android_night_icons.py

Requires `fonttools` (glyph outlines) and the resvg helper in this directory.

Usage:  python tool/branding/generate_launcher_wordmark.py [--no-render]
"""
from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

# One source of truth for the brand values: generate_wordmark.py already mirrors
# AppWordmark / AppColors and verifies the raster wordmark against that spec.
from generate_wordmark import FONT_PATH, GAP_EM, INK, INK_DARK, TRACKING_EM, WEIGHT

CANVAS = 1024
SAFE_FRACTION = 0.66  # Android adaptive icons guarantee the central 66% circle
OUT_DIR = Path("assets/icon")
RENDER_HELPER = Path("tool/branding/render_svg.js")

IOS_INK_WIDTH = 820  # 80% of the full-bleed iOS square
ADAPTIVE_INK_WIDTH = 640  # fits the 66% safe circle, see validate()
MIN_INK_FRACTION = 0.50  # a name smaller than half the square stops reading


def hex_color(rgb: tuple[int, int, int]) -> str:
    return "#%02X%02X%02X" % rgb


# generate_wordmark.py keeps the brand colours as RGB tuples for Pillow.
INK_HEX, INK_DARK_HEX = (hex_color(c) for c in (INK, INK_DARK))

IOS_LIGHT_SVG = OUT_DIR / "launcher_wordmark.svg"
IOS_DARK_SVG = OUT_DIR / "launcher_wordmark_dark.svg"
IOS_DARK_TRANSPARENT_SVG = OUT_DIR / "launcher_wordmark_ios_dark.svg"
ADAPTIVE_LIGHT_SVG = OUT_DIR / "launcher_wordmark_adaptive.svg"
ADAPTIVE_DARK_SVG = OUT_DIR / "launcher_wordmark_adaptive_dark.svg"
MONO_SVG = OUT_DIR / "launcher_wordmark_adaptive_mono.svg"

Box = tuple[float, float, float, float]


def _font() -> TTFont:
    if not FONT_PATH.exists():
        raise SystemExit(f"missing font {FONT_PATH} (run from the repo root)")
    font = TTFont(str(FONT_PATH))
    return instantiateVariableFont(font, {"wght": WEIGHT}, inplace=True)


def _union(a: Box | None, b: Box | None) -> Box | None:
    if a is None:
        return b
    if b is None:
        return a
    return (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))


def _half(font: TTFont, text: str) -> tuple[list[tuple[float, str]], Box | None, float]:
    """Vector paths for one half, its ink box and its advance in font units."""
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    hmtx = font["hmtx"]
    tracking = TRACKING_EM * font["head"].unitsPerEm
    parts: list[tuple[float, str]] = []
    box: Box | None = None
    x = 0.0
    for char in text:
        name = cmap[ord(char)]
        path = SVGPathPen(glyphs)
        glyphs[name].draw(path)
        commands = path.getCommands()
        if commands:
            parts.append((x, commands))
        bounds = BoundsPen(glyphs)
        glyphs[name].draw(bounds)
        if bounds.bounds is not None:
            x0, y0, x1, y1 = bounds.bounds
            box = _union(box, (x0 + x, y0, x1 + x, y1))
        x += hmtx[name][0] + tracking
    return parts, box, x


def build_svg(
    font: TTFont,
    *,
    background: str | None,
    ink: str,
    go: str,
    ink_width: int,
) -> tuple[str, float, float, float, Box]:
    """Lay out "Toki" + gap + "Go" and centre the pair on the canvas.

    Returns the SVG plus the placement used by `validate()` (transform and the
    font-unit ink box). Font coordinates are Y-up, so the group flips Y.
    """
    toki, toki_box, toki_advance = _half(font, "Toki")
    go_parts, go_box, _ = _half(font, "Go")
    gap = GAP_EM * font["head"].unitsPerEm
    go_dx = toki_advance + gap
    go_parts = [(x + go_dx, path) for x, path in go_parts]
    if go_box is not None:
        go_box = (
            go_box[0] + go_dx,
            go_box[1],
            go_box[2] + go_dx,
            go_box[3],
        )
    box = _union(toki_box, go_box)
    if box is None:
        raise SystemExit("the wordmark outlines are empty")

    scale = ink_width / (box[2] - box[0])
    tx = CANVAS / 2 - scale * (box[0] + box[2]) / 2
    ty = CANVAS / 2 + scale * (box[1] + box[3]) / 2
    bg = (
        f'  <rect width="{CANVAS}" height="{CANVAS}" fill="{background}"/>\n'
        if background
        else ""
    )

    def paths(parts: list[tuple[float, str]]) -> str:
        return "\n".join(f'    <path d="{path}" transform="translate({x:.1f} 0)"/>' for x, path in parts)

    appearance = "opaque" if background else "transparent"
    svg = f"""<!-- Generated by tool/branding/generate_launcher_wordmark.py - do not edit by hand.
     {appearance} TokiGo wordmark, uniformly filled "{ink}" (no brand red). -->
<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">
{bg}  <g transform="translate({tx:.2f} {ty:.2f}) scale({scale:.6f} {-scale:.6f})">
    <g fill="{ink}">
{paths(toki)}
    </g>
    <g fill="{go}">
{paths(go_parts)}
    </g>
  </g>
</svg>
"""
    return svg, tx, ty, scale, box


def validate(label: str, tx: float, ty: float, scale: float, box: Box, *, safe_zone: bool) -> None:
    """Fail loudly if the name would be clipped, too small or out of safe area."""
    corners = (
        (tx + scale * box[0], ty - scale * box[1]),
        (tx + scale * box[2], ty - scale * box[1]),
        (tx + scale * box[0], ty - scale * box[3]),
        (tx + scale * box[2], ty - scale * box[3]),
    )
    for x, y in corners:
        if not 0 <= x <= CANVAS or not 0 <= y <= CANVAS:
            raise SystemExit(f"{label}: wordmark corner ({x:.0f},{y:.0f}) is clipped")
    ink = (box[2] - box[0]) * scale / CANVAS
    if ink < MIN_INK_FRACTION:
        raise SystemExit(f"{label}: the wordmark is only {ink:.1%} of the canvas width")
    if safe_zone:
        safe_radius = CANVAS * SAFE_FRACTION / 2
        furthest = max(math.hypot(x - CANVAS / 2, y - CANVAS / 2) for x, y in corners)
        if furthest > safe_radius:
            raise SystemExit(
                f"{label}: wordmark corner {furthest:.0f}px from centre exceeds the "
                f"{SAFE_FRACTION:.0%} adaptive safe circle ({safe_radius:.0f}px)"
            )
    print(f"{label}: wordmark {ink:.1%} of canvas width")


def render(svg_path: Path, out_path: Path, size: int = CANVAS) -> None:
    if not RENDER_HELPER.exists():
        raise SystemExit(f"missing {RENDER_HELPER}")
    subprocess.run(
        ["node", str(RENDER_HELPER), str(svg_path), str(out_path), str(size)],
        check=True,
    )


def sync_ios_alternates() -> None:
    """Keep the registered alternate icon sets in step with the primary.

    `flutter_launcher_icons` only writes AppIcon.appiconset. Info.plist also
    registers `app_icon` / `app_icon_dark`, so render their listed sizes from
    the same fixed dark master — otherwise an alternate switch reveals the
    retired parasol.
    """
    catalogs = Path("ios/Runner/Assets.xcassets")
    for name in ("app_icon", "app_icon_dark"):
        folder = catalogs / f"{name}.appiconset"
        contents = folder / "Contents.json"
        if not contents.exists():
            continue
        for entry in json.loads(contents.read_text(encoding="utf-8"))["images"]:
            filename = entry.get("filename")
            if not filename:
                continue
            match = re.fullmatch(r"Icon-App-(\d+(?:\.\d+)?)x\1@(\d)x\.png", filename)
            if match is None:
                continue
            size = round(float(match.group(1)) * int(match.group(2)))
            render(IOS_DARK_SVG, folder / filename, size)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--no-render",
        action="store_true",
        help="write the SVGs only, do not rasterize the PNGs",
    )
    args = parser.parse_args()
    font = _font()

    # label, path, background, wordmark ink, ink width, safe zone.
    # Both halves always share one colour; only the light master is dark ink.
    masters = (
        ("iOS light", IOS_LIGHT_SVG, "#FFFFFF", INK_HEX, IOS_INK_WIDTH, False),
        ("iOS dark", IOS_DARK_SVG, "#000000", INK_DARK_HEX, IOS_INK_WIDTH, False),
        ("iOS dark transparent", IOS_DARK_TRANSPARENT_SVG, None, INK_DARK_HEX, IOS_INK_WIDTH, False),
        ("adaptive light", ADAPTIVE_LIGHT_SVG, None, INK_HEX, ADAPTIVE_INK_WIDTH, True),
        ("adaptive dark", ADAPTIVE_DARK_SVG, None, INK_DARK_HEX, ADAPTIVE_INK_WIDTH, True),
        ("adaptive mono", MONO_SVG, None, INK_DARK_HEX, ADAPTIVE_INK_WIDTH, True),
    )
    for label, path, background, ink, width, safe in masters:
        svg, *placement = build_svg(
            font, background=background, ink=ink, go=ink, ink_width=width
        )
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(svg, encoding="utf-8")
        validate(label, *placement, safe_zone=safe)

    if args.no_render:
        return 0

    rasters = (
        (IOS_LIGHT_SVG, "launcher_wordmark_1024.png"),
        (IOS_DARK_SVG, "launcher_wordmark_dark_1024.png"),
        (IOS_DARK_TRANSPARENT_SVG, "launcher_wordmark_ios_dark_1024.png"),
        (ADAPTIVE_LIGHT_SVG, "launcher_wordmark_adaptive_foreground_1024.png"),
        (ADAPTIVE_DARK_SVG, "launcher_wordmark_adaptive_dark_foreground_1024.png"),
        (MONO_SVG, "launcher_wordmark_adaptive_monochrome_1024.png"),
    )
    for svg_path, png_name in rasters:
        render(svg_path, OUT_DIR / png_name)
    sync_ios_alternates()
    print("now run: dart run flutter_launcher_icons")
    return 0


if __name__ == "__main__":
    sys.exit(main())
