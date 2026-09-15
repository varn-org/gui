local declare = require("gui.controls.declare")

local chooses = declare.chooses

--- The controls the library ships, each answering the drawing the control theme in force asks for.
local M = {}

M.switch = chooses("switch", "switch", require("gui.controls.switch"))
M.checkbox = chooses("checkbox", "checkbox", require("gui.controls.checkbox"))
M.radio = chooses("radio", "radio", require("gui.controls.radio"))
M.button = chooses("button", "button", require("gui.controls.button"))
M.segmented = chooses("segmented", "segmented", require("gui.controls.segmented"))
M.stepper = chooses("stepper", "stepper", require("gui.controls.stepper"))
M.rating = chooses("rating", "rating", require("gui.controls.rating"))
M.slider = chooses("slider", "slider", require("gui.controls.slider"))

--- A slider with two thumbs is drawn by the engine and by nothing else, since neither phone draws one.
M.range = chooses("rangeslider", nil, require("gui.controls.range"))
M.select = chooses("select", "picker", require("gui.controls.select"))
M.progress = chooses("progress", "progress", require("gui.controls.progress"))

--- A round progress is drawn by the engine and by nothing else, since neither phone draws one.
M.circle = chooses("progresscircle", nil, require("gui.controls.circle"))
M.spinner = chooses("spinner", "activity", require("gui.controls.spinner"))

--- The controls no system draws, which the engine draws under every control theme including `native`.
M.action = chooses("action", nil, require("gui.controls.action"))
M.pagination = chooses("pagination", nil, require("gui.controls.pagination"))
M.steps = chooses("steps", nil, require("gui.controls.steps"))
M.rail = chooses("rail", nil, require("gui.controls.rail"))
M.tree = chooses("tree", nil, require("gui.controls.tree"))
M.popover = chooses("popover", nil, require("gui.controls.popover"))
M.swipe = chooses("swipe", nil, require("gui.controls.swipe"))
M.snackbar = chooses("snackbar", nil, require("gui.controls.messages").Snackbar)
M.banner = chooses("banner", nil, require("gui.controls.messages").Banner)
M.card = chooses("card", "card", require("gui.controls.surfaces").Card)
M.tooltip = chooses("tooltip", "tooltip", require("gui.controls.surfaces").Tooltip)

--- A field is the one control that stays half the platform's: the chrome is drawn and the editable run
--- inside it is the platform's own, since a caret, a selection and every input method belong to it.
M.field = chooses("field", "textinput", require("gui.controls.field"))
M.area = chooses("field", "textarea", require("gui.controls.field"))
M.search = chooses("field", "searchbar", require("gui.controls.field"))
M.swatches = chooses("swatches", "colorpicker", require("gui.controls.swatches"))
M.calendar = chooses("calendar", "datepicker", require("gui.controls.calendar"))
M.clock = chooses("clock", "timepicker", require("gui.controls.clock"))

return M
