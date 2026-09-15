local M = {}

--- The rules every framework ships, written once so no screen writes them again.
---
--- A validator is a function of the value and of everything else the form holds, answering what is wrong
--- with it or nothing at all when it is fine. A caller's own function is a validator like any other, so
--- a rule nobody here thought of is written where it is needed rather than asked for.
---
--- Nothing but `required` refuses an empty value: a field somebody left alone is empty rather than wrong,
--- and reporting it as wrong before they have reached it is a form that shouts at a reader for opening it.

--- Answers whether a value is what a reader has not written anything into.
local function blank(value)
    return value == nil or value == "" or value == false
end

--- Answers a value as text, which is what a length, a pattern and a comparison are asked about.
local function written(value)
    if value == nil then
        return ""
    end

    return tostring(value)
end

--- Answers a value as a number, or nothing when it is not one.
local function numeric(value)
    if type(value) == "number" then
        return value
    end

    if type(value) ~= "string" then
        return nil
    end

    return tonumber(value)
end

--- Refuses a field a reader left empty, which is the one rule that looks at an empty value at all.
function M.required(message)
    return function(value)
        if blank(value) then
            return message or "This is needed"
        end

        return nil
    end
end

function M.minLength(least, message)
    return function(value)
        if blank(value) or #written(value) >= least then
            return nil
        end

        return message or ("At least " .. least .. " characters")
    end
end

function M.maxLength(most, message)
    return function(value)
        if blank(value) or #written(value) <= most then
            return nil
        end

        return message or ("At most " .. most .. " characters")
    end
end

function M.length(least, most, message)
    return function(value)
        if blank(value) then
            return nil
        end

        local size = #written(value)

        if size >= least and size <= most then
            return nil
        end

        return message or ("Between " .. least .. " and " .. most .. " characters")
    end
end

--- Refuses a value that does not match a Lua pattern, which is what a code or a reference is held to.
function M.pattern(shape, message)
    return function(value)
        if blank(value) or written(value):match(shape) ~= nil then
            return nil
        end

        return message or "This is not in the right shape"
    end
end

--- Refuses an address nothing could be sent to.
---
--- What is checked is the shape rather than whether anybody is there, since only sending to it answers
--- the second question. A single at sign, something either side of it, and a dot in what follows.
function M.email(message)
    return function(value)
        if blank(value) then
            return nil
        end

        local text = written(value)
        local name, host = text:match("^([^@%s]+)@([^@%s]+)$")

        if name ~= nil and host:match("^[%w%-%.]+%.[%a][%a]+$") ~= nil then
            return nil
        end

        return message or "This is not an email address"
    end
end

--- Refuses an address that names no scheme or no host.
function M.url(message)
    return function(value)
        if blank(value) or written(value):match("^%a[%w+%-%.]*://[^%s]+$") ~= nil then
            return nil
        end

        return message or "This is not an address"
    end
end

function M.number(message)
    return function(value)
        if blank(value) or numeric(value) ~= nil then
            return nil
        end

        return message or "This is not a number"
    end
end

function M.integer(message)
    return function(value)
        if blank(value) then
            return nil
        end

        local held = numeric(value)

        if held ~= nil and held % 1 == 0 then
            return nil
        end

        return message or "This is not a whole number"
    end
end

function M.min(least, message)
    return function(value)
        if blank(value) then
            return nil
        end

        local held = numeric(value)

        if held ~= nil and held >= least then
            return nil
        end

        return message or ("At least " .. least)
    end
end

function M.max(most, message)
    return function(value)
        if blank(value) then
            return nil
        end

        local held = numeric(value)

        if held ~= nil and held <= most then
            return nil
        end

        return message or ("At most " .. most)
    end
end

function M.range(least, most, message)
    return function(value)
        if blank(value) then
            return nil
        end

        local held = numeric(value)

        if held ~= nil and held >= least and held <= most then
            return nil
        end

        return message or ("Between " .. least .. " and " .. most)
    end
end

--- Refuses anything outside a set, which is what a code, a country or a plan is held to.
function M.oneOf(choices, message)
    return function(value)
        if blank(value) then
            return nil
        end

        for index = 1, #choices do
            if choices[index] == value then
                return nil
            end
        end

        return message or "This is not one of the choices"
    end
end

--- Refuses a value that differs from another field's, which is what a repeated password is.
function M.matches(name, message)
    return function(value, values)
        if value == values[name] then
            return nil
        end

        return message or "These do not match"
    end
end

--- Refuses a value a reader has to agree to and has not, which is what a checkbox on a form is.
function M.accepted(message)
    return function(value)
        if value == true then
            return nil
        end

        return message or "This has to be agreed to"
    end
end

--- Answers what is wrong with a value against a list of rules, which is the first thing that is.
---
--- The first is what is reported rather than all of them, since a field with three messages under it is
--- a field a reader reads none of.
function M.check(rules, value, values)
    for index = 1, #(rules or {}) do
        local rule = rules[index]

        if type(rule) ~= "function" then
            error("a rule is a function of the value, got a " .. type(rule), 0)
        end

        local wrong = rule(value, values or {})

        if wrong ~= nil then
            return wrong
        end
    end

    return nil
end

return M
