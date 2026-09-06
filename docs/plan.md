# 🗺️ Build plan

Every item says what it is, what it has to do, and what proves it is done. An item closes only when it is written, exercised by a test, and described in the documentation. A title alone is not an item.

Status: `[ ]` open · `[~]` partly done, with what is missing said plainly · `[x]` closed, meaning built, tested and documented

An item is closed only when a test that runs in `python3 run.py test` covers it. Where something is written and compiled but never executed, it is `[~]` and says so.

---

## A. Repository and tooling

- [x] **A1. Layout and metadata.** `README.md` presenting the project, `CLAUDE.md` binding the conventions, `AGENTS.md` pointing at it, `LICENSE.md`, `.editorconfig` matching the engine's, and a `.gitignore` covering the engine cache, the expanded bundle cache, build output and platform noise.
- [x] **A2. `run.py`.** Fetches a released `varn` binary for the host platform into `.varn/<version>/`, then runs the Lua suite against it. Takes `--version` and a filter. Mirrors what the components repository does, since a contributor should not need to build the engine.
- [x] **A3. Continuous integration.** One workflow running the Lua suite on Linux against a released engine. A second job building the three sample applications, so a renderer cannot rot silently.
- [x] **A4. Packaging tool.** `varn-gui pack <dir> <out.vap>` builds an application archive with its manifest, and `varn-gui doctor` validates one, reporting a missing font, an image no style references, or a manifest that names a screen that does not exist.

## B. The element layer

- [x] **B1. Elements.** A node is `{ type, props, children, key }`. Construction is `Text{ ... }` rather than `element("text", ...)`, so a tree reads like the interface it describes. Props and children may be given in one table, with the array part becoming children.
- [x] **B2. Keys and identity.** A keyed child keeps its node across a reorder. Without a key, position decides identity. The diff must move a keyed node rather than destroy and rebuild it, which a test asserts by watching a component's state survive a shuffle.
- [x] **B3. Components.** A component has `render`, optional `state`, `setState`, and the lifecycle hooks `onMount`, `onUpdate` and `onUnmount`. A function returning elements is a component with no state. `setState` marks the instance dirty and schedules one commit, so ten calls in a handler produce one diff.
- [x] **B4. The diff.** Produces a flat operation list: `create`, `update`, `insert`, `move`, `remove`. Update carries only the props that changed. The diff must never emit an operation for an unchanged subtree, which a test asserts by counting operations across a re-render that changes one leaf.
- [x] **B5. The commit scheduler.** Batches dirty components, runs the diff once, computes layout, and sends one `gui_apply`. Re-entrancy is refused: a `setState` from inside `render` is an error rather than a second commit.
- [x] **B6. Refs.** A component may hold a handle to a node to call an imperative action on it — focus a field, scroll a list to an index, play a video. The handle is a node id plus a method table, never a native object.
- [x] **B7. Context.** A value provided high in the tree and read far below without threading it through every component. The theme is the first user of it.

## C. Layout

- [x] **C1. Flexbox.** `direction` (`row`, `column`, and both reversed), `justify`, `align`, `alignSelf`, `wrap`, `grow`, `shrink`, `basis`, `gap`. Percentage and absolute sizes, `minWidth`/`maxWidth` and the height pair.
- [x] **C2. The box model.** `margin`, `padding` and `border` on every side, with the shorthands that take one, two or four values.
- [x] **C3. Absolute positioning.** `position = "absolute"` with `top`, `right`, `bottom`, `left`, resolved against the nearest positioned ancestor and taken out of flow.
- [x] **C4. Text measurement.** The engine asks a renderer for the size of a string in a font at a width bound and caches the answer, keyed by every input. The cache is invalidated when a font is registered or the scale factor changes.
- [x] **C5. Intrinsic sizes.** An image with no explicit size takes its natural one. A button takes its label plus padding. A node with neither content nor size is zero.
- [x] **C6. Layout tests against fixtures.** A table of trees and the frames they must produce, so a change to the engine that moves a pixel is caught rather than discovered on a device.
- [x] **C7. Safe area and insets.** The renderer reports the safe area and the keyboard height, and both are readable as layout inputs, so a screen can avoid the notch and the keyboard without a platform check.

## D. Styling

- [x] **D1. Style resolution.** A style is a table. A node takes a list of them plus inline props, resolved left to right, with the result cached by identity so a static style is resolved once.
- [x] **D2. Theme.** Colors, typography, spacing, radii and shadows, provided through context and swappable at runtime, which is what a light and dark switch is.
- [x] **D3. Colors.** Hex, `rgb`, `rgba`, `hsl`, and named theme colors. Alpha compositing. A helper for lighten, darken and contrast, since a component that picks a readable foreground needs it.
- [x] **D4. Typography.** Family, size, weight, style, line height, letter spacing, alignment, decoration and transform. A custom family resolves to a font registered from the bundle.
- [x] **D5. Appearance props.** Background, border colour, width and radius per corner, opacity, shadow, and `overflow`.
- [x] **D6. Transforms.** Translate, scale and rotate on a node, applied by the renderer without disturbing layout.
- [x] **D7. Responsive values.** A prop may be a table keyed by breakpoint, resolved against the current window size, so one tree serves a phone and a tablet.

## E. Assets and the application bundle

- [x] **E1. The archive format.** A `.vap` is a zip holding `manifest.lua`, `app.lua`, and `assets/` with `fonts/` and `images/`. The manifest names the entry point, the identifier, the version and the assets to preload.
- [x] **E2. Expansion and cache.** The archive is expanded once into a cache directory keyed by a hash of its bytes. A second launch finds it and skips the work. A corrupt or partially written cache is discarded and rebuilt.
- [x] **E3. Fonts.** A font in the bundle is registered with the platform under the family name the manifest gives it, and is then usable from any style. Registration invalidates the measurement cache.
- [x] **E4. Images.** Resolved by logical name to a file in the expanded bundle. Density variants (`@2x`, `@3x`) are chosen by the renderer's scale. A remote image is fetched with the engine's http client and cached on disk.
- [x] **E5. Asset validation.** `doctor` reports a style naming a font the bundle does not carry, an image referenced but absent, and an asset present but never referenced.

## F. Components

Each one declares its props and its events, appears in [components.md](components.md) — generated from those declarations, so it cannot document a prop it does not accept — and appears in the sample application, which `gui/tests/sample_test.lua` enforces by failing with the name of any component the gallery shows no example of.

A declared prop is honoured somewhere: `gui/tests/promises_test.lua` reads every one and fails when nothing in the three renderers or the components reads it by name, so a prop nobody built is not declared. What that test cannot see is a renderer that ignores a name its neighbour honours, which is E5 of [audit.md](audit.md) and is why each platform also carries a control suite of its own.

### F1. Structure
- [x] `View` — the box everything else is built from
- [x] `ScrollView` — vertical, horizontal or both, with paging, an indicator and a scroll event
- [x] `SafeArea` — insets the platform reports
- [x] `KeyboardAvoiding` — moves its content clear of the keyboard
- [x] `Spacer` and `Divider`

### F2. Content
- [x] `Text` — the typography of D4, plus `numberOfLines`
- [x] `RichText` — spans with their own styles, and a tappable span
- [x] `Image` — resize modes, placeholder and tint
- [x] `Icon` — from a registered icon font or an image
- [x] `Video` — play, pause, loop, muted, volume, rate, poster, and an end event
- [x] `WebView` — a url or html, with scripting on or off
- [x] `Canvas` — imperative drawing: paths, fills, strokes, text and images

### F3. Input
- [x] `Button` — title or arbitrary children, variants, sizes and a disabled state
- [x] `Pressable` — press, long press, the in and out phases, and a hit slop
- [x] `TextInput` — value, placeholder, secure, keyboard type, return key, a length limit, capitalisation, correction, focus control, and the change, submit, focus and blur events
- [x] `TextArea` — multiline with auto-grow
- [x] `Switch`, `Checkbox`, `Radio` and a radio group
- [x] `Slider` — range, step, and continuous or committed change
- [x] `Stepper`
- [x] `SegmentedControl`
- [x] `Picker` — a single choice from a list, through the platform's own chooser: a menu on iOS, a spinner on Android, a select on the web
- [x] `DatePicker` and `TimePicker`
- [x] `SearchBar`
- [x] `Rating` — a row of stars, each reporting the score it stands for
- [x] `ColorPicker`
- [x] `FilePicker` — with the platform's own chooser

### F4. Collections
- [x] `List` — the item of G below
- [x] `SectionList` — headers and footers that stick
- [x] `Grid` — a fixed or adaptive column count
- [x] `Carousel` — paged, horizontal or vertical, with an index event and programmatic movement
- [x] `Table` — columns, sorting and selection

### F5. Navigation and presentation
- [~] `NavigationStack` — push, pop and replace, with its own bar. The platform's back gesture does not reach it, which is E5 of [audit.md](audit.md)
- [x] `TabBar`
- [x] `Modal` and `Sheet` — with detents where the platform has them
- [x] `Alert` and `ActionSheet`
- [x] `Menu` — anchored to what opened it
- [x] `Toast`
- [x] `Drawer`
- [x] `Accordion`

### F6. Feedback
- [x] `ActivityIndicator`
- [x] `ProgressBar` — determinate and indeterminate
- [x] `Skeleton` — a shimmer placeholder
- [x] `RefreshControl` — pull to refresh
- [x] `Badge`, `Chip`, `Avatar`, `Card`, `Tooltip`

## G. Lists, in the detail the requirement asks for

- [x] **G1. Both axes.** One component, `horizontal = true` or not. The axis changes layout and the reuse pool, nothing else.
- [x] **G2. Item types.** `itemType(item, index)` returns a name. The renderer keeps one reuse pool per name, so a header cell is never handed to a row.
- [x] **G3. Arbitrary cell content.** A cell holds an element tree. Anything a component can build goes inside one, including another list.
- [x] **G4. Optional reuse.** `recycle = true` turns the pools on. Off, every item keeps its own views, which is right for a short list and for a cell holding state a pool would recycle away.
- [x] **G5. Extent.** A cell's size comes from the layout engine. A list may declare a fixed extent to skip measuring, which is what makes fifty thousand rows scroll.
- [x] **G6. Windowing.** Only the visible range plus a margin is realised. The margin is tunable.
- [x] **G7. Events.** Scroll, reaching the end, an item appearing and disappearing, and selection.
- [x] **G8. Imperative control.** Scroll to an index or an offset, animated or not.
- [x] **G9. Separators, headers, footers and an empty state.**
- [x] **G10. Sticky headers** in `SectionList`.

## H. The bridge

- [x] **H1. The operation protocol.** The wire shape of `create`, `update`, `insert`, `move`, `remove` and `frame`, versioned, with every field documented. This is the contract three renderers implement.
- [x] **H2. Events.** A renderer emits `gui.event` with a node id, a name and a payload. Lua routes it to the handler on that node.
- [x] **H3. Measurement.** The synchronous question a renderer answers, and the cache in front of it.
- [x] **H4. Capability reporting.** A renderer declares what it supports at start, so a component that needs a native picker can fail loudly on a renderer that has none rather than render nothing.
- [x] **H5. A protocol conformance suite.** One set of cases every renderer runs, proving it applies operations the same way. This is what keeps three implementations honest.

## I. Renderers

- [x] **I1. iOS, in Swift over UIKit.** Every node type has a view, the list and the plain scrolling view share one surface, fonts register, text is measured the way a label lays itself out, and the safe area is reported. `renderers/ios/tests` **runs** the conformance cases in the simulator, plus a measurement suite and a control suite of its own, which is what found that `Any as? CGFloat` reads nothing for a plain `Double` and left every number at its default.
- [~] **I2. Android, in Kotlin over the View system.** Every node type has a view, one scrolling surface serves them all, the sample application runs on an emulator, and the conformance cases run on the JVM under Robolectric with the real graphics. What is still open is a text-fitting defect: a bold label is given the width the engine measured and Android draws it wider, so it wraps and the last character is clipped. An icon still has no real glyph.
- [x] **I3. Web, in JavaScript over the DOM.** The same, and it **runs** the conformance cases: `renderers/web/tests/conformance.test.js` executes them against the real renderer over a small stand-in document, which is what found the move-ordering defect in it.
- [x] **I4. Parity.** All four renderers run the same fifteen cases and pass, and `gui/tests/conformance_test.lua` refuses a Lua, web, iOS or Android suite that does not carry exactly the same case names.

## J. The sample application

- [x] **J1. A gallery.** One screen per component family, exercising every prop and every event, written once and shipped as a `.vap`.
- [x] **J2. Custom assets.** Its own images, loaded from the archive, proving E end to end. It ships no font of its own, since a font carries a licence, and the text screen shows the weights the platform already has.
- [x] **J3. A theme switch.** Light and dark, changed at runtime, proving D2.
- [x] **J4. A long list.** Fifty thousand rows, several item types, reuse on, proving G at a size where a mistake shows.
- [x] **J5. A real screen.** A form with validation and a screen that talks to an API, proving the interface stays responsive while a request is in flight.
- [x] **J6. Three hosts.** All three run the same `gallery.vap`. The web application is asserted end to end by `renderers/web/tests/gallery.test.js`, against the released wasm engine. The iOS application was built and launched on the simulator, and the Android application on an emulator, both drawing the gallery with their own native widgets. A host that shares no filesystem with the engine is handed the framework and the archive as bytes, and one that does is pointed at them.

## K. Tests

- [x] **K1. Unit tests** for elements, the diff, layout, styles, colors and the bundle, run by `run.py` against a released engine.
- [x] **K2. Layout fixtures** of C6.
- [x] **K3. Protocol conformance** of H5.
- [x] **K4. A headless renderer** that records operations, so the whole framework is testable without a device.

## L. Documentation

- [x] **L1. `README.md`** — what it is, what it looks like, how to run the sample.
- [x] **L2. `CLAUDE.md`** — the binding conventions, including everything the engine's own file establishes and the rules this project adds.
- [x] **L3. `docs/architecture.md`** — done, the decisions and their alternatives.
- [x] **L4. A page per component** with every prop, every event and a runnable example.
- [x] **L5. `docs/layout.md`, `docs/styling.md`, `docs/assets.md`, `docs/lists.md`, `docs/bridge.md`.**
- [x] **L6. A porting guide** for writing a fourth renderer.
