local context = require("gui.context")

--- What a field reaches to read what the form holds and to say what a reader wrote.
---
--- A form is one thing spread over a screen: the values, what is wrong with each of them, whether any of
--- it may be sent, and the moment it is. A control deep inside a screen reaches all of that here rather
--- than having it threaded through every component between, which is the same reason a screen reaches
--- its router rather than being handed one.
return context.create({
    values = {},
    errors = {},
    valid = true,
    disabled = false,

    field = function()
        error("this field is not inside a form, so there is nothing holding its value", 2)
    end,

    setValue = function()
        error("this field is not inside a form, so there is nothing to write its value into", 2)
    end,

    submit = function()
        error("this is not inside a form, so there is nothing to submit", 2)
    end,

    reset = function()
        error("this is not inside a form, so there is nothing to reset", 2)
    end,
})
