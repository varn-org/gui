local gui = require("gui")
local validators = require("gui.validators")

local function start(description)
    local renderer = gui.headless()
    local runtime = gui.start(description, renderer, { size = { width = 390, height = 844 } })

    for _ = 1, 8 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end

    return runtime, renderer
end

--- Answers every word on screen, which is what a reader is actually told.
local function said(renderer)
    local found = {}

    for _, node in pairs(renderer.nodes) do
        if node.type == "text" and node.props.text ~= nil then
            found[#found + 1] = node.props.text
        end
    end

    return found
end

local function says(renderer, text)
    for _, word in ipairs(said(renderer)) do
        if word == text then
            return true
        end
    end

    return false
end

-- Every rule the framework ships answers what is wrong, and nothing at all when it is fine.
do
    local cases = {
        { rule = validators.required(), bad = "", good = "a" },
        { rule = validators.minLength(3), bad = "ab", good = "abc" },
        { rule = validators.maxLength(3), bad = "abcd", good = "abc" },
        { rule = validators.length(2, 4), bad = "a", good = "abc" },
        { rule = validators.pattern("^%d%d%d$"), bad = "12", good = "123" },
        { rule = validators.email(), bad = "ada@", good = "ada@example.com" },
        { rule = validators.url(), bad = "example.com", good = "https://example.com" },
        { rule = validators.number(), bad = "many", good = "12.5" },
        { rule = validators.integer(), bad = "1.5", good = "2" },
        { rule = validators.min(10), bad = "9", good = "10" },
        { rule = validators.max(10), bad = "11", good = "10" },
        { rule = validators.range(1, 5), bad = "6", good = "5" },
        { rule = validators.oneOf({ "one", "two" }), bad = "three", good = "two" },
        { rule = validators.accepted(), bad = false, good = true },
    }

    for index = 1, #cases do
        local case = cases[index]

        assert(case.rule(case.bad, {}) ~= nil, "rule " .. index .. " let " .. tostring(case.bad) .. " through")
        assert(case.rule(case.good, {}) == nil, "rule " .. index .. " refused " .. tostring(case.good))
    end

    -- Nothing but the two rules about emptiness looks at an empty value, since a field nobody has
    -- reached is empty rather than wrong.
    for index = 1, #cases do
        local case = cases[index]
        local about = case.rule ~= cases[1].rule and case.rule ~= cases[#cases].rule

        if about then
            assert(case.rule("", {}) == nil, "rule " .. index .. " shouted at an empty field")
            assert(case.rule(nil, {}) == nil, "rule " .. index .. " shouted at a field nobody has reached")
        end
    end

    -- A rule may read the whole form, which is what comparing two fields is.
    local same = validators.matches("password")

    assert(same("one", { password = "two" }) ~= nil, "two different values must not match")
    assert(same("one", { password = "one" }) == nil, "and two of the same must")
end

-- An email that could not be sent to is refused, and one that could is not.
do
    local rule = validators.email()

    for _, wrong in ipairs({ "ada", "ada@", "@example.com", "a b@example.com", "ada@example", "a@@b.com" }) do
        assert(rule(wrong, {}) ~= nil, wrong .. " is not an address and was let through")
    end

    for _, right in ipairs({ "a@b.co", "ada.lovelace@work.example.com", "a-b@c-d.org" }) do
        assert(rule(right, {}) == nil, right .. " is an address and was refused")
    end
end

--- A form of two fields, which is what every test below drives.
local Signup = gui.component({
    name = "Signup",
    state = { sent = nil, refused = nil },

    render = function(self)
        return gui.View { style = { grow = 1 },
            gui.Form {
                ref = self:ref("form"),
                initialValues = { email = "", password = "", again = "" },
                validateOn = self.props.validateOn,
                onSubmit = function(values) self:setState({ sent = values.email }) end,
                onInvalid = function(_, first) self:setState({ refused = first }) end,

                gui.Field {
                    name = "email",
                    label = "Email",
                    required = true,
                    rules = { gui.validators.email() },
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
                    name = "password",
                    label = "Password",
                    required = true,
                    rules = { gui.validators.minLength(8) },
                    render = function(field)
                        return gui.TextInput {
                            ref = field.ref,
                            value = field.value,
                            secure = true,
                            onChange = field.onChange,
                            onBlur = field.onBlur,
                        }
                    end,
                },

                gui.Field {
                    name = "again",
                    label = "Again",
                    rules = { gui.validators.matches("password", "These do not match") },
                    render = function(field)
                        return gui.TextInput {
                            ref = field.ref,
                            value = field.value,
                            onChange = field.onChange,
                            onBlur = field.onBlur,
                        }
                    end,
                },
            },

            gui.Text { text = self.state.sent or "nothing sent" },
        }
    end,
})

-- A form that has just opened says nothing about fields nobody has reached.
do
    local _, renderer = start(Signup {})

    assert(not says(renderer, "This is needed"), "a form that opens shouts at nobody")
    assert(says(renderer, "Email"), "and draws the name of each field")
end

-- Sending a form nobody filled in names every mistake and puts the keyboard in the first of them.
do
    local runtime, renderer = start(Signup {})
    local fields = renderer:findAll("textinput")

    runtime.root.instance:ref("form"):call("submit")
    runtime:commit()

    assert(says(renderer, "This is needed"), "a field that is needed and empty says so")
    assert(runtime.root.instance.state.refused == "email",
        "the first field on the screen that is wrong is the one named, it named "
            .. tostring(runtime.root.instance.state.refused))

    assert(#renderer.calls == 1, "and it is the one asked to take the keyboard")
    assert(renderer.calls[1].id == fields[1].id and renderer.calls[1].method == "focus",
        "which is the first field rather than whichever a table was walked to first")
end

-- A field judged as it is left says nothing while it is being typed into.
do
    local runtime, renderer = start(Signup { validateOn = "blur" })
    local email = renderer:findAll("textinput")[1]

    runtime:dispatch(email.id, "onChange", "not-an-address")
    runtime:commit()

    assert(not says(renderer, "This is not an email address"), "a field being typed into is not judged yet")

    runtime:dispatch(email.id, "onBlur", nil)
    runtime:commit()

    assert(says(renderer, "This is not an email address"), "and is judged the moment it is left")
end

-- A field judged as it is typed says so on the keystroke.
do
    local runtime, renderer = start(Signup { validateOn = "change" })
    local email = renderer:findAll("textinput")[1]

    runtime:dispatch(email.id, "onChange", "not-an-address")
    runtime:commit()

    assert(says(renderer, "This is not an email address"), "a field told to judge on every keystroke does")
end

-- Once a send has failed, every field is judged on the keystroke whatever it was told.
do
    local runtime, renderer = start(Signup { validateOn = "submit" })
    local email = renderer:findAll("textinput")[1]

    runtime:dispatch(email.id, "onChange", "not-an-address")
    runtime:commit()

    assert(not says(renderer, "This is not an email address"), "a form told to wait for a send waits")

    runtime.root.instance:ref("form"):call("submit")
    runtime:commit()

    assert(says(renderer, "This is not an email address"), "and judges everything once the send fails")

    runtime:dispatch(email.id, "onChange", "ada@example.com")
    runtime:commit()

    assert(not says(renderer, "This is not an email address"),
        "and goes on judging as the reader puts it right")
end

-- A form that is filled in correctly is sent, carrying what the reader wrote.
do
    local runtime, renderer = start(Signup {})
    local fields = renderer:findAll("textinput")

    runtime:dispatch(fields[1].id, "onChange", "ada@example.com")
    runtime:dispatch(fields[2].id, "onChange", "a long enough one")
    runtime:dispatch(fields[3].id, "onChange", "a long enough one")
    runtime:commit()

    runtime.root.instance:ref("form"):call("submit")
    runtime:commit()

    assert(says(renderer, "ada@example.com"), "a form that is right is sent with what was written in it")
end

-- A rule that reads another field is answered against what that field holds now.
do
    local runtime, renderer = start(Signup {})
    local fields = renderer:findAll("textinput")

    runtime:dispatch(fields[2].id, "onChange", "a long enough one")
    runtime:dispatch(fields[3].id, "onChange", "something else")
    runtime:dispatch(fields[3].id, "onBlur", nil)
    runtime:commit()

    assert(says(renderer, "These do not match"), "two that differ say so")

    runtime:dispatch(fields[3].id, "onChange", "a long enough one")
    runtime:commit()

    assert(not says(renderer, "These do not match"), "and stop the moment they are the same")
end

-- What the form holds is reachable from outside it and from inside it.
do
    local Watcher = gui.component({
        name = "Watcher",

        render = function(self)
            local held = gui.form:read(self)

            return gui.Text { text = held.valid and "ready" or "not ready" }
        end,
    })

    local Screen = gui.component({
        name = "Screen",

        render = function(self)
            return gui.Form {
                ref = self:ref("form"),
                initialValues = { email = "" },
                rules = { email = { gui.validators.required() } },

                gui.Field {
                    name = "email",
                    render = function(field)
                        return gui.TextInput { ref = field.ref, value = field.value, onChange = field.onChange }
                    end,
                },

                Watcher {},
            }
        end,
    })

    local runtime, renderer = start(Screen {})

    assert(says(renderer, "not ready"), "a form with a needed field empty is not ready to be sent")

    runtime.root.instance:ref("form"):call("setValue", { name = "email", value = "ada@example.com" })
    runtime:commit()

    assert(says(renderer, "ready"), "and is ready once it has been written into")

    local held = runtime.root.instance:ref("form"):call("values")

    assert(held.email == "ada@example.com", "what the form holds is what a caller reads back")

    runtime.root.instance:ref("form"):call("reset")
    runtime:commit()

    assert(says(renderer, "not ready"), "and resetting it puts back what it opened with")
end

-- A form refuses what it cannot work with, where it was written.
do
    local function refused(build, needle)
        local ok, problem = pcall(build)

        assert(not ok, "the form should have refused " .. needle)
        assert(tostring(problem):find(needle, 1, true) ~= nil, "it said " .. tostring(problem))
    end

    refused(function() return gui.Form { validateOn = "sometimes" } end, "validateOn")
    refused(function() return gui.Form { initialValues = "none" } end, "initialValues")
    refused(function() return gui.Field { render = function() end } end, "names the value")
    refused(function() return gui.Field { name = "a" } end, "render")
    refused(function() return gui.Field { name = "a", rules = 3, render = function() end } end, "rules")
end

print("gui.form ok")
