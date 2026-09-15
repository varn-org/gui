local async = require("async")
local config = require("config")
local gui = require("gui")
local http = require("http")
local parts = require("parts")

--- The button that sends the form, which reads what the form holds rather than being handed it.
---
--- A component inside a form reaches the values, what is wrong with them and the moment it is sent
--- through the form itself, so nothing above it has to thread a callback down to the button.
local Sender = gui.component({
    name = "FormSender",

    render = function(self)
        local held = gui.form:read(self)

        return gui.View { style = { direction = "row", gap = "sm" },
            gui.Button {
                title = "Submit",
                disabled = not held.valid,
                style = { grow = 1 },
                onPress = function() held.submit() end,
            },

            gui.Button {
                title = "Reset",
                variant = "outlined",
                style = { grow = 1 },
                onPress = function() held.reset() end,
            },
        }
    end,
})

--- A rule of the caller's own, which sits beside the ones the framework ships.
---
--- A validator is a function of the value and of everything else the form holds, so a rule nobody
--- thought of is written where it is needed rather than asked for.
local function noFreeMail(value)
    if value == nil or value == "" or value:match("@example%.com$") == nil then
        return nil
    end

    return "Use an address we can reply to"
end

local Form = gui.component({
    name = "FormDemo",
    state = { saved = nil },

    render = function(self)
        return parts.Page {
            gui.Form {
                ref = self:ref("form"),
                initialValues = { name = "", email = "", plan = "monthly", people = "1", agreed = false },
                validateOn = "blur",
                onSubmit = function(values) self:setState({ saved = values.name }) end,
                onInvalid = function(_, first) self:setState({ saved = gui.none, first = first }) end,

                parts.Block {
                    title = "Tell us about you",
                    summary = "Each field is judged when it is left, and on every keystroke once a send has failed",

                    gui.Field {
                        name = "name",
                        label = "Name",
                        required = true,
                        rules = { gui.validators.minLength(2) },
                        render = function(field)
                            return gui.TextInput {
                                ref = field.ref,
                                value = field.value,
                                placeholder = "Ada Lovelace",
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
                        rules = { gui.validators.email(), noFreeMail },
                        render = function(field)
                            return gui.TextInput {
                                ref = field.ref,
                                value = field.value,
                                placeholder = "you@work.com",
                                keyboard = "email",
                                autoCapitalize = "none",
                                onChange = field.onChange,
                                onBlur = field.onBlur,
                            }
                        end,
                    },

                    gui.Field {
                        name = "people",
                        label = "How many of you",
                        rules = { gui.validators.integer(), gui.validators.range(1, 50) },
                        render = function(field)
                            return gui.TextInput {
                                ref = field.ref,
                                value = field.value,
                                keyboard = "number",
                                onChange = field.onChange,
                                onBlur = field.onBlur,
                            }
                        end,
                    },
                },

                parts.Block {
                    title = "Choose a plan",

                    gui.Field {
                        name = "plan",
                        rules = { gui.validators.oneOf({ "monthly", "yearly" }) },
                        render = function(field)
                            return gui.RadioGroup {
                                value = field.value,
                                options = {
                                    { value = "monthly", label = "Monthly" },
                                    { value = "yearly", label = "Yearly" },
                                },
                                onChange = field.onChange,
                            }
                        end,
                    },

                    gui.Field {
                        name = "agreed",
                        rules = { gui.validators.accepted("The terms have to be agreed to") },
                        render = function(field)
                            return gui.Checkbox {
                                value = field.value == true,
                                label = "I agree to the terms",
                                onChange = field.onChange,
                            }
                        end,
                    },
                },

                parts.Block {
                    title = "Send it",
                    summary = "A send that fails puts the keyboard in the first field that is wrong",

                    Sender {},

                    self.state.saved ~= nil and gui.Text {
                        text = "Saved for " .. self.state.saved,
                        style = { color = "success", fontWeight = "600" },
                    } or false,
                },
            },
        }
    end,
})

local Network = gui.component({
    name = "NetworkDemo",
    state = { status = "idle", body = "", ticks = 0 },

    onMount = function(self)
        self:tick()

        if config.fetchOnOpen then
            self:fetch()
        end
    end,

    onUnmount = function(self)
        self.stopped = true
    end,

    --- Counts while a request is in flight, which is what shows the interface never froze waiting for it.
    tick = function(self)
        if self.stopped or self.ticking or self.state.status ~= "loading" then
            return
        end

        self.ticking = true
        self:setState({ ticks = self.state.ticks + 1 })

        self:after(120, function()
            self.ticking = false
            self:tick()
        end)
    end,

    --- Fetches over the network, answering the status and the body, or what went wrong instead.
    ---
    --- The demo names the address it asked and what came back, since a request that answers only
    --- "failed" tells a reader nothing about whether it was the network, the address or the transport.
    fetch = function(self)
        self:setState({ status = "loading", ticks = 0, body = "" })
        self:tick()

        require("async").spawn(function()
            local ok, answer = pcall(function()
                return http.client.get(config.address):await()
            end)

            if self.stopped then
                return
            end

            if not ok then
                self:setState({ status = "failed", body = config.address .. "\n" .. tostring(answer) })
                return
            end

            local status = "failed"
            if answer.status == 200 then
                status = "done"
            end

            self:setState({ status = status, body = answer.status .. " " .. tostring(answer.body):sub(1, 220) })
        end)
    end,

    render = function(self)
        return parts.Page {
            parts.Block {
                title = "Ask the network",
                gui.Button { title = "Fetch", onPress = function() self:fetch() end },
                gui.Text { text = "Status: " .. self.state.status, style = { color = "textMuted" } },
            },

            self.state.status == "loading" and parts.Block {
                title = "While it is in flight",
                gui.View { style = { direction = "row", gap = "md", align = "center" },
                    gui.ActivityIndicator {},
                    gui.Text { text = "Ticked " .. self.state.ticks .. " times, so nothing is frozen" },
                },
            } or false,

            self.state.body ~= "" and parts.Block {
                title = "What came back",
                gui.Text { text = self.state.body, style = { fontSize = "caption", color = "textMuted" } },
            } or false,
        }
    end,
})

--- An address names a screen, which is what a deep link, an app link and a web address all arrive as.
local Catalogue = gui.component({
            name = "RoutesCatalogue",
            render = function(self)
                local route = gui.navigation:read(self)
                local rows = {}

                for _, item in ipairs({ "kettle", "lamp", "rug" }) do
                    rows[#rows + 1] = gui.Pressable {
                        key = item,
                        accessibilityLabel = item,
                        style = { height = 52, direction = "row", align = "center", paddingHorizontal = "md" },
                        onPress = function() route.go("/items/" .. item) end,
                        gui.Text { text = item, style = { grow = 1 } },
                        gui.Icon { name = "chevron-right", size = 16, color = "textMuted" },
                    }
                end

                return gui.View { style = { grow = 1 },
                    gui.View { style = { padding = "md", gap = "xs" },
                        gui.Text { text = "This screen is at " .. route.path, style = { color = "textMuted" } },
                        gui.Text {
                            text = "A deep link, an app link and a web address all land here.",
                            style = { fontSize = "footnote", color = "textMuted" },
                        },
                    },
                    gui.Divider {},
                    table.unpack(rows),
                }
            end,
})

local Item = gui.component({
            name = "RoutesItem",
            render = function(self)
                local route = gui.navigation:read(self)

                return gui.View { style = { grow = 1, padding = "md", gap = "sm" },
                    gui.Text { text = route.params.id, style = { fontSize = "title", fontWeight = "700" } },
                    gui.Text { text = "at " .. route.address, style = { color = "textMuted" } },
                    gui.Button { title = "Back", variant = "tinted", onPress = function() route.back() end },
                }
            end,
})

local Addressed = gui.component({
    name = "RoutesDemo",

    render = function()
        return gui.Router {
            routes = {
                { path = "/", title = "Catalogue", render = function() return Catalogue {} end },
                {
                    path = "/items/:id",
                    title = function(where) return where.params.id end,
                    render = function() return Item {} end,
                },
            },
            notFound = function(where)
                return gui.View { style = { grow = 1, padding = "md" },
                    gui.Text { text = "Nothing answers " .. where.path },
                }
            end,
        }
    end,
})

--- What an application finds again next time it is opened, kept where the platform keeps a secret.
---
--- The point of the screen is the round trip: what is written here is still here after the application
--- has been closed and opened, which is the one thing a reader cannot see from a screenshot.
local Kept = gui.component({
    name = "PreferencesDemo",
    state = { name = "", value = "", names = {}, said = "" },

    onMount = function(self)
        self:list()
    end,

    --- Shows what is kept, or says why there is nothing to show rather than taking the screen with it.
    list = function(self)
        async.spawn(function()
            local ok, answer = pcall(function() return gui.preferences.names():await() end)

            if not ok then
                self:setState({ names = {}, said = tostring(answer) })
                return
            end

            self:setState({ names = answer })
        end)
    end,

    --- Runs one thing against the keystore and says what happened, however it turned out.
    ---
    --- A keystore is asked and answers, so everything here waits. A refusal is raised rather than read
    --- as an empty preference, which is why it is caught and said rather than left to the screen.
    against = function(self, said, work)
        async.spawn(function()
            local ok, problem = pcall(work)

            self:setState({ said = ok and said or tostring(problem) })
            self:list()
        end)
    end,

    render = function(self)
        local rows = {}

        for index = 1, #self.state.names do
            local name = self.state.names[index]

            rows[#rows + 1] = gui.Pressable {
                key = name,
                accessibilityLabel = name,
                style = { direction = "row", align = "center", gap = "sm", paddingVertical = "xs" },
                onPress = function()
                    self:against("Read it", function()
                        self:setState({ name = name, value = tostring(gui.preferences.get(name):await()) })
                    end)
                end,

                gui.Text { text = name, style = { grow = 1 } },
                gui.Icon { name = "chevron-right", size = 16, color = "textMuted" },
            }
        end

        return parts.Page {
            parts.Block {
                title = "Kept on the device",
                summary = "Written where the platform keeps a secret, and still here next time",

                gui.TextInput {
                    value = self.state.name,
                    placeholder = "Name",
                    onChange = function(value) self:setState({ name = value }) end,
                },

                gui.TextInput {
                    value = self.state.value,
                    placeholder = "What to keep under it",
                    onChange = function(value) self:setState({ value = value }) end,
                },

                gui.View { style = { direction = "row", gap = "sm" },
                    gui.Button {
                        title = "Keep",
                        style = { grow = 1 },
                        onPress = function()
                            self:against("Kept it", function()
                                gui.preferences.set(self.state.name, self.state.value):await()
                            end)
                        end,
                    },

                    gui.Button {
                        title = "Forget",
                        variant = "outlined",
                        style = { grow = 1 },
                        onPress = function()
                            self:against("Forgot it", function()
                                gui.preferences.remove(self.state.name):await()
                            end)
                        end,
                    },
                },

                self.state.said ~= "" and gui.Text {
                    text = self.state.said,
                    style = { fontSize = "caption", color = "textMuted" },
                } or false,
            },

            parts.Block {
                title = "What is kept",
                summary = "Press one to read it back",

                #rows == 0 and gui.Text {
                    text = "Nothing yet",
                    style = { color = "textMuted" },
                } or gui.View { table.unpack(rows) },

                gui.Button {
                    title = "Forget everything",
                    variant = "tinted",
                    onPress = function()
                        self:against("Forgot the lot", function() gui.preferences.clear():await() end)
                    end,
                },
            },
        }
    end,
})

return {
    { key = "routes", title = "Addresses", summary = "A link from outside lands on the screen it names", render = function() return Addressed {} end },
    { key = "form", title = "A form", summary = "Fields, validation and what is wrong", render = function() return Form {} end },
    { key = "network", title = "A request", summary = "The screen keeps moving while it waits", render = function() return Network {} end },
    { key = "kept", title = "What is remembered", summary = "Values the device keeps between runs", render = function() return Kept {} end },
}
