# 🔌 Writing a renderer

A renderer is a translator. It owns no policy: every size, colour and position arrives already decided, and its whole job is to turn a list of operations into whatever its platform draws with. The three that exist are between four and seven hundred lines each, which is the size this is meant to be.

## What you have to provide

Six functions, registered under the names the Lua side calls.

| Name | Given | Answers |
|---|---|---|
| `gui_apply` | an array of operations | nothing |
| `gui_measure` | `{ text, style, bound }` | `{ width, height }` |
| `gui_invoke` | `{ id, method, arguments }` | a boolean |
| `gui_capabilities` | nothing | a map of name to boolean |
| `gui_surface` | nothing | `{ width, height, scale, safeArea }` |
| `gui_register_font` | `{ family, path, weight, style }` | nothing |

And four events, emitted back: `gui.event`, `gui.resize`, `gui.keyboard` and `gui.fontsRegistered`.

Everything crosses as json. The operations and their fields are in [bridge.md](bridge.md).

## The shape of it

```
host                     renderer
 ├── register the six     ├── nodes: id → widget
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

## What not to do

- Do not lay anything out. Every frame arrives.
- Do not resolve a theme. Every colour and spacing arrives concrete.
- Do not keep a window or a reuse pool. The engine keeps both.
- Do not invent an event name the tree did not declare.
- Do not apply half a malformed batch. Refuse it.
- Do not let a platform exception unwind through the bridge. Contain it and report it.

## The three that exist

`renderers/web/` over the DOM, `renderers/ios/` over UIKit, and `renderers/android/` over the View system. Read whichever is closest to what you are building on — they solve the same problems in the same order, which is what makes them worth reading side by side.
