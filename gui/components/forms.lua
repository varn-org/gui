local component = require("gui.component")
local content = require("gui.components.content")
local form = require("gui.form")
local structure = require("gui.components.structure")
local support = require("gui.components.support")
local validators = require("gui.validators")

local M = {}

local View = structure.View
local Text = content.Text

local WHEN = { "change", "blur", "submit" }

--- The values, what is wrong with each of them, and the moment a reader asks for them to be sent.
---
--- Every screen that takes input was writing the same thing: a state field per control, a string per
--- mistake, a check before the button may be pressed, and a rule somebody wrote by hand for an address
--- or a length. That is the form, and it is the same form everywhere, so it is written once.
---
--- The form holds the values. A caller is told about every change through `onChange` and reaches them
--- through a ref, but nothing has to mirror them into a state field of its own for the form to work,
--- which is what turned every screen with three fields into forty lines of bookkeeping.
---
--- `validateOn` says when a field is judged: as it is typed into, when it is left, or only when the form
--- is sent. Whichever is chosen, a field is judged on every keystroke once a submit has failed, since by
--- then the reader has been told it is wrong and is watching for it to stop being wrong.
M.Form = support.component("Form", {
    props = { "initialValues", "rules", "validateOn", "disabled" },
    events = { "onChange", "onSubmit", "onInvalid" },
    defaults = { validateOn = "blur", disabled = false },
    validate = function(spec)
        if spec.initialValues ~= nil and type(spec.initialValues) ~= "table" then
            return "initialValues is a table of the values the form opens with, got a "
                .. type(spec.initialValues)
        end

        if spec.rules ~= nil and type(spec.rules) ~= "table" then
            return "rules is a table of field names to lists of rules, got a " .. type(spec.rules)
        end

        if not support.oneOf(spec.validateOn, WHEN) then
            return support.expected("validateOn", spec.validateOn, WHEN)
        end
    end,
}, component.define({
    name = "Form",
    state = { values = nil, touched = {}, failed = false },

    --- Answers the values the form opens with, which is a copy so nothing the caller holds is written to.
    opening = function(self)
        local held = {}

        for name, value in pairs(self.props.initialValues or {}) do
            held[name] = value
        end

        return held
    end,

    --- Answers the values as they stand, which is what a rule, a handler and a caller all read.
    values = function(self)
        return self.state.values or self:opening()
    end,

    --- Answers the rules a field is held to, which the form declares and a field may add to.
    rulesFor = function(self, name)
        local declared = (self.props.rules or {})[name]
        local given = self.fields ~= nil and self.fields[name] or nil

        if declared == nil then
            return given or {}
        end

        if given == nil then
            return declared
        end

        local both = {}

        for index = 1, #declared do
            both[#both + 1] = declared[index]
        end

        for index = 1, #given do
            both[#both + 1] = given[index]
        end

        return both
    end,

    --- Answers what is wrong with every field, which is what a submit is decided by.
    judge = function(self, values)
        local found = {}
        local named = {}

        for name in pairs(self.props.rules or {}) do
            named[name] = true
        end

        for name in pairs(self.fields or {}) do
            named[name] = true
        end

        for name in pairs(named) do
            found[name] = validators.check(self:rulesFor(name), values[name], values)
        end

        return found
    end,

    --- Answers what is wrong with every field as things stand, which is worked out rather than kept.
    ---
    --- Held in state it is a second copy of something the values already answer, and the two disagree
    --- for exactly as long as it takes a commit to land: a form opens with every rule unchecked, so a
    --- button that reads whether it may be sent is pressable for one frame on a form nobody has filled in.
    errors = function(self)
        return self:judge(self:values())
    end,

    --- Answers whether a field's mistake is one the reader should be looking at yet.
    showing = function(self, name)
        if self.state.failed then
            return true
        end

        return self.state.touched[name] == true
    end,

    --- Records what a reader wrote, judging it again where the form was told to.
    write = function(self, name, value)
        local values = {}

        for key, held in pairs(self:values()) do
            values[key] = held
        end

        values[name] = value

        local touched = self.state.touched

        if self.props.validateOn == "change" then
            touched = {}

            for key, held in pairs(self.state.touched) do
                touched[key] = held
            end

            touched[name] = true
        end

        self:setState({ values = values, touched = touched })

        if self.props.onChange ~= nil then
            self.props.onChange(values, name)
        end
    end,

    --- Records that a reader has finished with a field, which is when it is judged unless it is typed.
    leave = function(self, name)
        if self.props.validateOn == "submit" then
            return
        end

        local touched = {}

        for key, held in pairs(self.state.touched) do
            touched[key] = held
        end

        touched[name] = true
        self:setState({ touched = touched })
    end,

    --- Sends the form, or names what is wrong and puts the reader in front of the first of it.
    ---
    --- A form that refuses with nothing said and nothing focused is one a reader stares at, so the first
    --- field that failed is asked to take the keyboard, which is also what the engine lifts into view.
    submit = function(self)
        local values = self:values()
        local errors = self:judge(values)
        local wrong = nil

        for index = 1, #(self.order or {}) do
            local name = self.order[index]

            if wrong == nil and errors[name] ~= nil then
                wrong = name
            end
        end

        self:setState({ failed = wrong ~= nil })

        if wrong == nil then
            if self.props.onSubmit ~= nil then
                self.props.onSubmit(values)
            end

            return true
        end

        local holder = (self.handles or {})[wrong]

        if holder ~= nil then
            holder:call("focus")
        end

        if self.props.onInvalid ~= nil then
            self.props.onInvalid(errors, wrong)
        end

        return false
    end,

    reset = function(self)
        self:setState({ values = self:opening(), touched = {}, failed = false })
    end,

    --- Answers the handle a caller reaches the form through, which is what a screen outside it holds.
    handle = function(self)
        return {
            values = function() return self:values() end,
            errors = function() return self:errors() end,
            valid = function() return next(self:errors()) == nil end,
            setValue = function(arguments) self:write(arguments.name, arguments.value) end,
            submit = function() return self:submit() end,
            reset = function() self:reset() end,
        }
    end,

    --- Registers a field, which is how the form knows what it holds and in what order it reads.
    ---
    --- The order matters: a submit that failed puts the reader in front of the first mistake, and first
    --- means first on the screen rather than first in whatever order a table happened to be walked.
    join = function(self, name, rules, holder)
        self.fields = self.fields or {}
        self.handles = self.handles or {}
        self.order = self.order or {}

        local known = self.fields[name] ~= nil

        self.fields[name] = rules or {}
        self.handles[name] = holder

        if known then
            return
        end

        -- A field joins while it is being drawn, which is after the form was, so the form has to be
        -- drawn again to know what it now holds. Without it a form asked whether it may be sent answers
        -- against the rules of the fields that had joined by the last commit rather than by this one.
        self.order[#self.order + 1] = name
        self:setState({})
    end,

    render = function(self)
        local values = self:values()
        local errors = self:errors()

        local reach = {
            values = values,
            errors = errors,
            valid = next(errors) == nil,
            disabled = self.props.disabled,

            field = function(name)
                local wrong = nil

                -- The middle of an `and`/`or` may be nil here, and Lua then takes the other branch, so
                -- what is wrong with a field the reader has reached is read through a check instead.
                if self:showing(name) then
                    wrong = errors[name]
                end

                return {
                    name = name,
                    value = values[name],
                    error = wrong,
                    disabled = self.props.disabled,
                }
            end,

            join = function(name, rules, holder) self:join(name, rules, holder) end,
            setValue = function(name, value) self:write(name, value) end,
            leave = function(name) self:leave(name) end,
            submit = function() return self:submit() end,
            reset = function() self:reset() end,
        }

        return form.Provider {
            value = reach,
            style = { { gap = "md" }, self.props.style },
            table.unpack(self.children),
        }
    end,
}))

--- One control inside a form, with its name above it and what is wrong with it underneath.
---
--- The control itself is the caller's, since a name, an address, a date and a switch are four different
--- controls holding one value each. What this owns is everything around it that is the same every time:
--- the label, the binding, when the value is judged, and where the message goes.
M.Field = support.component("Field", {
    props = { "name", "label", "hint", "rules", "render", "required" },
    defaults = { required = false },
    validate = function(spec)
        if type(spec.name) ~= "string" then
            return "a field names the value it holds, got a " .. type(spec.name)
        end

        if type(spec.render) ~= "function" then
            return "render is a function answering the control this field binds, got a " .. type(spec.render)
        end

        if spec.rules ~= nil and type(spec.rules) ~= "table" then
            return "rules is a list of functions, got a " .. type(spec.rules)
        end
    end,
}, component.define({
    name = "Field",

    --- Answers the rules this field is held to, with the one `required` stands for written in.
    rules = function(self)
        local given = self.props.rules or {}

        if not self.props.required then
            return given
        end

        local all = { validators.required() }

        for index = 1, #given do
            all[#all + 1] = given[index]
        end

        return all
    end,

    render = function(self)
        local held = form:read(self)
        local name = self.props.name

        held.join(name, self:rules(), self:ref("control"))

        local state = held.field(name)
        local rows = {}

        if self.props.label ~= nil then
            -- The mark is drawn beside the label rather than written into it, since the caller's own
            -- words are what a reader hears as well as what they read.
            rows[#rows + 1] = View {
                key = "label",
                style = { direction = "row", gap = 2 },

                Text { text = self.props.label, style = { fontSize = "footnote", color = "textMuted" } },

                self.props.required and Text {
                    key = "needed",
                    text = "*",
                    accessibilityLabel = "needed",
                    style = { fontSize = "footnote", color = "danger" },
                } or false,
            }
        end

        rows[#rows + 1] = self.props.render({
            name = name,
            value = state.value,
            error = state.error,
            disabled = state.disabled,
            ref = self:ref("control"),
            onChange = function(value) held.setValue(name, value) end,
            onBlur = function() held.leave(name) end,
            onSubmit = function() held.submit() end,
        })

        if state.error ~= nil then
            rows[#rows + 1] = Text {
                key = "error",
                text = state.error,
                style = { fontSize = "footnote", color = "danger" },
            }
        elseif self.props.hint ~= nil then
            rows[#rows + 1] = Text {
                key = "hint",
                text = self.props.hint,
                style = { fontSize = "footnote", color = "textMuted" },
            }
        end

        return View { style = { { gap = "xs" }, self.props.style }, table.unpack(rows) }
    end,
}))

return M
