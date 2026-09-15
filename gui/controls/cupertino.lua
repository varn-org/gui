local theme = require("gui.controls.theme")

--- Apple's controls, at the sizes and the motion the platform draws them at.
---
--- Nothing here splashes. A press dims what was pressed and lets it come back, which is what every
--- control on that system does, so the press effect is a highlight and the ripple is absent rather than
--- turned down. The switch is the shape the rest of the industry copied: a pill track, a white thumb
--- standing slightly proud of it with a shadow under it, and no outline anywhere.
local EASE = { 0.25, 0.1, 0.25, 1 }

return theme.define({
    name = "cupertino",

    controls = {
        button = {
            metrics = { height = 44, touch = 44, paddingHorizontal = 16, radius = 10, gap = 6, border = 0, ripple = 0 },
            paint = {
                container = { rest = "primary", pressed = "primaryHover", disabled = "disabledSurface" },
                label = { rest = "onPrimary", disabled = "disabledText" },
                ripple = { rest = "onPrimary" },
                tint = { rest = "surfaceVariant", disabled = "disabledSurface" },
                outline = { rest = "primary", disabled = "disabledOutline" },
            },
            motion = { duration = 120, easing = EASE },
            press = "highlight",
        },

        checkbox = {
            metrics = { size = 22, radius = 999, border = 2, touch = 44, gap = 12, mark = 2 },
            paint = {
                box = {
                    rest = "outline",
                    on = "primary",
                    disabled = "disabledOutline",
                    disabledOn = "disabledSurface",
                    invalid = "danger",
                },
                mark = { rest = "onPrimary", disabled = "disabledText" },
                label = { rest = "text", disabled = "disabledText" },
            },
            motion = { duration = 120, easing = EASE },
            press = "highlight",
        },

        radio = {
            metrics = { size = 22, border = 2, dot = 12, touch = 44, gap = 12 },
            paint = {
                ring = { rest = "outline", on = "primary", disabled = "disabledOutline" },
                dot = { rest = "primary", disabled = "disabledOutline" },
                label = { rest = "text", disabled = "disabledText" },
            },
            motion = { duration = 120, easing = EASE },
            press = "highlight",
        },

        switch = {
            metrics = {
                width = 51, height = 31, radius = "pill", border = 0,
                thumb = 27, thumbOn = 27, inset = 2, touch = 44, mark = 0, shadow = "sm",
            },
            paint = {
                track = {
                    rest = "disabledOutline",
                    on = "success",
                    disabled = "disabledSurface",
                    disabledOn = "disabledSurface",
                },
                thumb = { rest = "background", on = "background", disabled = "disabledSurface" },
                mark = { rest = "background" },
            },
            motion = { duration = 200, easing = EASE },
            press = "none",
        },

        slider = {
            metrics = { track = 4, touch = 44, radius = "pill", thumbWidth = 28, thumbHeight = 28, gap = 0, tick = 2, touch = 44 },
            paint = {
                track = { rest = "disabledOutline", disabled = "disabledSurface" },
                fill = { rest = "primary", disabled = "disabledOutline" },
                thumb = { rest = "background", disabled = "disabledSurface" },
                tick = { rest = "onSurfaceVariant" },
            },
            motion = { duration = 100, easing = EASE },
            press = "none",
        },

        stepper = {
            metrics = { height = 32, button = 44, touch = 44, radius = 8, gap = 1, border = 0, valueWidth = 0 },
            paint = {
                container = { rest = "surfaceVariant", disabled = "disabledSurface" },
                button = { rest = "text", disabled = "disabledText" },
                value = { rest = "text", disabled = "disabledText" },
            },
            motion = { duration = 120, easing = EASE },
            press = "highlight",
        },

        segmented = {
            metrics = { height = 32, touch = 44, radius = 8, border = 0, paddingHorizontal = 12, gap = 2, mark = 0 },
            paint = {
                track = { rest = "surfaceVariant", disabled = "disabledSurface" },
                segment = { rest = "surfaceVariant", on = "background", disabled = "disabledSurface" },
                label = { rest = "text", on = "text", disabled = "disabledText" },
            },
            motion = { duration = 200, easing = EASE },
            press = "none",
        },

        select = {
            metrics = { height = 44, radius = 10, border = 0, paddingHorizontal = 16, gap = 8, menuRadius = 14, option = 44 },
            paint = {
                field = { rest = "surfaceVariant", pressed = "disabledSurface", disabled = "disabledSurface" },
                label = { rest = "text", disabled = "disabledText" },
                indicator = { rest = "onSurfaceVariant", disabled = "disabledText" },
                menu = { rest = "elevated" },
                option = { rest = "text", on = "primary" },
            },
            motion = { duration = 200, easing = EASE },
            press = "highlight",
        },

        progress = {
            metrics = { thickness = 4, circle = 36 },
            paint = { track = { rest = "disabledOutline" }, fill = { rest = "primary" } },
            motion = { duration = 200, easing = EASE },
            press = "none",
        },

        spinner = {
            metrics = { thickness = 3, sweep = 300 },
            paint = { arc = { rest = "onSurfaceVariant" } },
            motion = { duration = 900, easing = EASE },
            press = "none",
        },
        swatches = {
            metrics = { size = 34, touch = 44, radius = "pill", gap = 8, border = 2, mark = 2 },
            paint = {
                swatch = { rest = "surface", disabled = "disabledSurface" },
                mark = { rest = "onPrimary" },
                outline = { rest = "outline", on = "text" },
            },
            motion = { duration = 120, easing = EASE },
            press = "highlight",
        },

        calendar = {
            metrics = { day = 44, radius = "pill", gap = 8 },
            paint = {
                day = { rest = "background", on = "primary", disabled = "background" },
                number = { rest = "text", on = "onPrimary", disabled = "disabledText" },
                weekday = { rest = "onSurfaceVariant" },
            },
            motion = { duration = 120, easing = EASE },
            press = "highlight",
        },

        clock = {
            metrics = { size = 200, minutes = 1, radius = 14, gap = 8, column = 72, row = 44 },
            paint = {
                face = { rest = "surfaceVariant", on = "primary" },
                number = { rest = "text", on = "onPrimary" },
                hand = { rest = "primary" },
            },
            motion = { duration = 200, easing = EASE },
            press = "highlight",
        },

        collection = {
            metrics = { separator = 1, separatorInset = 16, dot = 7, dotGap = 6, header = 36 },
            paint = {
                separator = { rest = "separator" },
                dot = { rest = "separator", on = "primary" },
                header = { rest = "onSurfaceVariant" },
            },
            motion = { duration = 120, easing = EASE },
            press = "none",
        },

        card = {
            metrics = { radius = 10, padding = "md", elevation = "sm", border = 1 },
            paint = {
                container = { rest = "background", pressed = "surfaceVariant", hovered = "surfaceVariant" },
                outline = { rest = "outline" },
            },
            motion = { duration = 120, easing = EASE },
            press = "highlight",
        },

        tooltip = {
            metrics = { radius = 8, paddingHorizontal = 8, paddingVertical = 4 },
            paint = { container = { rest = "text" }, label = { rest = "background" } },
            motion = { duration = 120, easing = EASE },
            press = "none",
        },

        rating = {
            metrics = { size = 24, gap = 6, touch = 44 },
            paint = { mark = { rest = "disabledOutline", on = "warning", disabled = "disabledOutline" } },
            motion = { duration = 120, easing = EASE },
            press = "none",
        },

        field = {
            metrics = {
                height = 44, radius = 10, border = 0, focusBorder = 0, paddingHorizontal = 12,
                labelSize = "body", helperSize = "footnote", gap = 6, label = "beside",
            },
            paint = {
                container = { rest = "surfaceVariant", disabled = "disabledSurface" },
                label = { rest = "text", invalid = "danger", disabled = "disabledText" },
                text = { rest = "text", disabled = "disabledText" },
                helper = { rest = "onSurfaceVariant", invalid = "danger", disabled = "disabledText" },
                indicator = { rest = "separator", focused = "primary", invalid = "danger", disabled = "disabledOutline" },
            },
            motion = { duration = 120, easing = EASE },
            press = "none",
        },
    },
})
