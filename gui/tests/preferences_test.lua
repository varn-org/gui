local async = require("async")
local preferences = require("gui.preferences")

--- A keystore that answers the way every platform's does, which is whenever it answers.
---
--- Nothing about this is synchronous on any of the three: a keychain is queried, a keystore decrypts and
--- a browser reads a key out of IndexedDB, so a caller waits. What is held here is the json each host
--- holds rather than the value itself, since that is what comes back and what has to come back as what
--- it was.
local function keystore(options)
    local held = {}
    local answers = {}

    host = {
        gui_preferences = function(request)
            local reply = { ticket = request.ticket }

            if (options or {}).refuses then
                reply.problem = "the keystore refused it"
            elseif request.action == "set" then
                held[request.name] = request.value
            elseif request.action == "get" then
                reply.value = held[request.name]
            elseif request.action == "remove" then
                held[request.name] = nil
            elseif request.action == "clear" then
                held = {}
            elseif request.action == "names" then
                local names = {}

                for name in pairs(held) do
                    names[#names + 1] = name
                end

                table.sort(names)
                reply.value = names
            else
                reply.problem = "a preference is set, read, removed, cleared or listed"
            end

            answers[#answers + 1] = reply
        end,
    }

    return {
        held = held,
        -- A host answers after it has answered the call, which is what the event is for.
        settle = function()
            local pending = answers
            answers = {}

            for index = 1, #pending do
                preferences.answered(pending[index])
            end
        end,
    }
end

async.run(function()
    -- What was kept is what comes back, as the kind of value it was written as.
    do
        local store = keystore()

        for _, written in ipairs({ "a token", 42, true, false, { name = "Ada", years = { 1815, 1852 } } }) do
            local asked = preferences.set("held", written)

            store.settle()
            asked:await()

            local reading = preferences.get("held")

            store.settle()

            local read = reading:await()

            if type(written) == "table" then
                assert(read.name == written.name, "a table comes back as a table")
                assert(read.years[2] == written.years[2], "with what was inside it")
            else
                assert(read == written, "what was kept comes back, kept " .. tostring(written)
                    .. " and got " .. tostring(read))
            end
        end
    end

    -- A preference nobody has kept is nothing rather than a failure, which is the first run of every
    -- application that ever reads one.
    do
        local store = keystore()
        local reading = preferences.get("never written")

        store.settle()
        assert(reading:await() == nil, "a preference nobody kept answers nothing")
    end

    -- Taking one away takes it away, and clearing takes the lot.
    do
        local store = keystore()

        preferences.set("one", 1)
        preferences.set("two", 2)
        store.settle()

        local naming = preferences.names()

        store.settle()

        local names = naming:await()

        assert(#names == 2, "both were kept, there are " .. #names)

        preferences.remove("one")
        store.settle()

        local reading = preferences.get("one")

        store.settle()
        assert(reading:await() == nil, "what was taken away is gone")

        preferences.clear()
        store.settle()

        naming = preferences.names()
        store.settle()
        assert(#naming:await() == 0, "and clearing takes the rest")
    end

    -- A keystore that refuses says so rather than answering nothing, which reads as an empty preference.
    do
        local store = keystore({ refuses = true })
        local reading = preferences.get("held")

        store.settle()

        local ok, problem = pcall(function() return reading:await() end)

        assert(not ok, "a refusal is raised rather than read as nothing")
        assert(tostring(problem):find("could not be reached", 1, true) ~= nil,
            "and says what happened, it said " .. tostring(problem))
    end

    -- What cannot be written down is refused where it was written rather than kept as something the
    -- next run cannot make sense of.
    do
        keystore()

        local ok, problem = pcall(preferences.set, "held", print)

        assert(not ok, "a function is not a preference")
        assert(tostring(problem):find("string, a number, a boolean or a table", 1, true) ~= nil,
            "and says what one is, it said " .. tostring(problem))

        assert(not pcall(preferences.get, ""), "a preference is named")
    end

    print("gui.preferences ok")
end)
