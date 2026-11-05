#!/usr/bin/env python3
"""Generate the TokiGo app icon from the app's own brand spec.

The icon is a flat composition: a beach umbrella (parasol) above the word
"Go", both in white on the brand-red canvas. Nothing is drawn by eye — every
value comes from the theme tokens or the logo's own typography:

    brand red     #FF2D2D  == AppColors.brandRed / TokiGoColors.brandRed
                          (the exact red the "Go" in the logotype uses)
    umbrella/Go   #FFFFFF  == the logotype's light-on-brand pairing
    typeface      Manrope Variable, weight 800 (ExtraBold)
                          == AppTypography.fontFamily / weightExtraBold
    tracking      -0.012em == AppWordmark.trackingEm

The "Go" letterforms are converted to SVG <path> outlines from the bundled
font, so the artwork never depends on an installed font.

Two canvases are emitted because the two platforms have different safe areas:

  assets/icon/app_icon.svg              iOS master, 1024x1024, full-bleed
  assets/icon/app_icon_adaptive.svg     Android adaptive foreground, the whole
                                        group kept inside the central 66% safe
                                        zone (diagonal <= 66% of the canvas)

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

from fontTools.misc.transform import Transform
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

# --- canonical brand spec (mirror app_wordmark.dart / app_colors.dart) ----
FONT_PATH = Path("assets/fonts/Manrope-Variable.ttf")
WEIGHT = 800  # FontWeight.w800 == AppTypography.weightExtraBold
TRACKING_EM = -0.012  # AppWordmark.trackingEm
BRAND_RED = "#FF2D2D"  # AppColors.brandRed
WHITE = "#FFFFFF"

CANVAS = 1024

OUT_DIR = Path("assets/icon")
IOS_SVG = OUT_DIR / "app_icon.svg"
ADAPTIVE_SVG = OUT_DIR / "app_icon_adaptive.svg"
MONO_SVG = OUT_DIR / "app_icon_adaptive_mono.svg"
RENDER_HELPER = Path("tool/branding/render_svg.js")

# iOS composition: the group may use most of the full-bleed square.
IOS = {
    "canopy_half_width": 270,
    "hem_y": 400,
    "dome_height": 250,
    "scallop": 30,
    "pole_bottom": 520,
    "pole_width": 24,
    "finial_above": 32,
    "finial_below": 26,
    "finial_half": 14,
    "font_size": 390,
    "baseline": 890,
}

# Android composition: the whole group must fit the central safe zone
# (diagonal <= 66% of the canvas == 676px, matching generate_wordmark.py).
ADAPTIVE = {
    "canopy_half_width": 175,
    "hem_y": 410,
    "dome_height": 170,
    "scallop": 22,
    "pole_bottom": 490,
    "pole_width": 20,
    "finial_above": 26,
    "finial_below": 22,
    "finial_half": 12,
    "font_size": 250,
    "baseline": 755,
}

# Manrope ExtraBold cap height, measured from the font's own outlines at
# wght 800 ('G' spans -30..1470 on a 2000 upm grid).
CAP_HEIGHT_EM = 1470 / 2000


def load_go():
    """Return (glyph set, 'G' glyph, 'o' glyph, upm, advance G, advance o)."""
    if not FONT_PATH.exists():
        raise SystemExit(f"missing font {FONT_PATH} (run from the repo root)")
    font = TTFont(str(FONT_PATH))
    upm = font["head"].unitsPerEm
    # The bundled font is variable (wght 200..800, default 200 = ExtraLight):
    # resolve the ExtraBold instance through the glyph set's variation support.
    glyph_set = font.getGlyphSet(location={"wght": WEIGHT})
    cmap = font.getBestCmap()
    g_name = cmap[ord("G")]
    o_name = cmap[ord("o")]
    return (
        glyph_set,
        glyph_set[g_name],
        glyph_set[o_name],
        upm,
        glyph_set[g_name].width,
        glyph_set[o_name].width,
    )


def glyph_path(glyph, transform: Transform, glyph_set) -> str:
    """SVG path data for one glyph, with `transform` applied."""
    pen = SVGPathPen(glyph_set)
    glyph.draw(TransformPen(pen, transform))
    return pen.getCommands()


def go_group(glyph_set, g_glyph, o_glyph, upm, adv_g, adv_o, spec, cx):
    """Place the "Go" outlines centred on `cx`. Returns (path data, bbox)."""
    font_size = spec["font_size"]
    baseline = spec["baseline"]
    scale = font_size / upm
    tracking = TRACKING_EM * font_size
    width = (adv_g + adv_o) * scale + tracking
    left = cx - width / 2

    parts = []
    x = left
    for glyph, adv in ((g_glyph, adv_g), (o_glyph, adv_o)):
        transform = Transform(scale, 0, 0, -scale, x, baseline)
        parts.append(glyph_path(glyph, transform, glyph_set))
        x += adv * scale + tracking

    cap_height = CAP_HEIGHT_EM * font_size
    bbox = (left, left + width, baseline - cap_height, baseline)
    return " ".join(parts), bbox


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


def build_svg(spec, glyph_set, g_glyph, o_glyph, upm, adv_g, adv_o):
    cx = CANVAS / 2
    umbrella, u_bbox = umbrella_paths(spec, cx)
    go, g_bbox = go_group(
        glyph_set, g_glyph, o_glyph, upm, adv_g, adv_o, spec, cx
    )
    bbox = (
        min(u_bbox[0], g_bbox[0]),
        max(u_bbox[1], g_bbox[1]),
        min(u_bbox[2], g_bbox[2]),
        max(u_bbox[3], g_bbox[3]),
    )
    # Optically centre the whole group: the umbrella is much taller than the
    # word, so the pair is centred as ONE composition, not each piece.
    dy = CANVAS / 2 - (bbox[2] + bbox[3]) / 2
    svg = f"""<!-- Generated by tool/branding/generate_app_icon.py - do not edit by hand.
     Brand red {BRAND_RED} == AppColors.brandRed; umbrella and "Go" {WHITE}.
     "Go" is converted to outlines from Manrope ExtraBold (AppWordmark). -->
<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">
  <rect width="{CANVAS}" height="{CANVAS}" fill="{BRAND_RED}"/>
  <g fill="{WHITE}" transform="translate(0 {dy:.1f})">
    <path d="{umbrella}"/>
    <path d="{go}"/>
  </g>
</svg>
"""
    return svg, bbox


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

    glyph_set, g_glyph, o_glyph, upm, adv_g, adv_o = load_go()

    for spec, svg_path in ((IOS, IOS_SVG), (ADAPTIVE, ADAPTIVE_SVG)):
        svg, bbox = build_svg(
            spec, glyph_set, g_glyph, o_glyph, upm, adv_g, adv_o
        )
        svg_path.parent.mkdir(parents=True, exist_ok=True)
        svg_path.write_text(svg, encoding="utf-8")
        w = bbox[1] - bbox[0]
        h = bbox[3] - bbox[2]
        print(
            f"{svg_path}: ink {w:.0f}x{h:.0f}, "
            f"diagonal {(w * w + h * h) ** 0.5:.0f}"
        )

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
