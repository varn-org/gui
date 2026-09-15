local theme = require("gui.controls.theme")

--- Material Design 2, at the sizes and the motion it publishes.
---
--- The switch is the one that reads as this version rather than the one after it: a thin track with the
--- thumb standing over it and overhanging it on both sides, rather than a wide track holding the thumb
--- inside. Corners are small, buttons carry their words in capitals at a wide tracking, and a press is
--- always a ripple from where the finger landed.
local STANDARD = { 0.4, 0, 0.2, 1 }

return theme.define({
    name = "material2",

    controls = {
        button = {
            metrics = { height = 36, touch = 48, paddingHorizontal = 16, radius = 4, gap = 8, border = 1, ripple = 0.16 },
            paint = {
                container = { rest = "primary", hovered = "primaryHover", disabled = "disabledSurface" },
                label = { rest = "onPrimary", disabled = "disabledText" },
                ripple = { rest = "onPrimary" },
                tint = { rest = "primaryMuted", disabled = "disabledSurface" },
                outline = { rest = "primary", disabled = "disabledOutline" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "ripple",
        },

        checkbox = {
            metrics = { size = 18, radius = 2, border = 2, touch = 48, gap = 16, mark = 2 },
            paint = {
                box = {
                    rest = "onSurfaceVariant",
                    on = "primary",
                    disabled = "disabledOutline",
                    disabledOn = "disabledSurface",
                    invalid = "danger",
                },
                mark = { rest = "onPrimary", disabled = "disabledText" },
                label = { rest = "text", disabled = "disabledText" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "ripple",
        },

        radio = {
            metrics = { size = 20, border = 2, dot = 10, touch = 48, gap = 16 },
            paint = {
                ring = { rest = "onSurfaceVariant", on = "primary", disabled = "disabledOutline" },
                dot = { rest = "primary", disabled = "disabledOutline" },
                label = { rest = "text", disabled = "disabledText" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "ripple",
        },

        switch = {
            metrics = {
                width = 34, height = 14, radius = "pill", border = 0,
                thumb = 20, thumbOn = 20, inset = -3, touch = 48, mark = 0, shadow = "sm",
            },
            paint = {
                track = {
                    rest = "disabledOutline",
                    on = "primaryMuted",
                    disabled = "disabledSurface",
                    disabledOn = "disabledSurface",
                },
                thumb = { rest = "background", on = "primary", disabled = "disabledOutline" },
                mark = { rest = "primary" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "ripple",
        },

        slider = {
            metrics = { track = 2, touch = 48, radius = "pill", thumbWidth = 20, thumbHeight = 20, gap = 0, tick = 2, touch = 48 },
            paint = {
                track = { rest = "disabledOutline", disabled = "disabledSurface" },
                fill = { rest = "primary", disabled = "disabledOutline" },
                thumb = { rest = "primary", disabled = "disabledOutline" },
                tick = { rest = "onPrimary" },
            },
            motion = { duration = 100, easing = STANDARD },
            press = "none",
        },

        stepper = {
            metrics = { height = 36, button = 36, touch = 48, radius = 4, gap = 0, border = 1, valueWidth = 48 },
            paint = {
                container = { rest = "outline", disabled = "disabledOutline" },
                button = { rest = "primary", disabled = "disabledText" },
                value = { rest = "text", disabled = "disabledText" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "ripple",
        },

        segmented = {
            metrics = { height = 36, touch = 48, radius = 4, border = 1, paddingHorizontal = 12, gap = 8, mark = 0 },
            paint = {
                track = { rest = "outline", disabled = "disabledOutline" },
                segment = { rest = "background", on = "primaryMuted", disabled = "disabledSurface" },
                label = { rest = "onSurfaceVariant", on = "primary", disabled = "disabledText" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "ripple",
        },

        select = {
            metrics = { height = 56, radius = 4, border = 1, paddingHorizontal = 12, gap = 12, menuRadius = 4, option = 48 },
            paint = {
                field = { rest = "surfaceVariant", focused = "surfaceVariant", disabled = "disabledSurface" },
                label = { rest = "text", disabled = "disabledText" },
                indicator = { rest = "onSurfaceVariant", focused = "primary", disabled = "disabledText" },
                menu = { rest = "elevated" },
                option = { rest = "text", on = "primary" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "ripple",
        },

        progress = {
            metrics = { thickness = 4, circle = 40 },
            paint = { track = { rest = "primaryMuted" }, fill = { rest = "primary" } },
            motion = { duration = 200, easing = STANDARD },
            press = "none",
        },

        spinner = {
            metrics = { thickness = 4, sweep = 270 },
            paint = { arc = { rest = "primary" } },
            motion = { duration = 800, easing = STANDARD },
            press = "none",
        },
        swatches = {
            metrics = { size = 36, touch = 48, radius = 4, gap = 8, border = 2, mark = 2 },
            paint = {
                swatch = { rest = "surface", disabled = "disabledSurface" },
                mark = { rest = "onPrimary" },
                outline = { rest = "outline", on = "text" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "ripple",
        },

        calendar = {
            metrics = { day = 44, radius = "pill", gap = 8 },
            paint = {
                day = { rest = "background", on = "primary", disabled = "background" },
                number = { rest = "text", on = "onPrimary", disabled = "disabledText" },
                weekday = { rest = "onSurfaceVariant" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "ripple",
        },

        clock = {
            metrics = { size = 200, minutes = 5, radius = 4, gap = 8, column = 72, row = 44 },
            paint = {
                face = { rest = "surfaceVariant", on = "primary" },
                number = { rest = "text", on = "onPrimary" },
                hand = { rest = "primary" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "ripple",
        },

        collection = {
            metrics = { separator = 1, separatorInset = 16, dot = 8, dotGap = 8, header = 40 },
            paint = {
                separator = { rest = "separator" },
                dot = { rest = "separator", on = "primary" },
                header = { rest = "onSurfaceVariant" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "none",
        },

        card = {
            metrics = { radius = 4, padding = "md", elevation = "sm", border = 1 },
            paint = {
                container = { rest = "background", pressed = "surfaceVariant", hovered = "surfaceVariant" },
                outline = { rest = "outline" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "ripple",
        },

        tooltip = {
            metrics = { radius = 4, paddingHorizontal = 8, paddingVertical = 4 },
            paint = { container = { rest = "text" }, label = { rest = "background" } },
            motion = { duration = 200, easing = STANDARD },
            press = "none",
        },

        rating = {
            metrics = { size = 24, gap = 4, touch = 48 },
            paint = { mark = { rest = "disabledOutline", on = "warning", disabled = "disabledOutline" } },
            motion = { duration = 200, easing = STANDARD },
            press = "none",
        },

        field = {
            metrics = {
                height = 56, radius = 4, border = 1, focusBorder = 2, paddingHorizontal = 12,
                labelSize = "caption", helperSize = "caption", gap = 4, label = "above",
            },
            paint = {
                container = { rest = "surfaceVariant", disabled = "disabledSurface" },
                label = { rest = "onSurfaceVariant", focused = "primary", invalid = "danger", disabled = "disabledText" },
                text = { rest = "text", disabled = "disabledText" },
                helper = { rest = "onSurfaceVariant", invalid = "danger", disabled = "disabledText" },
                indicator = { rest = "onSurfaceVariant", focused = "primary", invalid = "danger", disabled = "disabledOutline" },
            },
            motion = { duration = 200, easing = STANDARD },
            press = "none",
        },
    },
})
