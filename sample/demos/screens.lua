local config = require("config")
local gui = require("gui")
local http = require("http")
local parts = require("parts")

--- Answers what is wrong with the form, which is what the caller is shown rather than a boolean.
local function problems(values)
    local found = {}

    if #values.name < 2 then
        found.name = "A name needs at least two characters"
    end

    if not values.email:find("@", 1, true) then
        found.email = "An email address needs an @"
    end

    if not values.agreed then
        found.agreed = "The terms have to be agreed to"
    end

    return found
end

local Form = gui.component({
    name = "FormDemo",
    state = { name = "", email = "", agreed = false, submitted = false, problems = {}, saved = false },

    render = function(self)
        local function field(key, label, extra)
            local spec = {
                value = self.state[key],
                placeholder = label,
                onChange = function(value) self:setState({ [key] = value }) end,
            }

            for name, value in pairs(extra or {}) do
                spec[name] = value
            end

            return gui.View { style = { gap = "xs" },
                gui.Text { text = label, style = { color = "textMuted" } },
                gui.TextInput(spec),
                self.state.problems[key] ~= nil and gui.Text {
                    text = self.state.problems[key],
                    style = { color = "danger", fontSize = "caption" },
                } or false,
            }
        end

        return parts.Page {
            parts.Block {
                title = "Tell us about you",
                field("name", "Name"),
                field("email", "Email", { keyboard = "email" }),
                gui.Checkbox {
                    value = self.state.agreed,
                    label = "I agree to the terms",
                    onChange = function(value) self:setState({ agreed = value }) end,
                },
                self.state.problems.agreed ~= nil and gui.Text {
                    text = self.state.problems.agreed,
                    style = { color = "danger", fontSize = "caption" },
                } or false,
            },

            parts.Block {
                title = "Send it",
                gui.Button {
                    title = "Submit",
                    onPress = function()
                        local found = problems(self.state)
                        local ok = next(found) == nil

                        self:setState({ submitted = true, problems = found, saved = ok })
                    end,
                },
                self.state.saved and gui.Text { text = "Saved", style = { color = "success", fontWeight = "600" } } or false,
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
        if self.stopped or self.state.status ~= "loading" then
            return
        end

        self:setState({ ticks = self.state.ticks + 1 })
        require("async").spawn(function()
            require("async").sleep(120):await()
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

return {
    { key = "form", title = "A form", summary = "Fields, validation and what is wrong", render = function() return Form {} end },
    { key = "network", title = "A request", summary = "The screen keeps moving while it waits", render = function() return Network {} end },
}
