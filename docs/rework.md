# 🔧 Rework

What was wrong with the gallery, why, and what closed each one. An item closes only when it is built, exercised by a test and described in the documentation.

Status: `[ ]` open · `[~]` in progress · `[x]` closed

---

## A. Nothing typed appeared, and events disagreed between platforms

- [x] **A1. One shape for an event payload.** The web sent the bare value for `onChange` while iOS and Android sent `{ value = … }`, so a handler written against one was broken on the other and nothing typed reached the tree on a device. A payload is now what the event carries: a value-changing event carries the value itself, a scroll carries `{ x, y }`, a selection carries `{ item, index }`, and a press carries nothing. `docs/bridge.md` carries the table.
- [x] **A2. Every renderer proved against it.** The conformance suite drives a change, a press and a scroll on each renderer and asserts the payload that comes back. The Android suite runs the same cases on the JVM, and `gui/tests/conformance_test.lua` refuses three suites that do not carry the same case names.
- [x] **A3. A field keeps its caret.** All three apply a value only when it differs from what the control already holds, with a case that moves the caret, applies the same value and asserts it did not move.

## B. It was unusably slow

- [x] **B1. A window with no linear scan.** A uniform extent is arithmetic and a measured one is a binary search over the prefix sums, so a list of fifty thousand rows costs what a list of fifty does.
- [x] **B2. Offsets that are not rebuilt from scratch.** Only what is asked for is computed, and a list no longer rebuilds every offset it has because the extent function it was given is a new closure.
- [x] **B3. A commit that does not re-measure the whole tree.** A box keeps what a layout pass produced and answers a repeat of the same question from it, so a deep tree no longer costs three to its depth. Boxes survive a commit, a style is compared by value so the diff stops marking every node changed, and a handler that travels as a marker is not a change a renderer can see. Re-rendering the whole index now sends nothing at all.
- [x] **B4. A scroll that does not commit the whole tree.** Cells are handed over in the order their pool slots were claimed and the child order is worked out against what the renderer holds after the removals, so a window sliding by one row no longer moves every row on the screen. A one-row scroll of a uniform list is four operations.
- [x] **B5. Numbers to hold it to.** `gui/tests/performance_test.lua` fails when re-rendering the index sends anything, when a keystroke costs more than four operations, when a uniform list scrolling one row costs more than twelve, when a scroll reorders a cell that did not move, or when a tree twenty-four deep measures its one string more than a handful of times. Against the headless renderer a keystroke went from 5.9 ms to 0.13, a scroll from 9.8 to 2.4, and a full re-render of the index from 17.7 to 0.6.

## C. It did not follow the system's appearance

- [x] **C1. The platform reports its appearance.** Light or dark arrives with the surface and again when it changes, on all three.
- [x] **C2. The tree follows it.** The runtime holds the appearance and the theme follows unless the application chose one of its own.
- [x] **C3. The sample follows the system.** It has no switch of its own and looks the way the phone is set.

## D. The chrome was amateurish

- [x] **D1. No hand-drawn Back button.** The way back is a bar item with the platform's own chevron, label and tint, sitting where a platform puts one.
- [x] **D2. A navigation bar that looks native.** The bar is 44 high with the title centred in it rather than pushed along by whatever sits beside it, over a hairline separator.
- [x] **D3. A list that looks native.** Rows are 60 high on a grouped background, with a title and a subtitle, a chevron on a row that opens something, and hairlines between them.
- [x] **D4. Spacing and type that are deliberate.** One type scale in the theme — caption, footnote, body, headline, title, heading, display — used everywhere rather than a size chosen per screen. A control the size of itself sits beside its label rather than under it.

## E. The network demo always failed

- [x] **E1. Find out what it answers.** It called `http.get`, which does not exist — the client lives at `http.client` — so every press answered "failed" and the reason was never shown, because a conditional child written as `nil` had dropped the block that would have shown it. The demo now names the address it asked and what came back.
- [x] **E2. Make it work on a device.** It fetches and shows a result on all three.
- [x] **E3. Prove it without the network.** `gui/tests/network_test.lua` drives the whole path — the press, the loading state, the answer on screen — against a server it starts itself.

## F. It had to be proved on the devices, not argued about

- [x] **F1. The conformance cases run on Android.** All fifteen run on the JVM under Robolectric with the real graphics, alongside iOS and the web.
- [x] **F2. A screenshot from each screen.** `python3 run.py shots` builds, installs and captures every screen in both appearances, so the chrome is looked at rather than argued about.
- [x] **F3. The suite covers what broke.** Every defect above has a test: the payload shape and the caret in the conformance suite, the radio that read its identity as its state, the budgets in `gui/tests/performance_test.lua`, the request in `gui/tests/network_test.lua`, and a `nil` among the children refused by `gui/element.lua` itself.

## G. Documentation

- [x] **G1. `CLAUDE.md`** carries the event contract, the appearance rule, the chrome proportions and the performance budget as binding, alongside the invariants the layout and the diff now rest on.
- [x] **G2. `docs/bridge.md`** carries the payload shape per event and what the platform reports, including the appearance.
- [x] **G3. `docs/plan.md`** reflects what is actually true.

## H. What running every screen turned up

Screenshotting all twenty-six screens in both appearances found a class of defect no tree-based test can see: a node that reaches a renderer and is drawn as nothing at all.

- [x] **H1. An element in a prop is now built.** Only the array part of a spec becomes children, so an accordion's sections, a stack's screens and a drawer's panel were never mounted and all three drew an empty box. They are Lua components now, built from the declared components underneath, and so is a table, which no renderer ever drew either.
- [x] **H2. A node is created with a style.** A node written with none of its own carried no style prop at all, so no renderer was told anything and each left its widget at the platform's default — a UILabel drawing at seventeen points against a frame measured at fifteen, truncating a row with room to spare.
- [x] **H3. A bundled picture reaches the screen.** A screen names the file it wants, and nothing turned that name into a path, so every image was an empty box. The runtime expands it against the bundle, taking the density variant the surface is drawn at.
- [x] **H4. A paragraph of runs is drawn.** No renderer drew a rich text span, so the block was empty on all three.
- [x] **H5. A button's variant is what it looks like.** iOS painted all four with the system's own filled configuration, so the theme reached none of them and four variants arrived as one.
- [x] **H6. Everything that was bare text has a look.** A badge, a chip, an avatar, a card, a tooltip, a skeleton, a divider and every field draw what the theme says rather than nothing.

## Still open

- **An icon has no glyph.** The type needs an icon set to draw from, which is a decision about what an application ships rather than a defect to fix: the platform's own symbols exist only on Apple, so a name means nothing on the other two until `Icon` draws from the bundle the way an image does.
- **The system back gesture does not reach Lua.** Android's back and the browser's history are handled by the platform alone, so a screen cannot consume them. A bar item is the way back on all three until `gui.back` exists.
