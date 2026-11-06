#!/usr/bin/env python3
"""Generate the TokiGo app icon from the app's own brand spec.

The icon is a flat composition:

    white canvas  ->  smaller brand-red disc  ->  white parasol inside it

Every value comes from the theme tokens:

    brand red     #FF2D2D  == AppColors.brandRed / TokiGoColors.brandRed
    canvas        #FFFFFF  == the app's light canvas
    parasol       #FFFFFF  == the parasol sits on the red disc, like the old
                              icon (white mark on brand-red)

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

    dart run flutter_native_splash:create
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

# iOS composition: the disc uses most of the full-bleed square, so the
# parasol is drawn large and centred inside it.
IOS = {
    "disc_radius": 380,
    "canopy_half_width": 250,
    "hem_y": 392,
    "dome_height": 172,
    "scallop": 27,
    "pole_bottom": 655,
    "pole_width": 28,
    "finial_above": 34,
    "finial_below": 28,
    "finial_half": 17,
    # Optical centre of the composed mark (disc + parasol) — the parasol
    # sits visually heavier low on the disc, so it is nudged up a touch.
    "lift": 18,
}

# Android composition: the disc must fit the central safe zone
# (diagonal <= 66% of the canvas == 676px, matching generate_wordmark.py).
ADAPTIVE = {
    "disc_radius": 300,
    "canopy_half_width": 196,
    "hem_y": 382,
    "dome_height": 135,
    "scallop": 21,
    "pole_bottom": 575,
    "pole_width": 22,
    "finial_above": 27,
    "finial_below": 22,
    "finial_half": 13,
    "lift": 14,
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


def disc(cx, cy, radius):
    # Classic full-circle: two semicircle arcs that always join correctly.
    return (
        f"M {cx:.1f} {cy - radius:.1f} "
        f"a {radius:.1f} {radius:.1f} 0 1 1 0 {2 * radius:.1f} "
        f"a {radius:.1f} {radius:.1f} 0 1 1 0 -{2 * radius:.1f} Z"
    )


def build_svg(spec, *, background):
    cx = CANVAS / 2
    cy = CANVAS / 2
    disc_radius = spec["disc_radius"]
    umbrella, bbox = umbrella_paths(spec, cx)
    # Optically centre the parasol on the disc (pole carries visual weight).
    dy = (CANVAS / 2 - (bbox[2] + bbox[3]) / 2) - spec["lift"]
    disc_path = disc(cx, cy, disc_radius)
    bg = (
        f'  <rect width="{CANVAS}" height="{CANVAS}" fill="{WHITE}"/>\n'
        if background
        else ""
    )
    svg = f"""<!-- Generated by tool/branding/generate_app_icon.py - do not edit by hand.
     Brand red {BRAND_RED} == AppColors.brandRed; the parasol {WHITE} on the
     red disc, the disc on the white canvas. -->
<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">
{bg}  <g fill="{BRAND_RED}">
    <path d="{disc_path}"/>
  </g>
  <g fill="{WHITE}" transform="translate(0 {dy:.1f})">
    <path d="{umbrella}"/>
  </g>
</svg>
"""
    return svg, bbox, dy, disc_radius


def validate(label: str, bbox, dy: float, disc_radius: float, *, safe_zone: bool) -> None:
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
    disc_x0, disc_x1 = CANVAS / 2 - disc_radius, CANVAS / 2 + disc_radius
    disc_y0, disc_y1 = CANVAS / 2 - disc_radius, CANVAS / 2 + disc_radius
    # The disc must stay fully inside the canvas — never clipped by the
    # platform mask.
    for name, value, low, high in (
        ("disc left", disc_x0, 0, CANVAS),
        ("disc right", disc_x1, 0, CANVAS),
        ("disc top", disc_y0, 0, CANVAS),
        ("disc bottom", disc_y1, 0, CANVAS),
    ):
        if not low <= value <= high:
            raise SystemExit(
                f"{label}: {name} = {value:.1f} falls outside the viewBox"
            )
    # The parasol must stay fully inside the disc.
    for name, value, low, high in (
        ("parasol left", x0, disc_x0, disc_x1),
        ("parasol right", x1, disc_x0, disc_x1),
        ("parasol top", y0 + dy, disc_y0, disc_y1),
        ("parasol bottom", y1 + dy, disc_y0, disc_y1),
    ):
        if not low <= value <= high:
            raise SystemExit(
                f"{label}: {name} = {value:.1f} falls outside the red disc"
            )
    # Legibility floor: the disc must still be a mark at 29pt.
    disc_area = 3.141592653589793 * disc_radius * disc_radius
    ink = disc_area / (CANVAS * CANVAS)
    if ink < MIN_INK_FRACTION:
        raise SystemExit(
            f"{label}: the disc covers only {ink:.1%} of the canvas — "
            f"too small to read at 29pt"
        )
    diagonal = 2 * disc_radius
    if safe_zone and diagonal > CANVAS * SAFE_FRACTION:
        raise SystemExit(
            f"{label}: mark diagonal {diagonal:.0f}px exceeds the "
            f"{SAFE_FRACTION:.0%} adaptive icon safe zone "
            f"({CANVAS * SAFE_FRACTION:.0f}px)"
        )
    print(
        f"{label}: disc {disc_radius * 2:.0f}px ({ink:.1%} of the canvas), "
        f"parasol {w:.0f}x{h:.0f}, diagonal {diagonal:.0f}"
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

    svgs = [
        (IOS, IOS_SVG, False, False),
        (ADAPTIVE, ADAPTIVE_SVG, True, True),
    ]
    for spec, svg_path, safe_zone, transparent in svgs:
        svg, bbox, dy, disc_radius = build_svg(spec, background=not transparent)
        svg_path.parent.mkdir(parents=True, exist_ok=True)
        svg_path.write_text(svg, encoding="utf-8")
        validate(str(svg_path), bbox, dy, disc_radius, safe_zone=safe_zone)

    if args.no_render:
        return 0

    render(IOS_SVG, OUT_DIR / "app_icon_1024.png", CANVAS)
    render(ADAPTIVE_SVG, OUT_DIR / "app_icon_adaptive_foreground_1024.png", CANVAS)
    # Adaptive background: a plain white square behind the disc. The mark is
    # drawn on white, so the platform colour does not fight it.
    adaptive = ADAPTIVE_SVG.read_text(encoding="utf-8")
    # Monochrome (Android 13+ themed icon): the parasol alone as a white
    # silhouette on a transparent canvas — Android tints it with the theme
    # colour. The red disc is deliberately dropped: it would just turn the
    # whole themed icon into a solid tinted circle.
    adaptive = ADAPTIVE_SVG.read_text(encoding="utf-8")
    mono = adaptive.replace(
        f'  <g fill="{BRAND_RED}">\n    <path d="{disc(CANVAS / 2, CANVAS / 2, ADAPTIVE["disc_radius"])}"/>\n  </g>\n',
        "",
    )
    MONO_SVG.write_text(mono, encoding="utf-8")
    render(MONO_SVG, OUT_DIR / "app_icon_adaptive_monochrome_1024.png", CANVAS)
    print("now run: dart run flutter_launcher_icons")
    return 0


if __name__ == "__main__":
    sys.exit(main())
