# 📝 Forms

A form is one thing spread over a screen: the values, what is wrong with each of them, whether any of it may be sent, and the moment a reader asks for it to be. Written by hand that is a state field per control, a string per mistake, a check before the button may be pressed and a rule somebody wrote again for an address or a length — which is what every screen that took input used to carry.

`gui.Form` holds the values, `gui.Field` binds one control to one name, `gui.validators` carries the rules everybody has, and a function of your own is a rule like any other.

## A form

```lua
local gui = require("gui")

local Signup = gui.component({
    name = "Signup",
    state = { sent = nil },

    render = function(self)
        return gui.Form {
            initialValues = { name = "", email = "", agreed = false },
            validateOn = "blur",
            onSubmit = function(values) self:setState({ sent = values.email }) end,

            gui.Field {
                name = "name",
                label = "Name",
                required = true,
                rules = { gui.validators.minLength(2) },
                render = function(field)
                    return gui.TextInput {
                        ref = field.ref,
                        value = field.value,
                        onChange = field.onChange,
                        onBlur = field.onBlur,
                    }
                end,
            },

            gui.Field {
                name = "email",
                label = "Email",
                hint = "We only use it to answer you",
                required = true,
                rules = { gui.validators.email() },
                render = function(field)
                    return gui.TextInput {
                        ref = field.ref,
                        value = field.value,
                        keyboard = "email",
                        autoCapitalize = "none",
                        onChange = field.onChange,
                        onBlur = field.onBlur,
                    }
                end,
            },

            Sender {},
        }
    end,
})
```

## The form holds the values

There is one model rather than two. `initialValues` is what the form opens with, the form holds them from then on, and `onChange(values, name)` reports every change so a screen that wants to mirror them can. Nothing has to keep a state field per control for the form to work.

What a caller writes into a field never reaches `initialValues`: the form copies it when it opens and again when it is reset, so the table a screen declared is never written to.

## A field

`gui.Field` owns everything around a control that is the same every time — the label, the binding, when the value is judged, and where the message goes — and the control itself stays the caller's, since a name, an address, a date and a switch are four different controls holding one value each.

`render` is handed one table:

| Field | What it is |
|---|---|
| `name` | The name this field holds, which is the key in `values` |
| `value` | What the form holds for it now |
| `error` | What is wrong with it, and only once the reader should be looking at it |
| `disabled` | Whether the form was told to take nothing |
| `ref` | The handle the form focuses on a failed send — give it to the control |
| `onChange` | What the control reports its new value to |
| `onBlur` | What the control reports being left to |
| `onSubmit` | Sends the form, which is what a return key on the last field does |

`required = true` writes `gui.validators.required()` in front of whatever `rules` the field carries and marks the label. A field with no `label` draws none, which is what a checkbox that carries its own words wants.

## When a value is judged

`validateOn` is `"change"`, `"blur"` or `"submit"`. Whichever it is, every field is judged on every keystroke once a send has failed, since by then the reader has been told it is wrong and is watching for it to stop being wrong.

A message is shown only for a field the reader has reached. A form that opens shouting at somebody for not having filled it in yet is worse than one that says nothing.

## Sending it

A send that passes calls `onSubmit(values)`. One that fails calls `onInvalid(errors, first)`, puts the keyboard in the first field on the screen that is wrong, and the engine lifts that field clear of the keyboard the way it does for any focused field. First means first on the screen rather than first in whatever order a table happened to be walked, which is why a field says where it is by joining the form as it draws.

## Reaching the form

Anything inside a form reads it through `gui.form`, which carries `values`, `errors`, `valid`, `disabled`, `submit` and `reset`. A button that sends the form is an ordinary component:

```lua
local Sender = gui.component({
    name = "Sender",

    render = function(self)
        local held = gui.form:read(self)

        return gui.Button {
            title = "Submit",
            disabled = not held.valid,
            onPress = function() held.submit() end,
        }
    end,
})
```

A screen **outside** the form reaches it through a ref instead:

```lua
gui.Form { ref = self:ref("form"), ... }

self:ref("form"):call("submit")
self:ref("form"):call("reset")
self:ref("form"):call("setValue", { name = "email", value = "ada@example.com" })
```

The handle answers `values`, `errors`, `valid`, `setValue`, `submit` and `reset`.

## The rules

`gui.validators` carries the ones every framework ships. Each answers what is wrong with a value or nothing at all when it is fine, and each takes an optional message of its own.

| Rule | Refuses |
|---|---|
| `required(message)` | A field left empty |
| `minLength(least, message)` | Fewer characters than that |
| `maxLength(most, message)` | More characters than that |
| `length(least, most, message)` | Anything outside that range of characters |
| `pattern(shape, message)` | Anything that does not match a Lua pattern |
| `email(message)` | Anything that is not shaped like an address |
| `url(message)` | Anything that names no scheme or no host |
| `number(message)` | Anything that is not a number |
| `integer(message)` | Anything that is not a whole number |
| `min(least, message)` | A number below that |
| `max(most, message)` | A number above that |
| `range(least, most, message)` | A number outside that |
| `oneOf(choices, message)` | Anything outside a set |
| `matches(name, message)` | A value that differs from another field's, which is a repeated password |
| `accepted(message)` | A box that has to be ticked and is not |

Nothing but `required` and `accepted` looks at an empty value: a field somebody has not reached is empty rather than wrong.

## A rule of your own

A validator is a function of the value and of everything else the form holds, so it sits beside the others with nothing to register:

```lua
local function noFreeMail(value)
    if value == nil or value == "" or value:match("@example%.com$") == nil then
        return nil
    end

    return "Use an address we can reply to"
end

gui.Field { name = "email", rules = { gui.validators.email(), noFreeMail }, ... }
```

A rule may read the whole form, which is what comparing two fields is:

```lua
rules = { gui.validators.matches("password", "These do not match") }
```

## Rules on the form

A form may carry its rules in one place instead, keyed by the name of the field, which is what a form whose rules come from somewhere else wants:

```lua
gui.Form {
    rules = {
        email = { gui.validators.required(), gui.validators.email() },
        people = { gui.validators.integer(), gui.validators.range(1, 50) },
    },
    ...
}
```

A field's own rules run after the form's.

## Reference and tests

The declarations are in [components.md](components.md). The suite is `gui/tests/form_test.lua`, and the gallery draws one under **Real screens / A form**.
