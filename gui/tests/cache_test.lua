local cache = require("gui.tools.cache")

-- What was stored is answered, and what was never stored is not.
do
    local store = cache.create(8)

    store:set("one", 1)
    store:set("two", 2)

    assert(store:get("one") == 1, "a stored value is answered")
    assert(store:get("two") == 2, "each under its own key")
    assert(store:get("three") == nil, "and a key nothing was stored under answers nothing")
end

-- The store stays inside the bound it was built with, however much is put in it.
--
-- Everything keyed by something an application produces over and over — a clock's text, the bytes of a
-- picture — grows for as long as the process runs, and a screen drawn for an hour is not a reason to
-- have kept every string it ever showed.
do
    local store = cache.create(64)

    for index = 1, 10000 do
        store:set("entry " .. index, index)
    end

    assert(store:held() <= 64, "a store of sixty-four holds no more than that, holds " .. store:held())
    assert(store:get("entry 10000") == 10000, "and what was just stored is still there")
end

-- What is asked for on the way is carried across the generation that retires the rest.
do
    local store = cache.create(8)

    store:set("kept", "here")

    for index = 1, 200 do
        store:set("passing " .. index, index)
        assert(store:get("kept") == "here", "what is asked for at every turn is never given up")
    end
end

-- What is never asked for is given up, which is the whole point of a bound.
do
    local store = cache.create(8)

    store:set("cold", true)

    for index = 1, 200 do
        store:set("passing " .. index, index)
    end

    assert(store:get("cold") == nil, "what nothing asked for again is gone")
end

-- Emptying it leaves nothing behind, which is what registering a font does to the measurements.
do
    local store = cache.create(8)

    store:set("one", 1)
    store:clear()

    assert(store:get("one") == nil, "what was cleared is gone")
    assert(store:held() == 0, "and the store says it holds nothing, says " .. store:held())
end

-- A store is asked for far more than it holds without the cost of a turn growing with what is in it.
--
-- Walking every entry to find the coldest one costs 23 microseconds at five hundred of them, which is a
-- millisecond of every frame of a scroll that measures fifty new strings. The store is on the path that
-- draws, so what a turn costs cannot grow with what has been drawn.
do
    local store = cache.create(512)
    local started = os.clock()

    for index = 1, 20000 do
        store:set("fresh " .. index, index)
    end

    local each = (os.clock() - started) * 1000000 / 20000

    assert(each < 5, "a store past its bound costs microseconds a turn, costs " .. string.format("%.1f", each))
end

print("gui.cache ok")
