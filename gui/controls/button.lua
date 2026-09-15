local component = require("gui.component")
local content = require("gui.components.content")
local parts = require("gui.controls.parts")
local Pressable = require("gui.components.pressable")
local structure = require("gui.components.structure")

local View = structure.View
local Text = content.Text

--- What each variant is made of, which is the same rule under every control theme.
---
--- A design system chooses the grounds and the outline, and which of them a variant uses is the variant
--- itself rather than the design: a tinted button is the tint everywhere, and what the tint is made of
--- is what separates one design from another.
local VARIANTS = {
    filled = { ground = "container", label = "label" },
    tinted = { ground = "tint", label = "primary", ink = "primary" },
    outlined = { border = "outline", label = "primary", ink = "primary" },
    plain = { label = "primary", ink = "primary" },
    destructive = { ground = "danger", label = "onPrimary", ink = "onPrimary" },
}

--- How much larger or smaller than the theme's own height each size is drawn at.
local SIZES = { small = 0.8, medium = 1, large = 1.2 }

--- A button drawn by the engine, which is a box with words in it and what a press does to it.
---
--- The ripple is a circle laid out in the middle of the button and scaled out of it, clipped by the
--- button's own corners. Material grows one from where the finger landed and Apple's system dims the
--- whole control instead, which is what the control theme's press says rather than anything here.
return component.define({
    name = "DrawnButton",
    state = { pressed = false, hovered = false, focused = false },

    render = function(self)
        local props = self.props
        local theme = props.theme
        local about = {
            disabled = props.disabled == true,
            pressed = self.state.pressed,
            hovered = self.state.hovered,
            focused = self.state.focused,
        }

        local variant = VARIANTS[props.variant] or VARIANTS.filled
        local scale = SIZES[props.size] or SIZES.medium
        local height = theme:metric("button", "height") * scale
        local press = theme:press("button")

        local painted = {
            radius = theme:metric("button", "radius"),
            height = height,
            paddingHorizontal = theme:metric("button", "paddingHorizontal"),
            gap = theme:metric("button", "gap"),
            direction = "row",
            align = "center",
            justify = "center",
            overflow = "hidden",
        }

        if variant.ground ~= nil then
            painted.background = variant.ground == "danger" and "danger"
                or parts.paint(theme, "button", variant.ground, about)
        end

        if variant.border ~= nil then
            painted.border = theme:metric("button", "border")
            painted.borderColor = parts.paint(theme, "button", variant.border, about)
        end

        if about.disabled then
            painted.opacity = 0.5
        end

        if press == "scale" and about.pressed then
            painted.transform = { scale = 0.97 }
        end

        if press == "highlight" and about.pressed then
            painted.opacity = 0.7
        end

        local inside = {}

        if press == "ripple" and about.pressed then
            inside[#inside + 1] = View {
                key = "ripple",
                transition = parts.motion(theme, "button"),
                style = {
                    position = "absolute",
                    left = 0,
                    right = 0,
                    top = 0,
                    bottom = 0,
                    background = parts.paint(theme, "button", "ripple", about),
                    opacity = theme:metric("button", "ripple"),
                },
            }
        end

        local ink = variant.ink ~= nil and variant.ink or parts.paint(theme, "button", variant.label, about)

        if props.title ~= nil then
            inside[#inside + 1] = Text {
                key = "title",
                text = props.title,
                numberOfLines = 1,
                style = { color = ink, fontSize = "headline", fontWeight = "600", textAlign = "center" },
            }
        end

        for index = 1, #self.children do
            inside[#inside + 1] = self.children[index]
        end

        -- The press is taken through a box at least the size of a finger and the ground is drawn inside
        -- it, since a design may draw a button shorter than the smallest target every system publishes.
        local ring = parts.ring(theme, about, theme:metric("button", "radius"))

        return Pressable {
            disabled = props.disabled,
            accessibilityLabel = props.accessibilityLabel or props.title,
            accessibilityRole = "button",
            accessibilityState = { disabled = about.disabled },
            testID = props.testID,
            style = {
                { minHeight = math.max(height, theme:metric("button", "touch")), justify = "center" },
                props.style,
            },
            transition = parts.motion(theme, "button"),
            onPress = props.onPress,
            onLongPress = props.onLongPress,
            onKeyDown = function(key)
                if parts.chooses(key.key) and props.onPress ~= nil then
                    props.onPress()
                end
            end,
            focusable = true,
            onFocus = function() self:setState({ focused = true }) end,
            onBlur = function() self:setState({ focused = false }) end,
            onPressIn = function() self:setState({ pressed = true }) end,
            onPressOut = function() self:setState({ pressed = false }) end,
            onHoverIn = function()
                self:setState({ hovered = true })

                if props.onHoverIn ~= nil then
                    props.onHoverIn()
                end
            end,
            onHoverOut = function()
                self:setState({ hovered = false })

                if props.onHoverOut ~= nil then
                    props.onHoverOut()
                end
            end,

            View {
                key = "container",
                transition = parts.motion(theme, "button"),
                style = painted,

                table.unpack(inside),
            },

            ring or false,
        }
    end,
})
