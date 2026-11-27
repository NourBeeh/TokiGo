#!/usr/bin/env python3
"""Compatibility entry point: the parasol icon generator is retired.

OWNER DECISION (2026-11-27): the umbrella/mascot was removed from the brand
identity surfaces (launcher, splash, AI). The old `generate_app_icon.py` used to
draw the parasol into the adaptive foreground rasters; leaving it runnable would
let a routine regeneration bring the retired mark back into those surfaces.
Owner follow-up kept one parasol on the Packages quick tile via separate
`assets/icon/packages_parasol*` files, which this wrapper never writes.

This wrapper now delegates to `generate_wordmark.py`, which writes the white
TokiGo wordmark into the same filenames (including the adaptive foreground and
monochrome layers), so every legacy command produces the new brand only.

Usage:  python tool/branding/generate_app_icon.py [--check]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from generate_wordmark import generate_all  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    return generate_all(check="--check" in args)


if __name__ == "__main__":
    sys.exit(main())
