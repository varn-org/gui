local async = require("async")

local M = {}

local waiting = {}
local nextTicket = 0

--- Answers the handle one request is tracked by, since a keystore answers whenever it answers.
local function claim()
    nextTicket = nextTicket + 1
    return nextTicket
end

--- Takes what a host answered and settles whoever asked for it.
function M.answered(reply)
    local asked = waiting[reply.ticket]

    if asked == nil then
        return
    end

    waiting[reply.ticket] = nil
    asked.reply = reply
    asked.settle()
end

local Asked = {}
Asked.__index = Asked

--- Waits for the keystore and answers what it said, raising when it could not do what was asked.
---
--- A value that is not there is not a failure: a preference nobody has written yet answers nothing, and
--- a caller reading one for the first time is the ordinary case rather than the broken one.
function Asked:await()
    self.answered:await()

    if self.reply.problem ~= nil then
        error("the preference could not be reached: " .. tostring(self.reply.problem), 0)
    end

    return self.reply.value
end

--- The types a preference may carry, which is what survives being written down and read back.
local function writable(value)
    local kind = type(value)

    return kind == "string" or kind == "number" or kind == "boolean" or kind == "table"
end

--- The two that reach the whole store rather than one preference in it.
local WHOLE = { clear = true, names = true }

local function ask(action, name, value)
    if not WHOLE[action] and (type(name) ~= "string" or name == "") then
        error("a preference is named, got " .. tostring(name), 3)
    end

    local ticket = claim()
    local answered, settle = async.deferred()
    local asked = setmetatable({ answered = answered, settle = settle }, Asked)

    -- A host that registered no keystore is said so by name rather than as a nil being called, which is
    -- what a renderer written against an older contract looks like from here.
    if type(host.gui_preferences) ~= "function" then
        error("this host keeps no preferences", 3)
    end

    waiting[ticket] = asked
    host.gui_preferences({ action = action, ticket = ticket, name = name, value = value })

    return asked
end

--- Keeps a value where the platform keeps what an application must find again, answering once it is in.
---
--- A string, a number, a boolean or a table of them, which is what survives being written down and read
--- back as what it was. Anything else is refused where it was written rather than stored as something
--- the next run cannot make sense of.
function M.set(name, value)
    if not writable(value) then
        error("a preference carries a string, a number, a boolean or a table, got " .. type(value), 2)
    end

    return ask("set", name, value)
end

--- Answers what was kept under a name, or nothing when nobody has kept anything under it.
function M.get(name)
    return ask("get", name)
end

--- Takes a preference away, answering once it is gone.
function M.remove(name)
    return ask("remove", name)
end

--- Takes every preference this application kept away, which is what signing out of one means.
function M.clear()
    return ask("clear")
end

--- Answers the names this application has kept something under.
function M.names()
    return ask("names")
end

return M
