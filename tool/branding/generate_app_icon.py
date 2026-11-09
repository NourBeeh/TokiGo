#!/usr/bin/env python3
"""Generate the TokiGo app icon from the app's own brand spec.

The icon is a flat, GitHub-inspired monochrome mark that inverts with the
system appearance:

    light mode  ->  white canvas  ->  black parasol
    dark mode   ->  black canvas  ->  white parasol

Every value comes from the theme tokens:

    white canvas  #FFFFFF
    black canvas  #000000  == AppColors.brandDark
    parasol       #000000 / #FFFFFF

The mark is deliberately flat and single-colour, like the GitHub logo: one
glyph, no gradients, no second accent colour. The wordmark ("Go") is
deliberately NOT part of the icon: at 29pt a second line of type under the
mark stops reading, and the parasol alone is the brand's own glyph. The
wordmark stays in `assets/branding/` and on the splash.

Three canvases are emitted because the platforms have different safe areas
and appearance variants:

  assets/icon/app_icon.svg                 light iOS/legacy master, opaque
  assets/icon/app_icon_dark.svg            dark opaque master (Android night)
  assets/icon/app_icon_ios_dark.svg        iOS 18 dark icon, transparent bg
  assets/icon/app_icon_adaptive.svg        Android light adaptive foreground,
                                           mark kept inside the 66% safe zone
  assets/icon/app_icon_adaptive_dark.svg   Android night adaptive foreground
  assets/icon/app_icon_adaptive_mono.svg   Android 13+ themed (monochrome)

Rasters (1024px PNG, plus the monochrome layer) are rendered from those SVGs
with `tool/branding/render_svg.js` (npm i @resvg/resvg-js). Then:

    dart run flutter_launcher_icons

Android's night foreground/mipmap resources are mirrored from the dark
rasters by `tool/branding/sync_android_night_icons.py` after that command.

Usage:  python tool/branding/generate_app_icon.py [--no-render]
"""
from __future__ import annotations

import argparse
import math
import subprocess
import sys
from pathlib import Path

# --- canonical brand spec (mirror app_colors.dart) ------------------------
BLACK = "#000000"  # dark canvas / light-mode parasol
WHITE = "#FFFFFF"  # light canvas / dark-mode parasol

CANVAS = 1024
# Android adaptive icons guarantee only the central 66% is visible.
SAFE_FRACTION = 0.66

OUT_DIR = Path("assets/icon")
IOS_LIGHT_SVG = OUT_DIR / "app_icon.svg"
IOS_DARK_SVG = OUT_DIR / "app_icon_dark.svg"
IOS_DARK_TRANSPARENT_SVG = OUT_DIR / "app_icon_ios_dark.svg"
ADAPTIVE_LIGHT_SVG = OUT_DIR / "app_icon_adaptive.svg"
ADAPTIVE_DARK_SVG = OUT_DIR / "app_icon_adaptive_dark.svg"
MONO_SVG = OUT_DIR / "app_icon_adaptive_mono.svg"
RENDER_HELPER = Path("tool/branding/render_svg.js")

# iOS composition: no container disc any more, so the parasol is the whole
# mark and can use most of the full-bleed square.
IOS = {
    "canopy_half_width": 380,
    "hem_y": 545,
    "dome_height": 300,
    "scallop": 38,
    "pole_bottom": 840,
    "pole_width": 42,
    "finial_above": 52,
    "finial_below": 44,
    "finial_half": 25,
    # Optical centre of the composed mark (canopy + pole) -- the thin pole
    # carries less weight than the dome, so the mark is nudged up a touch.
    "lift": 6,
}

# Android composition: the whole parasol must fit the central safe circle
# (diagonal <= 66% of the canvas == 676px, matching generate_wordmark.py).
ADAPTIVE = {
    "canopy_half_width": 260,
    "hem_y": 466,
    "dome_height": 205,
    "scallop": 29,
    "pole_bottom": 730,
    "pole_width": 35,
    "finial_above": 40,
    "finial_below": 35,
    "finial_half": 20,
    # The adaptive icon is masked to a circle, so the composed mark must sit
    # exactly on the canvas centre -- no optical lift.
    "lift": 0,
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


def build_svg(spec, *, background, ink):
    cx = CANVAS / 2
    umbrella, bbox = umbrella_paths(spec, cx)
    # Optically centre the parasol on the canvas (pole carries visual weight).
    dy = (CANVAS / 2 - (bbox[2] + bbox[3]) / 2) - spec["lift"]
    bg = (
        f'  <rect width="{CANVAS}" height="{CANVAS}" fill="{background}"/>\n'
        if background
        else ""
    )
    appearance = "light: black parasol on white" if ink == BLACK else (
        "dark: white parasol on black / transparent"
    )
    svg = f"""<!-- Generated by tool/branding/generate_app_icon.py - do not edit by hand.
     GitHub-inspired flat monochrome ({appearance}). -->
<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">
{bg}  <g fill="{ink}" transform="translate(0 {dy:.1f})">
    <path d="{umbrella}"/>
  </g>
</svg>
"""
    return svg, bbox, dy


def validate(label: str, spec, bbox, dy: float, *, safe_zone: bool) -> None:
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
    # The mark must stay fully inside the canvas -- never clipped by the
    # platform mask.
    for name, value, low, high in (
        ("mark left", x0, 0, CANVAS),
        ("mark right", x1, 0, CANVAS),
        ("mark top", y0 + dy, 0, CANVAS),
        ("mark bottom", y1 + dy, 0, CANVAS),
    ):
        if not low <= value <= high:
            raise SystemExit(f"{label}: {name} = {value:.1f} falls outside the viewBox")
    # Legibility floor: the mark must still read at 29pt.
    ink = w / CANVAS
    if ink < MIN_INK_FRACTION:
        raise SystemExit(
            f"{label}: the mark is only {ink:.1%} of the canvas width -- "
            f"too small to read at 29pt"
        )
    # Android adaptive icons guarantee only the central 66% circle. Check the
    # parasol's real extremes (canopy tips, finial, pole tip) rather than the
    # empty corners of its bounding box.
    if safe_zone:
        safe_radius = CANVAS * SAFE_FRACTION / 2
        centre = CANVAS / 2
        extremes = (
            (spec["canopy_half_width"], spec["hem_y"] + dy - centre),
            (spec["finial_half"], bbox[2] + dy - centre),
            (spec["pole_width"] / 2, spec["pole_bottom"] + dy - centre),
        )
        furthest = max(math.hypot(x, y) for x, y in extremes)
        if furthest > safe_radius:
            raise SystemExit(
                f"{label}: mark edge {furthest:.0f}px from centre exceeds the "
                f"{SAFE_FRACTION:.0%} adaptive icon safe circle "
                f"({safe_radius:.0f}px)"
            )
    print(
        f"{label}: mark {w:.0f}x{h:.0f} ({ink:.1%} of the canvas width), "
        f"vertical offset {dy:+.1f}"
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
        # label, spec, path, background, ink, safe_zone
        ("iOS light", IOS, IOS_LIGHT_SVG, WHITE, BLACK, False),
        ("iOS dark", IOS, IOS_DARK_SVG, BLACK, WHITE, False),
        (
            "iOS dark transparent",
            IOS,
            IOS_DARK_TRANSPARENT_SVG,
            None,
            WHITE,
            False,
        ),
        ("adaptive light", ADAPTIVE, ADAPTIVE_LIGHT_SVG, None, BLACK, True),
        ("adaptive dark", ADAPTIVE, ADAPTIVE_DARK_SVG, None, WHITE, True),
    ]
    for label, spec, svg_path, background, ink, safe_zone in svgs:
        svg, bbox, dy = build_svg(spec, background=background, ink=ink)
        svg_path.parent.mkdir(parents=True, exist_ok=True)
        svg_path.write_text(svg, encoding="utf-8")
        validate(label, spec, bbox, dy, safe_zone=safe_zone)

    if args.no_render:
        return 0

    render(IOS_LIGHT_SVG, OUT_DIR / "app_icon_1024.png", CANVAS)
    render(IOS_DARK_SVG, OUT_DIR / "app_icon_dark_1024.png", CANVAS)
    render(
        IOS_DARK_TRANSPARENT_SVG,
        OUT_DIR / "app_icon_ios_dark_1024.png",
        CANVAS,
    )
    render(
        ADAPTIVE_LIGHT_SVG,
        OUT_DIR / "app_icon_adaptive_foreground_1024.png",
        CANVAS,
    )
    render(
        ADAPTIVE_DARK_SVG,
        OUT_DIR / "app_icon_adaptive_dark_foreground_1024.png",
        CANVAS,
    )
    # Monochrome (Android 13+ themed icon): the parasol alone as a white
    # silhouette on a transparent canvas -- Android tints it with the theme
    # colour. It is the same artwork as the dark adaptive foreground, so the
    # layer can be copied verbatim.
    MONO_SVG.write_text(
        ADAPTIVE_DARK_SVG.read_text(encoding="utf-8"), encoding="utf-8"
    )
    render(MONO_SVG, OUT_DIR / "app_icon_adaptive_monochrome_1024.png", CANVAS)
    print("now run: dart run flutter_launcher_icons")
    return 0


if __name__ == "__main__":
    sys.exit(main())
