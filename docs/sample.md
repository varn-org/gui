# 📱 The sample

`sample/` is one application. It runs unchanged on iOS, on Android and in a browser, and it is the same tree in all three.

It is in two halves. **The demos** are one screen per subject — layout, lists, writing, controls, animation — and they exist to show a thing working and to be read afterwards. **The applications** are whole products: several screens each, their own state, their own navigation, their own behaviour around the keyboard. They exist to be judged as applications rather than as a list of what the library carries.

## The applications

| What it is | Where it lives | What it is built around |
|---|---|---|
| A shop | [`sample/apps/shop.lua`](../sample/apps/shop.lua) | A window, a product, a bag and a checkout |
| A podcast player | [`sample/apps/podcasts.lua`](../sample/apps/podcasts.lua) | A path with no end, and what a stack costs when it is deep |
| An account | [`sample/apps/settings.lua`](../sample/apps/settings.lua) | Grouped rows, a profile that saves, a destructive action behind a confirmation |
| A chat | [`sample/apps/chat.lua`](../sample/apps/chat.lua) | An inbox, a conversation and somebody answering |
| An inbox | [`sample/apps/mail.lua`](../sample/apps/mail.lua) | Rows, a search, a filter and a swipe that changes the list |
| The weather | [`sample/apps/weather.lua`](../sample/apps/weather.lua) | A hero nobody scrolls past, the hours beside it, the week under them |

## The five built after something

The last five go further than the others. Each is built to read as a kind of application a reader already has on their phone: not the colour of one, which is the easy half, but the density, the proportions, the order things come in and the particular shapes that kind of product settled on.

| What it is | Where it lives | What makes it read as itself |
|---|---|---|
| Food delivery | [`sample/apps/plate.lua`](../sample/apps/plate.lua) | Seven facts inside a seventy-two point row: the picture, the name, the rating, the kind of food, the distance, the time as a range, and the fee or the word for free in green |
| Ride hailing | [`sample/apps/hail.lua`](../sample/apps/hail.lua) | The map is the whole screen and a card is raised over the bottom of it, with the route drawn along streets rather than straight |
| A marketplace | [`sample/apps/bazaar.lua`](../sample/apps/bazaar.lua) | Crowding. A search, categories, a carousel, the day's deals and a two-across grid all above the fold, and four separate facts in the price block |
| Messaging | [`sample/apps/sprig.lua`](../sample/apps/sprig.lua) | The bubbles: pale on the right, white on the left, the time inside the bottom corner, the read marks, and a microphone that becomes an arrow the moment there is something to send |
| An audiobook player | [`sample/apps/lull.lua`](../sample/apps/lull.lua) | Shelves of covers and nothing to read, because what a reader is doing is scanning for one they already recognise |

### What each of them owes

**No real name and no real mark.** None carries the name, the logo or the exact colour of the product it is built after. What is copied is the shape, which is what makes an application read as the thing it is rather than as a mock-up. `gui/tests/sample_test.lua` holds every source file and every page in `docs/` against a list of names and fails on any of them, matched as whole words so that a paragraph about wrapping text stays a paragraph about wrapping text.

**A look of its own.** Each wears one through `gui.Look`, so five palettes sit in one tree and none of them is the gallery's. See [styling.md](styling.md).

**Every screen reachable and every screen comes back.** Each is a `gui.NavigationStack`, so a screen a reader can open is one they can leave. Where the application's own header is the point — the red band, the green band, the yellow band — the screen says `hidesBar` for itself and draws it, and the rest sit under the platform's own bar coloured by the look.

**Nothing fetched and nothing photographic.** Every picture is drawn by [`tools/draw-scenes.py`](../tools/draw-scenes.py) from the shape of the thing it stands for, in the palette its own application uses: a dish, a shopfront, a car from the side, a product, a face, a book cover. A shelf of them reads as one catalogue rather than as a search result, and the sample carries no network and no licence. The map and the wallpaper are not files at all — each is a `gui.Canvas` worked out from the box it turned out to fill.

**Held by the suite.** `gui/tests/apps_test.lua` walks each of the five: it presses what a reader would press, reads what would then be on screen, and then unwinds the whole stack and checks where it lands. A screen that draws nothing, a row that opens nothing and a way back that runs out each fail there.

**The guidelines.** `gui/tests/guidelines_test.lua` walks the whole gallery, so nothing smaller than a finger, nothing pressable without a name for a reader who cannot see it, and no handler with an empty body.

## Running it

| Command | What it does |
|---|---|
| `python3 run.py serve` | The gallery in a browser, rebuilt as you edit |
| `python3 run.py sample` | Packs `sample/` into the archive the two phone hosts read |
| `python3 run.py test` | The Lua suite, which includes everything above |
| `python3 run.py shots` | One screenshot per screen, in both appearances, on the simulator and in a browser |

The phone hosts are ordinary projects rather than tasks here, so each is built the way its platform builds one. On a phone plugged in:

```
python3 run.py sample
cd apps/ios && xcodegen generate
xcodebuild -project VarnGUI.xcodeproj -scheme VarnGUI -configuration Debug \
    -destination "platform=iOS,id=<the phone's UDID>" -derivedDataPath ../../.build/device \
    -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> ../../.build/device/Build/Products/Debug-iphoneos/VarnGUI.app
xcrun devicectl device process launch --device <UDID> dev.varn.gui
```

`xcrun xctrace list devices` answers the UDID, which is not the identifier `devicectl list devices` prints — xcodebuild takes the first and refuses the second by listing every simulator it does know. Android is `./gradlew :app:installDebug` from `apps/android`, and the archive is packed the same way first.

`VARN_GUI_DEMO=apps/plate` opens straight onto one of them, which is what the screenshot harness does on the simulator for each in turn.

A demo in the catalogue may also name a **walk** — what to press to reach the screens inside it and what to file each picture under — and the browser follows it, so a whole application is captured screen by screen rather than only on the one it opens on:

```lua
{ key = "plate", title = "Food delivery", render = function() return Plate {} end, chrome = false,
    screens = {
        { press = "Grill House", as = "place" },
        { press = "Double smash", as = "dish" },
    },
}
```

A picture of the screen an application opens on says nothing about any of the screens behind it, and this is what a restaurant cover drawn as its own logo, two rows of carousel dots and a slider a third of the width it had were each found by.

## Reference and tests

The gallery's index is `sample/catalogue.lua` and the applications are listed in `sample/demos/apps.lua`. The suites are `gui/tests/apps_test.lua`, `gui/tests/sample_test.lua` and `gui/tests/guidelines_test.lua`.
