local theme = require("gui.controls.theme")

--- Material Design 3, at the sizes and the motion it publishes.
---
--- What separates it from the version before is mostly the switch and the corners: the track is wide
--- enough to hold the thumb inside it rather than under it, the thumb is small until it is on and carries
--- a tick, an unselected track is outlined, and everything is rounded further than it was.
local EMPHASISED = { 0.2, 0, 0, 1 }
local STANDARD = { 0.2, 0, 0, 1 }

return theme.define({
    name = "material3",

    controls = {
        button = {
            metrics = { height = 40, touch = 48, paddingHorizontal = 24, radius = "pill", gap = 8, border = 1, ripple = 0.12 },
            paint = {
                container = {
                    rest = "primary",
                    hovered = "primaryHover",
                    disabled = "disabledSurface",
                },
                label = { rest = "onPrimary", disabled = "disabledText" },
                ripple = { rest = "onPrimary" },
                tint = { rest = "secondaryContainer", disabled = "disabledSurface" },
                outline = { rest = "outline", disabled = "disabledOutline" },
            },
            motion = { duration = 200, easing = EMPHASISED },
            press = "ripple",
        },

        checkbox = {
            metrics = { size = 18, radius = 2, border = 2, touch = 48, gap = 16, mark = 2 },
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
            motion = { duration = 150, easing = STANDARD },
            press = "ripple",
        },

        radio = {
            metrics = { size = 20, border = 2, dot = 10, touch = 48, gap = 16 },
            paint = {
                ring = { rest = "outline", on = "primary", disabled = "disabledOutline" },
                dot = { rest = "primary", disabled = "disabledOutline" },
                label = { rest = "text", disabled = "disabledText" },
            },
            motion = { duration = 150, easing = STANDARD },
            press = "ripple",
        },

        switch = {
            metrics = {
                width = 52, height = 32, radius = "pill", border = 2,
                thumb = 16, thumbOn = 24, inset = 4, touch = 48, mark = 2, shadow = "none",
            },
            paint = {
                track = {
                    rest = "surfaceVariant",
                    on = "primary",
                    disabled = "disabledSurface",
                    disabledOn = "disabledSurface",
                },
                thumb = { rest = "outline", on = "onPrimary", disabled = "disabledOutline" },
                mark = { rest = "primary", disabled = "disabledText" },
            },
            motion = { duration = 200, easing = EMPHASISED },
            press = "ripple",
        },

        slider = {
            metrics = { track = 16, touch = 48, radius = "pill", thumbWidth = 4, thumbHeight = 44, gap = 6, tick = 4, touch = 48 },
            paint = {
                track = { rest = "surfaceVariant", disabled = "disabledSurface" },
                fill = { rest = "primary", disabled = "disabledOutline" },
                thumb = { rest = "primary", disabled = "disabledOutline" },
                tick = { rest = "onPrimary" },
            },
            motion = { duration = 100, easing = STANDARD },
            press = "none",
        },

        stepper = {
            metrics = { height = 40, button = 40, touch = 48, radius = "pill", gap = 4, border = 1, valueWidth = 48 },
            paint = {
                container = { rest = "surfaceVariant", disabled = "disabledSurface" },
                button = { rest = "onSurfaceVariant", disabled = "disabledText" },
                value = { rest = "text", disabled = "disabledText" },
            },
            motion = { duration = 150, easing = STANDARD },
            press = "ripple",
        },

        segmented = {
            metrics = { height = 40, touch = 48, radius = "pill", border = 1, paddingHorizontal = 12, gap = 8, mark = 2 },
            paint = {
                track = { rest = "outline", disabled = "disabledOutline" },
                segment = { rest = "background", on = "secondaryContainer", disabled = "disabledSurface" },
                label = { rest = "onSurfaceVariant", on = "onSecondaryContainer", disabled = "disabledText" },
            },
            motion = { duration = 200, easing = EMPHASISED },
            press = "ripple",
        },

        select = {
            metrics = { height = 56, radius = 4, border = 1, paddingHorizontal = 16, gap = 12, menuRadius = 4, option = 48 },
            paint = {
                field = { rest = "surfaceVariant", focused = "surfaceVariant", disabled = "disabledSurface" },
                label = { rest = "text", disabled = "disabledText" },
                indicator = { rest = "onSurfaceVariant", focused = "primary", disabled = "disabledText" },
                menu = { rest = "elevated" },
                option = { rest = "text", on = "primary" },
            },
            motion = { duration = 200, easing = EMPHASISED },
            press = "ripple",
        },

        progress = {
            metrics = { thickness = 4, circle = 40 },
            paint = { track = { rest = "secondaryContainer" }, fill = { rest = "primary" } },
            motion = { duration = 200, easing = EMPHASISED },
            press = "none",
        },

        spinner = {
            metrics = { thickness = 4, sweep = 270 },
            paint = { arc = { rest = "primary" } },
            motion = { duration = 800, easing = STANDARD },
            press = "none",
        },
        tabbar = {
            metrics = { height = 64, indicator = 32, indicatorWidth = 64, radius = "pill", gap = 4, rule = 0 },
            paint = {
                container = { rest = "surface" },
                indicator = { rest = "surface", on = "secondaryContainer" },
                icon = { rest = "onSurfaceVariant", on = "onSecondaryContainer" },
                label = { rest = "onSurfaceVariant", on = "text" },
            },
            motion = { duration = 200, easing = EMPHASISED },
            press = "ripple",
        },

        chip = {
            metrics = { height = 32, radius = 8, border = 1, paddingHorizontal = 12, gap = 8 },
            paint = {
                container = { rest = "background", on = "secondaryContainer", disabled = "disabledSurface" },
                label = { rest = "onSurfaceVariant", on = "onSecondaryContainer", disabled = "disabledText" },
                outline = { rest = "outline", on = "secondaryContainer" },
            },
            motion = { duration = 150, easing = STANDARD },
            press = "ripple",
        },

        badge = {
            metrics = { size = 16, radius = "pill", paddingHorizontal = 4, dot = 6 },
            paint = { container = { rest = "danger" }, label = { rest = "onPrimary" } },
            motion = { duration = 150, easing = STANDARD },
            press = "none",
        },

        avatar = {
            metrics = { radius = "pill", border = 0 },
            paint = { container = { rest = "secondaryContainer" }, label = { rest = "onSecondaryContainer" } },
            motion = { duration = 150, easing = STANDARD },
            press = "none",
        },

        skeleton = {
            metrics = { radius = 4, height = 16, gap = 8 },
            paint = { block = { rest = "surfaceVariant" }, shimmer = { rest = "background" } },
            motion = { duration = 1200, easing = STANDARD },
            press = "none",
        },

        accordion = {
            metrics = { row = 56, radius = 12, gap = 8, chevron = 24, paddingHorizontal = 16 },
            paint = {
                row = { rest = "surfaceVariant", on = "secondaryContainer" },
                label = { rest = "text", on = "onSecondaryContainer" },
                chevron = { rest = "onSurfaceVariant" },
            },
            motion = { duration = 200, easing = EMPHASISED },
            press = "ripple",
        },

        overlay = {
            metrics = { radius = 28, padding = 24, gap = 16, elevation = "lg", sheetRadius = 28 },
            paint = {
                panel = { rest = "elevated" },
                scrim = { rest = "overlay" },
                title = { rest = "text" },
                message = { rest = "onSurfaceVariant" },
                action = { rest = "primary", invalid = "danger" },
            },
            motion = { duration = 250, easing = EMPHASISED },
            press = "ripple",
        },

        swatches = {
            metrics = { size = 36, touch = 48, radius = "pill", gap = 8, border = 2, mark = 2 },
            paint = {
                swatch = { rest = "surface", disabled = "disabledSurface" },
                mark = { rest = "onPrimary" },
                outline = { rest = "outline", on = "text" },
            },
            motion = { duration = 150, easing = STANDARD },
            press = "ripple",
        },

        calendar = {
            metrics = { day = 44, radius = "pill", gap = 8 },
            paint = {
                day = { rest = "background", on = "primary", disabled = "background" },
                number = { rest = "text", on = "onPrimary", disabled = "disabledText" },
                weekday = { rest = "onSurfaceVariant" },
            },
            motion = { duration = 150, easing = STANDARD },
            press = "ripple",
        },

        clock = {
            metrics = { size = 200, minutes = 5, radius = 16, gap = 8, column = 72, row = 44 },
            paint = {
                face = { rest = "surfaceVariant", on = "primary" },
                number = { rest = "text", on = "onPrimary" },
                hand = { rest = "primary" },
            },
            motion = { duration = 200, easing = EMPHASISED },
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
            metrics = { radius = 12, padding = "md", elevation = "sm", border = 1 },
            paint = {
                container = { rest = "background", pressed = "surfaceVariant", hovered = "surfaceVariant" },
                outline = { rest = "outline" },
            },
            motion = { duration = 150, easing = STANDARD },
            press = "ripple",
        },

        tooltip = {
            metrics = { radius = 4, paddingHorizontal = 8, paddingVertical = 4 },
            paint = { container = { rest = "text" }, label = { rest = "background" } },
            motion = { duration = 150, easing = STANDARD },
            press = "none",
        },

        rating = {
            metrics = { size = 28, gap = 4, touch = 48 },
            paint = { mark = { rest = "outline", on = "primary", disabled = "disabledOutline" } },
            motion = { duration = 150, easing = STANDARD },
            press = "none",
        },

        field = {
            metrics = {
                height = 56, radius = 4, border = 1, focusBorder = 2, paddingHorizontal = 16,
                labelSize = "caption", helperSize = "caption", gap = 4, label = "float",
            },
            paint = {
                container = { rest = "surfaceVariant", disabled = "disabledSurface" },
                label = { rest = "onSurfaceVariant", focused = "primary", invalid = "danger", disabled = "disabledText" },
                text = { rest = "text", disabled = "disabledText" },
                helper = { rest = "onSurfaceVariant", invalid = "danger", disabled = "disabledText" },
                indicator = { rest = "outline", focused = "primary", invalid = "danger", disabled = "disabledOutline" },
            },
            motion = { duration = 150, easing = STANDARD },
            press = "none",
        },
    },
})
