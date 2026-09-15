#!/usr/bin/env python3
"""Draws the product artwork the shop in `sample/apps` is built out of.

A shop that pulls its pictures off a photograph service shows a bowl of strawberries under `Shell Chair`,
which is exactly as wrong as it sounds and is what the demo used to do. Every picture here is drawn from
the shape of the thing it stands for, in one palette, so the grid reads as one catalogue rather than as
whatever a stranger's service happened to answer with.

Nothing here is photography and nothing pretends to be. It is the flat illustration a catalogue uses for
a thing it has no photograph of yet, which is a real shape a real application has.

Run it with `python3 tools/draw-products.py`, which needs Pillow and nothing else. The pictures it writes
are committed, so nobody has to run it to build the sample.
"""

from pathlib import Path

from PIL import Image, ImageDraw

INTO = Path(__file__).resolve().parent.parent / "sample" / "assets" / "images"

# One square, drawn at the size a grid cell is worth on the densest screen the sample runs on.
SIZE = 800

# The palette the whole catalogue is drawn in, so four pictures beside each other read as one shop.
#
# Each product carries a ground, an ink and an accent. The ground is what the tile is, the ink is the
# object itself, and the accent picks out whatever part of it reads as a different material.
PALETTE = {
    "chair": ("#efe7da", "#4a3729", "#b98b55"),
    "lamp": ("#e2e7ec", "#26313a", "#d8a531"),
    "rug": ("#f0e3d5", "#8b4f2e", "#cf9f77"),
    "table": ("#e6eae0", "#3f4a35", "#93a583"),
    "kettle": ("#e9e4ee", "#332c40", "#9b8ab5"),
    "vase": ("#e7e7df", "#3f5256", "#a9bcb7"),
}


def mixed(one, other, share):
    """Answers a colour part of the way between two, which is what a tone lighter than the ink is."""
    first = [int(one[at:at + 2], 16) for at in (1, 3, 5)]
    second = [int(other[at:at + 2], 16) for at in (1, 3, 5)]
    held = [round(a + (b - a) * share) for a, b in zip(first, second)]

    return "#%02x%02x%02x" % tuple(held)


def ground(name):
    """Answers a tile in the product's own ground with the platform the object stands on drawn in."""
    tone = PALETTE[name]
    picture = Image.new("RGB", (SIZE, SIZE), tone[0])
    drawing = ImageDraw.Draw(picture)

    # A soft round platform behind the object, which lifts it off the tile without a shadow to align.
    drawing.ellipse((110, 110, 690, 690), fill=mixed(tone[0], tone[2], 0.45))

    return picture, drawing


def chair():
    """A moulded shell over four splayed legs, seen from the side."""
    picture, drawing = ground("chair")
    ink, accent = PALETTE["chair"][1], PALETTE["chair"][2]

    # The legs first, so the shell sits over them the way it does on the chair.
    for top, bottom in ((300, 250), (330, 400), (520, 470), (545, 620)):
        drawing.line([(top, 470), (bottom, 660)], fill=accent, width=18)

    drawing.line([(240, 660), (640, 660)], fill=accent, width=14)

    # The shell is the seat and the back in one piece, which is what a moulded chair is.
    drawing.polygon([(236, 470), (566, 442), (576, 500), (246, 528)], fill=ink)
    drawing.polygon([(236, 470), (196, 238), (272, 214), (322, 462)], fill=ink)
    drawing.pieslice((190, 190, 420, 300), start=180, end=350, fill=ink)

    return picture


def lamp():
    """A weighted base, an arm that arcs over and a shade at the end of it."""
    picture, drawing = ground("lamp")
    ink, accent = PALETTE["lamp"][1], PALETTE["lamp"][2]

    drawing.ellipse((290, 630, 510, 686), fill=ink)
    drawing.line([(400, 656), (400, 300)], fill=ink, width=18)
    drawing.arc((400, 180, 640, 420), start=180, end=360, fill=ink, width=18)
    drawing.line([(640, 292), (640, 320)], fill=ink, width=18)
    drawing.polygon([(576, 316), (704, 316), (676, 408), (604, 408)], fill=accent)
    drawing.ellipse((600, 396, 680, 422), fill=ink)

    return picture


def rug():
    """A flat weave seen from above, with a border and a run of stripes across it."""
    picture, drawing = ground("rug")
    ink, accent = PALETTE["rug"][1], PALETTE["rug"][2]

    drawing.rounded_rectangle((160, 250, 640, 550), radius=16, fill=accent)
    drawing.rounded_rectangle((160, 250, 640, 550), radius=16, outline=ink, width=20)

    for at in range(4):
        top = 310 + at * 56
        drawing.line([(210, top), (590, top)], fill=ink, width=10)

    drawing.line([(400, 285), (400, 515)], fill=ink, width=10)

    for edge, step in ((250, -26), (550, 26)):
        for at in range(9):
            left = 200 + at * 50
            drawing.line([(left, edge), (left, edge + step)], fill=ink, width=8)

    return picture


def table():
    """A top over two trestles, seen from the side."""
    picture, drawing = ground("table")
    ink, accent = PALETTE["table"][1], PALETTE["table"][2]

    for middle in (280, 520):
        drawing.line([(middle, 340), (middle - 95, 640)], fill=accent, width=20)
        drawing.line([(middle, 340), (middle + 95, 640)], fill=accent, width=20)
        drawing.line([(middle - 58, 520), (middle + 58, 520)], fill=accent, width=14)

    drawing.rounded_rectangle((140, 300, 660, 348), radius=14, fill=ink)
    drawing.line([(170, 640), (630, 640)], fill=ink, width=12)

    return picture


def kettle():
    """A body, a spout, a handle over the top and a lid."""
    picture, drawing = ground("kettle")
    ink, accent = PALETTE["kettle"][1], PALETTE["kettle"][2]

    drawing.arc((300, 190, 500, 420), start=180, end=360, fill=accent, width=24)
    drawing.polygon([(520, 370), (672, 268), (688, 306), (540, 420)], fill=accent)

    drawing.rounded_rectangle((260, 330, 540, 650), radius=70, fill=ink)
    drawing.rounded_rectangle((340, 292, 460, 340), radius=16, fill=accent)
    drawing.rounded_rectangle((312, 440, 488, 480), radius=14, fill=accent)

    return picture


def vase():
    """A narrow neck over a wide body, with two stems out of it."""
    picture, drawing = ground("vase")
    ink, accent = PALETTE["vase"][1], PALETTE["vase"][2]

    drawing.line([(398, 360), (318, 205)], fill=accent, width=12)
    drawing.line([(402, 360), (474, 228)], fill=accent, width=12)
    drawing.ellipse((272, 150, 360, 224), fill=accent)
    drawing.ellipse((440, 178, 516, 248), fill=accent)

    drawing.polygon(
        [(348, 348), (452, 348), (528, 512), (486, 654), (314, 654), (272, 512)],
        fill=ink,
    )
    drawing.rounded_rectangle((344, 318, 456, 362), radius=12, fill=accent)

    return picture


DRAWN = {
    "product-chair.png": chair,
    "product-lamp.png": lamp,
    "product-rug.png": rug,
    "product-table.png": table,
    "product-kettle.png": kettle,
    "product-vase.png": vase,
}


def main():
    for name, draw in DRAWN.items():
        picture = draw()

        picture.save(INTO / name)
        print(f"{name} {picture.width}x{picture.height}")


if __name__ == "__main__":
    main()
