local element = require("gui.element")

local M = {}

local scheduler = nil

--- The value a caller sets a state field to when it wants the field gone.
---
--- A nil in a table is invisible to `pairs`, so a state field could otherwise never be cleared: the
--- change would simply not be seen.
M.none = setmetatable({}, { __tostring = function() return "none" end })

--- Points the component layer at the scheduler that owns the commits from here on.
---
--- An instance keeps the one it was built under rather than reading this when it needs it, since two
--- runtimes in one process would otherwise share the last one to start and a component would ask a
--- runtime that does not hold it to draw it.
function M.useScheduler(value)
    scheduler = value
end

local function copy(source)
    local result = {}

    if source ~= nil then
        for key, value in pairs(source) do
            result[key] = value
        end
    end

    return result
end

--- The moments a component is told about, which are the ones a platform tells a screen about.
---
--- Nine of them are about the screen and two about the application. `onPause` carries which state it is
--- going to — in front and not taking input, or out of sight and possibly about to be ended — since what
--- is worth doing differs: a game pauses at the first and a draft is saved at the second.
---
--- Mounting is a screen being built and unmounting is it being taken down, which is what iOS calls
--- loading and Android calls creating. Appearing is it being shown, which is a different thing: a stack
--- keeps the screen under the one on top, and a tab bar keeps every tab, so a screen that is built is
--- not necessarily one a reader can see. Each moment comes in a pair, before and after, since work that
--- has to happen before a reader sees a change is not the same as work that follows one.
local LIFECYCLE = {
    onWillMount = true,
    onMount = true,
    onWillAppear = true,
    onAppear = true,
    onWillDisappear = true,
    onDisappear = true,
    onUpdate = true,
    onWillUnmount = true,
    onUnmount = true,
    onPause = true,
    onResume = true,
}

local RESERVED = {
    render = true,
    state = true,
    name = true,
}

for name in pairs(LIFECYCLE) do
    RESERVED[name] = true
end

local Instance = {}
Instance.__index = Instance

--- Merges the given fields into the state and asks for a commit, which happens once however often this is called.
function Instance:setState(changes)
    if type(changes) ~= "table" then
        error("state is a table of the fields to change, got " .. type(changes), 2)
    end

    if self.rendering then
        error("setState cannot be called from inside render, since a commit would then run inside a commit", 2)
    end

    -- False is the middle of an `and`/`or` and Lua takes the other branch for it, so what a screen
    -- asked to be cleared is told apart from what it set to false by a check rather than by a fallback.
    for key, value in pairs(changes) do
        if value == M.none then
            self.state[key] = nil
        else
            self.state[key] = value
        end
    end

    if self.mounted and self.scheduler ~= nil then
        self.scheduler.markDirty(self.node)
    end
end

--- Runs work once the given time has passed, if the component is still on screen by then.
---
--- A body handed to `spawn` is caught by nothing above it: the engine reports it as unhandled and stops
--- the loop for that tick, so a dismissal handler that fails takes the frame with it. A delay is whole
--- milliseconds, which is what a platform timer takes.
function Instance:after(milliseconds, work)
    if type(milliseconds) ~= "number" or milliseconds ~= milliseconds then
        error("a delay is a number of milliseconds, got " .. tostring(milliseconds), 2)
    end

    local async = require("async")
    local delay = math.max(0, math.floor(milliseconds + 0.5))

    local run = function()
        if not self.mounted then
            return
        end

        local ok, problem = pcall(work, self)

        if not ok and self.scheduler ~= nil then
            self.scheduler.report("something a component asked to happen later failed: " .. tostring(problem))
        end
    end

    async.spawn(function()
        local slept = pcall(function() async.sleep(delay):await() end)

        if not slept or not self.mounted then
            return
        end

        if self.scheduler ~= nil and self.scheduler.holds(run) then
            return
        end

        run()
    end)
end

--- Answers the handle this component holds under a name, which is the same one on every render.
---
--- A ref built in the render is a new handle on every commit, pointing at nothing until the commit that
--- follows, and one built in `onMount` does not exist for the first render at all — which is a screen
--- whose first press reaches nothing. Naming it here is what makes it one handle for the life of the
--- component, built the first time it is asked for.
function Instance:ref(name)
    if self.refs == nil then
        self.refs = {}
    end

    if self.refs[name] == nil then
        self.refs[name] = require("gui.ref").create()
    end

    return self.refs[name]
end

--- Answers whether this is on screen, which is what the thing showing it says rather than the tree.
---
--- A component told about appearing is rendered again when what shows it changes its mind, since the
--- moment is fired from the render that follows. One that only asks is answered without that, so a
--- question asked from a timer costs nothing and no component is rendered for an answer nothing draws.
function Instance:visible()
    local visibility = require("gui.visibility")

    if self.watchesVisibility then
        return visibility.of(self)
    end

    return visibility.showing(self)
end

--- Runs work over and over while the component is on screen, which is what anything that pulses needs.
---
--- Writing the loop by hand is a component that schedules itself again from inside its own handler, and
--- one that forgets to stop is a screen that has been left still ticking. A tab bar keeps every tab and
--- a stack keeps the screen under the one on top, so a pulse that ran on being mounted alone would run
--- for the life of the application on a screen nobody can see, asking for a commit each time. A turn
--- taken out of sight is skipped rather than ended, so the pulse is there again on coming back.
function Instance:every(milliseconds, work)
    self:after(milliseconds, function()
        if self:visible() then
            work(self)
        end

        self:every(milliseconds, work)
    end)
end

function Instance:render()
    self.rendering = true
    local ok, rendered = pcall(self.definition.render, self)
    self.rendering = false

    if not ok then
        error(rendered, 0)
    end

    return rendered
end

--- Declares a component, answering a constructor that takes props and children like any other element.
---
--- The definition carries `render`, an optional initial `state`, and the optional `onMount`, `onUpdate`
--- and `onUnmount` callbacks. A definition without state is a component that only describes.
function M.define(definition)
    if type(definition) == "function" then
        definition = { render = definition }
    end

    if type(definition.render) ~= "function" then
        error("a component needs a render function", 2)
    end

    -- A component declared inside a render is a different kind on every commit, so what it drew is torn
    -- down and built again each time: the screen comes out blank and nothing at all is reported. It is
    -- declared once, where it is written, and used from wherever it is needed.
    if scheduler ~= nil and scheduler.rendering ~= nil and scheduler.rendering() then
        error("a component is declared once rather than inside a render, which builds a new one each time", 2)
    end

    -- A definition may carry helper methods beside render, and an instance reaches them like any other.
    --
    -- One named as something every component already answers is refused rather than allowed to take its
    -- place: the component would work and everything the engine calls that method for would quietly get
    -- the caller's instead, which is a screen that draws nothing with nothing anywhere saying why.
    local methods = setmetatable({}, { __index = Instance })
    for key, value in pairs(definition) do
        if type(value) == "function" and not RESERVED[key] then
            if Instance[key] ~= nil then
                error((definition.name or "a component") .. " cannot have a method named " .. key
                    .. ", since that is one every component already answers", 0)
            end

            methods[key] = value
        end
    end

    local metatable = { __index = methods }

    local kind = {
        name = definition.name,
        definition = definition,
    }

    function kind.instantiate(props, children, node)
        local instance = setmetatable({
            definition = definition,
            props = props,
            children = children,
            state = copy(definition.state),
            node = node,
            scheduler = scheduler,
            mounted = true,
            rendering = false,
        }, metatable)

        for name in pairs(LIFECYCLE) do
            instance[name] = definition[name]
        end

        instance.watchesVisibility = definition.onWillAppear ~= nil or definition.onAppear ~= nil
            or definition.onWillDisappear ~= nil or definition.onDisappear ~= nil

        return instance
    end

    local build = element.define(kind)

    local constructor = function(spec)
        return build(spec)
    end

    -- The kind is what the retained tree stores as a node's type, so a context reads it to find its provider.
    kind.constructor = constructor
    return constructor, kind
end

return M
