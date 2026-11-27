"""Keep the generated native splash outputs on the fixed dark splash.

`flutter_native_splash:create` writes a white iOS storyboard background and
`contentMode="center"` every time it runs. The packaged splash image already
has the dark field, but a white storyboard can flash before that image loads.
The generator also emits trailing spaces in `web/index.html`, which fail
`git diff --check`. Run this after every native splash regeneration:

    dart run flutter_native_splash:create
    python scripts/normalize_ios_launch_screen.py
"""
from __future__ import annotations

import re
from pathlib import Path

STORYBOARD = Path("ios/Runner/Base.lproj/LaunchScreen.storyboard")
WEB_INDEX = Path("web/index.html")

CENTER = 'contentMode="center" image="LaunchImage"'
FIT = 'contentMode="scaleAspectFit" image="LaunchImage"'
WHITE = (
    '<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" '
    'colorSpace="custom" customColorSpace="sRGB"/>'
)
DARK = (
    '<color key="backgroundColor" red="0.066666666669999999" '
    'green="0.066666666669999999" blue="0.066666666669999999" alpha="1" '
    'colorSpace="custom" customColorSpace="sRGB"/>'
)


def normalize_storyboard() -> None:
    text = STORYBOARD.read_bytes().decode("utf-8")
    text = text.replace(CENTER, FIT).replace(WHITE, DARK)
    if FIT not in text or DARK not in text:
        raise SystemExit("unexpected LaunchScreen.storyboard format")
    STORYBOARD.write_bytes(text.encode("utf-8"))


def normalize_web_index() -> None:
    text = WEB_INDEX.read_bytes().decode("utf-8")
    # The generator's HTML template emits whitespace-only lines with two
    # spaces. Strip trailing blanks without changing the file's line endings.
    text = re.sub(r"[ \t]+(?=\r?\n)", "", text)
    WEB_INDEX.write_bytes(text.encode("utf-8"))


def main() -> None:
    normalize_storyboard()
    normalize_web_index()
    print("native splash normalized: #111111 / scaleAspectFit, clean web template")


if __name__ == "__main__":
    main()
