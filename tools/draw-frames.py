#!/usr/bin/env python3
"""Draws the nine-slice artwork the frames demo is built out of.

A nine-slice picture is cut at four numbers of pixels. The four corners are drawn at their own size and
never stretch, each edge stretches along one axis only, and the middle stretches both ways. That is a
constraint on the artwork itself rather than on the code that draws it: every piece of ornament sits
entirely inside a corner, an edge strip carries only what still reads correctly when it is pulled along
its own axis, and the middle is flat colour.

The window is the one cut unevenly, deeper along its top, so the bar across it belongs to the corner
pieces and is never stretched downwards.

Run it with `python3 tools/draw-frames.py`, which needs Pillow and nothing else. The pictures it writes
are committed, so nobody has to run it to build the sample.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

INTO = Path(__file__).resolve().parent.parent / "sample" / "assets" / "images"

# Where each picture is cut, as top, right, bottom and left, which is the order the screen writes them
# in and the order `border-image-slice` takes. `gui/tests/nineslice_test.lua` holds the two together.
CUTS = {
    "window.png": (28, 28, 28, 28),
    "window-titled.png": (46, 28, 28, 28),
    "button-green.png": (30, 26, 30, 26),
    "button-stone.png": (30, 26, 30, 26),
    "button-pressed.png": (30, 26, 30, 26),
    "button-off.png": (30, 26, 30, 26),
}

# Everything is drawn at one point to the pixel, so a button and the panel it sits on are the same
# material at the same weight. A button drawn half the size had to be scaled to twice that weight to be
# large enough to press, which put every step of its edge at twice the size of every step on the panel
# around it and made the two read as different things badly matched.
SIZE = 96

PANEL = "#292438"

# How far the corners of a button are cut away, how thick its ring is and how wide its bevel is, all in
# the pixels of a picture ninety-six across. A chamfer of twenty gives the staircase twenty steps rather
# than ten, so each one is half the size against the same drawn edge.
# How large a button's picture is and how far its ends are drawn in, in that picture's own pixels.
PLATE = (96, 64)
NOTCH = 7


def bracket(picture, right=False, bottom=False):
    """Draws one corner bracket, turned so that the same shape serves all four corners.

    It is drawn one pixel in from the edge and is twenty-six across, which leaves a pixel to spare
    before the cut at twenty-eight. Which faces are lit is chosen per corner, so the light reads as
    coming from the same place on all four.
    """
    tile = Image.new("RGBA", (26, 26))
    draw = ImageDraw.Draw(tile)

    draw.polygon([(0, 0), (25, 0), (25, 8), (10, 8), (8, 10), (8, 25), (0, 25)], fill="#110f1b")
    draw.polygon([(1, 1), (24, 1), (24, 7), (9, 7), (7, 9), (7, 24), (1, 24)], fill="#665777")
    draw.polygon([(2, 2), (23, 2), (23, 5), (7, 5), (5, 7), (5, 23), (2, 23)], fill="#aa99bf")

    across = "#e0cfea" if not bottom else "#93809f"
    down = "#cab9da" if not right else "#84708f"

    draw.line([(1, 1), (24, 1)], fill=across)
    draw.line([(1, 1), (1, 24)], fill=down)
    draw.line([(3, 3), (21, 3)], fill="#73617f")
    draw.line([(3, 4), (3, 21)], fill="#73617f")
    draw.line([(8, 6), (23, 6)], fill="#392e48")
    draw.line([(6, 8), (6, 23)], fill="#392e48")
    draw.line([(22, 2), (22, 5)], fill="#d2bedf")
    draw.line([(2, 22), (5, 22)], fill="#bba5cc")

    draw.rectangle((10, 10, 21, 21), fill="#15111f")
    draw.rectangle((11, 11, 20, 20), fill="#756382")
    draw.line([(11, 20), (11, 11), (20, 11)], fill="#b7a3bb")
    draw.rectangle((13, 13, 18, 18), fill="#211c30")
    draw.rectangle((14, 14, 17, 17), fill="#706080")
    draw.line([(14, 17), (14, 14), (17, 14)], fill="#bca7cd")
    draw.point((15, 15), fill="#e0cbe9")

    draw.line([(10, 24), (23, 24), (24, 23), (24, 10)], fill="#51415f")

    if right:
        tile = tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)

    if bottom:
        tile = tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)

    picture.alpha_composite(tile, (69 if right else 1, 69 if bottom else 1))


def window(titled=False):
    """Draws the panel: rings of colour round a flat middle, with a bracket at each corner.

    The bar a titled window carries lies entirely inside the top cut of forty-six, so the strip between
    the top corners is stretched across the width and never down the height.
    """
    picture = Image.new("RGBA", (96, 96))
    draw = ImageDraw.Draw(picture)

    draw.rectangle((2, 2, 93, 95), fill="#0d0b14")

    rings = [
        (3, "#251e33"), (4, "#847198"), (5, "#b4a1cb"), (6, "#756587"),
        (7, "#51435f"), (8, "#191420"), (9, "#393047"), (10, PANEL),
    ]

    for inset, colour in rings:
        draw.rectangle((inset, inset, 95 - inset, 95 - inset), fill=colour)

    draw.line((8, 88, 87, 88), fill="#3a2f46")
    draw.line((6, 90, 89, 90), fill="#6c597e")

    if titled:
        draw.rectangle((10, 10, 85, 40), fill="#191522")
        draw.line((10, 10, 85, 10), fill="#211b2e")
        draw.line((10, 41, 85, 41), fill="#191522")
        draw.line((10, 42, 85, 42), fill="#877294")

    for right in (False, True):
        for bottom in (False, True):
            bracket(picture, right, bottom)

    return picture


def plate(size, cut, gradient, ring, notch):
    """Draws the body of a button: a gold plate with its ends drawn in, lit at the top and deep at the base.

    The colour runs down the plate and the cuts leave only a few flat rows between the top and bottom
    pieces, so what is stretched when the button is taller than the picture is a band of one tone rather
    than the run of colour itself. The ends are drawn in, and the whole of that curve lives inside the
    top and bottom pieces with its innermost rows flat, so a side edge is the same row all the way down.
    """
    width, height = size
    top, _, bottom, _ = cut
    picture = Image.new("RGBA", size)
    draw = ImageDraw.Draw(picture)

    def drawnAt(y):
        # The curve is finished by the cut and flat between the cuts, so every row of a side edge is the
        # same row. A curve that ran to the middle of the plate instead would be stretched down the
        # length of a taller button, and what came out would not be the shape that was drawn.
        if y < top:
            near = 1 - y / top
        elif y >= height - bottom:
            near = 1 - (height - 1 - y) / bottom
        else:
            return notch

        return round(notch * (1 - near * near))

    for y in range(height):
        drawn = drawnAt(y)
        draw.line([(drawn, y), (width - 1 - drawn, y)], fill=ring)

    def shareAt(y):
        # The run of colour is finished by the cuts as well, and for the same reason: what a taller
        # button stretches is then a band of one tone rather than the run itself.
        if y < top:
            return y / top / 2

        if y >= height - bottom:
            return 1 - (height - 1 - y) / bottom / 2

        return 0.5

    for y in range(2, height - 2):
        drawn = drawnAt(y)
        draw.line([(drawn + 2, y), (width - 3 - drawn, y)], fill=mixed(gradient, shareAt(y)))

    return picture


def mixed(between, share):
    """Answers the colour a share of the way down a run of two, in whole steps so no band is dithered."""
    first, second = between
    steps = 12
    at = round(share * (steps - 1)) / (steps - 1)

    return tuple(round(a + (b - a) * at) for a, b in zip(first, second))


def clamp(picture, cut, right=False, bottom=False):
    """Draws one metal clamp over a corner of a button, turned so the same shape serves all four."""
    tile = Image.new("RGBA", (22, 22))
    draw = ImageDraw.Draw(tile)

    draw.polygon([(0, 0), (21, 0), (21, 6), (7, 6), (6, 7), (6, 21), (0, 21)], fill="#1d1a2b")
    draw.polygon([(1, 1), (20, 1), (20, 5), (6, 5), (5, 6), (5, 20), (1, 20)], fill="#6f7996")
    draw.polygon([(2, 2), (19, 2), (19, 4), (5, 4), (4, 5), (4, 19), (2, 19)], fill="#c9d2e4")
    draw.line([(2, 2), (19, 2)], fill="#eef2fa")
    draw.line([(2, 2), (2, 19)], fill="#eef2fa")
    draw.line([(18, 6), (18, 18), (6, 18)], fill="#8d97b3")

    if right:
        tile = tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)

    if bottom:
        tile = tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)

    width, height = picture.size
    picture.alpha_composite(tile, (width - 23 if right else 1, height - 23 if bottom else 1))


# The face of each button, as the two colours its plate runs between. A frame drawn from artwork is how a
# button is drawn from artwork, so it carries one of these per state the way a control carries one look
# per state everywhere else.
FACES = {
    "green": ((249, 216, 112), (238, 170, 52)),
    "pressed": ((214, 158, 46), (186, 128, 30)),
    "stone": ((214, 216, 228), (150, 154, 176)),
    "off": ((128, 124, 140), (98, 95, 110)),
}


def button(face="green"):
    """Draws a button: a plate with its ends drawn in and a metal clamp over each of its four corners."""
    gradient = FACES[face]

    picture = plate(PLATE, CUTS["button-green.png"], gradient, "#241f33", NOTCH)

    for right in (False, True):
        for bottom in (False, True):
            clamp(picture, CUTS["button-green.png"], right, bottom)

    return picture


def smeared(picture, cut):
    """Answers every place the artwork and the cuts disagree, which is what a stretch would smear.

    An edge strip is stretched along one axis, so every row of a side edge has to be the same row of
    pixels and every column of a top or bottom edge the same column. Anything sloped, tapered or rounded
    that crosses a cut line is drawn once in the corner piece and pulled out of shape in the strip
    beside it. Looking at the stretched output and comparing it with itself does not see that. Reading
    the pixels does.
    """
    top, right, bottom, left = cut
    width, height = picture.size
    pixels = picture.load()
    faults = []

    for y in range(top, height - bottom):
        for x in list(range(0, left)) + list(range(width - right, width)):
            if pixels[x, y] != pixels[x, top]:
                faults.append(f"the side edge changes down the picture at {x},{y}")
                break

    for x in range(left, width - right):
        for y in list(range(0, top)) + list(range(height - bottom, height)):
            if pixels[x, y] != pixels[left, y]:
                faults.append(f"the top or bottom edge changes across the picture at {x},{y}")
                break

    return faults


def main():
    drawn = {
        "window.png": window(),
        "window-titled.png": window(titled=True),
        "button-green.png": button("green"),
        "button-stone.png": button("stone"),
        "button-pressed.png": button("pressed"),
        "button-off.png": button("off"),
    }

    for name, picture in drawn.items():
        cut = CUTS[name]
        faults = smeared(picture, cut)

        if faults:
            raise SystemExit(f"{name} cannot be cut at {cut}: " + "; ".join(faults[:3]))

        picture.save(INTO / name)
        print(f"{name} {picture.width}x{picture.height} cut at {cut}")


if __name__ == "__main__":
    main()
