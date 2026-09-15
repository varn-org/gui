# 🔌 Writing a renderer

A renderer is a translator. It owns no policy: every size, colour and position arrives already decided, and its whole job is to turn a list of operations into whatever its platform draws with. The three that exist are between one and a half and two and a half thousand lines each, which is the size this is meant to be.

## What you have to provide

Eleven functions, registered under the names the Lua side calls.

| Name | Given | Answers |
|---|---|---|
| `gui_apply` | an array of operations | nothing |
| `gui_measure` | `{ text, style, bound }` | `{ width, height }` |
| `gui_measure_control` | `{ type }` | `{ width, height }` |
| `gui_invoke` | `{ id, method, arguments }` | a boolean |
| `gui_capabilities` | nothing | a map of name to boolean |
| `gui_surface` | nothing | `{ width, height, scale, platform, appearance, safeArea }` |
| `gui_register_font` | `{ family, path, weight, style }` | nothing |
| `gui_theme` | `{ appearance, background, text, primary, family }` | nothing |
| `gui_files` | `{ action, ticket, path, title }` | nothing, answered with `gui.files` |
| `gui_preferences` | `{ action, ticket, name, value }` | nothing, answered with `gui.preferences` |
| `gui_problem` | `{ problem }` | nothing |

`gui_theme` is what the platform paints around the tree: the ground behind the surface, the face a control the platform owns writes its own captions in, and whatever the system draws a selection and a caret in. None of that is a node, so none of it follows a look unless the host is told.

`gui_files` keeps a file where the platform keeps pictures and films, or hands it to the system's own way of sending one. It answers whenever the reader is done rather than when it returns, so the reply comes back as a `gui.files` event carrying the `ticket` it was asked with.

`gui_preferences` keeps what an application must find again next time it is opened, where the platform keeps a secret rather than in a file the application writes. A value crosses as whatever it is — a string, a number, a boolean or a table — and comes back as that, so what a host holds is the json of it rather than the text of it. It answers whenever the keystore answers, which is never at once, so the reply comes back as a `gui.preferences` event carrying the `ticket` it was asked with.

A twelfth, `gui_address`, is called only by a host that declared the `address` capability, since a phone has nowhere to show one.

`gui_register_font` is called once per file and several files may carry one family, so a renderer keeps them by weight and draws a style in the face nearest the weight it names. One that keeps a family as a single face has two of the three the framework ships thrown away and draws every weight in whichever registered last.

`gui_problem` is where something goes wrong that the application cannot be told about itself — it failed to start, or a commit raised — and the host is the one with a screen to say it on. The engine's log is not one: a reader looking at a blank application is told nothing by it. It is handed to the launcher as the `onProblem` the host passes in, so a host that registers nothing here has an application that dies quietly.

`gui_measure_control` answers the size the platform draws a control at, which is the one thing about it the engine cannot know. `gui_surface` carries `platform` and `appearance` because the chrome is drawn from them: a renderer that answers neither has no navigation bar of its platform's shape and no dark mode.

And twelve events, emitted back: `gui.event`, `gui.resize`, `gui.appearance`, `gui.insets`, `gui.back`, `gui.keyboard`, `gui.fontsRegistered`, `gui.files`, `gui.preferences`, `gui.lifecycle`, `gui.memory` and `gui.stop`. A host that declared the `address` capability emits `gui.address` as well, since it is the one that owns a history to go back through.

`gui.lifecycle` carries `{ state }`, one of `active`, `inactive` or `background`, and `gui_surface` answers the state the application is in at the start so one launched out of sight is not told it is in front. Active is in front and taking input. Inactive is in front and not — a call arriving, the control centre pulled down, a window losing focus — which is where a game pauses and a video need not. Background is out of sight and may be ended without another word, which is where a draft is saved.

The three platforms reach those three by different routes and at different times, and a host has one job here: say which of the three it is now. iOS has four notifications and the state it reports inside one is still the old state, so what the notification means is what is sent. Android has an activity that goes on running while it is paused, which no other platform does. A browser has a page that is hidden, a window that is blurred, and `pagehide` as the last word it will ever get. A host emitting one of these must pump the engine in the same breath rather than waiting for its next frame, because the frames stop when the window goes and a moment queued for a pump that is not coming is a screen never told it went away.

`gui.memory` says the platform wants back what it can get. The engine gives up what it can work out again — the measurements it has taken and the bytes of pictures it is holding — and nothing a screen put anywhere. It is iOS's memory warning, Android's `onTrimMemory` above `TRIM_MEMORY_RUNNING_LOW`, and, in a browser, the page being hidden, since a browser asks by discarding rather than by saying so.

Handing an application over is a separate contract: a host registers `gui_archive` answering where the archive is, which `gui/host/launch.lua` reads. A host that shares no filesystem with the engine hands the framework over the same way, registering `gui_framework` answering the bytes of it, and the Lua it launches with writes them down and extracts them before the launcher is reached — the browser is one such host, and a desktop or a game host embedding the engine may be another.

Everything crosses as json. The operations and their fields are in [bridge.md](bridge.md).

## The shape of it

```
host                     renderer
 ├── register the eleven  ├── nodes: id → widget
 ├── load the chunk       ├── apply(ops)
 ├── pump the loop        ├── measureText(...)
 └── emit events          └── invoke(...)
```

The host owns the run loop. It loads the application with `load_string` and then calls `poll` once a frame, so every host call the script makes arrives on the thread that owns the interface. The renderer then touches its widgets with no dispatch, no lock and no deadlock. Do not give the engine a thread of its own.

## The smaller set a drawn control theme needs

An application that chooses a drawn control theme — `material2`, `material3`, `cupertino` or one of its own — is drawn out of boxes, text and paths, so a renderer for it has a much shorter list to build. This is the portability contract: build these and the whole library runs, controls included.

| Node | What it has to do |
|---|---|
| `view` | A box with a background, a border, a corner radius, a shadow, an opacity, a transform and clipping |
| `text` | A run of text at a size, a weight, a colour and a line limit |
| `image` | A picture at a resize mode |
| `canvas` | A run of straight lines, filled or stroked, in a colour and at a width |
| `scroll` | A surface that scrolls and reports where it is |
| `layer` | A box hung from the surface rather than from its parent |
| `textinput` | One editable run of text, which is the one thing that cannot be drawn |
| `pressable` | A box that reports a press, a hover, focus and a drag |

Beside those, four things every node may carry: `accessibilityLabel`, `accessibilityRole`, `accessibilityState` and `accessibilityValue`. A drawn control is a box with a colour in it to a screen reader unless the renderer honours them, so they are part of the set rather than a refinement of it.

A text field is the one control that stays half the platform's. The caret, the selection handles, the system keyboard, autocorrect, dictation and every input method for a language that needs one belong to the platform's own text editing, and drawing a box that imitates them would be a text engine rather than a control. What a control theme draws is everything around the text and the editable run itself stays the platform's, inside that chrome.

## Step by step

**1. A retained map from id to widget.** Ids are never reused, so a plain map is enough. A `create` builds a widget and puts it in the map. A `remove` takes it out. Nothing else allocates.

**2. A factory from node type to widget.** One switch. A type you do not implement is a type you leave out of your capabilities.

**3. Placement.** An `insert` and a `move` are the same code: detach, then attach under the parent at the given one-based index. A parent of `0` is the surface. A move must keep the same widget — a view that moves keeps its scroll position, its focus and its animation state, and rebuilding it is a conformance failure.

**4. Frames.** A `frame` is a rect in the coordinate space of the node the child was inserted into, in points. Set it. Never compute one, never lay anything out, and never let a platform layout pass move a node afterwards — on Android that means a `ViewGroup` whose `onLayout` places each child exactly where it was told. A scrolling view's children are framed against its content layer, so scrolling is the layer moving rather than every frame changing.

**5. Props.** An `update` carries only what changed, so apply what you are given and leave the rest alone. A value equal to `"__varn_removed__"` means clear the prop rather than set it. A handler arrives as `true`, which means bind that event and report it back by the name of the prop that declared it. `onLayout` is the exception: it is answered by the engine's own layout, so a renderer ignores it.

**6. Scrolling.** A `list`, `sectionlist`, `grid` or `carousel` is a scrolling surface with a content layer. It carries `contentExtent` and `horizontal`, its children are placed in content coordinates, and it reports `onScroll` with `{ x, y }`. It keeps no window and no reuse pool of its own — the engine decides which cells exist and which one serves each entry, which is what keeps three renderers agreeing about a list of fifty thousand rows.

**7. Measurement.** Answer honestly for your own font engine, with the width bound applied. The engine caches every answer, so this is asked once per distinct question.

**8. Capabilities.** Declare what you actually do. A screen that needs a camera or a native picker reads `renderer:can(name)` and says so rather than drawing a node you have no answer for, and it can only do that if what you declared is true.

## Proving it

`gui.conformance` carries the cases every renderer runs: attachment, ordering, partial updates, the removed sentinel, moves that keep identity, reparenting, subtree removal, framing, refusal of a malformed batch, measurement and capability declaration.

A screenshot cannot be compared across platforms. A tree can, which is why the suite asserts on the tree a renderer built rather than on what it looks like. Run it against your renderer before you trust it against a screen.

A tree that is right is not a screen that is right. A control measured as nothing is drawn as a dot, a caption is stacked on the box it belongs beside, a header trembles across the rows it covers: every one of those builds the tree the suite expects. Drive the real platform as well — `renderers/web/tests/browser.test.js` drives a headless browser and `apps/ios/UITests` drives the simulator with a finger — and look at the screens with `python3 run.py shots`, which walks the gallery on the simulator and in a browser and writes both side by side.

## What a renderer decides for itself

Every size, colour and position arrives finished, and this is what cannot: the platform is the only one that knows it.

- **What a string measures**, which is `gui_measure`, and **what a control is drawn at**, which is `gui_measure_control`. Measure the control your own renderer builds, not an empty one of the same kind: a probe missing the parts a control is made of, or the rules that give it its look, answers a size nothing on the screen ever has. Build it with the same call `create` builds a node with, and keep the answer — a measurement costs a layout, and the engine asks for one per node.
- **How far a percentage travel goes.** A transform's `translateX` and `translateY` take a number of points or a percentage written as a string, and a percentage is a share of the node's own size — which the layout works out and the tree never sees. A panel leaving by its own edge is written `translateY = "100%"`, and it has to be read against the node when it is applied, after the frame rather than when the node was created.
- **What a chooser came back with.** A `filepicker` opens the chooser its `kind` names — `image` for the photo library, `file` for everything else — offering the mime types or extensions in `accept`, and reports `onPick` once per file with `{ name, size, type, bytes }`. `bytes` is base64 and is `null` for a file larger than `maxBytes`, which is reported named and measured rather than read. One report per file rather than one for the set is what keeps a screen moving while a reader's photographs are still being read. Nothing is written to disk: where a chosen file belongs is the application's to decide.
- **How far a sound has got.** An `audio` node is never seen, since the tree draws the player: it is told a `source` and whether it is `playing`, and it reports `onReady` with the duration once the file has been read, `onProgress` with `{ position, duration }` about four times a second, and `onEnd` unless it was told to `loop`. Moving it to a moment is the `seek` action carrying `{ seconds }`, never a prop — a prop carrying a moment is sent only when it differs from the last one, so a reader dragging a scrubber back to where they were the first time is answered by nothing at all.
- **Where a surface is scrolled to.** A scrolling node reports `onScroll` with `{ x, y }` in points as it moves, and it reports once more the moment the handler is bound, since the engine asks because it has a use for the answer now: it lifts a focused field clear of the keyboard and puts the surface back once the keyboard has gone, and neither is worked out correctly against an offset nobody has ever reported. The engine also gives a surface the room the keyboard took from it, through `contentExtent`, which is the inset every platform adds for one — so a renderer adds nothing of its own for the keyboard and takes the extent it is given.
- **What a key is called.** `onKeyDown` and `onKeyUp` reach whatever has focus, which is what every platform delivers a key to, and each carries `{ key, shift, ctrl, alt, meta, repeat }`. `key` is named the way `KeyboardEvent.key` names it, since that is the only published set of names for keys: a printable key carries the character itself and everything else carries a name — `Enter`, `Escape`, `Tab`, `Backspace`, `Delete`, `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`, `Home`, `End`, `PageUp`, `PageDown` — and anything else is `Unidentified` rather than whatever the platform happens to call it. A box listening for one takes focus so that it can be reached.
- **What an editor holds.** A `richeditor` holds a document rather than a string: `value` is a list of `{ text, marks }` runs, where a mark is one of `bold`, `italic`, `underline`, `strikethrough`, `code` and `link`, and `link` carries where it points rather than `true`. A mark is semantic, so each platform draws it with its own bold, its own italic and its own monospace rather than with a weight the tree named, and only the colour a link is drawn in comes from the tree, as `linkColor`. It reports `onChange` with the document, `onSelectionChange` with `{ start, end, marks }` counted in characters, and it takes `toggleMark`, `setLink`, `clearLink`, `copy`, `cut`, `paste` and `selectAll` as actions. Writing the document back into it while a reader is typing takes the caret to the end of it, so it ignores a value it said itself the way a field ignores one.
- **What a caller may ask of a node.** `invoke` performs an action by name on one node: `focus` and `blur` on anything that takes typing, `scrollTo` with `{ x, y, animated }` on a scrolling surface, `play`, `pause` and `seek` on a film, `seek` on a sound, and `capturePhoto`, `startRecording` and `stopRecording` on a camera. A name the renderer has no answer for is refused by raising, and so is an action asked of a node that cannot perform it — `scrollTo` on a label and `play` on a picture are each a caller's mistake, and one renderer throwing where another quietly does nothing is exactly the drift this contract exists to stop.
- **What the map is looking at.** A `map` is given a `center` and a `zoom`, where the zoom is the one every raster map on the web is cut in: at zoom `z` a view `w` points wide spans `360 × w / (256 × 2^z)` degrees of longitude. It reports `onRegionChange` when a reader moves it and never when a prop does, `onMarkerPress` with the `key` of the mark that was pressed, and `onPress` with the coordinate a press landed on, which is not reported when a mark was under it. Apple has MapKit and gives it away, and Android's own map is Google's, which is a dependency and a key before a screen can show a street, so the Android renderer and the browser draw the tiles themselves.
- **What the system's own bars are told.** A `safearea` carries `bars`, the list of the system's bars the reader still sees, and naming fewer hides the rest. Hiding one gives its room back to the window, so the insets reported afterwards change with it and a tree that was correct before is correct after. What a platform cannot do it says through the `systemBars` capability rather than doing nothing quietly, and what a reader does to bring a hidden bar back is left as the platform's own — taking that away is how an application traps somebody inside itself.

- **What a frame drawn from artwork is.** A `nineslice` paints its box with the picture `source` names, cut into nine at `slice`, which arrives as `{ top, right, bottom, left }` in the picture's own pixels. It may also carry `sources`, a picture per state keyed by `pressed`, `disabled`, `hovered` and `focused`, and a state it names none for is drawn with `source` — which is what makes a frame a button that presses. The four corners are drawn at their own size, each edge is stretched along one axis only and the middle is stretched both ways, and `sliceScale` says how many points one pixel of the border comes out at. Three things are easy to get wrong here. The frame is painted **over** the box and never inside it, since children arrive at frames the engine already worked out and a border that took room would shift every one of them by its own thickness. The pieces are drawn **without smoothing**, because a frame is artwork and a two-pixel rule scaled up and smoothed is a smear. And a picture cut wider than itself has no middle left, so it is drawn whole rather than with its corners overlapping. The browser has this as `border-image` and iOS as a layer's `contentsCenter`, and drawing nine pieces by hand is exact wherever the platform has neither.

- **What a run of colour and a blurred panel are.** A `gradient` paints its box with the colours it was given, in one of a fixed set of directions — `down`, `up`, `right`, `left`, `diagonal` — with optional stops, so the same run comes out at the same angle everywhere rather than at whatever each platform makes of an angle in degrees. A `blur` stands over what is behind it at the `intensity` it was given, tinted by `tint`, and children are drawn above it rather than inside it. iOS has the system's own material and a browser has `backdrop-filter`, and Android has no blur of a view's own backdrop at all, so what it draws there is the tint alone.
- **A failure inside a call the engine made never escapes it.** What a host registers is called from the engine's own frame, so an exception that escapes unwinds through it and takes the process with it — under wasm it unwinds frames no C++ handler can catch, and the call never returns, leaving the Lua stack mid-call and the runtime dead with the page still standing. Catch it, answer the engine with something it can read, and tell the application what went wrong. Telling the application cannot throw either, since that is the one frame that must not.
- **What a page inside a `webview` may do.** `javaScriptEnabled` says whether the page it shows runs scripts, and it has to reach the decision the platform actually takes: the browser writes it into the iframe's sandbox, Android turns it off in the web settings, and iOS decides it per navigation, since a `WKWebView` answers a copy of the configuration it was built with and a preference written on that copy changes nothing.
- **A number a host reports is a number.** A surface, a safe area, a keyboard height and every number in an event's payload are checked where they arrive: what is not finite, or is a length below nothing, is refused or dropped rather than laid out against. Report points, not whatever the platform's own arithmetic answered mid-gesture.
- **A host event is delivered by the loop rather than in place.** `emit` posts it, so a host that says it is finished and takes its pump away in the next line never delivers the message: emit, poll, then stop pumping. Everything a host set up to watch the window — a notification observer, a gesture recogniser, a layout listener — is kept and given back at the same moment, or it outlives the surface and reports into a runtime that has stopped.
- **A problem is shown over the application, never in place of it.** Writing one into the surface takes the screen away for good: the retained tree is gone and every id the renderer holds names a widget that is not there, so one failed handler ends the session. A banner, a toast, whatever the platform has — over what is drawn, and with a way to put it away.
- **A handler is set rather than added.** A prop that comes and goes rebinds, so a listener that is added each time leaves a control reporting each event once per binding. Keep one listener for the life of the view and swap what it calls.
- **What a node opened is given back when the node goes.** A player, a receiver, a map's fetchers, a timer: each is opened by a node and closed by its removal, and by nothing else. Detaching is not removal — a cell that scrolls out of a list detaches and comes back, so a player closed there is a sound that never plays again. Anything answering from off the main thread checks that what it is answering is still there: a tile that arrives after the map has gone, a permission a reader granted after the screen was left, a fix that came back late.
- **Where a pinned box goes.** A node inside a scrolling surface may carry `pinned = { from, to }`, two offsets in the surface's content coordinates. It sits at `clamp(offset, from, to - extent)` along the scrolling axis and draws above its siblings, which is a section header held to the leading edge and pushed off by the section after it. Hold it as the surface scrolls rather than waiting for a commit: a commit follows a finger rather than leading it, so a header placed from the tree drifts across the rows it covers on every flick. Hold it the way the platform holds one, too — the phones move a view inside the callback the scroll view makes before it draws, and a browser dispatches its scroll event after the compositor has already painted, so a position worked out in one is a frame late and the header trembles. The browser is told the range to follow the surface over and drives the rest itself.
- **What an input method is in the middle of.** A field carries the value the tree gives it, except while a reader is composing a word — the sound of a Japanese, Chinese or Korean word held by the platform until they pick what it stands for. Writing over that takes the half-written word away, and the return that picks one is not a return that submits. Ask the platform: marked text on iOS, a composing span on Android, a composition on the web.
- **What a keyboard can reach.** A control the platform drew answers a tab and a return for itself. One built out of a box does not, so a row carrying `onPress` has to be given a tab stop, the role it plays, and the keys that stand for a press, or a reader with no pointer cannot use the screen at all.
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
