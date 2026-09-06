# 🌉 The bridge

One call carries a commit, and one event carries what a person did. This page is the contract three renderers implement, and a fourth would.

## The shape of a commit

Lua sends a flat array of operations through `host.gui_apply`. Every operation names a node by id, and ids are never reused.

| Operation | Fields | What a renderer does |
|---|---|---|
| `create` | `id`, `type`, `props` | Builds the widget that stands for `type` and applies `props`. It is not attached to anything yet. |
| `update` | `id`, `props` | Applies only the props given. A prop whose value is the removed sentinel is cleared. |
| `insert` | `id`, `parent`, `index` | Attaches the node under `parent` at a one-based `index`. A `parent` of `0` is the surface. |
| `move` | `id`, `parent`, `index` | Moves an already attached node. The widget is the same one, never a rebuilt copy. |
| `remove` | `id` | Detaches and forgets the node. Its children were removed before it. |
| `frame` | `id`, `x`, `y`, `width`, `height` | Places the node at a rect relative to the node it sits inside. A renderer never computes one. |

The removed sentinel travels as the string `__varn_removed__`, because a table cannot carry `nil`.

## What a renderer must guarantee

- **A move keeps identity.** A view that moves is the same view, with its scroll position, its focus and its animation state intact. Rebuilding it is a conformance failure.
- **An update is partial.** A prop that was not in the batch keeps the value it had.
- **A frame is relative** to the node the child was inserted into, and in points rather than pixels. A renderer adds a child to its parent, so the parent's origin is already applied — an absolute frame would have to be flattened into one layer, and then nothing could clip, scroll or move as a subtree.
- **Order is exact.** Operations are applied in the order they arrive, since a later one may depend on an earlier one.
- **A malformed batch is refused**, not applied in part.

## What a renderer honours

A prop a component declares is a prop something reads. `gui/tests/promises_test.lua` searches the three renderers and the components for every declared name and fails when nothing anywhere honours it, so a renderer that drops a prop is not quietly behind — it is a failing test. These are the ones a renderer owns, grouped by what the platform has to be asked for.

| Family | Props | What a renderer does |
|---|---|---|
| A field | `maxLength`, `autoCapitalize`, `autoCorrect`, `placeholderColor`, `secure`, `keyboard`, `returnKey`, `editable` | Refuses an edit that would pass `maxLength` rather than truncating after the fact, so the caret stays where the typist left it. |
| A control's colours | `Switch.onColor/offColor/thumbColor`, `Slider.trackColor/thumbColor`, `ProgressBar.color/trackColor`, `Image.tint` | Tints the platform control. A colour arrives resolved, never as a theme name. |
| A step | `Slider.step`, `Stepper.step` | Snaps the value the control reports, so a stepper counting in fives never reports a four. |
| A slider | `continuous` | Reports `onChange` while dragging and `onCommit` when the finger lifts. `continuous = false` reports only on commit. |
| A video | `autoplay`, `controls`, `loop`, `muted`, `volume`, `rate`, `poster`, `resizeMode`, `onEnd` | Drives the platform player. A poster is drawn until the first frame is ready. |
| A press | `hitSlop`, `onPressIn`, `onPressOut`, `disabled` | Grows the touch area by `hitSlop` and reports both edges of the press. A control shows the platform's own feedback while it is held. |
| A box | `pointerEvents`, `overflow`, `opacity`, `transform` | A box with no handler and `pointerEvents` unset lets a touch through to whatever sits under it. A scrolling view always clips. |
| Rich text | `spans` | Draws the runs with their own styles inside one paragraph, so a link is part of the sentence rather than a view beside it. |

A prop reaching a renderer is already resolved: spacing and radii are numbers, colours are literal, and a frame is in points. A renderer carries no theme and no layout of its own.

### A control the platform has none of

`segments`, `options` and `count` build what a control holds, and a platform without a control for one of them builds it out of parts of its own — a row of buttons for a segmented control, a menu for a chooser, a row of stars for a rating, two buttons and a readout for a stepper. The engine sends these types no children, so what is inside one belongs to the renderer the way a `UISegmentedControl`'s segments belong to UIKit.

Two rules hold wherever a renderer builds a control:

- **A structural prop applied again replaces what it built**, never adds to it, and the choice already made is carried across the rebuild.
- **The tree writing a value back is not a person choosing one.** A control set from a prop reports nothing, or a handler that stores what it was given comes round again as a second choice.

## Events

A renderer reports what happened through `host.emit("gui.event", …)` with a node id, the name of the prop that declared the handler, and a payload.

```json
{ "id": 42, "name": "onChange", "payload": "typed text" }
```

The name is the prop, so a node with `onPress` receives `onPress`. A renderer never invents a name the tree did not declare.

**A payload is what the event carries, and nothing wrapping it.** A handler is written once and runs on all three, so a renderer that wraps a value in a table leaves that handler broken on its platform alone — which is exactly how typing into a field once reached the tree on the web and nowhere else.

| Event | Payload | Example |
|---|---|---|
| `onChange` on a field | The text itself | `"typed text"` |
| `onChange` on a switch, a checkbox or a radio | The boolean itself | `true` |
| `onChange` on a slider or a stepper | The number itself | `0.4` |
| `onChange` on a segmented control or a picker | The chosen index or value | `2` |
| `onPress`, `onLongPress`, `onSubmit`, `onFocus`, `onBlur` | Nothing | `null` |
| `onScroll`, `onScrollEnd` | The offset it reached | `{ "x": 0, "y": 240 }` |
| `onSelect` | The entry and where it sits | `{ "item": …, "index": 3 }` |
| `onLayout` | Answered by the engine's own layout, never by a renderer | — |

## What the platform reports

| Event | Carries | What the runtime does with it |
|---|---|---|
| `gui.resize` | `width`, `height`, and optionally `safeArea` and `appearance` | Relays out the tree at the new size |
| `gui.insets` | `top`, `right`, `bottom`, `left` | Every `SafeArea` avoids them as padding |
| `gui.keyboard` | `height` | Every `KeyboardAvoiding` leaves that much clear |
| `gui.appearance` | `appearance`, which is `"light"` or `"dark"` | Re-themes the tree, unless the application chose a theme of its own |
| `gui.fontsRegistered` | Nothing | Drops the measurement cache |

`host.gui_surface()` answers the same things at start — `width`, `height`, `scale`, `appearance` and `safeArea` — so an application is themed and inset correctly on its first frame rather than after one repaint. Light and dark come from the platform, so an application carries no switch of its own for something the reader already set on their device.

## What crosses back

Measurement is the one question Lua asks a renderer, because only the platform knows what its font engine does with a string.

```
host.gui_measure({ text = "hello", style = { fontSize = 15 }, bound = 320 })
  → { width = 38, height = 20 }
```

The answer is cached against every input, so the same question is asked once. Registering a font drops the cache.

A control has a size of its own the way a string has a width, and neither is something Lua can work out:

```
host.gui_measure_control({ type = "switch" })
  → { width = 61, height = 28 }
```

It is asked once per type. A number written into the tree instead is a number that was true of one platform on one day — a switch was 51 across until it was 61 — and a frame worked out from the old one spills the control out of the box it was given.

## Capabilities

A renderer declares what it can do at start, so a component that needs a native picker fails loudly on a renderer that has none rather than rendering nothing.

```
host.gui_capabilities() → { text = true, video = false, … }
```

The names are in `gui/bridge/conformance.lua`.

## Imperative actions

A ref reaches one node through `host.gui_invoke`, with `focus`, `blur`, `scrollTo`, `scrollToIndex`, `play` and `pause`. A renderer refuses a name it has no answer for rather than doing nothing quietly.

## Proving a renderer

`gui/bridge/conformance.lua` carries the cases every renderer runs. They cover attachment, ordering, partial updates, the removed sentinel, moves that keep identity, reparenting, subtree removal, framing, refusal of a malformed batch, measurement and capability declaration.

A screenshot cannot be compared across platforms. A tree can, which is why the suite asserts on the tree a renderer built rather than on what it looks like.
