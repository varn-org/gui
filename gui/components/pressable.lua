local support = require("gui.components.support")

--- A box that answers a finger, by the gesture the finger actually made.
---
--- A swipe is not a press. Every platform tells them apart by how far the finger travelled, and a box
--- that took either as a press opened whatever it was for when a reader meant to scroll past it.
--- `onSwipe` carries the direction it went, which is what an item does something different for.
---
--- `onDoublePress` is the platform's own double tap rather than two presses counted here: each of the
--- three waits for the second before it reports the first, which is why a box that counts them itself
--- answers the first press as well.
---
--- `onKeyDown` and `onKeyUp` reach whatever has focus, which is what every platform delivers a key to.
---
--- `focusable` is what makes a box a stop on the way through with a keyboard, and `onFocus` and `onBlur`
--- are how it knows it is the one being used. A control drawn by the engine cannot draw a focus ring
--- without them, which is the whole of using one from a keyboard.
---
--- `onContextPress` is the second button on a mouse and a long press with a finger, which every platform
--- means the same thing by. It carries where it happened, since what it opens is drawn there.
---
--- A drag is what a slider is, and `panAxis` is what makes one possible inside something that scrolls: it
--- says which axis this box is claiming, so the surface under it keeps the other. A box that claims none
--- claims nothing and a finger across it scrolls whatever holds it.
return support.host("pressable", {
    props = { "disabled", "hitSlop", "focusable", "autoFocus", "panAxis" },
    events = { "onPress", "onDoublePress", "onLongPress", "onPressIn", "onPressOut", "onSwipe",
        "onHoverIn", "onHoverOut", "onKeyDown", "onKeyUp", "onFocus", "onBlur", "onContextPress",
        "onPanStart", "onPanMove", "onPanEnd" },
    actions = { "focus", "blur" },
    defaults = { disabled = false, focusable = false, autoFocus = false },
    validate = function(spec)
        if not support.oneOf(spec.panAxis, { "horizontal", "vertical", "both" }) then
            return support.expected("panAxis", spec.panAxis, { "horizontal", "vertical", "both" })
        end
    end,
})
