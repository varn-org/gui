local async = require("async")
local gui = require("gui")
local http = require("http")

-- The demo is loaded the way a host loads it, against a server this test owns.
package.path = "sample/?.lua;sample/?/init.lua;" .. package.path

local catalogue = require("catalogue")
local config = require("config")

local PORT = 8781
config.address = "http://127.0.0.1:" .. PORT .. "/hello"

local function drain(runtime)
    for _ = 1, 8 do
        if not runtime:needsCommit() then
            break
        end

        runtime:commit()
    end
end

--- Answers the text of every label on screen joined together, which is what a reader sees.
local function shown(renderer)
    local labels = renderer:findAll("text")
    local text = {}

    for index = 1, #labels do
        text[#text + 1] = tostring(labels[index].props.text)
    end

    return table.concat(text, "\n")
end

async.run(function()
    local server = http.createApp()

    server:get("/hello", function(ctx)
        ctx:text("the server answered")
    end)

    server:listen({ host = "127.0.0.1", port = PORT })

    local demo = catalogue.find("screens", "network")
    assert(demo ~= nil, "the gallery must carry the network demo")

    local renderer = gui.headless()
    local runtime = gui.start(gui.View { style = { grow = 1 }, demo.render(gui.theme.create()) }, renderer,
        { size = { width = 390, height = 844 } })
    drain(runtime)

    local button = nil

    for _, node in pairs(runtime.byId) do
        if node.type == "button" and type(node.props.onPress) == "function" then
            button = node
        end
    end

    assert(button ~= nil, "the demo must carry the button that starts the request")
    assert(shown(renderer):find("Status: idle", 1, true) ~= nil, "the demo starts idle")

    button.props.onPress()
    drain(runtime)

    assert(shown(renderer):find("Status: loading", 1, true) ~= nil,
        "the demo must report that a request is in flight, showing\n" .. shown(renderer))

    -- The request runs on the pool and resolves on the loop, so the screen is read once it has landed.
    for _ = 1, 100 do
        async.sleep(20):await()
        drain(runtime)

        if shown(renderer):find("Status: done", 1, true) ~= nil then
            break
        end
    end

    local text = shown(renderer)
    assert(text:find("Status: done", 1, true) ~= nil, "the request must succeed, the screen shows\n" .. text)
    assert(text:find("the server answered", 1, true) ~= nil, "the demo must show what came back, showing\n" .. text)

    print("gui.network ok")
end)
