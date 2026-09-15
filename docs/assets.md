# 📦 Assets and the application bundle

An application is a directory, and a `.vap` is that directory zipped. The same archive runs on iOS, on Android and in the browser.

```
gallery/
├── manifest.lua
├── app.lua
├── demos/
├── apps/
└── assets/
    ├── fonts/
    └── images/
```

## The manifest

```lua
return {
    identifier = "dev.varn.gui.gallery",
    name = "Varn GUI Gallery",
    version = "1.0.0",
    entry = "app.lua",

    fonts = {
        { family = "Gallery", file = "gallery-regular.ttf", weight = "400" },
        { family = "Gallery", file = "gallery-bold.ttf", weight = "700" },
    },

    preload = { "images/logo.png" },
}
```

`identifier` and `version` are required, `entry` defaults to `app.lua`, `fonts` are registered before anything is measured, and `preload` names what is read at start rather than when it is first drawn.

## The entry point

The entry answers an element, or a function that builds one.

```lua
local gui = require("gui")

return function()
    return gui.SafeArea { style = { grow = 1, background = "background" }, Gallery {} }
end
```

## Packing

```
python3 run.py pack gallery gallery.vap
python3 run.py sample
```

## Expansion

An archive is expanded once into a cache keyed by a hash of its bytes, so a second launch finds it and skips the work. A cache written only in part carries no completion marker, so it is discarded and rebuilt rather than trusted.

```lua
require("gui.host.launch").run("/path/gallery.vap", { cache = "/path/cache" })
```

A project directory opens without packing, which is what a development loop wants:

```lua
require("gui.host.launch").run("./gallery", { directory = true })
```

## Fonts

The framework ships Roboto and registers it before the first layout on every platform, and the theme names it, so the same tree is drawn in the same face on a phone and on a page rather than in whatever each platform calls its system font. It is the subset published for the web, under the Apache licence that travels beside the files in `gui/assets/fonts/`. A project that wants another face names its own in the theme, and one that wants a different set of faces ships them.

A font in the bundle is registered with the platform under the family the manifest gives it, before the first layout, so nothing is measured in a font it is not drawn in. A project's faces are registered after the framework's, so a project naming `Roboto` replaces the face rather than being replaced by it. It replaces the weight it declares and only that one, so a project shipping a regular of its own keeps the framework's medium and bold beside it. Any style may then name the family.

A family is a name over several files, and each is registered under the weight it carries. A style naming a family and a weight is drawn in the face nearest that weight, so a family shipping a regular, a medium and a bold has three weights and a family shipping one has one — asking a single face for a bold gets that face, not a bold.

```lua
gui.Text { text = "Ready", style = { fontFamily = "Gallery", fontWeight = "700" } }
```

Registering a font invalidates the measurement cache, since the same string in a different face is a different size.

A file the platform refuses is reported rather than passed over. A style naming a family that was never registered would otherwise be drawn in the system font, at a size the engine measured for a face it is not drawn in, and nobody would be told the file was never read.

## Images

An image is named logically and the runtime resolves it to a file in the expanded bundle before the source reaches a renderer, so a screen writes the name and nothing else. A density variant is chosen by the surface's scale, the plain name is the answer when the bundle carries none for that scale, and a name the bundle does not carry is refused rather than drawn as an empty box. A source that carries a scheme is left alone for the platform to fetch.

```
assets/images/logo.png
assets/images/logo@2x.png
assets/images/logo@3x.png
```

```lua
gui.Image { source = "logo.png", resizeMode = "contain" }
gui.Image { source = "https://picsum.photos/id/1015/600/400", placeholder = "logo.png" }
```

A remote image is fetched with the engine's http client into the archive's own cache, following the redirects every picture service answers with, and handed to the renderer as a local file. While it is on its way the `placeholder` is what is drawn, and it stays if the picture never comes. `onLoad` and `onError` are reported by the engine, since the engine is what fetched it.

## The framework itself

An application is Lua on top of the framework, so a host has to carry the framework as well as the archive.

A picture a frame is cut from is the exception to the density variant. `gui.NineSlice` is cut at four numbers of pixels and those numbers point at the file that was named, so the engine resolves that source at the plain name and never at an `@2x` — cutting a picture twice the size at the same four numbers would draw every corner at half the width it was authored at. A frame that has to be crisper is shipped larger and drawn smaller with `sliceScale`.

A host that shares a filesystem with the engine points at it. The iOS application carries `gui/` in its bundle and tells the engine where it sits. A host that shares no filesystem is handed the bytes: the browser fetches `framework.zip` and the Lua side writes it into the filesystem the engine does have, and the Android application unpacks it out of its assets.

`python3 run.py sample` packs both, `python3 run.py web` puts them beside the engine for the page, and `python3 run.py serve` does that and serves it, since a browser needs a server for its modules and for the wasm.

## Where an application writes

A project is expanded read-only into a cache, so anything an application keeps — a picked file, a draft, something it downloaded — goes where the host said it may write, which is the only place a phone has one.

```lua
local folder = gui.storage.directory("picked")
fs.writeFile(folder .. "/" .. file.name, bytes)
```

`directory` answers an absolute path, making the folder if it is not there. A path relative to the working directory lands wherever the process happened to be started, which is writable on a desktop and is not on a device, so a file written that way works everywhere except the phone it was written for.

The argument is a name rather than a path: a separator points somewhere the host never said the application may write, and so does a name of dots alone, and both are refused where they are written. An application that was launched without being told where it may write is told so rather than answered with nothing.

## What an application must find again

A directory is where an application writes what it produced. A preference is the other thing: the small values it has to find again next time it is opened, and which it would rather nobody else could read — a token, who is signed in, what a reader chose last time.

```lua
gui.preferences.set("token", answer.token):await()

local token = gui.preferences.get("token"):await()
```

A preference carries a string, a number, a boolean or a table of them, and comes back as what it was written as rather than as the text of it. One nobody has written answers nothing, which is the first run of every application that ever reads one. `remove` takes one away, `clear` takes the lot, and `names` answers what this application has kept. Every one of them answers when the keystore answers rather than at once, so every one is waited on.

What holds them is each platform's own, and what that is worth differs:

| Platform | Kept in | What that means |
|---|---|---|
| iOS | the keychain | Encrypted at rest by the system, reachable only by this application, not readable off a backup, and not readable at all until the device has been unlocked once since it was started. |
| Android | the keystore | The values are sealed with an AES key generated inside the keystore, backed by hardware where the phone has it. The process may use the key and never read it, so what is on disk is cipher text and removing the application takes the key with it. |
| Browser | IndexedDB, under a key the page cannot read | The store belongs to this origin and nothing served from anywhere else reaches it. The values are encrypted with a non-extractable key, so a copy of the site data is worth nothing without the browser profile it came from. |

A browser has no secure element and this does not pretend otherwise: it is origin isolation and a key the page itself cannot export, which is the strongest a page is offered. A reader who hands somebody their unlocked machine has handed over what is in it.

## Checking a project

`doctor` reads a project or an archive and reports what is wrong and what is worth knowing.

```
python3 run.py doctor sample
python3 run.py doctor sample/dist/gallery.vap
```

It reports as a **problem** a font the manifest declares that the project does not carry, an image a source names that is absent, a manifest with no identifier or version, an entry point that does not exist, and a preload naming something missing. It reports as a **note** an asset present but never referenced, a font family registered but no style names, and a font file the manifest does not declare.

A problem fails the check. A note does not.

## Reference and tests

`gui/assets/bundle.lua` opens a project, `gui/host/storage.lua` says where it may write, `gui/tools/doctor.lua` checks one, and `gui/tests/bundle_test.lua`, `gui/tests/doctor_test.lua`, `gui/tests/binding_test.lua` and `gui/tests/host_test.lua` cover expansion, the corrupt cache, density variants, every case the doctor reports, what a name for a directory may be, and a project launching from its archive with its fonts registered.
