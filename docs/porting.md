# 🔌 Writing a renderer

A renderer is a translator. It owns no policy: every size, colour and position arrives already decided, and its whole job is to turn a list of operations into whatever its platform draws with. The three that exist are between one and a half and two and a half thousand lines each, which is the size this is meant to be.

## What you have to provide

Seven functions, registered under the names the Lua side calls.

| Name | Given | Answers |
|---|---|---|
| `gui_apply` | an array of operations | nothing |
| `gui_measure` | `{ text, style, bound }` | `{ width, height }` |
| `gui_measure_control` | `{ type }` | `{ width, height }` |
| `gui_invoke` | `{ id, method, arguments }` | a boolean |
| `gui_capabilities` | nothing | a map of name to boolean |
| `gui_surface` | nothing | `{ width, height, scale, platform, appearance, safeArea }` |
| `gui_register_font` | `{ family, path, weight, style }` | nothing |

`gui_measure_control` answers the size the platform draws a control at, which is the one thing about it the engine cannot know. `gui_surface` carries `platform` and `appearance` because the chrome is drawn from them: a renderer that answers neither has no navigation bar of its platform's shape and no dark mode.

And seven events, emitted back: `gui.event`, `gui.resize`, `gui.appearance`, `gui.insets`, `gui.back`, `gui.keyboard` and `gui.fontsRegistered`.

Handing an application over is a separate contract: a host registers `gui_archive` answering where the archive is, which `gui/host/launch.lua` reads.

Everything crosses as json. The operations and their fields are in [bridge.md](bridge.md).

## The shape of it

```
host                     renderer
 ├── register the seven   ├── nodes: id → widget
 ├── load the chunk       ├── apply(ops)
 ├── pump the loop        ├── measureText(...)
 └── emit events          └── invoke(...)
```

The host owns the run loop. It loads the application with `load_string` and then calls `poll` once a frame, so every host call the script makes arrives on the thread that owns the interface. The renderer then touches its widgets with no dispatch, no lock and no deadlock. Do not give the engine a thread of its own.

## Step by step

**1. A retained map from id to widget.** Ids are never reused, so a plain map is enough. A `create` builds a widget and puts it in the map. A `remove` takes it out. Nothing else allocates.

**2. A factory from node type to widget.** One switch. A type you do not implement is a type you leave out of your capabilities.

**3. Placement.** An `insert` and a `move` are the same code: detach, then attach under the parent at the given one-based index. A parent of `0` is the surface. A move must keep the same widget — a view that moves keeps its scroll position, its focus and its animation state, and rebuilding it is a conformance failure.

**4. Frames.** A `frame` is a rect in the coordinate space of the node the child was inserted into, in points. Set it. Never compute one, never lay anything out, and never let a platform layout pass move a node afterwards — on Android that means a `ViewGroup` whose `onLayout` places each child exactly where it was told. A scrolling view's children are framed against its content layer, so scrolling is the layer moving rather than every frame changing.

**5. Props.** An `update` carries only what changed, so apply what you are given and leave the rest alone. A value equal to `"__varn_removed__"` means clear the prop rather than set it. A handler arrives as `true`, which means bind that event and report it back by the name of the prop that declared it. `onLayout` is the exception: it is answered by the engine's own layout, so a renderer ignores it.

**6. Scrolling.** A `list`, `sectionlist`, `grid` or `carousel` is a scrolling surface with a content layer. It carries `contentExtent` and `horizontal`, its children are placed in content coordinates, and it reports `onScroll` with `{ x, y }`. It keeps no window and no reuse pool of its own — the engine decides which cells exist and which one serves each entry, which is what keeps three renderers agreeing about a list of fifty thousand rows.

**7. Measurement.** Answer honestly for your own font engine, with the width bound applied. The engine caches every answer, so this is asked once per distinct question.

**8. Capabilities.** Declare what you actually do. A component that needs a native picker then fails loudly on a renderer that has none, rather than rendering nothing and leaving someone to work out why.

## Proving it

`gui/bridge/conformance.lua` carries the cases every renderer runs: attachment, ordering, partial updates, the removed sentinel, moves that keep identity, reparenting, subtree removal, framing, refusal of a malformed batch, measurement and capability declaration.

A screenshot cannot be compared across platforms. A tree can, which is why the suite asserts on the tree a renderer built rather than on what it looks like. Run it against your renderer before you trust it against a screen.

## What a renderer decides for itself

Every size, colour and position arrives finished, and this is what cannot: the platform is the only one that knows it.

- **What a string measures**, which is `gui_measure`, and **what a control is drawn at**, which is `gui_measure_control`.
- **How far a percentage travel goes.** A transform's `translateX` and `translateY` take a number of points or a percentage written as a string, and a percentage is a share of the node's own size — which the layout works out and the tree never sees. A panel leaving by its own edge is written `translateY = "100%"`, and it has to be read against the node when it is applied, after the frame rather than when the node was created.
- **What a chooser came back with.** A `filepicker` opens the chooser its `kind` names — `image` for the photo library, `file` for everything else — offering the mime types or extensions in `accept`, and reports `onPick` once per file with `{ name, size, type, bytes }`. `bytes` is base64 and is `null` for a file larger than `maxBytes`, which is reported named and measured rather than read. One report per file rather than one for the set is what keeps a screen moving while a reader's photographs are still being read. Nothing is written to disk: where a chosen file belongs is the application's to decide.
- **How far a sound has got.** An `audio` node is never seen, since the tree draws the player: it is told a `source`, whether it is `playing`, and a `position` to move to, and it reports `onReady` with the duration once the file has been read, `onProgress` with `{ position, duration }` about four times a second, and `onEnd` unless it was told to `loop`.
- **What the map is looking at.** A `map` is given a `center` and a `zoom`, where the zoom is the one every raster map on the web is cut in: at zoom `z` a view `w` points wide spans `360 × w / (256 × 2^z)` degrees of longitude. It reports `onRegionChange` when a reader moves it and never when a prop does, `onMarkerPress` with the `key` of the mark that was pressed, and `onPress` with the coordinate a press landed on, which is not reported when a mark was under it. Apple has MapKit and gives it away, and Android's own map is Google's, which is a dependency and a key before a screen can show a street, so the Android renderer and the browser draw the tiles themselves.
- **What a run of colour and a blurred panel are.** A `gradient` paints its box with the colours it was given, in one of a fixed set of directions — `down`, `up`, `right`, `left`, `diagonal` — with optional stops, so the same run comes out at the same angle everywhere rather than at whatever each platform makes of an angle in degrees. A `blur` stands over what is behind it at the `intensity` it was given, tinted by `tint`, and children are drawn above it rather than inside it. iOS has the system's own material and a browser has `backdrop-filter`, and Android has no blur of a view's own backdrop at all, so what it draws there is the tint alone.
- **A failure inside a call the engine made never escapes it.** What a host registers is called from the engine's own frame, so an exception that escapes unwinds through it and takes the process with it. Catch it, answer the engine with something it can read, and tell the application what went wrong.
- **A handler is set rather than added.** A prop that comes and goes rebinds, so a listener that is added each time leaves a control reporting each event once per binding. Keep one listener for the life of the view and swap what it calls.
- **What a node opened is given back when the node goes.** A player, a receiver, a map's fetchers, a timer: each is opened by a node and closed by its removal, and by nothing else. Detaching is not removal — a cell that scrolls out of a list detaches and comes back, so a player closed there is a sound that never plays again. Anything answering from off the main thread checks that what it is answering is still there: a tile that arrives after the map has gone, a permission a reader granted after the screen was left, a fix that came back late.
- **Where a pinned box goes.** A node inside a scrolling surface may carry `pinned = { from, to }`, two offsets in the surface's content coordinates. It sits at `clamp(offset, from, to - extent)` along the scrolling axis and draws above its siblings, which is a section header held to the leading edge and pushed off by the section after it. Hold it as the surface scrolls rather than waiting for a commit: a commit follows a finger rather than leading it, so a header placed from the tree drifts across the rows it covers on every flick.
- **Where the device is.** A `location` node is never seen either, and asking is mounting one: it asks for the permission the platform requires, reports `onChange` with `{ latitude, longitude, accuracy }` once, or every fix while `watch` is set, and reports `onError` rather than leaving a screen waiting when a reader refuses. Unmounting it stops the receiver. A permission belongs to the activity on Android, so the renderer asks the host for one the way a file chooser does.

## What not to do

- Do not lay anything out. Every frame arrives.
- Do not resolve a theme. Every colour and spacing arrives concrete.
- Do not keep a window or a reuse pool. The engine keeps both.
- Do not invent an event name the tree did not declare.
- Do not apply half a malformed batch. Refuse it.
- Do not let a platform exception unwind through the bridge. Contain it and report it.

## The three that exist

`renderers/web/` over the DOM, `renderers/ios/` over UIKit, and `renderers/android/` over the View system. Read whichever is closest to what you are building on — they solve the same problems in the same order, which is what makes them worth reading side by side.
