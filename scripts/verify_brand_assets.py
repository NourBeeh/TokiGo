"""Verify the TokiGo brand assets without a device.

Three checks, cheapest first:

  python scripts/verify_brand_assets.py
  python scripts/verify_brand_assets.py --apk build/app/outputs/flutter-apk/app-debug.apk

1. brand red   — samples the pixels of the wordmark's "Go" and prints the
                  dominant red, so the token is checked against the ARTIFACT
                  rather than against a claim.
  red census   — every image in the repo, distinct saturated reds only.
  mark present — each final icon asset must carry a real white parasol: a
                  connected white component covering a meaningful share of the
                  canvas, with no white pixel touching the outer edge (a
                  clipped mark reads as a missing one). Assets that paint a
                  background must paint it in the brand red.

Exit code is non-zero if any check fails.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
import zipfile
from collections import Counter, deque
from pathlib import Path

from PIL import Image

CANVAS = 1024
# Android adaptive icons guarantee only the central 66% is visible.
SAFE_FRACTION = 0.66
EXPECTED_BRAND_RED = (255, 45, 45)  # #FF2D2D, the "Go" of the wordmark

SKIP_DIRS = {"node_modules", ".git", "build", ".dart_tool", ".gradle"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif"}

FINAL_ASSETS = (
    "assets/icon/app_icon_1024.png",
    "assets/icon/app_icon_adaptive_foreground_1024.png",
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png",
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png",
    "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png",
    "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_monochrome.png",
)

# The parasol must cover at least this share of the canvas to read as the
# brand mark rather than a speck.
MIN_MARK_COVERAGE = 0.02


class Checker:
    def __init__(self) -> None:
        self.failures: list[str] = []

    def fail(self, message: str) -> None:
        self.failures.append(message)

    def report(self) -> int:
        for message in self.failures:
            print(f"  FAIL {message}")
        if self.failures:
            print(f"{len(self.failures)} check(s) failed")
            return 1
        print("all brand asset checks passed")
        return 0


def is_white(pixel) -> bool:
    r, g, b = pixel[:3]
    a = pixel[3] if len(pixel) > 3 else 255
    return r > 200 and g > 200 and b > 200 and a > 128


def is_red(pixel) -> bool:
    r, g, b = pixel[:3]
    a = pixel[3] if len(pixel) > 3 else 255
    return a > 200 and r > 120 and r - max(g, b) > 50


def brand_red(wordmark: Path) -> tuple[int, int, int] | None:
    """Dominant red in the RIGHT half of the wordmark — that is the "Go"."""
    if not wordmark.exists():
        return None
    im = Image.open(wordmark).convert("RGBA")
    w, h = im.size
    px = im.load()
    counts: Counter = Counter()
    for y in range(h):
        for x in range(w // 2, w):
            pixel = px[x, y]
            if is_red(pixel):
                counts[pixel[:3]] += 1
    return counts.most_common(1)[0][0] if counts else None


def red_census(repo: Path) -> None:
    """Every distinct saturated red across the repo's images."""
    counts: Counter = Counter()
    for path in repo.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in IMAGE_EXTS:
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        try:
            im = Image.open(path).convert("RGBA")
        except Exception:
            continue
        im.thumbnail((512, 512))
        px = im.load()
        w, h = im.size
        for y in range(h):
            for x in range(w):
                pixel = px[x, y]
                if is_red(pixel):
                    counts[pixel[:3]] += 1
    print("distinct reds across the repo's images:")
    if not counts:
        print("  none")
        return
    for (r, g, b), n in counts.most_common(8):
        print(f"  #{r:02X}{g:02X}{b:02X}  x{n}")


def white_components(im: Image.Image) -> list[tuple[int, tuple[int, int, int, int]]]:
    """4-connected white components, largest first: (pixel count, bbox)."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = [[False] * w for _ in range(h)]
    components: list[tuple[int, tuple[int, int, int, int]]] = []
    for y in range(h):
        for x in range(w):
            if not is_white(px[x, y]) or seen[y][x]:
                continue
            queue = deque([(x, y)])
            seen[y][x] = True
            n = 0
            min_x = max_x = x
            min_y = max_y = y
            while queue:
                cx, cy = queue.popleft()
                n += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if (
                        0 <= nx < w
                        and 0 <= ny < h
                        and is_white(px[nx, ny])
                        and not seen[ny][nx]
                    ):
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            components.append((n, (min_x, min_y, max_x, max_y)))
    components.sort(key=lambda item: item[0], reverse=True)
    return components


def edge_white(im: Image.Image) -> int:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    return (
        sum(1 for x in range(w) if is_white(px[x, 0]) or is_white(px[x, h - 1]))
        + sum(1 for y in range(h) if is_white(px[0, y]) or is_white(px[w - 1, y]))
    )


def dominant_red(im: Image.Image) -> tuple[int, int, int] | None:
    """Most common saturated red in the image, if any."""
    im = im.convert("RGBA")
    im.thumbnail((512, 512))
    px = im.load()
    w, h = im.size
    counts: Counter = Counter()
    for y in range(h):
        for x in range(w):
            pixel = px[x, y]
            if is_red(pixel):
                counts[pixel[:3]] += 1
    return counts.most_common(1)[0][0] if counts else None


def check_asset(path: Path, checker: Checker) -> None:
    if not path.exists():
        checker.fail(f"{path}: missing")
        return
    im = Image.open(path)
    label = f"{path} ({im.size[0]}x{im.size[1]})"

    components = white_components(im)
    if not components:
        checker.fail(f"{label}: no white parasol found")
        return
    area, (min_x, min_y, max_x, max_y) = components[0]
    coverage = area / (im.size[0] * im.size[1])
    if coverage < MIN_MARK_COVERAGE:
        checker.fail(
            f"{label}: the white mark covers only {coverage:.1%} of the canvas "
            f"(minimum {MIN_MARK_COVERAGE:.0%})"
        )
        return

    edge = edge_white(im)
    if edge:
        checker.fail(f"{label}: {edge} white pixels touch the outer edge (clipped)")
        return

    # A painted background must be the brand red, not a near-miss.
    red = dominant_red(im)
    if red is not None and red != EXPECTED_BRAND_RED:
        checker.fail(
            f"{label}: background red is "
            f"#{red[0]:02X}{red[1]:02X}{red[2]:02X}, expected "
            f"#{EXPECTED_BRAND_RED[0]:02X}{EXPECTED_BRAND_RED[1]:02X}"
            f"{EXPECTED_BRAND_RED[2]:02X}"
        )
        return

    print(
        f"  OK {label}: parasol covers {coverage:.1%}, "
        f"bbox {max_x - min_x}x{max_y - min_y} at ({min_x},{min_y})"
    )


def check_apk(apk: Path, checker: Checker) -> None:
    if not apk.exists():
        checker.fail(f"{apk}: missing")
        return
    with zipfile.ZipFile(apk) as archive:
        names = [n for n in archive.namelist() if "ic_launcher" in n and n.endswith(".png")]
        if not names:
            checker.fail(f"{apk}: no launcher icon entries")
            return
        print(f"  APK icon entries: {len(names)}")
        with tempfile.TemporaryDirectory() as tmp:
            target = names[0]
            archive.extract(target, tmp)
            check_asset(Path(tmp) / target, checker)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".", type=Path)
    parser.add_argument("--apk", type=Path)
    args = parser.parse_args()

    checker = Checker()

    print("brand red (sampled from the wordmark's 'Go'):")
    sampled = brand_red(args.repo / "assets/branding/logo_wordmark.png")
    if sampled is None:
        checker.fail("assets/branding/logo_wordmark.png: no red pixels found")
    else:
        hexs = "#%02X%02X%02X" % sampled
        print(f"  {hexs}")
        if sampled != EXPECTED_BRAND_RED:
            checker.fail(
                f"logo 'Go' is {hexs}, expected "
                f"#{EXPECTED_BRAND_RED[0]:02X}{EXPECTED_BRAND_RED[1]:02X}"
                f"{EXPECTED_BRAND_RED[2]:02X}"
            )

    print()
    red_census(args.repo)

    print()
    print("final assets:")
    for asset in FINAL_ASSETS:
        check_asset(args.repo / asset, checker)

    if args.apk:
        print()
        check_apk(args.apk, checker)

    print()
    return checker.report()


if __name__ == "__main__":
    sys.exit(main())
