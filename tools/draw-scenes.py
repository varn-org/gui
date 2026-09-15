#!/usr/bin/env python3
"""Draws the artwork the five applications in `sample/apps` are built out of.

Every picture is drawn from the shape of the thing it stands for, in the palette its own application
uses, so a shelf of them reads as one catalogue rather than as whatever a photograph service answered
with. Nothing here is fetched, which is also what keeps the sample free of a network and of a licence.

Run it with `python3 tools/draw-scenes.py`, which needs Pillow and nothing else. What it writes is
committed, so nobody has to run it to build the sample.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

INTO = Path(__file__).resolve().parent.parent / "sample" / "assets" / "images"

SIZE = 640


def mixed(one, other, share):
    first = tuple(int(one[at:at + 2], 16) for at in (1, 3, 5))
    second = tuple(int(other[at:at + 2], 16) for at in (1, 3, 5))

    return tuple(round(first[at] + (second[at] - first[at]) * share) for at in range(3))


def canvas(ground):
    picture = Image.new("RGB", (SIZE, SIZE), ground)
    return picture, ImageDraw.Draw(picture)


def save(picture, name):
    picture.save(INTO / f"{name}.png")
    print(f"  {name}.png")


def ring(draw, middle, radius, fill):
    draw.ellipse([middle[0] - radius, middle[1] - radius, middle[0] + radius, middle[1] + radius], fill=fill)


# A plate of food, drawn as what is on it rather than as a photograph of it.
DISHES = {
    "burger": ("#fdf0e4", "#8a4b1e", "#e8a33c", "#5c8a3a"),
    "pizza": ("#fdeee6", "#b2451f", "#f0c36a", "#7a9e46"),
    "sushi": ("#eef3f2", "#2f4858", "#e8b4a0", "#4f7f6a"),
    "salad": ("#eef5e8", "#3f6b33", "#8fbf5f", "#d5a63a"),
    "noodles": ("#fbf1e2", "#8a5a22", "#d9a441", "#6f8f4a"),
    "dessert": ("#fdeaf0", "#8c3355", "#e8a0bd", "#c8964a"),
}


def dish(name):
    ground, ink, accent, herb = DISHES[name]
    picture, draw = canvas(ground)
    middle = SIZE // 2

    ring(draw, (middle, middle), 250, mixed(ground, "#000000", 0.05))
    ring(draw, (middle, middle), 230, "#ffffff")

    if name == "burger":
        draw.rounded_rectangle([middle - 170, middle - 120, middle + 170, middle - 40], 40, fill=accent)
        draw.rounded_rectangle([middle - 175, middle - 45, middle + 175, middle - 5], 16, fill=herb)
        draw.rounded_rectangle([middle - 170, middle - 10, middle + 170, middle + 55], 22, fill=ink)
        draw.rounded_rectangle([middle - 170, middle + 50, middle + 170, middle + 125], 40, fill=accent)
        for at in range(-3, 4):
            ring(draw, (middle + at * 42, middle - 92), 7, mixed(accent, "#ffffff", 0.7))

    if name == "pizza":
        ring(draw, (middle, middle), 200, accent)
        ring(draw, (middle, middle), 175, mixed(accent, ink, 0.25))
        for angle in range(0, 360, 45):
            at = math.radians(angle)
            ring(draw, (middle + 100 * math.cos(at), middle + 100 * math.sin(at)), 26, ink)
        for angle in range(20, 360, 90):
            at = math.radians(angle)
            ring(draw, (middle + 45 * math.cos(at), middle + 45 * math.sin(at)), 16, herb)

    if name == "sushi":
        for offset in (-120, 0, 120):
            draw.rounded_rectangle([middle + offset - 55, middle - 70, middle + offset + 55, middle + 70], 26, fill="#ffffff")
            draw.rounded_rectangle([middle + offset - 55, middle - 70, middle + offset + 55, middle - 20], 20, fill=accent)
            draw.rounded_rectangle([middle + offset - 58, middle - 10, middle + offset + 58, middle + 30], 8, fill=ink)
        draw.rounded_rectangle([middle - 200, middle + 120, middle + 200, middle + 150], 14, fill=herb)

    if name == "salad":
        for angle in range(0, 360, 30):
            at = math.radians(angle)
            draw.ellipse([
                middle + 110 * math.cos(at) - 55, middle + 110 * math.sin(at) - 38,
                middle + 110 * math.cos(at) + 55, middle + 110 * math.sin(at) + 38,
            ], fill=accent if angle % 60 else herb)
        ring(draw, (middle, middle), 60, mixed(herb, "#ffffff", 0.4))
        for angle in range(0, 360, 72):
            at = math.radians(angle)
            ring(draw, (middle + 60 * math.cos(at), middle + 60 * math.sin(at)), 18, ink)

    if name == "noodles":
        for index in range(7):
            top = middle - 90 + index * 26
            draw.arc([middle - 170, top - 40, middle + 170, top + 40], 200, 340, fill=accent, width=14)
        ring(draw, (middle - 80, middle + 60), 34, ink)
        ring(draw, (middle + 70, middle + 40), 28, herb)

    if name == "dessert":
        draw.polygon([(middle - 130, middle + 140), (middle + 130, middle + 140), (middle, middle - 60)], fill=accent)
        ring(draw, (middle, middle - 80), 52, ink)
        ring(draw, (middle, middle - 80), 26, mixed(ink, "#ffffff", 0.6))
        draw.rounded_rectangle([middle - 150, middle + 135, middle + 150, middle + 175], 18, fill=herb)

    save(picture, f"dish-{name}")
    return picture


# The wide picture across the top of a place, which is what it serves rather than the mark on its door.
#
# A logo stretched across a banner is a block of one colour, so the cover is three plates of the place's
# own food on its own ground. The plates are the drawings above rather than a second set at another size.
COVERS = {
    "grill": ("burger", "#f7e2cd"),
    "sushi": ("sushi", "#dde8e6"),
    "green": ("salad", "#e2eed8"),
    "bakery": ("dessert", "#f5e6cf"),
    "pasta": ("pizza", "#f8ddd0"),
    "sweets": ("dessert", "#f7dbe4"),
}

COVER_WIDE = 1200
COVER_TALL = 500


def cover(name, plates):
    which, ground = COVERS[name]
    picture = Image.new("RGB", (COVER_WIDE, COVER_TALL), ground)
    plate = plates[which]

    for index, (across, size) in enumerate(((150, 420), (600, 520), (1030, 380))):
        scaled = plate.resize((size, size), Image.LANCZOS)
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
        picture.paste(scaled, (across - size // 2, COVER_TALL // 2 - size // 2 + (index - 1) * 24), mask)

    save(picture, f"cover-{name}")


# The mark a place carries where a photograph of the place would be.
PLACES = {
    "grill": ("#c8372d", "#ffffff"),
    "sushi": ("#1f3b4d", "#e8f0f2"),
    "green": ("#2f7a3f", "#f0f7ec"),
    "bakery": ("#8a5a22", "#fdf3e2"),
    "pasta": ("#a3321f", "#fcefe6"),
    "sweets": ("#8c3355", "#fdeaf0"),
}


def place(name):
    ground, ink = PLACES[name]
    picture, draw = canvas(ground)
    middle = SIZE // 2

    draw.rounded_rectangle([middle - 190, middle - 190, middle + 190, middle + 190], 70,
                           outline=ink, width=22)

    if name == "grill":
        for offset in (-70, 0, 70):
            draw.rounded_rectangle([middle + offset - 16, middle - 110, middle + offset + 16, middle + 110], 16, fill=ink)
    if name == "sushi":
        ring(draw, (middle, middle), 90, ink)
        ring(draw, (middle, middle), 44, ground)
    if name == "green":
        draw.polygon([(middle, middle - 120), (middle + 110, middle + 90), (middle - 110, middle + 90)], fill=ink)
    if name == "bakery":
        draw.arc([middle - 130, middle - 90, middle + 130, middle + 170], 180, 360, fill=ink, width=40)
        draw.rounded_rectangle([middle - 140, middle + 50, middle + 140, middle + 84], 16, fill=ink)
    if name == "pasta":
        for index in range(5):
            draw.arc([middle - 120, middle - 110 + index * 46, middle + 120, middle - 50 + index * 46],
                     200, 340, fill=ink, width=16)
    if name == "sweets":
        ring(draw, (middle, middle + 30), 86, ink)
        draw.rounded_rectangle([middle - 16, middle - 140, middle + 16, middle - 50], 14, fill=ink)

    save(picture, f"place-{name}")


# The cars a ride application offers, drawn from the side.
CARS = {
    "small": ("#1c1c1e", "#f2f2f4", 0.78),
    "large": ("#1c1c1e", "#f2f2f4", 1.0),
    "black": ("#0b0b0c", "#c9a227", 0.92),
}


def car(name):
    ink, ground, scale = CARS[name]
    picture, draw = canvas(ground)
    middle = SIZE // 2
    width = int(230 * scale)
    height = int(90 * scale)

    draw.rounded_rectangle([middle - width, middle - height // 2, middle + width, middle + height], 40, fill=ink)
    draw.polygon([
        (middle - width + 50, middle - height // 2),
        (middle - width + 130, middle - height - 60),
        (middle + width - 140, middle - height - 60),
        (middle + width - 60, middle - height // 2),
    ], fill=ink)
    draw.polygon([
        (middle - width + 74, middle - height // 2 - 10),
        (middle - width + 140, middle - height - 36),
        (middle - 16, middle - height - 36),
        (middle - 16, middle - height // 2 - 10),
    ], fill=mixed(ink, ground, 0.7))
    draw.polygon([
        (middle + 6, middle - height // 2 - 10),
        (middle + 6, middle - height - 36),
        (middle + width - 150, middle - height - 36),
        (middle + width - 80, middle - height // 2 - 10),
    ], fill=mixed(ink, ground, 0.7))

    for offset in (-width + 90, width - 90):
        ring(draw, (middle + offset, middle + height), 52, mixed(ink, "#000000", 0.4))
        ring(draw, (middle + offset, middle + height), 24, mixed(ink, ground, 0.55))

    save(picture, f"car-{name}")


# The things a marketplace sells, drawn as the shape each of them is.
GOODS = {
    "phone": ("#eef1f5", "#20242b", "#3a7bd5"),
    "shoe": ("#f3eee7", "#2d2a26", "#d24b2f"),
    "watch": ("#eceff3", "#1d1f24", "#c2a24a"),
    "headset": ("#efeaf4", "#2a2233", "#7b5cc4"),
    "camera": ("#eaf0ee", "#1f2a26", "#4f8f74"),
    "console": ("#eef0f4", "#232730", "#d0434f"),
}


def good(name):
    ground, ink, accent = GOODS[name]
    picture, draw = canvas(ground)
    middle = SIZE // 2

    if name == "phone":
        draw.rounded_rectangle([middle - 110, middle - 200, middle + 110, middle + 200], 34, fill=ink)
        draw.rounded_rectangle([middle - 92, middle - 180, middle + 92, middle + 180], 24, fill=accent)
        draw.rounded_rectangle([middle - 30, middle - 192, middle + 30, middle - 176], 8, fill=ink)
    if name == "shoe":
        draw.rounded_rectangle([middle - 200, middle + 40, middle + 200, middle + 120], 36, fill=ink)
        draw.polygon([
            (middle - 200, middle + 50), (middle - 160, middle - 70),
            (middle - 40, middle - 80), (middle + 120, middle + 10), (middle + 200, middle + 50),
        ], fill=accent)
        for at in range(-3, 2):
            draw.line([(middle + at * 34 - 40, middle - 40), (middle + at * 34, middle + 20)], fill=ground, width=10)
    if name == "watch":
        draw.rounded_rectangle([middle - 70, middle - 210, middle + 70, middle + 210], 34, fill=mixed(ink, ground, 0.5))
        draw.rounded_rectangle([middle - 100, middle - 110, middle + 100, middle + 110], 44, fill=ink)
        draw.rounded_rectangle([middle - 82, middle - 92, middle + 82, middle + 92], 34, fill=accent)
    if name == "headset":
        draw.arc([middle - 180, middle - 190, middle + 180, middle + 110], 180, 360, fill=ink, width=40)
        for offset in (-160, 160):
            draw.rounded_rectangle([middle + offset - 52, middle - 50, middle + offset + 52, middle + 110], 34, fill=accent)
    if name == "camera":
        draw.rounded_rectangle([middle - 200, middle - 110, middle + 200, middle + 140], 36, fill=ink)
        draw.rounded_rectangle([middle - 70, middle - 160, middle + 40, middle - 100], 16, fill=ink)
        ring(draw, (middle, middle + 15), 92, mixed(ink, ground, 0.35))
        ring(draw, (middle, middle + 15), 62, accent)
    if name == "console":
        draw.rounded_rectangle([middle - 210, middle - 70, middle + 210, middle + 90], 70, fill=ink)
        ring(draw, (middle + 120, middle + 10), 26, accent)
        draw.rounded_rectangle([middle - 160, middle - 12, middle - 80, middle + 20], 10, fill=accent)
        draw.rounded_rectangle([middle - 136, middle - 36, middle - 104, middle + 44], 10, fill=accent)

    save(picture, f"good-{name}")


# A book cover, which is the whole of what an audiobook application shows.
BOOKS = {
    "tide": ("#12324a", "#7fd3e0", "#f2f7f8"),
    "ember": ("#3b1420", "#e0704f", "#fbeee6"),
    "north": ("#14281f", "#8fbf7a", "#f0f6ea"),
    "glass": ("#2a2040", "#b59ae8", "#f4f0fb"),
    "signal": ("#1d1d22", "#e8c15a", "#f8f4ea"),
    "harbour": ("#0f2d33", "#5fb0a5", "#eef7f5"),
}


def book(name):
    ground, accent, ink = BOOKS[name]
    picture, draw = canvas(ground)
    middle = SIZE // 2

    if name == "tide":
        for index in range(5):
            draw.arc([-60, middle - 120 + index * 64, SIZE + 60, middle + 60 + index * 64],
                     200, 340, fill=accent, width=12)
    if name == "ember":
        ring(draw, (middle, middle + 40), 150, accent)
        ring(draw, (middle, middle + 70), 96, ground)
    if name == "north":
        draw.polygon([(middle, 120), (SIZE - 90, SIZE - 140), (90, SIZE - 140)], fill=accent)
        draw.polygon([(middle, 120), (middle + 80, SIZE - 300), (middle - 80, SIZE - 300)], fill=ground)
    if name == "glass":
        for index in range(4):
            draw.rounded_rectangle([90 + index * 30, 120 + index * 40, SIZE - 90 - index * 30, SIZE - 120],
                                   20, outline=accent, width=8)
    if name == "signal":
        for index in range(5):
            draw.arc([middle - 60 - index * 58, middle - 60 - index * 58,
                      middle + 60 + index * 58, middle + 60 + index * 58], 210, 330, fill=accent, width=12)
        ring(draw, (middle, middle), 22, accent)
    if name == "harbour":
        draw.rounded_rectangle([90, middle + 40, SIZE - 90, middle + 120], 30, fill=accent)
        draw.line([(middle, 120), (middle, middle + 60)], fill=accent, width=12)
        draw.polygon([(middle + 10, 130), (middle + 150, middle - 20), (middle + 10, middle - 20)], fill=ink)

    # Where the title and the author are set, which is two runs rather than one slab.
    draw.rounded_rectangle([60, SIZE - 104, SIZE - 60, SIZE - 76], 8, fill=ink)
    draw.rounded_rectangle([60, SIZE - 64, SIZE - 220, SIZE - 46], 6, fill=mixed(ink, ground, 0.45))

    save(picture, f"book-{name}")


# A face, drawn as the round mark a conversation list carries where a photograph would be.
FACES = {
    "one": "#5a7d9a", "two": "#8a5a7d", "three": "#4f7f6a",
    "four": "#8a6a3a", "five": "#6a5a8a", "six": "#3f6b70",
}


def face(name):
    ground = FACES[name]
    picture, draw = canvas(mixed(ground, "#ffffff", 0.82))
    middle = SIZE // 2

    ring(draw, (middle, middle - 40), 120, ground)
    draw.ellipse([middle - 220, middle + 110, middle + 220, middle + 420], fill=ground)
    save(picture, f"face-{name}")


def main():
    INTO.mkdir(parents=True, exist_ok=True)

    print("drawing what the applications are built out of")

    plates = {}

    for name in DISHES:
        plates[name] = dish(name)
    for name in COVERS:
        cover(name, plates)
    for name in PLACES:
        place(name)
    for name in CARS:
        car(name)
    for name in GOODS:
        good(name)
    for name in BOOKS:
        book(name)
    for name in FACES:
        face(name)


if __name__ == "__main__":
    main()
