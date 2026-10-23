#!/usr/bin/env python3
"""Build the README showcase GIF from the real UI screenshots in docs/."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "docs" / "assets" / "nvim-go-showcase.gif"
SOURCES = [
    (ROOT / "docs" / "nvim-go-workbench.png", 2200),
    (ROOT / "docs" / "nvim-go-editor.png", 1600),
    (ROOT / "docs" / "nvim-go-hover.png", 2600),
]

WIDTH = 960
HEIGHT = 540
BACKGROUND = (26, 27, 38)


def render_frame(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGB")
    fitted = ImageOps.contain(image, (WIDTH, HEIGHT), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (WIDTH, HEIGHT), BACKGROUND)
    x = (WIDTH - fitted.width) // 2
    y = (HEIGHT - fitted.height) // 2
    canvas.paste(fitted, (x, y))

    # Give every frame its own adaptive palette. A shared GIF palette is what
    # produced the noisy/static-looking screenshot in the first showcase.
    return canvas.quantize(
        colors=256,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    missing = [str(path) for path, _ in SOURCES if not path.is_file()]
    if missing:
        raise SystemExit("Missing showcase source image(s): " + ", ".join(missing))

    frames = [render_frame(path) for path, _ in SOURCES]
    durations = [duration for _, duration in SOURCES]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        args.output,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        disposal=2,
        optimize=False,
    )
    print(f"Wrote {args.output} ({args.output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
