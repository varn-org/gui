local fs = require("fs")

local M = {}

local root = nil

--- Records where the application may write, which only the host that launched it knows.
function M.use(path)
    root = path
    fs.mkdir(path)
end

--- Answers a directory the application may write to, made if it is not there yet.
---
--- A screen has nowhere else to put anything. A path relative to the working directory is written
--- wherever the process happens to have been started, which on a phone is not writable at all, so a
--- picked file written that way succeeds on a desktop and fails on the device it was written for.
function M.directory(name)
    if root == nil then
        error("the application has not been told where it may write", 2)
    end

    if type(name) ~= "string" or name == "" or name:find("[/\\]") ~= nil then
        error("a directory is named, not pathed, got " .. tostring(name), 2)
    end

    local path = root .. "/" .. name

    fs.mkdir(path)
    return path
end

return M
