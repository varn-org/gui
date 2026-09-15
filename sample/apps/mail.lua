local gui = require("gui")

--- A mail application: an inbox under a large title, a search that answers as it is typed, and a message.
---
--- The shape is the one every list application has, which is why it is worth replicating: a bar that owns
--- its own large title and collapses it as the reader scrolls, rows that say what they are without being
--- opened, a filter, actions that change the list under the reader, and a push into one of them.
local MESSAGES = {
    {
        key = "m1",
        from = "Nadia Whitfield",
        subject = "Friday's numbers",
        preview = "The second quarter came in ahead of the plan we set in March, mostly on the back of",
        body = "The second quarter came in ahead of the plan we set in March, mostly on the back of "
            .. "renewals rather than anything new.\n\nTwo things I want to flag before the meeting. The "
            .. "first is that the renewal rate is flattering the number: it is the same customers paying "
            .. "more rather than more customers paying. The second is that we are still short a person on "
            .. "support, and it shows in the response times.\n\nHappy to talk either through before "
            .. "Friday if it helps.",
        at = "09:12",
        unread = true,
        flagged = false,
    },
    {
        key = "m2",
        from = "Tomas Lind",
        subject = "Re: the flat in Södermalm",
        preview = "The agent says we can see it on Saturday morning, but she wants to know by tonight",
        body = "The agent says we can see it on Saturday morning, but she wants to know by tonight "
            .. "whether we are coming.\n\nIt is the one with the odd kitchen, but the light is good and "
            .. "it is five minutes from the water. I think we should look.",
        at = "08:47",
        unread = true,
        flagged = true,
    },
    {
        key = "m3",
        from = "Ellery Books",
        subject = "Your order has shipped",
        preview = "Two of the three are on their way. The third is printing and will follow next week",
        body = "Two of the three are on their way. The third is printing and will follow next week.\n\n"
            .. "You will not be charged for it until it ships.",
        at = "Yesterday",
        unread = false,
        flagged = false,
    },
    {
        key = "m4",
        from = "Ruth Abara",
        subject = "Sunday",
        preview = "Bringing the dog. Bringing bread. Not bringing the speaker, you were right about it",
        body = "Bringing the dog. Bringing bread. Not bringing the speaker, you were right about it.\n\n"
            .. "Around one?",
        at = "Yesterday",
        unread = false,
        flagged = true,
    },
    {
        key = "m5",
        from = "The Quiet Review",
        subject = "Issue 84: what we build with",
        preview = "This week: three essays on tools that outlive the people who chose them, and a short",
        body = "This week: three essays on tools that outlive the people who chose them, and a short "
            .. "piece on why nobody writes documentation for the thing they are about to replace.",
        at = "Tuesday",
        unread = false,
        flagged = false,
    },
    {
        key = "m6",
        from = "Ines Okonkwo",
        subject = "The drawings came back",
        preview = "Two of them are exactly what we asked for and the third is better than what we asked",
        body = "Two of them are exactly what we asked for and the third is better than what we asked "
            .. "for.\n\nI have put all three in the folder. Have a look before Thursday and tell me "
            .. "which one you want to take forward.",
        at = "Monday",
        unread = false,
        flagged = false,
    },
}

local FILTERS = {
    { key = "all", label = "All" },
    { key = "unread", label = "Unread" },
    { key = "flagged", label = "Flagged" },
}

--- The tones a face is drawn on, which is what tells one row from the next at a glance.
local FACES = { "indigo400", "teal400", "deepOrange300", "purple300", "blue400", "green400" }

--- Answers the initials a face is drawn as when there is no picture of one.
local function initials(name)
    local letters = {}

    for word in name:gmatch("%S+") do
        letters[#letters + 1] = word:sub(1, 1)
    end

    return table.concat(letters, "", 1, math.min(2, #letters)):upper()
end

--- Answers the tone one name is always drawn on, which is a name's own rather than its place in a list.
local function tone(name)
    local total = 0

    for index = 1, #name do
        total = total + name:byte(index)
    end

    return FACES[total % #FACES + 1]
end

local Mail = gui.component({
    name = "MailApp",
    state = { filter = "all", search = "", read = {}, flags = {}, removed = {}, reply = "", scrolled = 0 },

    --- Answers a message as it stands now, which is what the reader has done to it since it arrived.
    ---
    --- A flag the reader took off is `false` and one they never touched is `nil`, and those are two
    --- different answers: the second falls back to what the message arrived as and the first does not.
    stateOf = function(self, message)
        local flagged = self.state.flags[message.key]

        if flagged == nil then
            flagged = message.flagged
        end

        return {
            unread = self.state.read[message.key] == nil and message.unread,
            flagged = flagged,
        }
    end,

    --- The messages the reader is looking at, which is the filter and the search together.
    showing = function(self)
        local wanted = self.state.search:lower()
        local found = {}

        for _, message in ipairs(MESSAGES) do
            local held = self:stateOf(message)
            local matches = wanted == ""
                or message.from:lower():find(wanted, 1, true) ~= nil
                or message.subject:lower():find(wanted, 1, true) ~= nil

            local passes = self.state.filter == "all"
                or (self.state.filter == "unread" and held.unread)
                or (self.state.filter == "flagged" and held.flagged)

            if matches and passes and self.state.removed[message.key] == nil then
                found[#found + 1] = message
            end
        end

        return found
    end,

    counted = function(self)
        local total = 0

        for _, message in ipairs(MESSAGES) do
            if self.state.removed[message.key] == nil and self:stateOf(message).unread then
                total = total + 1
            end
        end

        return total
    end,

    open = function(self, message)
        local read = {}

        for key in pairs(self.state.read) do
            read[key] = true
        end

        read[message.key] = true
        self:setState({ looking = message.key, read = read })
    end,

    flag = function(self, message)
        local flags = {}

        for key, value in pairs(self.state.flags) do
            flags[key] = value
        end

        flags[message.key] = not self:stateOf(message).flagged
        self:setState({ flags = flags, said = flags[message.key] and "Flagged" or "Unflagged" })
    end,

    remove = function(self, message)
        local removed = {}

        for key in pairs(self.state.removed) do
            removed[key] = true
        end

        removed[message.key] = true
        self:setState({ removed = removed, looking = gui.none, said = "Moved to the bin" })
    end,

    markAll = function(self)
        local read = {}

        for _, message in ipairs(MESSAGES) do
            read[message.key] = true
        end

        self:setState({ read = read, said = "Everything marked as read" })
    end,

    Row = function(self, message)
        local held = self:stateOf(message)

        return gui.Pressable {
            key = message.key,
            accessibilityLabel = message.subject,
            onPress = function() self:open(message) end,
            onSwipe = function(way)
                if way == "left" then
                    self:remove(message)
                    return
                end

                self:flag(message)
            end,
            style = { direction = "row", gap = "sm", paddingHorizontal = "md", paddingVertical = "sm",
                background = "background" },

            gui.View {
                style = { width = 10, align = "center", justify = "start", paddingTop = 6 },
                held.unread and gui.View {
                    style = { width = 9, height = 9, radius = "pill", background = "primary" },
                } or false,
            },

            gui.Avatar {
                initials = initials(message.from),
                color = tone(message.from),
                textColor = "#ffffff",
                size = 42,
            },

            gui.View { style = { grow = 1, shrink = 1, gap = 1 },
                gui.View { style = { direction = "row", align = "center", gap = "sm" },
                    gui.Text {
                        text = message.from,
                        numberOfLines = 1,
                        style = { grow = 1, shrink = 1, fontSize = "headline",
                            fontWeight = held.unread and "700" or "600" },
                    },
                    gui.Text {
                        text = message.at,
                        style = { fontSize = "caption", color = "textMuted" },
                    },
                    gui.Icon { name = "chevron-right", size = 13, color = "textMuted" },
                },

                gui.View { style = { direction = "row", align = "center", gap = "xs" },
                    held.flagged and gui.Icon { name = "bookmark", size = 13, color = "warning" } or false,
                    gui.Text {
                        text = message.subject,
                        numberOfLines = 1,
                        style = { grow = 1, shrink = 1, fontSize = "footnote",
                            fontWeight = held.unread and "600" or "400" },
                    },
                },

                gui.Text {
                    text = message.preview,
                    numberOfLines = 2,
                    style = { fontSize = "footnote", color = "textMuted", lineHeight = 1.35 },
                },
            },
        }
    end,

    --- Nothing to show, which is a screen in its own right rather than an empty list.
    Nothing = function(self)
        local looking = self.state.search ~= ""

        return gui.View {
            style = { grow = 1, align = "center", justify = "center", gap = "sm", padding = "lg" },
            gui.Icon { name = "mail", size = 40, color = "textMuted" },
            gui.Text {
                text = looking and "Nothing matches that" or "Nothing here",
                style = { fontSize = "headline", fontWeight = "600" },
            },
            gui.Text {
                text = looking and "Try a different name or subject"
                    or "Messages you have not filed will show up here",
                style = { fontSize = "footnote", color = "textMuted", textAlign = "center" },
            },
        }
    end,

    --- What sits under the bar and above the rows, which is the search and the filter.
    Filtering = function(self)
        local chips = {}

        for _, filter in ipairs(FILTERS) do
            chips[#chips + 1] = gui.Chip {
                key = filter.key,
                label = filter.label,
                selected = self.state.filter == filter.key,
                onPress = function() self:setState({ filter = filter.key }) end,
            }
        end

        return gui.View {
            style = { paddingHorizontal = "md", paddingBottom = "sm", gap = "sm", background = "background" },

            gui.SearchBar {
                value = self.state.search,
                placeholder = "Search",
                onChange = function(value) self:setState({ search = value }) end,
            },

            gui.View { style = { direction = "row", gap = "sm" }, table.unpack(chips) },
        }
    end,

    Inbox = function(self)
        local showing = self:showing()
        local insets = gui.environment:read(self).insets

        return gui.View { style = { grow = 1, background = "background" },
            self:Filtering(),

            #showing == 0 and self:Nothing() or gui.List {
                style = { grow = 1 },
                data = showing,
                keyExtractor = function(message) return message.key end,
                separator = gui.Divider { inset = 68 },
                renderItem = function(message) return self:Row(message) end,

                -- The bar owns the large title and collapses it against what the content has moved, so
                -- the rule under the bar appears at the moment the title gives way rather than cutting
                -- across it. What the list has to say is how far it has been scrolled.
                onScroll = function(where) self:setState({ scrolled = where.y }) end,

                -- The list runs under whatever the system draws over the bottom of the glass and stops
                -- above it, so the last row is one a finger can reach.
                footer = gui.Spacer { size = insets.bottom + 56 },
                footerExtent = insets.bottom + 56,
            },

            self:Toolbar(insets),
        }
    end,

    --- The strip along the bottom, which is where a mail application puts what it does to the whole list.
    Toolbar = function(self, insets)
        local waiting = self:counted()

        return gui.View {
            key = "toolbar",
            style = { position = "absolute", left = 0, right = 0, bottom = 0,
                paddingBottom = insets.bottom, background = "elevated", shadow = "sm" },

            gui.Divider {},

            gui.View {
                style = { direction = "row", align = "center", height = 48, paddingHorizontal = "md",
                    gap = "sm" },

                gui.Pressable {
                    accessibilityLabel = "Mark all as read",
                    disabled = waiting == 0,
                    onPress = function() self:markAll() end,
                    style = { minHeight = 44, justify = "center", opacity = waiting == 0 and 0.4 or 1 },
                    gui.Text { text = "Mark all read", style = { color = "primary", fontSize = "footnote" } },
                },

                gui.Text {
                    text = waiting == 0 and "All read" or (waiting .. " unread"),
                    style = { grow = 1, fontSize = "footnote", color = "textMuted", textAlign = "center" },
                },

                gui.Pressable {
                    accessibilityLabel = "Write",
                    onPress = function() self:setState({ said = "Nothing to write to yet" }) end,
                    style = { minWidth = 44, minHeight = 44, align = "center", justify = "center" },
                    gui.Icon { name = "send", size = 20, color = "primary" },
                },
            },
        }
    end,

    Message = function(self, message)
        local held = self:stateOf(message)
        local insets = gui.environment:read(self).insets

        return gui.KeyboardAvoiding { style = { grow = 1, background = "background" },
            gui.ScrollView {
                style = { grow = 1 },
                contentStyle = { padding = "md", gap = "md", paddingBottom = 24 + insets.bottom },

                gui.Text {
                    text = message.subject,
                    style = { fontSize = "title", fontWeight = "700", lineHeight = 1.25 },
                },

                gui.View { style = { direction = "row", gap = "sm", align = "center" },
                    gui.Avatar {
                        initials = initials(message.from),
                        color = tone(message.from),
                        textColor = "#ffffff",
                        size = 44,
                    },
                    gui.View { style = { grow = 1, shrink = 1 },
                        gui.Text { text = message.from, style = { fontWeight = "600" } },
                        gui.Text {
                            text = "to me · " .. message.at,
                            style = { fontSize = "caption", color = "textMuted" },
                        },
                    },
                },

                gui.Divider {},
                gui.Text { text = message.body, style = { lineHeight = 1.6 } },

                self.state.replying and gui.View { style = { gap = "sm", paddingTop = "sm" },
                    gui.TextArea {
                        placeholder = "Write a reply",
                        rows = 4,
                        value = self.state.reply,
                        onChange = function(value) self:setState({ reply = value }) end,
                    },

                    gui.Button {
                        title = "Send",
                        disabled = self.state.reply == "",
                        onPress = function()
                            self:setState({ replying = false, reply = "", said = "Reply sent" })
                        end,
                    },
                } or false,

                gui.View { style = { direction = "row", gap = "sm", paddingTop = "sm" },
                    gui.Button {
                        title = self.state.replying and "Put the reply away" or "Reply",
                        style = { grow = 1 },
                        onPress = function() self:setState({ replying = not self.state.replying }) end,
                    },
                    gui.Button {
                        title = "Delete",
                        variant = "outlined",
                        accessibilityLabel = "Delete",
                        style = { grow = 1 },
                        onPress = function() self:remove(message) end,
                    },
                },
            },
        }
    end,

    looking = function(self)
        for _, message in ipairs(MESSAGES) do
            if message.key == self.state.looking then
                return message
            end
        end

        return nil
    end,

    --- What sits on the right of the bar, which is what the screen under it is for.
    trailing = function(self, message)
        if message == nil then
            return {
                { key = "compose", icon = "plus", accessibilityLabel = "New message",
                    onPress = function() self:setState({ said = "Nothing to write to yet" }) end },
            }
        end

        local held = self:stateOf(message)

        return {
            {
                key = "flag",
                icon = "bookmark",
                color = held.flagged and "warning" or "primary",
                accessibilityLabel = held.flagged and "Unflag" or "Flag",
                onPress = function() self:flag(message) end,
            },
            {
                key = "bin",
                icon = "trash",
                accessibilityLabel = "Delete",
                onPress = function() self:remove(message) end,
            },
        }
    end,

    render = function(self)
        local message = self:looking()

        local screens = {
            {
                key = "inbox",
                title = "Inbox",
                largeTitle = true,
                scrolled = self.state.scrolled,
                trailing = self:trailing(nil),
                content = self:Inbox(),
            },
        }

        if message ~= nil then
            screens[2] = {
                key = message.key,
                title = message.from,
                trailing = self:trailing(message),
                content = self:Message(message),
            }
        end

        return gui.View { style = { grow = 1 },
            gui.NavigationStack {
                style = { grow = 1 },
                backTitle = "Inbox",
                screens = screens,
                index = #screens,
                onIndexChange = function() self:setState({ looking = gui.none, replying = false }) end,
            },

            gui.Toast {
                visible = self.state.said ~= nil,
                message = self.state.said or "",
                duration = 1600,
                onDismiss = function() self:setState({ said = gui.none }) end,
            },
        }
    end,
})

return Mail
