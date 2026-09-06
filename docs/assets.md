# 📦 Assets and the application bundle

An application is a directory, and a `.vap` is that directory zipped. The same archive runs on iOS, on Android and in the browser.

```
gallery/
├── manifest.lua
├── app.lua
├── screens/
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

A font in the bundle is registered with the platform under the family the manifest gives it, before the first layout, so nothing is measured in a font it is not drawn in. Any style may then name the family.

```lua
gui.Text { text = "Ready", style = { fontFamily = "Gallery", fontWeight = "700" } }
```

Registering a font invalidates the measurement cache, since the same string in a different face is a different size.

A file the platform refuses is reported rather than passed over. A style naming a family that was never registered would otherwise be drawn in the system font, at a size the engine measured for a face it is not drawn in, and nobody would be told the file was never read. The sample ships no font of its own, since a font carries a licence: a project adds its own files and names them in the manifest.

## Images

An image is named logically and the runtime resolves it to a file in the expanded bundle before the source reaches a renderer, so a screen writes the name and nothing else. A density variant is chosen by the surface's scale, the plain name is the answer when the bundle carries none for that scale, and a name the bundle does not carry is refused rather than drawn as an empty box. A source that carries a scheme is left alone for the platform to fetch.

```
assets/images/logo.png
assets/images/logo@2x.png
assets/images/logo@3x.png
```

```lua
gui.Image { source = "images/logo.png", resizeMode = "contain" }
```

A remote image is fetched with the engine's http client and cached on disk.

## The framework itself

An application is Lua on top of the framework, so a host has to carry the framework as well as the archive.

A host that shares a filesystem with the engine points at it. The iOS application carries `gui/` in its bundle and tells the engine where it sits. A host that shares no filesystem is handed the bytes: the browser fetches `framework.zip` and the Lua side writes it into the filesystem the engine does have, and the Android application unpacks it out of its assets.

`python3 run.py sample` packs both, and `python3 run.py web` puts them beside the engine for the page.

## Checking a project

`doctor` reads a project or an archive and reports what is wrong and what is worth knowing.

```
python3 run.py doctor sample
python3 run.py doctor sample/dist/gallery.vap
```

It reports as a **problem** a font the manifest declares that the project does not carry, an image a source names that is absent, a manifest with no identifier or version, an entry point that does not exist, and a preload naming something missing. It reports as a **note** an asset present but never referenced, a font family registered but no style names, and a font file the manifest does not declare.

A problem fails the check. A note does not.

## Reference and tests

`gui/assets/bundle.lua` opens a project, `gui/tools/doctor.lua` checks one, and `gui/tests/bundle_test.lua`, `gui/tests/doctor_test.lua` and `gui/tests/host_test.lua` cover expansion, the corrupt cache, density variants, every case the doctor reports, and a project launching from its archive with its fonts registered.
