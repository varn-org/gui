local async = require("async")

local M = {}

local waiting = {}
local nextTicket = 0

--- Answers the handle one request is tracked by, since a platform answers whenever it answers.
local function claim()
    nextTicket = nextTicket + 1
    return nextTicket
end

--- Takes what a host answered and settles whoever asked for it.
---
--- The reply carries the ticket it belongs to, since a reader may be saving one thing while sharing
--- another and a sheet stays open for as long as they look at it. A reply nobody is waiting on is life
--- rather than a mistake, since a sheet outlives the screen that opened it.
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

--- Waits for the platform to be done and answers what it said.
---
--- A deferred promise carries no value of its own, so what the host answered is held beside it and read
--- back here rather than being squeezed through the signal that it arrived.
function Asked:await()
    self.answered:await()
    return self.reply
end

local function ask(action, path, options)
    if type(path) ~= "string" or path == "" then
        error("a file is named by its path, got " .. tostring(path), 3)
    end

    local ticket = claim()
    local answered, settle = async.deferred()
    local asked = setmetatable({ answered = answered, settle = settle }, Asked)

    waiting[ticket] = asked
    host.gui_files({
        action = action,
        ticket = ticket,
        path = path,
        title = (options or {}).title,
    })

    return asked
end

--- Keeps a file where the platform keeps pictures and films, answering once it is there.
---
--- The answer carries where it ended up, or a `problem` saying why it did not: a reader who refused the
--- library and a sheet they closed without choosing anything are both ordinary, so neither is a failure
--- that takes a screen with it.
---
--- What a camera captures is written where the application may write, which is a place only the
--- application can reach: a reader who took a picture has nothing until it is somewhere they can open it
--- again. Each platform has one place that means kept — the photo library on a phone, the downloads a
--- browser writes to — and this is that place rather than a directory chosen by a tree.
function M.save(path, options)
    return ask("save", path, options)
end

--- Hands a file to the platform's own way of sending it, answering once the reader is done with it.
---
--- A share sheet is also where a reader saves to somewhere the application never hears about, which is
--- why a phone offers no other way to put a picture in a message.
function M.share(path, options)
    return ask("share", path, options)
end

return M
