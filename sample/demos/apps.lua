local Bazaar = require("apps.bazaar")
local Chat = require("apps.chat")
local Hail = require("apps.hail")
local Lull = require("apps.lull")
local Mail = require("apps.mail")
local Plate = require("apps.plate")
local Podcasts = require("apps.podcasts")
local Settings = require("apps.settings")
local Shop = require("apps.shop")
local Sprig = require("apps.sprig")
local Weather = require("apps.weather")

--- Whole applications rather than components, which is what the components are for.
---
--- Each one is several screens, holds its own state, navigates, animates and behaves around the
--- keyboard. They are here to be judged as applications, not as a list of what the library carries.
---
--- The last five go further: each is built to read as a kind of application a reader already has on
--- their phone, down to the density, the proportions and the order things come in. None carries a real
--- name or a real mark, each wears a look of its own through `gui.Look`, and every picture in them is
--- drawn by `tools/draw-scenes.py` rather than fetched.
return {
    { key = "shop", title = "A shop", summary = "A window, a product, a bag and a checkout",
        render = function() return Shop {} end, chrome = false },
    { key = "podcasts", title = "A podcast player", summary = "Categories, shows and a path with no end",
        render = function() return Podcasts {} end, chrome = false },
    { key = "settings", title = "An account", summary = "Grouped rows, a profile and a confirmation",
        render = function() return Settings {} end, chrome = false },
    { key = "chat", title = "A chat", summary = "An inbox, a conversation and somebody answering",
        render = function() return Chat {} end, chrome = false },
    { key = "mail", title = "An inbox", summary = "Rows, a search, a filter, a message and a swipe",
        render = function() return Mail {} end, chrome = false },
    { key = "weather", title = "The weather", summary = "A hero, the hours beside it and the week under them",
        render = function() return Weather {} end, chrome = false },

    { key = "plate", title = "Food delivery", summary = "An address, a place, a dish and a bag",
        render = function() return Plate {} end, chrome = false,
        screens = {
            { press = "Grill House", as = "place" },
            { press = "Double smash", as = "dish" },
            { press = "Add R$ 38,90", as = "bag" },
            { press = "Place the order", as = "ordered" },
        },
    },
    { key = "hail", title = "Ride hailing", summary = "A drawn map, a route, a car and a driver",
        render = function() return Hail {} end, chrome = false,
        screens = {
            { press = "Work", as = "ride" },
            { press = "Book Hail Go", as = "trip" },
        },
    },
    { key = "bazaar", title = "A marketplace", summary = "Deals, a product, a search and a basket",
        render = function() return Bazaar {} end, chrome = false,
        screens = {
            { press = "Smartphone Aurora 12 256 GB 8 GB RAM, unlocked, dual chip", as = "product" },
            { press = "Buy now", as = "basket" },
        },
    },
    { key = "sprig", title = "Messaging", summary = "Conversations, bubbles, status and calls",
        render = function() return Sprig {} end, chrome = false,
        screens = {
            { press = "Ana Ribeiro", as = "conversation" },
        },
    },
    { key = "lull", title = "An audiobook player", summary = "Shelves, a book, chapters and a player",
        render = function() return Lull {} end, chrome = false,
        screens = {
            { press = "The Turning Tide", as = "book" },
            { press = "Continue", as = "player" },
        },
    },
}
