local routing = require("gui.routing")

-- An address is read the same whether it arrived as a link, an app link or a path in a browser.
do
    local deep = routing.parse("varn://items/3?open=yes")

    assert(deep.scheme == "varn", "a deep link carries the scheme it arrived through")
    assert(deep.host == nil, "a scheme of an application's own names no machine")
    assert(deep.path == "/items/3", "so all of it is the path, which is what the same routes answer")
    assert(deep.query.open == "yes", "and what it was asked with")

    local app = routing.parse("https://varn.dev/items/3")

    assert(app.scheme == "https" and app.host == "varn.dev", "an app link carries where it came from")
    assert(app.path == "/items/3", "and the path it named")

    local web = routing.parse("/items/3?q=a%20b&flag")

    assert(web.scheme == nil and web.host == nil, "a plain path came from nowhere in particular")
    assert(web.path == "/items/3", "and is the path itself")
    assert(web.query.q == "a b", "what was escaped is read back as what it stood for")
    assert(web.query.flag == "", "and a flag with no value is there with none")
end

-- A path is the same path however it was written.
do
    assert(routing.parse("").path == "/", "nothing at all is the root")
    assert(routing.parse("/").path == "/", "and so is a slash")
    assert(routing.parse("items").path == "/items", "a path without a leading slash is one with it")
    assert(routing.parse("/items/").path == "/items", "and a trailing slash is not a different screen")
end

-- A pattern takes what stands in its place, and refuses what does not match.
do
    assert(routing.match("/items", "/items") ~= nil, "a plain path matches itself")
    assert(routing.match("/items", "/other") == nil, "and nothing else")
    assert(routing.match("/items", "/items/3") == nil, "a deeper path is a different screen")
    assert(routing.match("/items/:id", "/items") == nil, "and a shallower one is too")

    local params = routing.match("/items/:id/edit", "/items/42/edit")

    assert(params ~= nil and params.id == "42", "a named segment answers what stood there")

    local rest = routing.match("/files/*path", "/files/a/b/c.txt")

    assert(rest ~= nil and rest.path == "a/b/c.txt", "what is left over is answered whole")

    local root = routing.match("/*", "/anything/at/all")

    assert(root ~= nil and root.rest == "anything/at/all", "a pattern with nothing named answers the rest")
end

-- The first route that matches wins, so a specific path is written above the pattern that would take it.
do
    local routes = {
        { path = "/items/new" },
        { path = "/items/:id" },
        { path = "/*" },
    }

    local route, params = routing.resolve(routes, "/items/new")
    assert(route.path == "/items/new", "the specific route wins where it matches")

    route, params = routing.resolve(routes, "/items/7")
    assert(route.path == "/items/:id" and params.id == "7", "and the pattern takes the rest")

    route = routing.resolve(routes, "/somewhere/else")
    assert(route.path == "/*", "and what nothing else matches lands on what takes everything")

    local none, _, parsed = routing.resolve({ { path = "/items" } }, "/nowhere")
    assert(none == nil, "an address nothing matches lands on no route at all")
    assert(parsed.path == "/nowhere", "and is still read, so a screen can say what was asked for")
end

print("gui.routing ok")
