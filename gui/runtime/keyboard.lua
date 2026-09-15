local natural = require("gui.layout.natural")
local protocol = require("gui.bridge.protocol")

--- How much room is left between a revealed field and the top of the keyboard.
local MARGIN = 12

--- The keyboard, and where a surface is scrolled to.
---
--- The two are one thing: the keyboard takes room away from whatever surface it covers, the engine gives
--- that room back so a focused field can be lifted clear of it, and taking the room away again is what
--- brings the screen down when the keyboard goes. A surface is asked where it is only while the engine
--- has a use for the answer.
return function(Runtime)

--- Answers how much of a scrolling surface the keyboard is over, which is room it has to give back.
function Runtime:coveredBy(node)
    if self.environment.keyboard <= 0 or self.size == nil or self.frames == nil then
        return 0
    end

    local frame = self.frames[node.id]

    if frame == nil then
        return 0
    end

    local bottom = self:screenTop(node) + frame.height

    return math.max(0, bottom - (self.size.height - self.environment.keyboard))
end

--- Answers how far down the surface a host node sits, which is every frame above it added up.
function Runtime:screenTop(node)
    local top = 0
    local walk = node

    while walk ~= nil do
        local frame = self.frames[walk.id]

        if frame ~= nil then
            top = top + frame.y
        end

        walk = walk.parentNode

        while walk ~= nil and walk.kind ~= "host" do
            walk = walk.parentNode
        end
    end

    return top
end

--- Brings a surface back inside its own content when what it holds no longer reaches where it is.
---
--- The keyboard going away takes back the room it was given, and a surface left scrolled past its last
--- row shows a blank band that a reader cannot scroll out of — which is what a field screen thrown up
--- to make room and never put back was. The engine owns the layout, so the engine is what knows.
function Runtime:holdInside(id, extent)
    local at = self.offsets[id]
    local frame = self.frames ~= nil and self.frames[id] or nil

    if at == nil or frame == nil then
        return
    end

    local room = math.max(0, extent - frame.height)

    if at <= room + 1 then
        return
    end

    self.offsets[id] = room
    self.holding[#self.holding + 1] = { id = id, y = room }
end

--- Moves every surface the layout left scrolled past its own content, once the batch has landed.
---
--- It happens after the batch rather than inside it, since a surface is moved against the frames and the
--- extent the batch is carrying and neither has reached the renderer while the batch is being built.
function Runtime:holdSurfaces()
    local waiting = self.holding
    self.holding = {}

    for index = 1, #waiting do
        local ok, problem = pcall(function()
            self.renderer:invoke(waiting[index].id, "scrollTo", { x = 0, y = waiting[index].y, animated = false })
        end)

        if not ok then
            self:report("a surface could not be brought back inside its content: " .. tostring(problem))
        end
    end
end

--- Answers whether the engine has a use for where a surface is scrolled to.
---
--- A scroll is reported by the pixel, so a surface is asked only when the answer is worth the crossing:
--- something under it watching to be seen, or a keyboard it has to lift a field clear of and put the
--- surface back from afterwards.
function Runtime:needsOffset()
    return self.watching > 0 or self.environment.keyboard > 0
end

--- Asks every scrolling surface for its offset, or stops asking, which is what the keyboard changes.
---
--- Whether the engine wants the answer is a question about the whole surface rather than about one node,
--- so it is put to all of them at once rather than only to the ones a batch happens to be carrying.
function Runtime:rebindScrolls(ops)
    local wanted = self:needsOffset()

    for id, node in pairs(self.byId) do
        if natural.scrolling[node.type] and type(node.props.onScroll) ~= "function" then
            ops[#ops + 1] = { op = "update", id = id, props = { onScroll = wanted or protocol.removed } }
        end
    end
end

--- Scrolls whatever holds the focused node so the keyboard is not covering it.
---
--- A field halfway down a scroll view is behind the keyboard the moment it comes up, and padding the
--- bottom of the page does nothing about it. The engine already knows every frame and which node has
--- focus, so it works out how far short the field falls and asks the surface holding it to move.
function Runtime:reveal()
    local id = self.focused

    if id == nil or self.environment.keyboard <= 0 or self.size == nil or self.frames == nil then
        return
    end

    local frame = self.frames[id]
    local surface = self:scrollerOf(self.byId[id])

    if frame == nil or surface == nil then
        return
    end

    -- A cell's frame is in the content the surface scrolls over, so where it lands on screen is the
    -- surface's own position plus how far down the content it sits, less how far the surface is scrolled.
    local clear = self.size.height - self.environment.keyboard
    local target = surface.top + surface.content + frame.height + MARGIN - clear

    -- A surface is never asked to go further than its own content reaches. Pushed past it, a screen with
    -- nothing to scroll is thrown off the top of itself and stays there, since there is no row below to
    -- come back from — which is what every field screen did the moment the keyboard came up.
    local held = self.frames[surface.id]
    local extent = self.extents[surface.id]

    if extent ~= nil and held ~= nil then
        target = math.min(target, math.max(0, extent - held.height))
    end

    if target <= (self.offsets[surface.id] or 0) then
        return
    end

    self.offsets[surface.id] = target

    -- A reveal runs at the end of a commit, and what it asks of is a node the batch has just touched:
    -- a surface whose type changed under it refuses the call, and a refusal here would take the commit
    -- with it rather than leaving a field unlifted.
    local ok, problem = pcall(function()
        self.renderer:invoke(surface.id, "scrollTo", { x = 0, y = target, animated = true })
    end)

    if not ok then
        self:report("a field could not be lifted clear of the keyboard: " .. tostring(problem))
    end
end

--- Asks for the focused field to be lifted clear of the keyboard once the next commit has landed.
---
--- The room the keyboard needs is made by the layout, so a reveal worked out before that commit is one
--- worked out against a surface that has not been given the room yet.
function Runtime:askReveal()
    self.revealing = true
    self:schedule()
end

--- Answers the scrolling host a node sits inside, how far down its content it sits, and where it is.
function Runtime:scrollerOf(node)
    local content = 0
    local walk = node

    while walk ~= nil do
        local parent = walk.parentNode

        while parent ~= nil and parent.kind ~= "host" do
            parent = parent.parentNode
        end

        if parent == nil then
            return nil
        end

        local frame = self.frames[walk.id]

        if frame ~= nil then
            content = content + frame.y
        end

        if natural.scrolling[parent.type] then
            return { id = parent.id, content = content, top = self:screenTop(parent) }
        end

        walk = parent
    end

    return nil
end

end
