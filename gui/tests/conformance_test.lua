local gui = require("gui")
local conformance = require("gui.bridge.conformance")

-- The reference renderer passes every case, which is what makes it the reference.
do
    local failures = conformance.run(gui.headless)

    if #failures > 0 then
        error("the headless renderer failed conformance:\n  " .. table.concat(failures, "\n  "), 0)
    end

    assert(#conformance.cases >= 11, "the suite must cover the whole contract, has " .. #conformance.cases)
end

-- A renderer that ignores a removal is caught rather than passing quietly.
do
    local broken = gui.headless()
    local original = broken.apply

    broken.apply = function(self, ops)
        local kept = {}
        for index = 1, #ops do
            if ops[index].op ~= "remove" then
                kept[#kept + 1] = ops[index]
            end
        end

        return original(self, kept)
    end

    local failures = conformance.run(function() return broken end)
    assert(#failures > 0, "a renderer that drops removals must fail the suite")
end

-- A renderer that moves by rebuilding is caught, since identity is part of the contract.
do
    local failures = conformance.run(function()
        local renderer = gui.headless()
        local original = renderer.place

        renderer.place = function(self, op)
            if op.op == "move" then
                return
            end

            return original(self, op)
        end

        return renderer
    end)

    assert(#failures > 0, "a renderer that ignores a move must fail the suite")
end

--- Answers the name a case is written under in a suite whose language names a test as an identifier.
local function identifier(name)
    local built = "test"

    for word in name:gmatch("%S+") do
        built = built .. word:sub(1, 1):upper() .. word:sub(2)
    end

    return built
end

--- Refuses a suite that does not carry exactly the cases this one does, naming both sides of the gap.
local function agrees(suite, declared)
    local missing = {}

    for index = 1, #conformance.cases do
        if not declared[conformance.cases[index].name] then
            missing[#missing + 1] = conformance.cases[index].name
        end
    end

    assert(#missing == 0, "the " .. suite .. " suite is missing " .. table.concat(missing, ", "))

    local extra = {}

    for name in pairs(declared) do
        local found = false

        for index = 1, #conformance.cases do
            if conformance.cases[index].name == name then
                found = true
            end
        end

        if not found then
            extra[#extra + 1] = name
        end
    end

    assert(#extra == 0, "the " .. suite .. " suite carries cases this one does not: " .. table.concat(extra, ", "))
end

-- Every suite runs the same cases, so a case added on one side cannot be forgotten on the others.
-- A batch is checked for what it carries as well as for what it names.
--
-- A field of the wrong type reaches every renderer as something it reads as nothing: a width that is a
-- string is a node laid out at nowhere on three platforms rather than a failure named where it was made.
do
    local protocol = require("gui.bridge.protocol")

    assert(protocol.validate({ { op = "frame", id = 1, x = 0, y = 0, width = 10, height = 10 } }) == nil,
        "a frame made of numbers is a frame")

    local wrong = protocol.validate({ { op = "frame", id = 1, x = 0, y = 0, width = "10", height = 10 } })

    assert(wrong ~= nil and wrong:find("width", 1, true) ~= nil,
        "a width that is not a number is refused, saying which field: " .. tostring(wrong))

    local nothing = protocol.validate({ { op = "frame", id = 1, x = 0, y = 0, width = 0 / 0, height = 10 } })

    assert(nothing ~= nil, "and so is one that is not a number at all")

    local named = protocol.validate({ { op = "create", id = "one", type = "view" } })

    assert(named ~= nil and named:find("id", 1, true) ~= nil,
        "an id that is not a number is refused: " .. tostring(named))
end


do
    local async = require("async")
    local fs = require("fs")

    async.run(function()
        local web = {}

        for name in fs.readFile("renderers/web/conformance.js"):await():gmatch('name:%s*"([^"]+)"') do
            web[name] = true
        end

        agrees("web", web)

        local named = {}
        for index = 1, #conformance.cases do
            named[identifier(conformance.cases[index].name)] = conformance.cases[index].name
        end

        local swift = {}

        for name in fs.readFile("renderers/ios/tests/ConformanceTests.swift"):await():gmatch("func (test%w+)%s*%(") do
            assert(named[name] ~= nil, "the iOS suite carries a case this one does not: " .. name)
            swift[named[name]] = true
        end

        agrees("iOS", swift)

        local kotlin = {}

        for name in fs.readFile("renderers/android/src/test/kotlin/dev/varn/gui/ConformanceTest.kt"):await()
            :gmatch("fun (test%w+)%s*%(") do
            assert(named[name] ~= nil, "the Android suite carries a case this one does not: " .. name)
            kotlin[named[name]] = true
        end

        agrees("Android", kotlin)

        print("gui.conformance ok")
    end)
end
