local gui = require("gui")

--- A chat: an inbox of conversations and the conversation itself, drawn the way a product draws them.
---
--- The header is a run of colour rather than a flat bar, the bubbles come from either side, the other
--- person answers after a moment with three dots while they do, and the composer sits over the messages
--- on the material the platform draws behind a bar.
local PEOPLE = {
    {
        key = "daniel",
        name = "Daniel William",
        face = "https://picsum.photos/id/1005/200/200",
        status = "Active now",
        online = true,
        when = "3 min ago",
        unread = 2,
        said = "Let me know if you need help",
        history = {
            { key = "d1", mine = true, text = "Hey Daniel", at = "09:02" },
            { key = "d2", mine = false, text = "Hi Ahmad", at = "09:03" },
            { key = "d3", mine = false, text = "Let me know if you need help", at = "09:03" },
        },
        replies = { "Of course, one moment", "Sending it over now", "Done — anything else?" },
    },
    {
        key = "agus",
        name = "Agus Barber",
        face = "https://picsum.photos/id/1012/200/200",
        status = "Active 5 minutes ago",
        online = true,
        when = "09:05",
        unread = 1,
        said = "Yeah, I can help you",
        history = {
            { key = "a1", mine = false, text = "Yeah, I can help you", at = "09:05" },
        },
        replies = { "Tomorrow at four?", "Booked you in" },
    },
    {
        key = "andrew",
        name = "Andrew Raymond",
        face = "https://picsum.photos/id/1027/200/200",
        status = "Active yesterday",
        online = false,
        when = "Yesterday",
        unread = 0,
        said = "Thanks very much",
        history = {
            { key = "r1", mine = true, text = "That worked, thank you", at = "18:20" },
            { key = "r2", mine = false, text = "Thanks very much", at = "18:24" },
        },
        replies = { "Any time" },
    },
    {
        key = "bos",
        name = "Bos Paxi Barber",
        face = "https://picsum.photos/id/1074/200/200",
        status = "Active on Tuesday",
        online = false,
        when = "Aug 10",
        unread = 0,
        said = "Recommended barberman",
        history = {
            { key = "b1", mine = false, text = "Recommended barberman", at = "11:40" },
        },
        replies = { "He is the best in town" },
    },
    {
        key = "peter",
        name = "Peter Andrew",
        face = "https://picsum.photos/id/1062/200/200",
        status = "Active last week",
        online = false,
        when = "May 12",
        unread = 0,
        said = "Recommended, thanks",
        history = {
            { key = "p1", mine = false, text = "Recommended, thanks", at = "16:02" },
        },
        replies = { "Glad it helped" },
    },
}

local HEADER = { "primary", "#7C6BF2" }

--- What the inbox stands on, which is where a reader expects the rest of an application to be.
local PLACES = {
    { key = "discover", label = "Discover", icon = "compass" },
    { key = "nearby", label = "Nearby", icon = "pin" },
    { key = "inbox", label = "Inbox", icon = "message" },
    { key = "saved", label = "Bookmark", icon = "bookmark" },
    { key = "profile", label = "Profile", icon = "user" },
}

--- The three dots that say somebody is writing, which pulse rather than sit there.
local Typing = gui.component({
    name = "ChatTyping",
    state = { phase = 1 },

    onMount = function(self)
        self:every(320, function() self:setState({ phase = self.state.phase % 3 + 1 }) end)
    end,

    render = function(self)
        local dots = {}

        for index = 1, 3 do
            dots[index] = gui.View {
                key = "dot:" .. index,
                style = {
                    width = 7, height = 7, radius = "pill", background = "textMuted",
                    opacity = index == self.state.phase and 1 or 0.35,
                },
                transition = { duration = 220 },
            }
        end

        return gui.View {
            style = { direction = "row", align = "center", gap = 5, alignSelf = "start",
                background = "surface", radius = "pill", paddingHorizontal = 14, paddingVertical = 10 },
            table.unpack(dots),
        }
    end,
})

--- One conversation in the inbox, with the face, what was said last and what is waiting.
local Conversation = gui.component({
    name = "ChatConversation",

    render = function(self)
        local person = self.props.person

        return gui.Pressable {
            style = { direction = "row", align = "center", gap = "md", paddingHorizontal = "md",
                paddingVertical = 12, background = "background" },
            accessibilityLabel = person.name,
            onPress = self.props.onOpen,

            gui.View { style = { width = 52, height = 52 },
                gui.Avatar { source = person.face, size = 52, shape = "circle" },

                person.online and gui.View {
                    key = "online",
                    style = { position = "absolute", right = 0, bottom = 2, width = 14, height = 14,
                        radius = "pill", background = "success", border = 2, borderColor = "background" },
                } or false,
            },

            gui.View { style = { grow = 1, gap = 3 },
                gui.Text { text = person.name, numberOfLines = 1,
                    style = { fontWeight = "700", fontSize = "body" } },
                gui.Text { text = person.said, numberOfLines = 1,
                    style = { color = "textMuted", fontSize = "footnote" } },
            },

            gui.View { style = { align = "end", gap = 6 },
                gui.Text { text = person.when, style = { fontSize = "caption", color = "textMuted" } },
                self.props.unread > 0 and gui.Badge { key = "unread", value = self.props.unread } or false,
            },
        }
    end,
})

local Chat = gui.component({
    name = "Chat",
    state = { open = nil, said = {}, draft = "", typing = false, place = "inbox", read = {} },

    --- Answers the person a key names, which is what the open conversation is.
    person = function(self, key)
        for index = 1, #PEOPLE do
            if PEOPLE[index].key == key then
                return PEOPLE[index]
            end
        end

        return nil
    end,

    --- Answers every message in a conversation, which is what it opened with plus what was said since.
    messages = function(self, person)
        local said = {}

        for index = 1, #person.history do
            said[index] = person.history[index]
        end

        for _, message in ipairs(self.state.said[person.key] or {}) do
            said[#said + 1] = message
        end

        return said
    end,

    open = function(self, person)
        local read = {}

        for key in pairs(self.state.read) do
            read[key] = true
        end

        read[person.key] = true
        self:setState({ open = person.key, draft = "", read = read })
    end,

    --- Answers how much is waiting in a conversation, which is nothing once it has been read.
    waiting = function(self, person)
        if self.state.read[person.key] then
            return 0
        end

        return person.unread
    end,

    send = function(self)
        local text = (self.state.draft or ""):match("^%s*(.-)%s*$")
        local person = self:person(self.state.open)

        if text == "" or person == nil then
            return
        end

        local said = {}

        for key, list in pairs(self.state.said) do
            said[key] = list
        end

        local mine = {}

        for _, message in ipairs(said[person.key] or {}) do
            mine[#mine + 1] = message
        end

        mine[#mine + 1] = { key = "mine:" .. #mine .. ":" .. text, mine = true, text = text, at = "now" }
        said[person.key] = mine

        self:setState({ said = said, draft = "", typing = true })
        self:after(900, function() self:answer(person) end)
    end,

    --- The other side answers, which is what makes the screen feel like a conversation.
    answer = function(self, person)
        local said = {}

        for key, list in pairs(self.state.said) do
            said[key] = list
        end

        local held = {}

        for _, message in ipairs(said[person.key] or {}) do
            held[#held + 1] = message
        end

        local reply = person.replies[(#held % #person.replies) + 1]

        held[#held + 1] = { key = "theirs:" .. #held, mine = false, text = reply, at = "now" }
        said[person.key] = held

        self:setState({ said = said, typing = false })
    end,

    Bubble = function(self, message, person)
        local mine = message.mine

        return gui.View {
            key = message.key,
            style = { direction = "row", justify = mine and "end" or "start", gap = "sm" },
            enter = { opacity = 0, transform = { translateY = 14 } },
            transition = { duration = 260, easing = "easeOut" },

            not mine and gui.Avatar { key = "face", source = person.face, size = 28, shape = "circle" } or false,

            gui.View {
                key = "text",
                style = { maxWidth = "72%", radius = "lg", paddingHorizontal = 14, paddingVertical = 10,
                    background = mine and "primary" or "surface" },
                gui.Text {
                    text = message.text,
                    style = { color = mine and "onPrimary" or "text", fontSize = "body" },
                },
            },
        }
    end,

    Inbox = function(self)
        local rows = {}

        for index = 1, #PEOPLE do
            local person = PEOPLE[index]

            rows[index] = gui.View { key = person.key,
                Conversation {
                    person = person,
                    unread = self:waiting(person),
                    onOpen = function() self:open(person) end,
                },
                index < #PEOPLE and gui.Divider { key = "line", inset = 80 } or false,
            }
        end

        local waiting = 0

        for index = 1, #PEOPLE do
            waiting = waiting + self:waiting(PEOPLE[index])
        end

        return gui.View { style = { grow = 1, background = "background" },
            gui.Gradient {
                colors = HEADER,
                direction = "diagonal",
                style = { paddingTop = 56, paddingBottom = 28, paddingHorizontal = "md",
                    radius = 28, gap = 6 },

                gui.View { style = { direction = "row", align = "center" },
                    gui.Text { text = "Inbox",
                        style = { grow = 1, fontSize = "heading", fontWeight = "700", color = "onPrimary" } },
                    gui.Pressable {
                        accessibilityLabel = "Search",
                        style = { width = 44, height = 44, radius = "pill", align = "center", justify = "center",
                            background = "#FFFFFF33" },
                        onPress = function() end,
                        gui.Icon { name = "search", size = 20, color = "onPrimary" },
                    },
                },

                gui.Text {
                    text = waiting == 0 and "You are all caught up"
                        or ("You have " .. waiting .. " unread messages"),
                    style = { color = "#FFFFFFCC", fontSize = "footnote" },
                },
            },

            gui.ScrollView { style = { grow = 1 }, contentStyle = { paddingBottom = 96 },
                table.unpack(rows),
            },

            self:Places(),
        }
    end,

    --- The bar the inbox stands on, drawn on the material the platform puts behind one.
    Places = function(self)
        local items = {}

        for index = 1, #PLACES do
            local place = PLACES[index]
            local here = place.key == self.state.place

            items[index] = gui.Pressable {
                key = place.key,
                style = { grow = 1, basis = 0, align = "center", justify = "center", gap = 3, height = 56 },
                accessibilityLabel = place.label,
                onPress = function() self:setState({ place = place.key }) end,

                gui.Icon { name = place.icon, size = 20, color = here and "primary" or "textMuted" },
                gui.Text {
                    text = place.label,
                    style = { fontSize = "caption", fontWeight = "600",
                        color = here and "primary" or "textMuted" },
                },
            }
        end

        return gui.Blur {
            key = "places",
            intensity = 0.92,
            tint = "background",
            style = { position = "absolute", left = 0, right = 0, bottom = 0, direction = "row",
                paddingBottom = 6 },
            table.unpack(items),
        }
    end,

    Talk = function(self, person)
        local said = self:messages(person)

        -- Everything the conversation shows is one list, since a table unpacked anywhere but last is
        -- cut to its first value: the screen showed one bubble and nothing after it.
        local shown = { gui.Text { key = "day", text = "Today",
            style = { alignSelf = "center", fontSize = "caption", color = "textMuted" } } }

        for index = 1, #said do
            shown[#shown + 1] = self:Bubble(said[index], person)
        end

        if self.state.typing then
            shown[#shown + 1] = gui.View { key = "typing", style = { direction = "row", gap = "sm" },
                gui.Avatar { source = person.face, size = 28, shape = "circle" },
                Typing {},
            }
        end

        -- The composer is the last row rather than a panel over the messages, so the keyboard lifts it
        -- rather than covering it.
        return gui.KeyboardAvoiding { style = { grow = 1, background = "background" },
            gui.Gradient {
                colors = HEADER,
                direction = "right",
                style = { paddingTop = 52, paddingBottom = 14, paddingHorizontal = "sm",
                    direction = "row", align = "center", gap = "sm", radius = 24 },

                gui.Pressable {
                    accessibilityLabel = "Back to the inbox",
                    style = { width = 44, height = 44, align = "center", justify = "center" },
                    onPress = function() self:setState({ open = gui.none, typing = false }) end,
                    gui.Icon { name = "arrow-left", size = 20, color = "onPrimary" },
                },

                gui.Avatar { source = person.face, size = 40, shape = "circle" },

                gui.View { style = { grow = 1, gap = 1 },
                    gui.Text { text = person.name, numberOfLines = 1,
                        style = { fontWeight = "700", color = "onPrimary" } },
                    gui.Text { text = person.status,
                        style = { fontSize = "caption", color = "#FFFFFFCC" } },
                },

                gui.Pressable {
                    accessibilityLabel = "More",
                    style = { width = 44, height = 44, align = "center", justify = "center" },
                    onPress = function() end,
                    gui.Icon { name = "more-vertical", size = 20, color = "onPrimary" },
                },
            },

            gui.ScrollView {
                style = { grow = 1 },
                contentStyle = { padding = "md", gap = 10 },
                keyboardDismissMode = "on-drag",

                table.unpack(shown),
            },

            gui.Blur {
                intensity = 0.9,
                tint = "background",
                style = { paddingHorizontal = "md", paddingVertical = 12, direction = "row",
                    align = "center", gap = "sm" },

                gui.TextInput {
                    value = self.state.draft,
                    placeholder = "Write a message",
                    returnKey = "send",
                    style = { grow = 1, background = "surface", radius = "pill",
                        paddingHorizontal = 16, height = 44 },
                    onChange = function(value) self:setState({ draft = value }) end,
                    onSubmit = function() self:send() end,
                },

                gui.Pressable {
                    accessibilityLabel = "Send",
                    style = { width = 44, height = 44, radius = "pill", background = "primary",
                        align = "center", justify = "center" },
                    onPress = function() self:send() end,
                    gui.Icon { name = "send", size = 18, color = "onPrimary" },
                },
            },
        }
    end,

    render = function(self)
        local person = self:person(self.state.open)
        local screens = { { key = "inbox", title = "Inbox", content = self:Inbox() } }

        if person ~= nil then
            screens[2] = { key = "talk:" .. person.key, title = person.name, content = self:Talk(person) }
        end

        return gui.NavigationStack {
            style = { grow = 1 },
            hidesBar = true,
            index = #screens,
            screens = screens,
            onPop = function() self:setState({ open = gui.none, typing = false }) end,
        }
    end,
})

return Chat
