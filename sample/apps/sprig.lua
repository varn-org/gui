local gui = require("gui")

--- A messaging application, which is the one screen everybody already knows by heart.
---
--- Every header here is drawn rather than the platform's, because that is what makes one of these read
--- as itself: a green band running to the top of the glass, the tabs inside it, and in a conversation an
--- avatar, a name, a line saying when somebody was last here and two marks on the right. A platform bar
--- over any of that would be a second bar, so each screen says it draws its own.
local LOOK = gui.theme.define({
    name = "sprig",
    radii = { sm = 6, md = 8, lg = 14, pill = 999 },
    spacing = { xs = 4, sm = 8, md = 14, lg = 20, xl = 28 },
    light = {
        colors = {
            primary = "#00a884", onPrimary = "#ffffff", background = "#ffffff", surface = "#f0f2f5",
            elevated = "#ffffff", text = "#111b21", textMuted = "#667781", border = "#e9edef",
            separator = "#0000000f", success = "#00a884", warning = "#e8a33d", danger = "#ea0038",
        },
    },
    dark = {
        colors = {
            primary = "#00a884", onPrimary = "#062d26", background = "#0b141a", surface = "#202c33",
            elevated = "#111b21", text = "#e9edef", textMuted = "#8696a0", border = "#2a3942",
            separator = "#ffffff12", success = "#00a884", warning = "#f0bf6b", danger = "#f15c6d",
        },
    },
})

--- The band across the top, which is one colour whichever side of the look the device is on.
local BAND = "#008069"
local ONBAND = "#ffffff"

--- What sits behind the bubbles, drawn rather than carried as a picture.
---
--- The wallpaper of one of these is a pale ground with a scatter of small marks on it. A photograph of
--- one would be a file to ship and a licence to carry, and the thing itself is forty little shapes.
local PAPER = "#efe7dd"
local PAPER_DARK = "#0b141a"
local MARK = "#d9cec2"
local MARK_DARK = "#182229"

local function scatter(width, height, dark)
    local commands = {
        { op = "fill", color = dark and PAPER_DARK or PAPER,
            path = { { 0, 0 }, { width, 0 }, { width, height }, { 0, height } } },
    }

    local ink = dark and MARK_DARK or MARK
    local step = 56
    local at = 0

    for y = 0, height + step, step do
        for x = 0, width + step, step do
            at = at + 1
            local shift = (at % 2 == 0) and step / 2 or 0
            local size = 3 + (at % 3)

            commands[#commands + 1] = {
                op = "stroke",
                color = ink,
                width = 1.5,
                path = {
                    { x + shift - size, y }, { x + shift, y - size },
                    { x + shift + size, y }, { x + shift, y + size }, { x + shift - size, y },
                },
            }
        end
    end

    return commands
end

local Wallpaper = gui.component({
    name = "SprigWallpaper",
    state = { width = 0, height = 0 },

    render = function(self)
        local dark = gui.environment:read(self).appearance == "dark"

        return gui.View {
            style = { position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
                background = dark and PAPER_DARK or PAPER, overflow = "hidden" },
            pointerEvents = "none",
            onLayout = function(frame)
                if frame.width ~= self.state.width or frame.height ~= self.state.height then
                    self:setState({ width = frame.width, height = frame.height })
                end
            end,

            self.state.width > 0 and gui.Canvas {
                key = "paper",
                style = { position = "absolute", top = 0, left = 0,
                    width = self.state.width, height = self.state.height },
                commands = scatter(self.state.width, self.state.height, dark),
            } or false,
        }
    end,
})

local CHATS = {
    {
        key = "ana",
        name = "Ana Ribeiro",
        face = "face-one.png",
        seen = "online",
        time = "14:32",
        unread = 2,
        messages = {
            { key = "a1", mine = false, text = "are you coming tonight?", time = "14:28" },
            { key = "a2", mine = true, text = "yes, leaving in twenty minutes", time = "14:30", read = true },
            { key = "a3", mine = false, text = "bring the speaker if you can", time = "14:31" },
            { key = "a4", mine = false, text = "the small one is fine", time = "14:32" },
        },
    },
    {
        key = "team",
        name = "Friday football",
        face = "face-two.png",
        seen = "last seen today at 13:04",
        time = "13:04",
        unread = 0,
        messages = {
            { key = "t1", mine = false, text = "pitch is booked for seven", time = "12:58" },
            { key = "t2", mine = false, text = "we are nine, need one more", time = "12:59" },
            { key = "t3", mine = true, text = "I will ask Rafa", time = "13:04", read = true },
        },
    },
    {
        key = "mum",
        name = "Mãe",
        face = "face-three.png",
        seen = "last seen today at 11:20",
        time = "11:20",
        unread = 0,
        messages = {
            { key = "m1", mine = false, text = "did you eat?", time = "11:18" },
            { key = "m2", mine = true, text = "yes, twice", time = "11:19", read = true },
            { key = "m3", mine = false, text = "good", time = "11:20" },
        },
    },
    {
        key = "rafa",
        name = "Rafael",
        face = "face-four.png",
        seen = "last seen yesterday at 22:41",
        time = "Yesterday",
        unread = 0,
        messages = {
            { key = "r1", mine = true, text = "sent you the file", time = "22:38", read = true },
            { key = "r2", mine = false, text = "got it, thanks", time = "22:41" },
        },
    },
    {
        key = "building",
        name = "Building 42",
        face = "face-five.png",
        seen = "last seen Monday",
        time = "Monday",
        unread = 5,
        messages = {
            { key = "b1", mine = false, text = "water is off between nine and noon", time = "09:12" },
            { key = "b2", mine = false, text = "the lift is back", time = "16:40" },
        },
    },
    {
        key = "clara",
        name = "Clara",
        face = "face-six.png",
        seen = "last seen Sunday",
        time = "Sunday",
        unread = 0,
        messages = {
            { key = "c1", mine = false, text = "happy birthday!", time = "08:02" },
            { key = "c2", mine = true, text = "thank you", time = "09:30", read = false },
        },
    },
}

local STATUS = {
    { key = "me", name = "My status", line = "Tap to add an update", face = "face-two.png", mine = true },
    { key = "ana", name = "Ana Ribeiro", line = "Today at 12:04", face = "face-one.png" },
    { key = "rafa", name = "Rafael", line = "Today at 09:51", face = "face-four.png" },
    { key = "clara", name = "Clara", line = "Yesterday at 20:12", face = "face-six.png" },
}

local CALLS = {
    { key = "ana", name = "Ana Ribeiro", face = "face-one.png", line = "Today, 13:20", missed = false, video = false },
    { key = "rafa", name = "Rafael", face = "face-four.png", line = "Today, 10:02", missed = true, video = true },
    { key = "mum", name = "Mãe", face = "face-three.png", line = "Yesterday, 19:44", missed = false, video = false },
}

local TABS = { "Chats", "Status", "Calls" }

local function find(key)
    for index = 1, #CHATS do
        if CHATS[index].key == key then
            return CHATS[index]
        end
    end

    return nil
end

local Sprig = gui.component({
    name = "Sprig",
    state = { screen = "list", tab = 1, open = nil, typed = "", sent = {}, search = "" },

    --- Answers a conversation as everything it came with plus whatever was typed into it here.
    messagesOf = function(self, chat)
        local said = {}

        for index = 1, #chat.messages do
            said[index] = chat.messages[index]
        end

        for _, message in ipairs(self.state.sent[chat.key] or {}) do
            said[#said + 1] = message
        end

        return said
    end,

    send = function(self)
        local typed = self.state.typed

        if typed == "" then
            return
        end

        local sent = {}

        for key, said in pairs(self.state.sent) do
            sent[key] = said
        end

        local key = self.state.open
        local mine = {}

        for _, message in ipairs(sent[key] or {}) do
            mine[#mine + 1] = message
        end

        mine[#mine + 1] = {
            key = key .. "-sent-" .. (#mine + 1),
            mine = true,
            text = typed,
            time = "14:40",
            read = false,
        }

        sent[key] = mine
        self:setState({ sent = sent, typed = "" })
    end,

    --- The band, which is the name of the application, three marks, and the tabs under them.
    Band = function(self)
        local insets = gui.environment:read(self).insets
        local marks = {}
        local wanted = { { key = "camera", icon = "camera" }, { key = "search", icon = "search" },
            { key = "more", icon = "more-vertical" } }

        for index = 1, #wanted do
            marks[index] = gui.Pressable {
                key = wanted[index].key,
                style = { width = 44, height = 44, align = "center", justify = "center" },
                accessibilityLabel = wanted[index].key == "more" and "More" or wanted[index].key:gsub("^%l", string.upper),
                onPress = function() self:setState({ tab = wanted[index].key == "camera" and 2 or self.state.tab }) end,

                gui.Icon { name = wanted[index].icon, size = 22, color = ONBAND },
            }
        end

        local tabs = {}

        for index = 1, #TABS do
            local on = index == self.state.tab
            local unread = 0

            if index == 1 then
                for _, chat in ipairs(CHATS) do
                    unread = unread + (chat.unread > 0 and 1 or 0)
                end
            end

            tabs[index] = gui.Pressable {
                key = TABS[index],
                style = { grow = 1, basis = 0, height = 48, align = "center", justify = "center",
                    direction = "row", gap = 6 },
                accessibilityLabel = TABS[index],
                accessibilityState = { selected = on },
                onPress = function() self:setState({ tab = index }) end,

                gui.Text {
                    text = TABS[index]:upper(),
                    style = { color = on and ONBAND or "#ffffffa8", fontWeight = "700",
                        fontSize = "footnote", letterSpacing = 0.5 },
                },

                index == 1 and unread > 0 and gui.View {
                    key = "unread",
                    style = { minWidth = 20, height = 20, radius = 999, background = ONBAND,
                        align = "center", justify = "center", paddingHorizontal = 5 },
                    gui.Text {
                        text = tostring(unread),
                        style = { color = BAND, fontSize = "caption", fontWeight = "700" },
                    },
                } or false,

                on and gui.View {
                    key = "rule",
                    style = { position = "absolute", left = 0, right = 0, bottom = 0, height = 3,
                        background = ONBAND },
                } or false,
            }
        end

        return gui.View { style = { background = BAND, paddingTop = insets.top },
            gui.View { style = { direction = "row", align = "center", height = 56, paddingLeft = "md" },
                gui.Text {
                    text = "Sprig",
                    style = { grow = 1, color = ONBAND, fontSize = "title", fontWeight = "700" },
                },
                table.unpack(marks),
            },

            gui.View { style = { direction = "row" }, table.unpack(tabs) },
        }
    end,

    ChatRow = function(self, chat)
        local said = self:messagesOf(chat)
        local last = said[#said]

        return gui.Pressable {
            style = { grow = 1, direction = "row", align = "center", gap = "sm", paddingLeft = "md" },
            accessibilityLabel = chat.name,
            onPress = function() self:setState({ screen = "chat", open = chat.key }) end,

            gui.Avatar { source = chat.face, size = 50 },

            gui.View { style = { grow = 1, shrink = 1, gap = 3, paddingRight = "md" },
                gui.View { style = { direction = "row", align = "center", gap = "sm" },
                    gui.Text {
                        text = chat.name,
                        numberOfLines = 1,
                        style = { grow = 1, shrink = 1, fontSize = "headline", fontWeight = "500" },
                    },
                    gui.Text {
                        text = chat.time,
                        style = { fontSize = "caption",
                            color = chat.unread > 0 and "primary" or "textMuted" },
                    },
                },

                gui.View { style = { direction = "row", align = "center", gap = 4 },
                    last.mine and gui.Icon {
                        key = "seen",
                        name = "check-double",
                        size = 14,
                        color = last.read and "#53bdeb" or "textMuted",
                    } or false,

                    gui.Text {
                        text = last.text,
                        numberOfLines = 1,
                        style = { grow = 1, shrink = 1, fontSize = "footnote", color = "textMuted" },
                    },

                    chat.unread > 0 and gui.View {
                        key = "count",
                        style = { minWidth = 20, height = 20, radius = 999, background = "primary",
                            align = "center", justify = "center", paddingHorizontal = 6 },
                        gui.Text {
                            text = tostring(chat.unread),
                            style = { color = "onPrimary", fontSize = "caption", fontWeight = "700" },
                        },
                    } or false,
                },
            },
        }
    end,

    Chats = function(self)
        local insets = gui.environment:read(self).insets

        return gui.View { style = { grow = 1 },
            gui.List {
                style = { grow = 1, background = "background" },
                data = CHATS,
                itemExtent = 72,
                keyExtractor = function(chat) return chat.key end,
                separator = gui.Divider { color = "separator", inset = 78 },
                footer = gui.Spacer { size = insets.bottom + 88 },
                footerExtent = insets.bottom + 88,
                renderItem = function(chat) return self:ChatRow(chat) end,
            },

            gui.Pressable {
                style = { position = "absolute", right = 16, bottom = insets.bottom + 16,
                    width = 56, height = 56, radius = "lg", background = "primary",
                    align = "center", justify = "center", shadow = "md" },
                accessibilityLabel = "New conversation",
                onPress = function() self:setState({ screen = "chat", open = CHATS[1].key }) end,

                gui.Icon { name = "message", size = 24, color = "onPrimary" },
            },
        }
    end,

    Status = function(self)
        local rows = {}

        for index = 1, #STATUS do
            local entry = STATUS[index]

            rows[index] = gui.Pressable {
                key = entry.key,
                style = { direction = "row", align = "center", gap = "sm", paddingHorizontal = "md",
                    minHeight = 72 },
                accessibilityLabel = entry.name,
                onPress = function() self:setState({ tab = 1 }) end,

                gui.View {
                    style = { padding = 2, radius = 999,
                        border = entry.mine and 0 or 2, borderColor = "primary" },
                    gui.Avatar { source = entry.face, size = 50 },
                },

                gui.View { style = { grow = 1, shrink = 1, gap = 2 },
                    gui.Text { text = entry.name, numberOfLines = 1, style = { fontWeight = "500" } },
                    gui.Text {
                        text = entry.line,
                        numberOfLines = 1,
                        style = { fontSize = "footnote", color = "textMuted" },
                    },
                },
            }
        end

        return gui.ScrollView {
            style = { grow = 1, background = "background" },
            contentStyle = { paddingVertical = "xs" },
            table.unpack(rows),
        }
    end,

    Calls = function(self)
        local rows = {}

        for index = 1, #CALLS do
            local call = CALLS[index]

            rows[index] = gui.Pressable {
                key = call.key,
                style = { direction = "row", align = "center", gap = "sm", paddingHorizontal = "md",
                    minHeight = 72 },
                accessibilityLabel = call.name,
                onPress = function() self:setState({ screen = "chat", open = "ana" }) end,

                gui.Avatar { source = call.face, size = 50 },

                gui.View { style = { grow = 1, shrink = 1, gap = 3 },
                    gui.Text {
                        text = call.name,
                        numberOfLines = 1,
                        style = { fontWeight = "500", color = call.missed and "danger" or "text" },
                    },
                    gui.View { style = { direction = "row", align = "center", gap = 4 },
                        gui.Icon {
                            name = call.missed and "arrow-down" or "arrow-up",
                            size = 13,
                            color = call.missed and "danger" or "primary",
                        },
                        gui.Text {
                            text = call.line,
                            style = { fontSize = "footnote", color = "textMuted" },
                        },
                    },
                },

                gui.Icon { name = call.video and "video" or "phone", size = 22, color = "primary" },
            }
        end

        return gui.ScrollView {
            style = { grow = 1, background = "background" },
            contentStyle = { paddingVertical = "xs" },
            table.unpack(rows),
        }
    end,

    List = function(self)
        local shown = self:Chats()

        if self.state.tab == 2 then
            shown = self:Status()
        end

        if self.state.tab == 3 then
            shown = self:Calls()
        end

        return gui.View { style = { grow = 1, background = "background" },
            self:Band(),
            shown,
        }
    end,

    --- A conversation, which is the bubbles over the wallpaper and the composer under them.
    Chat = function(self)
        local chat = find(self.state.open)
        local insets = gui.environment:read(self).insets
        local said = self:messagesOf(chat)
        local bubbles = {}

        for index = 1, #said do
            local message = said[index]
            local dark = gui.environment:read(self).appearance == "dark"

            bubbles[index] = gui.View {
                key = message.key,
                style = { alignSelf = message.mine and "end" or "start", maxWidth = "80%",
                    radius = "lg", paddingLeft = "sm", paddingRight = "sm", paddingTop = 6,
                    paddingBottom = 6, marginBottom = 4,
                    background = message.mine and (dark and "#005c4b" or "#d9fdd3")
                        or (dark and "#202c33" or "#ffffff"),
                    shadow = "sm", direction = "row", align = "end", gap = 6 },

                gui.Text {
                    text = message.text,
                    style = { shrink = 1, color = dark and "#e9edef" or "#111b21", lineHeight = 1.35 },
                },

                gui.View { style = { direction = "row", align = "center", gap = 3, paddingTop = 4 },
                    gui.Text {
                        text = message.time,
                        style = { fontSize = 11, color = dark and "#8696a0" or "#667781" },
                    },
                    message.mine and gui.Icon {
                        key = "seen",
                        name = "check-double",
                        size = 14,
                        color = message.read and "#53bdeb" or (dark and "#8696a0" or "#667781"),
                    } or false,
                },
            }
        end

        local typing = self.state.typed ~= ""

        return gui.KeyboardAvoiding { style = { grow = 1, background = "background" },
            gui.View { style = { background = BAND, paddingTop = insets.top },
                gui.View { style = { direction = "row", align = "center", height = 56, gap = "xs",
                    paddingHorizontal = 4 },

                    gui.Pressable {
                        style = { width = 40, height = 44, align = "center", justify = "center" },
                        accessibilityLabel = "Back",
                        onPress = function() self:setState({ screen = "list" }) end,
                        gui.Icon { name = "arrow-left", size = 22, color = ONBAND },
                    },

                    gui.Avatar { source = chat.face, size = 40 },

                    gui.View { style = { grow = 1, shrink = 1, gap = 1, paddingLeft = 6 },
                        gui.Text {
                            text = chat.name,
                            numberOfLines = 1,
                            style = { color = ONBAND, fontSize = "headline", fontWeight = "600" },
                        },
                        gui.Text {
                            text = chat.seen,
                            numberOfLines = 1,
                            style = { color = "#ffffffc4", fontSize = "caption" },
                        },
                    },

                    gui.Pressable {
                        style = { width = 44, height = 44, align = "center", justify = "center" },
                        accessibilityLabel = "Video call",
                        onPress = function() self:setState({ screen = "list", tab = 3 }) end,
                        gui.Icon { name = "video", size = 22, color = ONBAND },
                    },
                    gui.Pressable {
                        style = { width = 44, height = 44, align = "center", justify = "center" },
                        accessibilityLabel = "Voice call",
                        onPress = function() self:setState({ screen = "list", tab = 3 }) end,
                        gui.Icon { name = "phone", size = 20, color = ONBAND },
                    },
                },
            },

            gui.View { style = { grow = 1 },
                Wallpaper {},

                gui.ScrollView {
                    style = { grow = 1 },
                    contentStyle = { padding = "sm", paddingBottom = "md" },
                    keyboardDismissMode = "interactive",
                    table.unpack(bubbles),
                },
            },

            gui.View {
                style = { direction = "row", align = "end", gap = 6, padding = 6,
                    paddingBottom = insets.bottom + 6, background = "surface" },

                gui.View {
                    style = { grow = 1, shrink = 1, direction = "row", align = "center", gap = 4,
                        background = "elevated", radius = "lg", paddingHorizontal = "xs", minHeight = 46 },

                    gui.Pressable {
                        style = { width = 36, height = 44, align = "center", justify = "center" },
                        accessibilityLabel = "Attach",
                        onPress = function() self:setState({ typed = self.state.typed .. "📎" }) end,
                        gui.Icon { name = "paperclip", size = 20, color = "textMuted" },
                    },

                    gui.TextInput {
                        style = { grow = 1, background = "transparent", paddingHorizontal = 0 },
                        placeholder = "Message",
                        value = self.state.typed,
                        accessibilityLabel = "Message",
                        onChange = function(value) self:setState({ typed = value }) end,
                        onSubmit = function() self:send() end,
                    },

                    gui.Pressable {
                        style = { width = 36, height = 44, align = "center", justify = "center" },
                        accessibilityLabel = "Camera",
                        onPress = function() self:setState({ screen = "list", tab = 2 }) end,
                        gui.Icon { name = "camera", size = 20, color = "textMuted" },
                    },
                },

                gui.Pressable {
                    style = { width = 46, height = 46, radius = 999, background = "primary",
                        align = "center", justify = "center" },
                    accessibilityLabel = typing and "Send" or "Record a message",
                    onPress = function() self:send() end,

                    gui.Icon {
                        name = typing and "send" or "microphone",
                        size = 22,
                        color = "onPrimary",
                    },
                },
            },
        }
    end,

    screens = function(self)
        local screens = {
            { key = "list", title = "Sprig", content = self:List(), hidesBar = true },
        }

        if self.state.screen == "chat" then
            screens[2] = {
                key = "chat",
                title = find(self.state.open).name,
                content = self:Chat(),
                hidesBar = true,
            }
        end

        return screens
    end,

    render = function(self)
        local screens = self:screens()

        return gui.Look {
            value = LOOK,
            style = { grow = 1 },

            gui.NavigationStack {
                style = { grow = 1 },
                screens = screens,
                index = #screens,
                onPop = function() self:setState({ screen = "list" }) end,
            },
        }
    end,
})

return Sprig
