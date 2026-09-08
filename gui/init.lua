local element = require("gui.element")
local component = require("gui.component")
local runtime = require("gui.runtime")
local theme = require("gui.style.theme")
local animation = require("gui.style.animation")
local color = require("gui.style.color")
local headless = require("gui.bridge.headless")
local protocol = require("gui.bridge.protocol")
local conformance = require("gui.bridge.conformance")
local context = require("gui.context")
local visibility = require("gui.visibility")
local environment = require("gui.environment")
local ref = require("gui.ref")
local storage = require("gui.host.storage")
local resolve = require("gui.style.resolve")

local families = require("gui.components.families")

local M = {
    component = component.define,
    none = component.none,
    element = element,
    theme = theme,
    color = color,
    animation = animation,
    protocol = protocol,
    headless = headless.create,
    conformance = conformance,
    context = context.create,
    Showing = visibility.Showing,
    environment = environment,
    ref = ref.create,
    storage = storage,
    resolveStyle = resolve.resolve,
}

for index = 1, #families do
    for name, constructor in pairs(require(families[index].module)) do
        if M[name] ~= nil then
            error("two component families both define " .. name, 0)
        end

        M[name] = constructor
    end
end

--- Answers every component name the library exposes, which the conformance suite walks.
function M.components()
    local support = require("gui.components.support")
    local names = {}

    for index = 1, #families do
        for name, exported in pairs(require(families[index].module)) do
            -- A family also carries helpers its own components are built from, and a component is what
            -- declares itself, which is the same thing the reference page is built from.
            if support.declarations[exported] ~= nil then
                names[#names + 1] = name
            end
        end
    end

    table.sort(names)
    return names
end

--- Starts a description on a renderer, answering the runtime that drives it from then on.
function M.start(description, renderer, options)
    return runtime.start(description, renderer, options)
end

return M
