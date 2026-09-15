local M = {}

--- What an address is made of, which is the same on a phone, in a browser and behind a deep link.
---
--- A deep link is `scheme://host/path?query`, an app link is `https://host/path?query` and a web address
--- is `/path?query`. What a screen is chosen by is the path and the query, so the scheme and the host are
--- read off and kept rather than matched on: an application that wants to know which link it arrived
--- through reads them, and everything else is spared the difference.
function M.parse(address)
    if type(address) ~= "string" then
        error("an address is a string, got a " .. type(address), 2)
    end

    local scheme, rest = address:match("^(%a[%w+.-]*)://(.*)$")
    local host = nil

    if rest ~= nil then
        local authority
        authority, rest = rest:match("^([^/?#]*)(.*)$")

        -- A scheme of an application's own has no host to speak of: `varn://items/3` names the item, not
        -- a machine called items. The web's own schemes do have one, which is what makes an app link and
        -- the address a browser is at the same address, so the same routes answer all three.
        if scheme == "http" or scheme == "https" then
            host = authority
        else
            rest = "/" .. authority .. rest
        end
    else
        rest = address
    end

    local path, query = rest:match("^([^?#]*)%??([^#]*)")

    if path == nil or path == "" then
        path = "/"
    end

    if path:sub(1, 1) ~= "/" then
        path = "/" .. path
    end

    -- A path is the same path whether or not it was written with a slash at the end, or half the links
    -- an application is given land nowhere at all.
    if #path > 1 and path:sub(-1) == "/" then
        path = path:sub(1, -2)
    end

    return {
        scheme = scheme,
        host = host ~= "" and host or nil,
        path = path,
        query = M.query(query or ""),
    }
end

--- Answers what an escaped run of text stood for, which is what a link carries a space or an accent as.
local function unescape(text)
    local read = tostring(text):gsub("+", " ")
    read = read:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    return read
end

--- Answers the pairs a query string carries, with what was escaped read back as what it stood for.
function M.query(text)
    local found = {}

    for pair in tostring(text):gmatch("[^&]+") do
        local name, value = pair:match("^([^=]*)=?(.*)$")

        if name ~= nil and name ~= "" then
            found[unescape(name)] = unescape(value)
        end
    end

    return found
end

--- Answers the segments a path is made of, which is what one is matched against another by.
local function segments(path)
    local found = {}

    for segment in tostring(path):gmatch("[^/]+") do
        found[#found + 1] = segment
    end

    return found
end

--- Answers what a pattern takes out of a path, or nothing at all when the path is not one it matches.
---
--- A segment written `:name` takes whatever is in that place and answers it under that name, and one
--- written `*name` takes everything left, which is what a file path inside an address is. Anything else
--- matches itself and nothing else.
function M.match(pattern, path)
    local wanted = segments(pattern)
    local given = segments(path)
    local params = {}

    for index = 1, #wanted do
        local segment = wanted[index]
        local rest = segment:match("^%*(.*)$")

        if rest ~= nil then
            local tail = {}

            for at = index, #given do
                tail[#tail + 1] = given[at]
            end

            params[rest ~= "" and rest or "rest"] = table.concat(tail, "/")
            return params
        end

        if given[index] == nil then
            return nil
        end

        local name = segment:match("^:(.+)$")

        if name ~= nil then
            params[name] = unescape(given[index])
        elseif segment ~= given[index] then
            return nil
        end
    end

    if #given > #wanted then
        return nil
    end

    return params
end

--- Answers the route an address lands on, and what that route takes out of it.
---
--- The first route that matches wins, so a list is read in the order it was written and a specific path
--- is written above the pattern that would also take it.
function M.resolve(routes, address)
    local parsed = M.parse(address)

    for index = 1, #routes do
        local route = routes[index]

        if type(route.path) ~= "string" then
            error("a route names the path it answers, got a " .. type(route.path), 2)
        end

        local params = M.match(route.path, parsed.path)

        if params ~= nil then
            return route, params, parsed
        end
    end

    return nil, nil, parsed
end

return M
