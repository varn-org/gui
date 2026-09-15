<h1 align="center">Varn GUI</h1>

<p align="center">
    <a href="https://github.com/varn-org/gui/actions/workflows/check.yml"><img src="https://github.com/varn-org/gui/actions/workflows/check.yml/badge.svg" alt="Check"></a> </p>

**One Lua program, three native interfaces.** Describe a screen once and iPhone, Android and the browser draw it with the widgets they already ship — a `UILabel`, a `TextView` and a `<span>`, from the same line of Lua. Layout is computed in Lua and a renderer receives finished frames, so one description cannot lay out three different ways.

It runs on [Varn](https://github.com/varn-org/varn), which means a screen scrolls while a request is in flight, with no dispatch and no lock.

## 🚀 Quickstart

```bash
python3 run.py test              # fetch a released engine and run the suite
python3 run.py sample            # pack the sample into sample/dist/gallery.vap
python3 run.py web               # assemble the page: framework, gallery and engine
python3 run.py serve             # assemble it and serve it, which is how a browser opens it
python3 run.py shots             # screenshot every screen, on the simulator and in a browser
```

A counter, whole:

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

return { root = Counter {} }
```

An application answers the tree it starts from, and the host on each platform loads it and draws it.

## ✨ Components

There are 86, each declaring the props it accepts and the events it reports. A prop a component does not declare is refused where it was written, and one nothing honours cannot be declared at all.

| Family | What you get |
|---|---|
| 🧱 Structure | Views, dividers, spacers, safe areas, keyboard avoidance and frames drawn from artwork |
| 📝 Content | Text, rich text, images, icons, canvas, video and web views |
| ✍️ Writing | An editor over styled text, with the toolbar that marks it |
| ⌨️ Input | Fields, switches, checkboxes, radios, sliders, steppers, pickers and buttons |
| 📋 Forms | Values, the rules everybody has, and a send that puts the keyboard in the first mistake |
| 📜 Collections | Lists, section lists, grids and carousels, windowed and reusing their cells |
| 🗂️ Containers | Accordions, radio groups and tables |
| 🧭 Bars | A navigation bar that owns the top of the screen, a tab bar and the shape a screen is built into |
| 🧳 Navigation | Navigation stacks, a router driven by the address, and drawers |
| 📐 Adapting | A split view that reads the room it has rather than the device it is on |
| 🎬 Presence | Holding what is leaving until it has left |
| 🪟 Presentation | Modals, sheets, alerts, action sheets, menus and toasts |
| 🔔 Feedback | Badges, chips, cards, avatars, progress, spinners and skeletons |

Lists deserve their own line. One component along either axis, cells reused per item type, a cell holding anything a component can build, reuse turned off with one field, and only what can be seen realised — so fifty thousand rows hold as many views as fifty.

Forms deserve one too. The form holds the values, a field binds one control to one name, fifteen rules ship with it and a function of your own is a rule like any other, and a send that fails puts the keyboard in the first field on the screen that is wrong.

Looks deserve another. A look is one design with light and dark on either side of it, so choosing one never stops the application following the device, and any screen can put the tree in another. `nuxt`, `bootstrap` and `blossom` ship with the framework, and what the platform paints around the tree — the ground behind the surface, the caret, the selection, the accent on a control the platform owns — is painted from the same look.

Full reference: [docs/components.md](docs/components.md).

## 🎨 The sample

The gallery opens on an index of what there is to see, and each entry opens a demo of its own: text fields, toggles, pickers, a canvas, lists of every shape, fifty thousand rows, a camera, a look over what it sees, an editor over styled text, a form with validation and a screen that talks to an API. Six whole applications sit beside them — a shop, a podcast player, an account screen, a chat, an inbox and the weather — each several screens with state, navigation and a keyboard.

The application is Lua from the index down, navigation included. The same archive runs in all three hosts under [apps/](apps/).

## 🌍 Runs everywhere

| Platform | Drawn with | Host |
|---|---|---|
| 🍎 iOS | UIKit | [apps/ios](apps/ios) |
| 🤖 Android | Android views | [apps/android](apps/android) |
| 🌐 Browser | The DOM | [apps/web](apps/web) |

A renderer owns no policy: every size, colour and position arrives already decided, and its whole job is to turn a list of operations into whatever its platform draws with. Writing a fourth is [docs/porting.md](docs/porting.md).

## 📚 Documentation

| Topic | File |
|---|---|
| 🧩 Every component | [docs/components.md](docs/components.md) |
| 🏛️ Architecture | [docs/architecture.md](docs/architecture.md) |
| 📐 Layout | [docs/layout.md](docs/layout.md) |
| 🎨 Styling | [docs/styling.md](docs/styling.md) |
| 🎛 Controls | [docs/controls.md](docs/controls.md) |
| 📱 The sample | [docs/sample.md](docs/sample.md) |
| 📜 Lists | [docs/lists.md](docs/lists.md) |
| 📝 Forms | [docs/forms.md](docs/forms.md) |
| ✍️ Writing | [docs/writing.md](docs/writing.md) |
| 🔔 Events and moments | [docs/events.md](docs/events.md) |
| 🎬 Animation | [docs/animation.md](docs/animation.md) |
| 📦 Assets | [docs/assets.md](docs/assets.md) |
| 🔌 The bridge | [docs/bridge.md](docs/bridge.md) |
| 🛠️ Writing a renderer | [docs/porting.md](docs/porting.md) |
| 🔬 Review | [docs/review.md](docs/review.md) |
| 🗺️ Roadmap | [docs/roadmap.md](docs/roadmap.md) |

## 🗂️ Layout

```
gui/           the framework, which is the same code on every target
  components/  the components, each declaring what it accepts
  layout/      flexbox
  style/       the theme, colours, icons and style resolution
  collections/ the window and the reuse pools a list scrolls through
  bridge/      the wire protocol, the headless renderer and the conformance suite
  host/        starting an application against a platform
  tools/       the project checker and the reference generator
  tests/       the suite, run against a released engine
renderers/     web, ios and android, each a translator that owns no policy
apps/          one sample host per platform
sample/        the gallery, packed into a .vap
```

## 💜 Support

If this project saved you time, consider supporting it: [GitHub Sponsors](https://github.com/sponsors/paulocoutinhox) · [Ko-fi](https://ko-fi.com/paulocoutinho).

Made with care by [Paulo Coutinho](https://github.com/paulocoutinhox).

Licensed under [MIT](LICENSE.md).
