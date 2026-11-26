#!/usr/bin/env python3
"""Mirror the fixed launcher icon into Android's night resources.

`flutter_launcher_icons` generates only one adaptive-icon set. TokiGo pins the
wordmark launcher icon in both appearances, so the night set is an exact copy of
the light set rather than a second resize (a different resampler would leave
one-pixel differences on the letter edges):

  mipmap-night-*/ic_launcher.png              black field, white TokiGo wordmark
  drawable-night-*/ic_launcher_foreground.png transparent, same wordmark

`values-night/colors.xml` also has to override `ic_launcher_background` with
#000000. That XML lives in the repo; this script only writes the rasters.

Run it AFTER `dart run flutter_launcher_icons`:

    python tool/branding/generate_launcher_wordmark.py
    dart run flutter_launcher_icons
    python tool/branding/sync_android_night_icons.py

Usage:  python tool/branding/sync_android_night_icons.py
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

RES = Path("android/app/src/main/res")
DENSITIES = ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")


def main() -> int:
    for density in DENSITIES:
        for prefix, filename in (
            ("mipmap", "ic_launcher.png"),
            ("drawable", "ic_launcher_foreground.png"),
        ):
            source = RES / f"{prefix}-{density}" / filename
            out_dir = RES / f"{prefix}-night-{density}"
            if not source.exists():
                raise SystemExit(f"missing {source} (run flutter_launcher_icons first)")
            out_dir.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, out_dir / filename)
            print(f"{source} -> {out_dir / filename}")

    print("now ensure values-night/colors.xml sets ic_launcher_background to #000000")
    return 0


if __name__ == "__main__":
    sys.exit(main())
