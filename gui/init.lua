local element = require("gui.element")
local component = require("gui.component")
local runtime = require("gui.runtime")
local theme = require("gui.style.theme")
local color = require("gui.style.color")
local headless = require("gui.bridge.headless")
local protocol = require("gui.bridge.protocol")
local conformance = require("gui.bridge.conformance")
local context = require("gui.context")
local ref = require("gui.ref")
local resolve = require("gui.style.resolve")

local FAMILIES = {
    (require("gui.components.structure")),
    (require("gui.components.content")),
    (require("gui.components.input")),
    (require("gui.components.collections")),
    (require("gui.components.containers")),
    (require("gui.components.presentation")),
    (require("gui.components.feedback")),
}

local M = {
    component = component.define,
    none = component.none,
    element = element,
    theme = theme,
    color = color,
    protocol = protocol,
    headless = headless.create,
    conformance = conformance,
    context = context.create,
    ref = ref.create,
    resolveStyle = resolve.resolve,
}

for index = 1, #FAMILIES do
    for name, constructor in pairs(FAMILIES[index]) do
        if M[name] ~= nil then
            error("two component families both define " .. name, 0)
        end

        M[name] = constructor
    end
end

--- Answers every component name the library exposes, which the conformance suite walks.
function M.components()
    local names = {}

    for index = 1, #FAMILIES do
        for name in pairs(FAMILIES[index]) do
            names[#names + 1] = name
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
