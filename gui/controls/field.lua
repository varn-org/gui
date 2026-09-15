local component = require("gui.component")
local content = require("gui.components.content")
local element = require("gui.element")
local parts = require("gui.controls.parts")
local structure = require("gui.components.structure")

local View = structure.View
local Text = content.Text

--- The host nodes the editable run itself is, which stay the platform's whatever a design draws.
local INPUT = element.define("textinput")
local AREA = element.define("textarea")
local SEARCH = element.define("searchbar")

--- What a control theme draws around a text input, with the platform's own editing inside it.
---
--- A text input cannot be drawn. The caret, the selection handles, the system keyboard, autocorrect,
--- dictation and every input method for a language that needs one belong to the platform's own text
--- editing, and drawing a box that imitates them would be a text engine rather than a control.
---
--- What is drawn is everything around the words: the container and its fill, the outline and what focus
--- does to it, where the label sits, the helper line, and the parts at either end. Where the label sits
--- is what separates the designs — Material 3 floats it into the outline, Material 2 raises it above,
--- and Apple's writes it beside.
return component.define({
    name = "DrawnField",
    state = { focused = false, hovered = false },

    render = function(self)
        local props = self.props
        local theme = props.theme
        local about = {
            disabled = props.editable == false,
            focused = self.state.focused,
            hovered = self.state.hovered,
            invalid = props.invalid == true,
        }

        local placed = theme:metric("field", "label")
        local written = props.value ~= nil and props.value ~= ""
        local floating = placed == "float" and (self.state.focused or written)
        local build = props.multiline and AREA or (props.searching and SEARCH or INPUT)

        local inside = {}

        if props.leading ~= nil then
            inside[#inside + 1] = props.leading
        end

        inside[#inside + 1] = build {
            key = "text",
            ref = props.ref,
            value = props.value,
            placeholder = floating and nil or props.placeholder,
            placeholderColor = parts.paint(theme, "field", "helper", about),
            secure = props.secure,
            keyboard = props.keyboard,
            returnKey = props.returnKey,
            autoCapitalize = props.autoCapitalize,
            autoCorrect = props.autoCorrect,
            maxLength = props.maxLength,
            editable = props.editable,
            autoFocus = props.autoFocus,
            rows = props.rows,
            grows = props.grows,
            style = {
                grow = 1,
                alignSelf = "stretch",
                minHeight = props.multiline and theme:metric("field", "height") or nil,
                color = parts.paint(theme, "field", "text", about),
                background = "transparent",
                paddingHorizontal = 0,
            },
            onChange = props.onChange,
            onSubmit = props.onSubmit,
            onSelectionChange = props.onSelectionChange,
            onKeyDown = props.onKeyDown,
            onKeyUp = props.onKeyUp,
            onFocus = function()
                self:setState({ focused = true })

                if props.onFocus ~= nil then
                    props.onFocus()
                end
            end,
            onBlur = function()
                self:setState({ focused = false })

                if props.onBlur ~= nil then
                    props.onBlur()
                end
            end,
        }

        if props.trailing ~= nil then
            inside[#inside + 1] = props.trailing
        end

        local box = View {
            key = "container",
            transition = parts.motion(theme, "field"),
            style = {
                direction = "row",
                align = props.multiline and "start" or "center",
                gap = 8,
                minHeight = props.multiline and nil or theme:metric("field", "height"),
                paddingHorizontal = theme:metric("field", "paddingHorizontal"),
                paddingTop = floating and 18 or nil,
                radius = theme:metric("field", "radius"),
                background = parts.paint(theme, "field", "container", about),
                border = self.state.focused
                    and theme:metric("field", "focusBorder")
                    or theme:metric("field", "border"),
                borderColor = parts.paint(theme, "field", "indicator", about),
            },

            table.unpack(inside),
        }

        local stacked = {}

        if props.label ~= nil and placed == "above" then
            stacked[#stacked + 1] = Text {
                key = "label",
                text = props.label,
                style = {
                    fontSize = theme:metric("field", "labelSize"),
                    color = parts.paint(theme, "field", "label", about),
                },
            }
        end

        if props.label ~= nil and placed == "float" then
            -- A floating label sits inside the box, so the box is what holds it rather than the column.
            box = View {
                key = "floating",
                style = { justify = "center" },

                box,

                Text {
                    key = "label",
                    text = props.label,
                    pointerEvents = "none",
                    transition = parts.motion(theme, "field"),
                    style = {
                        position = "absolute",
                        left = theme:metric("field", "paddingHorizontal"),
                        top = floating and 8 or nil,
                        fontSize = floating and theme:metric("field", "labelSize") or "body",
                        color = parts.paint(theme, "field", "label", about),
                    },
                },
            }
        end

        stacked[#stacked + 1] = box

        if props.helper ~= nil then
            stacked[#stacked + 1] = Text {
                key = "helper",
                text = props.helper,
                style = {
                    fontSize = theme:metric("field", "helperSize"),
                    color = parts.paint(theme, "field", "helper", about),
                },
            }
        end

        if placed == "beside" and props.label ~= nil then
            return View {
                testID = props.testID,
                style = {
                    { direction = "row", align = "center", gap = theme:metric("field", "gap") },
                    props.style,
                },

                Text {
                    key = "label",
                    text = props.label,
                    style = {
                        fontSize = theme:metric("field", "labelSize"),
                        color = parts.paint(theme, "field", "label", about),
                    },
                },

                View { style = { grow = 1, gap = theme:metric("field", "gap") }, table.unpack(stacked) },
            }
        end

        return View {
            testID = props.testID,
            style = { { gap = theme:metric("field", "gap") }, props.style },
            table.unpack(stacked),
        }
    end,
})
