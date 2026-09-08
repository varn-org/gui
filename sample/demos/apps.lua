local Chat = require("apps.chat")
local Podcasts = require("apps.podcasts")
local Settings = require("apps.settings")
local Shop = require("apps.shop")

--- Whole applications rather than components, which is what the components are for.
---
--- Each one is several screens, holds its own state, navigates, animates and behaves around the
--- keyboard. They are here to be judged as applications, not as a list of what the library carries.
return {
    { key = "shop", title = "A shop", summary = "A window, a product, a bag and a checkout",
        render = function() return Shop {} end, chrome = false },
    { key = "podcasts", title = "A podcast player", summary = "Shows, search, favourites and a player",
        render = function() return Podcasts {} end, chrome = false },
    { key = "settings", title = "An account", summary = "Grouped rows, a profile and a confirmation",
        render = function() return Settings {} end, chrome = false },
    { key = "chat", title = "A chat", summary = "An inbox, a conversation and somebody answering",
        render = function() return Chat {} end, chrome = false },
}
