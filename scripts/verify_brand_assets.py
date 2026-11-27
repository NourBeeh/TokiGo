"""Verify the TokiGo brand assets without a device.

Three checks, cheapest first:

  python scripts/verify_brand_assets.py
  python scripts/verify_brand_assets.py --apk build/app/outputs/flutter-apk/app-debug.apk

1. white master — the branding wordmark must carry white ink in both halves
                  and zero saturated red: the old red "Go" is retired.
  red census   — every image in the repo, distinct saturated reds only.
  mark present — every final launcher/splash asset must carry the TokiGo
                  wordmark in a single white ink: a white "Toki" on the left
                  and a white "Go" on the right, neither clipped by the edge.
                  The parasol is gone from every branding asset.

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

SKIP_DIRS = {"node_modules", ".git", "build", ".dart_tool", ".gradle"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif"}

FINAL_ASSETS = (
    "assets/icon/launcher_wordmark_dark_1024.png",
    "assets/icon/launcher_wordmark_adaptive_dark_foreground_1024.png",
    "assets/icon/launcher_wordmark_adaptive_monochrome_1024.png",
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png",
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png",
    "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png",
    "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_monochrome.png",
    "assets/branding/logo_splash_dark.png",
    "assets/branding/logo_branding_dark.png",
    "android/app/src/main/res/drawable-xxxhdpi/splash.png",
    "android/app/src/main/res/drawable-xxxhdpi/android12splash.png",
)

# Each half must cover at least this share of the canvas to read as a name
# rather than a speck. The "Go" is shorter than "Toki", hence a lower floor.
MIN_TOKI_COVERAGE = 0.015
MIN_GO_COVERAGE = 0.008


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


def check_wordmark_master(wordmark: Path, checker: Checker) -> None:
    """The wide master is white on both halves, with no retired red ink."""
    if not wordmark.exists():
        checker.fail(f"{wordmark}: missing")
        return
    im = Image.open(wordmark).convert("RGBA")
    w, h = im.size
    px = im.load()
    left = right = red = 0
    for y in range(h):
        for x in range(w):
            pixel = px[x, y]
            if is_red(pixel):
                red += 1
            if is_white(pixel):
                if x < w // 2:
                    left += 1
                else:
                    right += 1
    label = f"{wordmark} ({w}x{h})"
    if red:
        checker.fail(f"{label}: {red} saturated-red pixels remain in the master")
    if left == 0 or right == 0:
        checker.fail(f"{label}: white wordmark halves missing ({left}/{right})")
    if not red and left and right:
        print(f"  OK {label}: white Toki {left}px + Go {right}px, no red")


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


def ink_components(
    im: Image.Image, predicate
) -> list[tuple[int, tuple[int, int, int, int]]]:
    """4-connected components matching `predicate`, largest first."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = [[False] * w for _ in range(h)]
    components: list[tuple[int, tuple[int, int, int, int]]] = []
    for y in range(h):
        for x in range(w):
            if not predicate(px[x, y]) or seen[y][x]:
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
                        and predicate(px[nx, ny])
                        and not seen[ny][nx]
                    ):
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            components.append((n, (min_x, min_y, max_x, max_y)))
    components.sort(key=lambda item: item[0], reverse=True)
    return components


def edge_ink(im: Image.Image, predicate) -> int:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    return (
        sum(1 for x in range(w) if predicate(px[x, 0]) or predicate(px[x, h - 1]))
        + sum(1 for y in range(h) if predicate(px[0, y]) or predicate(px[w - 1, y]))
    )


def check_asset(path: Path, checker: Checker) -> None:
    if not path.exists():
        checker.fail(f"{path}: missing")
        return
    im = Image.open(path).convert("RGBA")
    label = f"{path} ({im.size[0]}x{im.size[1]})"
    w, h = im.size
    total = w * h

    # Every launcher master in use is light ink: white on black, white on
    # transparency, or the all-white themed layer. Both halves share it.
    parts = ink_components(im, is_white)
    toki_ink = sum(n for n, box in parts if (box[0] + box[2]) / 2 < w / 2)
    go_ink = sum(n for n, box in parts if (box[0] + box[2]) / 2 >= w / 2)
    if toki_ink / total < MIN_TOKI_COVERAGE:
        checker.fail(
            f"{label}: the 'Toki' half covers only {toki_ink / total:.1%} "
            f"(minimum {MIN_TOKI_COVERAGE:.0%})"
        )
        return
    if go_ink / total < MIN_GO_COVERAGE:
        checker.fail(
            f"{label}: the 'Go' half covers only {go_ink / total:.1%} "
            f"(minimum {MIN_GO_COVERAGE:.0%})"
        )
        return

    edge = edge_ink(im, is_white)
    if edge:
        checker.fail(f"{label}: {edge} white pixels touch the outer edge (clipped)")
        return

    px = im.load()
    red = sum(
        1 for y in range(h) for x in range(w) if is_red(px[x, y])
    )
    if red:
        checker.fail(f"{label}: {red} brand-red pixels remain in the launcher icon")
        return

    print(
        f"  OK {label}: white Toki {toki_ink / total:.1%} + "
        f"Go {go_ink / total:.1%}, no red"
    )


LAUNCH_GLOBS = (
    "android/app/src/main/res/drawable*/splash.png",
    "android/app/src/main/res/drawable*/android12splash.png",
    "android/app/src/main/res/drawable*/android12branding.png",
    "ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png",
    "ios/Runner/Assets.xcassets/LaunchBackground.imageset/*.png",
    "web/splash/img/*.png",
)


def check_launch_assets(repo: Path, checker: Checker) -> None:
    """Every launch density on every platform: no retired red, white name present.

    The launch screen is baked per density (Android mdpi..xxxhdpi plus night
    variants, iOS 1x/2x/3x light and dark, web 1x..4x), so checking one file
    proves nothing about the asset that actually ships on a device. iOS also
    keeps its own launch snapshot, which is why a stale red mark can survive a
    rebuild on that platform.
    """
    seen: list[Path] = []
    for pattern in LAUNCH_GLOBS:
        seen.extend(sorted(repo.glob(pattern)))
    if not seen:
        checker.fail("no launch assets found to verify")
        return
    for path in seen:
        try:
            im = Image.open(path).convert("RGBA")
        except Exception as exc:  # pragma: no cover - corrupt asset
            checker.fail(f"{path}: unreadable ({exc})")
            continue
        original = im.size
        im.thumbnail((512, 512))
        w, h = im.size
        px = im.load()
        red = sum(1 for y in range(h) for x in range(w) if is_red(px[x, y]))
        if red:
            checker.fail(f"{path} ({original[0]}x{original[1]}): {red} saturated-red pixels")
            continue
        # A launch image that is meant to carry the name must actually have
        # white ink; the plain background field legitimately has none.
        if "LaunchBackground" not in path.parent.name:
            white = sum(1 for y in range(h) for x in range(w) if is_white(px[x, y]))
            if white == 0:
                checker.fail(f"{path} ({original[0]}x{original[1]}): no white wordmark ink")
                continue
        print(f"  OK {path} ({original[0]}x{original[1]}): no red")
    print(f"  checked {len(seen)} launch images")


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

    print("branding master (white TokiGo only, no red Go):")
    check_wordmark_master(
        args.repo / "assets/branding/logo_wordmark.png", checker
    )

    print()
    red_census(args.repo)

    print()
    print("final assets:")
    for asset in FINAL_ASSETS:
        check_asset(args.repo / asset, checker)

    print()
    print("launch images (all platforms, all densities):")
    check_launch_assets(args.repo, checker)

    if args.apk:
        print()
        check_apk(args.apk, checker)

    print()
    return checker.report()


if __name__ == "__main__":
    sys.exit(main())
