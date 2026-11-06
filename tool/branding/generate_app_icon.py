#!/usr/bin/env python3
"""Generate the TokiGo app icon from the app's own brand spec.

The icon is a flat composition: ONE white beach umbrella (parasol) centred on
the brand-red canvas. Nothing is drawn by eye — every value comes from the
theme tokens:

    brand red     #FF2D2D  == AppColors.brandRed / TokiGoColors.brandRed
                          (the exact red the "Go" in the logotype uses)
    umbrella      #FFFFFF  == the logotype's light-on-brand pairing

The wordmark ("Go") is deliberately NOT part of the icon: at 29pt a second
line of type under the mark stops reading, and the parasol alone is the
brand's own glyph. The wordmark stays in `assets/branding/` and on the splash.

Two canvases are emitted because the two platforms have different safe areas:

  assets/icon/app_icon.svg              iOS master, 1024x1024, full-bleed
  assets/icon/app_icon_adaptive.svg     Android adaptive foreground, the mark
                                        kept inside the central 66% safe zone
                                        (diagonal <= 66% of the canvas)

Rasters (1024px PNG, plus the monochrome layer) are rendered from those SVGs
with `tool/branding/render_svg.js` (npm i @resvg/resvg-js). Then:

    dart run flutter_launcher_icons

Usage:  python tool/branding/generate_app_icon.py [--no-render]
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

# --- canonical brand spec (mirror app_colors.dart) ------------------------
BRAND_RED = "#FF2D2D"  # AppColors.brandRed
WHITE = "#FFFFFF"

CANVAS = 1024
# Android adaptive icons guarantee only the central 66% is visible.
SAFE_FRACTION = 0.66

OUT_DIR = Path("assets/icon")
IOS_SVG = OUT_DIR / "app_icon.svg"
ADAPTIVE_SVG = OUT_DIR / "app_icon_adaptive.svg"
MONO_SVG = OUT_DIR / "app_icon_adaptive_mono.svg"
RENDER_HELPER = Path("tool/branding/render_svg.js")

# iOS composition: the mark may use most of the full-bleed square, so the
# parasol is drawn large and centred.
IOS = {
    "canopy_half_width": 380,
    "hem_y": 400,
    "dome_height": 265,
    "scallop": 41,
    "pole_bottom": 665,
    "pole_width": 32,
    "finial_above": 47,
    "finial_below": 41,
    "finial_half": 24,
}

# Android composition: the mark must fit the central safe zone
# (diagonal <= 66% of the canvas == 676px, matching generate_wordmark.py).
ADAPTIVE = {
    "canopy_half_width": 266,
    "hem_y": 400,
    "dome_height": 186,
    "scallop": 28,
    "pole_bottom": 592,
    "pole_width": 25,
    "finial_above": 34,
    "finial_below": 30,
    "finial_half": 18,
}

# A mark smaller than this share of the canvas stops reading as the brand at
# the 29pt iOS settings size (a speck reads as a rendering bug).
MIN_INK_FRACTION = 0.20


def umbrella_paths(spec, cx):
    """Flat parasol: finial, dome canopy with a 4-panel scalloped hem, pole."""
    hw = spec["canopy_half_width"]
    hem_y = spec["hem_y"]
    dome_h = spec["dome_height"]
    apex_y = hem_y - dome_h
    scallop = spec["scallop"]
    pole_w = spec["pole_width"]
    pole_bottom = spec["pole_bottom"]
    finial_half = spec["finial_half"]
    finial_top = apex_y - spec["finial_above"]
    finial_bottom = apex_y + spec["finial_below"]

    # Canopy: elliptical dome from the left rib tip, over the apex, to the right.
    canopy = (
        f"M {cx - hw:.1f} {hem_y:.1f} "
        f"A {hw:.1f} {dome_h:.1f} 0 0 1 {cx + hw:.1f} {hem_y:.1f} "
    )
    # Hem: four scalloped panels back to the left rib tip.
    steps = 4
    for i in range(steps, 0, -1):
        x1 = cx - hw + (2 * hw) * i / steps
        x0 = cx - hw + (2 * hw) * (i - 1) / steps
        mid = (x0 + x1) / 2
        canopy += f"Q {mid:.1f} {hem_y - scallop:.1f} {x0:.1f} {hem_y:.1f} "
    canopy += "Z"

    # Pole: a rounded-end bar from under the canopy to its tip. The winding
    # matches the canopy's so the overlap is a union, not a nonzero-rule hole.
    pole = (
        f"M {cx + pole_w / 2:.1f} {hem_y - 10:.1f} "
        f"L {cx + pole_w / 2:.1f} {pole_bottom - pole_w / 2:.1f} "
        f"Q {cx + pole_w / 2:.1f} {pole_bottom:.1f} {cx:.1f} {pole_bottom:.1f} "
        f"Q {cx - pole_w / 2:.1f} {pole_bottom:.1f} {cx - pole_w / 2:.1f} "
        f"{pole_bottom - pole_w / 2:.1f} "
        f"L {cx - pole_w / 2:.1f} {hem_y - 10:.1f} Z"
    )

    # Finial: the little cap that crowns the canopy.
    finial = (
        f"M {cx - finial_half:.1f} {finial_top + finial_half:.1f} "
        f"Q {cx - finial_half:.1f} {finial_top:.1f} {cx:.1f} {finial_top:.1f} "
        f"Q {cx + finial_half:.1f} {finial_top:.1f} {cx + finial_half:.1f} "
        f"{finial_top + finial_half:.1f} "
        f"L {cx + finial_half:.1f} {finial_bottom:.1f} "
        f"L {cx - finial_half:.1f} {finial_bottom:.1f} Z"
    )

    half = max(hw, pole_w / 2, finial_half)
    bbox = (cx - half, cx + half, finial_top, pole_bottom)
    return f"{pole} {canopy} {finial}", bbox


def build_svg(spec):
    cx = CANVAS / 2
    umbrella, bbox = umbrella_paths(spec, cx)
    # Optically centre the mark on the canvas.
    dy = CANVAS / 2 - (bbox[2] + bbox[3]) / 2
    svg = f"""<!-- Generated by tool/branding/generate_app_icon.py - do not edit by hand.
     Brand red {BRAND_RED} == AppColors.brandRed; the parasol {WHITE}. -->
<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">
  <rect width="{CANVAS}" height="{CANVAS}" fill="{BRAND_RED}"/>
  <g fill="{WHITE}" transform="translate(0 {dy:.1f})">
    <path d="{umbrella}"/>
  </g>
</svg>
"""
    return svg, bbox, dy


def validate(label: str, bbox, dy: float, *, safe_zone: bool) -> None:
    """Fail loudly rather than ship an icon whose mark silently vanished.

    Every check here is a regression guard: an icon that rendered an empty
    canvas, or a mark clipped by the platform mask, is a failure even though
    the SVG is technically valid.
    """
    x0, x1, y0, y1 = bbox
    w = x1 - x0
    h = y1 - y0
    if w <= 0 or h <= 0:
        raise SystemExit(f"{label}: the parasol outlines are empty")
    # The mark is shifted by the group transform, so check the shift too.
    for name, value, low, high in (
        ("mark left", x0, 0, CANVAS),
        ("mark right", x1, 0, CANVAS),
        ("mark top", y0 + dy, 0, CANVAS),
        ("mark bottom", y1 + dy, 0, CANVAS),
    ):
        if not low <= value <= high:
            raise SystemExit(
                f"{label}: {name} = {value:.1f} falls outside the viewBox"
            )
    # Legibility floor: the mark must still be a mark at 29pt.
    ink = w * h / (CANVAS * CANVAS)
    if ink < MIN_INK_FRACTION:
        raise SystemExit(
            f"{label}: the mark covers only {ink:.1%} of the canvas — "
            f"too small to read at 29pt"
        )
    diagonal = (w * w + h * h) ** 0.5
    if safe_zone and diagonal > CANVAS * SAFE_FRACTION:
        raise SystemExit(
            f"{label}: mark diagonal {diagonal:.0f}px exceeds the "
            f"{SAFE_FRACTION:.0%} adaptive icon safe zone "
            f"({CANVAS * SAFE_FRACTION:.0f}px)"
        )
    print(
        f"{label}: ink {w:.0f}x{h:.0f} ({ink:.1%} of the canvas), "
        f"diagonal {diagonal:.0f}"
    )


def render(svg_path: Path, out_path: Path, size: int) -> None:
    if not RENDER_HELPER.exists():
        raise SystemExit(f"missing {RENDER_HELPER}")
    subprocess.run(
        ["node", str(RENDER_HELPER), str(svg_path), str(out_path), str(size)],
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--no-render",
        action="store_true",
        help="write the SVGs only, do not rasterize the PNGs",
    )
    args = parser.parse_args()

    for spec, svg_path, safe_zone in (
        (IOS, IOS_SVG, False),
        (ADAPTIVE, ADAPTIVE_SVG, True),
    ):
        svg, bbox, dy = build_svg(spec)
        svg_path.parent.mkdir(parents=True, exist_ok=True)
        svg_path.write_text(svg, encoding="utf-8")
        validate(str(svg_path), bbox, dy, safe_zone=safe_zone)

    if args.no_render:
        return 0

    render(IOS_SVG, OUT_DIR / "app_icon_1024.png", CANVAS)
    render(ADAPTIVE_SVG, OUT_DIR / "app_icon_adaptive_foreground_1024.png", CANVAS)
    # Monochrome (Android 13+ themed icon): the SAME artwork as the adaptive
    # foreground, but as a white silhouette on a TRANSPARENT canvas — Android
    # tints it with the theme colour, so a painted background would turn the
    # whole icon into a solid tinted square.
    adaptive = ADAPTIVE_SVG.read_text(encoding="utf-8")
    mono = adaptive.replace(
        f'  <rect width="{CANVAS}" height="{CANVAS}" fill="{BRAND_RED}"/>\n', ""
    )
    MONO_SVG.write_text(mono, encoding="utf-8")
    render(MONO_SVG, OUT_DIR / "app_icon_adaptive_monochrome_1024.png", CANVAS)
    print("now run: dart run flutter_launcher_icons")
    return 0


if __name__ == "__main__":
    sys.exit(main())
