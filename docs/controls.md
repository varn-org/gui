# 🎛 Controls

A look says what a control is coloured in. A **control theme** says what it is built out of: the sizes it is drawn at, which colour role each of its parts takes in each of its states, how it moves between them, and what a finger does to it.

The two are separate and either may be changed without touching the other, so the same control theme in two looks is two different-looking applications and one set of controls.

```lua
gui.start(tree, renderer, { theme = gui.theme.looks.blossom, controls = gui.controls.material3 })
```

## Which of the two draws it

A control is one public name and two ways of being drawn, and which one is used is the control theme's to say rather than the screen's. `gui.Switch` is the platform's own switch under `native` and a drawn one under any other control theme, with nothing about the screen changed.

| Control theme | What it draws |
|---|---|
| `native` | The platform's own control, which is what an application that names none is given |
| `material2` | Material Design 2, at its own proportions and motion |
| `material3` | Material Design 3 |
| `cupertino` | Apple's |

`native` is the default. A reader already knows how the control their own system draws behaves, down to how long a press has to be held and what a drag across it does, and none of that is worth imitating where the real one is there to be used.

The other three are drawn by the engine out of boxes, text and paths. That is what makes the library portable: a renderer that can build those can host the whole of it, which is the list in [porting.md](porting.md).

## Changing it while the application runs

```lua
local Chooser = gui.component({
    name = "Chooser",

    render = function(self)
        local wearing = gui.theming:read(self)

        return gui.SegmentedControl {
            segments = { "Native", "Material 3", "Cupertino" },
            onChange = function(index)
                wearing.useControls(({ gui.controls.native, gui.controls.material3, gui.controls.cupertino })[index])
            end,
        }
    end,
})
```

`gui.theming` carries the look and the controls in force and the way to ask for another of either. Reading it draws the component again when either changes, so a chooser shows which one is on without holding a copy of the answer.

## What a control theme carries

One entry per control, and each entry is four things.

| Field | What it is |
|---|---|
| `metrics` | The sizes it is drawn at, in points, or a name into the look's spacing and radii |
| `paint` | A colour role per part, per state |
| `motion` | How long a change takes and on what curve |
| `press` | What a finger does to it — `ripple`, `highlight`, `scale` or `none` |
| `draw` | A component that draws it instead, where reshaping is not enough |

A part is painted per state, and a state is a refinement rather than a separate painting: a switch that is on and pressed is painted as one that is on unless the theme says what pressing does to it, so a theme carries only what it actually changes. The states, most particular first, are `disabledOn`, `disabled`, `invalid`, `pressed`, `focused`, `hovered`, `on`, and `rest` — which is the one every part must carry.

```lua
switch = {
    metrics = { width = 52, height = 32, radius = "pill", thumb = 16, thumbOn = 24, inset = 4 },
    paint = {
        track = { rest = "surfaceVariant", on = "primary", disabled = "disabledSurface" },
        thumb = { rest = "outline", on = "onPrimary" },
        mark = { rest = "primary" },
    },
    motion = { duration = 200, easing = { 0.2, 0, 0, 1 } },
    press = "ripple",
}
```

A colour is named as a **role** rather than as a colour, which is what makes a control theme and a look two separate things. The roles a control may name are the ones every look carries: `primary`, `onPrimary`, `background`, `surface`, `elevated`, `text`, `textMuted`, `separator`, `border`, `success`, `warning`, `danger`, plus the ones a drawn control needs — `outline`, `surfaceVariant`, `onSurfaceVariant`, `primaryHover`, `primaryMuted`, `secondaryContainer`, `onSecondaryContainer`, `disabledSurface`, `disabledText` and `disabledOutline`. A look that names none of those is still a complete palette, since each is worked out from the ones it does carry.

## A control of your own

Nothing about the set the library ships is closed. A control somebody writes is a control in every sense: it registers its own kind, a control theme may carry an entry for it and replace how it is drawn, its props are checked and it appears in the reference.

```lua
local Gauge = gui.control("Gauge", {
    parts = { "track", "needle" },
    props = { "value", "label" },
    defaults = { value = 0 },

    -- How it is drawn where a control theme says nothing about it. A kind registered after a theme was
    -- written would otherwise leave that theme incomplete, including the four that ship.
    drawn = {
        metrics = { height = 8 },
        paint = { track = { rest = "surfaceVariant" }, needle = { rest = "primary" } },
        motion = { duration = 150 },
        press = "none",
    },
}, gui.component({
    name = "DrawnGauge",

    render = function(self)
        local theme = self.props.theme

        return gui.View {
            accessibilityRole = "progressbar",
            accessibilityValue = { now = self.props.value, least = 0, most = 1 },
            style = {
                height = theme:metric("gauge", "height"),
                background = gui.controls.parts.paint(theme, "gauge", "track", {}),
            },
        }
    end,
}))
```

`platform` names the host node a control theme reaches when it hands the control to the platform. A control that names none is drawn by the engine under every control theme, which is what a control no system has is.

`gui.controls.parts` is what the library's own controls are built out of — the state list, the paint lookup, the motion, the touch box, the focus ring, the marks, the arcs — so a control of your own is built the same way rather than from nothing.

## Drawing one some other way

Metrics and paint reshape a control and cannot rebuild one. A control theme may carry a `draw` instead, which is a component handed the props and the theme:

```lua
local spelled = gui.controls.extend(gui.controls.material3, {
    name = "spelled",
    controls = {
        switch = { draw = gui.component({
            name = "WordedSwitch",
            render = function(self) return gui.Text { text = self.props.value and "ON" or "OFF" } end,
        }) },
    },
})
```

Everything else about the design it came from stays as it was, and the design it came from is untouched.

## One design from another

```lua
local squared = gui.controls.extend(gui.controls.material3, {
    name = "squared",
    controls = {
        button = { metrics = { radius = 4 } },
        select = { metrics = { radius = 4 } },
    },
})
```

`extend` writes what changes over another control theme, so a design that is Material 3 with square corners is the corners and nothing else. `define` builds one from nothing, and refuses one that leaves a control out or names a part no control has — both are mistakes in a table rather than states to recover from, and a control theme that draws nothing where a control was written is not something to discover on a screen.

## A finger, a pointer and a keyboard

Every drawn control answers all three.

A **finger** presses it and a **pointer** hovers over it, which paints the `hovered` state. A pointer's second button and a finger held on the control both raise `onContextPress`, carrying where it happened so what it opens is drawn there.

A **keyboard** reaches every drawn control, since each is a stop on the way through, and each answers the keys its own kind owns rather than whatever the platform would have done:

| Control | Keys |
|---|---|
| Switch, checkbox, radio, button | Space and return |
| Segmented control | The arrows, home and end, which walk the set |
| Stepper, rating | The arrows, which move the value, and home and end |
| Select | The down arrow and return to open, escape to close |

The control the keyboard has reached draws a ring around itself. It is one thing for a whole design rather than a state on every part of every control, so a control theme carries it once:

```lua
focus = { width = 2, color = "primary", offset = 2 }
```

A design that wants none says a width of nothing.

## What is drawn

Every control below is drawn by the engine under `material2`, `material3` and `cupertino`, and handed to the platform under `native` where the platform has one.

| Control | Under `native` |
|---|---|
| `Switch`, `Checkbox`, `Radio`, `Button`, `SegmentedControl`, `Stepper`, `Rating`, `Slider`, `Picker` | The platform's own |
| `ProgressBar`, `ActivityIndicator`, `Card`, `Tooltip` | The platform's own |
| `RangeSlider`, `ProgressCircle` | Drawn, since neither phone has one |
| `FloatingActionButton`, `NavigationRail`, `Pagination`, `ProgressSteps`, `TreeView`, `SwipeActions` | Drawn, since neither phone has one |
| `Snackbar`, `Banner`, `Popover` | Drawn, since neither phone has one |
| `TextField` | Drawn chrome around the platform's own editing |
| `DatePicker`, `TimePicker`, `ColorPicker` | The platform's own |
| `TabBar`, `Chip`, `Badge`, `Avatar`, `Skeleton`, `Accordion` | Drawn, and shaped by the design |
| `Modal`, `Sheet`, `Alert`, `ActionSheet`, `Menu`, `Toast` | Drawn, and shaped by the design |
| A list's separator and a carousel's dots | Drawn, and shaped by the design |

A control the platform does not draw names no platform node, and a control theme that tries to hand it to one is told so by name. That is what `ProgressCircle` is: what a system draws round is a spinner, which says something is happening rather than how much is done.

## What it costs

A drawn control is several nodes where a native one is one. A screen of forty rows each holding a switch is 121 nodes under `native` and 221 under `material3`, and laying it out again takes 4.4 ms and 4.5 ms — eighty per cent more nodes for two per cent more time. `gui/tests/performance_test.lua` holds it there, and counts the operations one press sends.

## The one that stays half native

A text field cannot be drawn. The caret, the selection handles, the system keyboard, autocorrect, dictation and every input method for a language that needs one belong to the platform's own text editing, and drawing a box that imitates them would be a text engine rather than a control.

What a control theme draws is everything around the text: the container and its fill, the outline and what focus does to it, the label and where it sits, the helper line, the error state, and the leading and trailing parts. The editable run itself stays the platform's, inside that chrome.

This is a boundary rather than a gap. A fourth renderer has to build one editable text run and nothing else about text editing.

## Reference and tests

The declarations are in [components.md](components.md), where a control that either may draw is written as `` `switch` or Lua ``. The suite is `gui/tests/controls_test.lua`, and the gallery draws every control in every control theme under **Controls**.
