# 🎨 Varn GUI

One Lua program describes an interface. iOS, Android and the browser draw it with the widgets they already ship.

```lua
local gui = require("gui")

local Counter = gui.component({
    state = { count = 0 },

    render = function(self)
        return gui.View { style = { padding = 24, gap = 12 },
            gui.Text { "Tapped " .. self.state.count .. " times", style = { fontSize = 20 } },
            gui.Button { title = "Tap me", onPress = function()
                self:setState({ count = self.state.count + 1 })
            end },
        }
    end,
})

gui.run(Counter)
```

That runs unchanged on all three, and on each one the label is a `UILabel`, a `TextView` and a `<span>`.

## How it works

Layout is computed in Lua, so one description cannot lay out three different ways. A renderer receives finished frames and a batch of operations, applies them to real widgets, and reports events back. It decides nothing, which is what keeps three implementations in agreement.

The engine is driven by the platform's own run loop, so a script's work happens on the thread that owns the interface. A screen scrolls while a request is in flight, with no dispatch and no lock.

[docs/architecture.md](docs/architecture.md) records the decisions and what each was chosen over.

## Getting started

```bash
python3 run.py test              # fetch a released engine and run the suite
python3 run.py sample            # pack the sample application into sample/dist/gallery.vap
python3 run.py doctor sample     # check a project's manifest, fonts and images
python3 run.py fetch-native      # download the engine each sample application links against
python3 run.py web               # assemble the page: the framework, the gallery and the engine
```

The sample opens on an index of what there is to see, grouped by the kind of thing it is, and each entry opens a demo of its own: text fields, toggles, pickers, a canvas, lists of every shape, a long list of fifty thousand rows, a form with validation and a screen that talks to an API. The application is Lua from the index down, navigation included. The same archive runs in all three hosts under [apps/](apps/).

## Every component

Structure, content, input, collections, navigation and feedback — fifty-five of them, each declaring the props it accepts and the events it reports. A prop a component does not declare is refused where it was written.

Lists deserve their own line. One component along either axis, cells reused per item type, a cell holding anything a component can build, reuse turned off with one field, and only what can be seen realised — so fifty thousand rows hold as many views as fifty.

## Documentation

| Page | What it covers |
|---|---|
| [architecture.md](docs/architecture.md) | The decisions the project rests on, and what each was chosen over |
| [components.md](docs/components.md) | Every component, its props, its events and its defaults |
| [layout.md](docs/layout.md) | Flexbox, the box model, safe areas and the keyboard |
| [styling.md](docs/styling.md) | Styles, the theme, colours, typography and transforms |
| [lists.md](docs/lists.md) | Item types, cell reuse, windowing and the collections built on them |
| [assets.md](docs/assets.md) | The `.vap` archive, fonts, images and the project checker |
| [bridge.md](docs/bridge.md) | The contract three renderers implement |
| [porting.md](docs/porting.md) | Writing a fourth renderer |
| [plan.md](docs/plan.md) | What is built and what is still open |

## Layout

```
ui/            the framework, which is the same code on every target
  components/  the components, each declaring what it accepts
  layout/      flexbox
  style/       the theme, colours and style resolution
  collections/ the window and the reuse pools a list scrolls through
  bridge/      the wire protocol, the headless renderer and the conformance suite
  host/        starting an application against a platform
  tools/       the project checker and the reference generator
  tests/       the suite, run against a released engine
renderers/     web, ios and android, each a translator that owns no policy
apps/          one sample host per platform
sample/        the gallery, packed into a .vap
```
