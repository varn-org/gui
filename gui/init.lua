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
local navigation = require("gui.navigation")
local observable = require("gui.observable")
local ref = require("gui.ref")
local storage = require("gui.host.storage")

local families = require("gui.components.families")
local support = require("gui.components.support")

local M = {
    component = component.define,
    none = component.none,
    theme = theme,
    color = color,
    filter = require("gui.style.filter"),
    animation = animation,
    protocol = protocol,
    headless = headless.create,
    conformance = conformance,
    context = context.create,
    observable = observable.create,
    navigation = navigation,
    form = require("gui.form"),
    marks = require("gui.marks"),
    validators = require("gui.validators"),
    theming = require("gui.theming"),
    controls = require("gui.controls"),
    control = require("gui.controls.declare").control,
    Showing = visibility.Showing,
    environment = environment,
    ref = ref.create,
    storage = storage,
    files = require("gui.files"),
    preferences = require("gui.preferences"),
}

-- A family also carries the helpers its own components and its siblings are built from, and `gui.X` is a
-- component, so only what declares itself as one is taken. The overlay a drawer is built out of would
-- otherwise stand on the public table beside the components, undocumented and untested, and a component
-- named after one of them later would be refused as a name two families define.
for index = 1, #families do
    for name, exported in pairs(require(families[index].module)) do
        if support.declarations[exported] ~= nil then
            if M[name] ~= nil then
                error("two component families both define " .. name, 0)
            end

            M[name] = exported
        end
    end
end

--- Answers every component name the library exposes, which the conformance suite walks.
function M.components()
    local names = {}

    for name, exported in pairs(M) do
        if support.declarations[exported] ~= nil then
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
