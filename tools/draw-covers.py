#!/usr/bin/env python3
"""Draws the cover artwork the listening application in `sample/apps` is built out of.

Cover art for a show is a shape and a palette rather than a photograph, which is why it is the one kind
of picture that can honestly be drawn rather than downloaded. Every cover here is one geometric idea in
two tones, so six of them in a list read as six shows rather than as six stock photographs of nothing.

Run it with `python3 tools/draw-covers.py`, which needs Pillow and nothing else. The pictures it writes
are committed, so nobody has to run it to build the sample.
"""

from pathlib import Path

from PIL import Image, ImageDraw

INTO = Path(__file__).resolve().parent.parent / "sample" / "assets" / "images"

# One square, drawn at the size a cover is worth on the densest screen the sample runs on.
SIZE = 400


def tile(ground):
    picture = Image.new("RGB", (SIZE, SIZE), ground)

    return picture, ImageDraw.Draw(picture)


def signal():
    """A run of bars of falling height, which is what a signal against noise looks like."""
    picture, drawing = tile("#1d2b3a")

    for at in range(9):
        left = 30 + at * 38
        height = (300, 210, 340, 150, 270, 110, 230, 90, 190)[at]

        drawing.rounded_rectangle((left, SIZE - 40 - height, left + 22, SIZE - 40), radius=11, fill="#4fc3f7")

    return picture


def long_way():
    """A road that bends away over a horizon."""
    picture, drawing = tile("#2f3d2c")

    drawing.ellipse((-140, 190, 540, 560), fill="#5c7a4e")
    drawing.polygon([(150, 400), (250, 400), (216, 210), (196, 210)], fill="#e4dcc6")

    for at in range(4):
        top = 240 + at * 42
        drawing.line([(206 + at * 2, top), (208 + at * 2, top + 20)], fill="#2f3d2c", width=8)

    drawing.ellipse((280, 60, 360, 140), fill="#e8c16a")

    return picture


def kitchen():
    """A table seen from above, with three plates on it."""
    picture, drawing = tile("#3b2b24")

    drawing.rounded_rectangle((40, 120, 360, 340), radius=24, fill="#c98f5c")

    for left in (110, 200, 290):
        drawing.ellipse((left - 42, 188, left + 42, 272), fill="#f2e6d5")
        drawing.ellipse((left - 24, 206, left + 24, 254), fill="#c98f5c")

    return picture


def hours():
    """A clock face with two hands, which is the one shape an hour has."""
    picture, drawing = tile("#2b2437")

    drawing.ellipse((60, 60, 340, 340), outline="#d9b38c", width=16)

    drawing.line([(200, 200), (200, 108)], fill="#d9b38c", width=14)
    drawing.line([(200, 200), (276, 236)], fill="#e8a0a0", width=12)
    drawing.ellipse((188, 188, 212, 212), fill="#e8a0a0")

    return picture


def tide():
    """Three waves running across, which is the line a tide leaves."""
    picture, drawing = tile("#12323d")

    for at, tone in enumerate(("#1f5a68", "#2c8296", "#5fc0cf")):
        top = 150 + at * 70

        for step in range(5):
            left = step * 100 - 40
            drawing.arc((left, top - 40, left + 100, top + 40), start=180, end=360, fill=tone, width=16)

    return picture


def before():
    """An arch over a road, which is what is left of what came before."""
    picture, drawing = tile("#33261f")

    drawing.rectangle((90, 200, 130, 360), fill="#cbb08a")
    drawing.rectangle((270, 200, 310, 360), fill="#cbb08a")
    drawing.arc((90, 120, 310, 340), start=180, end=360, fill="#cbb08a", width=40)
    drawing.rectangle((60, 356, 340, 372), fill="#8c7355")
    drawing.ellipse((150, 60, 250, 160), fill="#e0b96b")

    return picture


DRAWN = {
    "show-signal.png": signal,
    "show-long.png": long_way,
    "show-kitchen.png": kitchen,
    "show-hours.png": hours,
    "show-tide.png": tide,
    "show-before.png": before,
}


def main():
    for name, draw in DRAWN.items():
        picture = draw()

        picture.save(INTO / name)
        print(f"{name} {picture.width}x{picture.height}")


if __name__ == "__main__":
    main()
