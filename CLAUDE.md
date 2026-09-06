# Varn GUI — project guide for Claude

Varn GUI is one Lua program describing an interface that three renderers draw with the widgets their platform already ships. The engine underneath is [varn-org/varn](https://github.com/varn-org/varn), which this repository consumes as a released binary and never builds. The higher-level Lua libraries that are not about interfaces live in [varn-org/components](https://github.com/varn-org/components).

This file is binding. Follow it exactly instead of re-deriving conventions each session.

## Core principles (non-negotiable)

- **No gambiarras, no fallbacks, no dead/legacy code, no backward-compat shims.** Write it the way an experienced product engineer at a top company would, using current best practices.
- **No `else` for unknown cases that create surprising implicit behavior.** Handle the known cases explicitly. Do not paper over the unknown.
- **Code and comments are in English.**
- **Do the work only when it genuinely makes sense and is actually needed — never just to show work.**
- **IMPORTANT: never run git commit/push on your own.** Leave the working tree dirty. The user runs git.

## Commands

Everything goes through `python3 run.py <task>`:

- `test` — fetch a released engine into `.varn/` and run the Lua suite against it.
- `pack <dir> <out.vap>` — build an application archive from a project directory.
- `doctor <archive>` — validate an archive and report what is missing or unused.
- `sample` — pack the sample application into `sample/dist/`.
- `fetch-native` — download the released `varn.xcframework` and `varn.aar` the two mobile sample hosts link against.
- `shots` — build, install and screenshot every gallery screen on the iOS simulator, in both appearances.

The other renderers run the same suite themselves: `node --test renderers/web/tests` for the web, `xcodebuild test` in `renderers/ios/tests` for iOS, and `./gradlew :app:testDebugUnitTest` in `apps/android` for Android.

## Architecture and organization

- **The renderer owns no policy.** If a renderer has to decide something, the decision belonged in Lua and three renderers will disagree about it. This is the rule the whole project rests on.
- **Layout is computed in Lua** and renderers receive finished frames, each relative to the node it sits inside, since a renderer adds a child to its parent and the parent's origin is already applied. Text measurement is the one thing that crosses back, because only the platform knows its own font engine.
- **A commit sends one batch of operations**, never a call per widget and never the whole tree. Lua holds the virtual tree, the renderer holds the retained one, and neither reads the other's.
- **The host drives the runtime with `load` plus `poll`** on the thread that owns the interface, so every `host.*` call lands there and a renderer touches its views with no dispatch and no lock.
- **Lua owns the window and the reuse pools, the renderer owns the scroll view.** A list realises its own cells as ordinary nodes, and a pooled cell keeps its identity in the element tree, so reuse is the reconciler patching a subtree rather than a second mechanism beside it. The renderer contributes a native scroll view with a `contentExtent`, reporting its offset. It keeps no window and no pool.
- **A style is resolved into concrete values before it crosses the bridge.** Resolution happens in `Runtime:resolveStyles`, never in the diff, so no renderer carries a theme and three of them cannot disagree about what a spacing step means. A new theme re-sends every node its style.
- **Nothing crosses the bridge that json cannot carry.** `gui/bridge/wire.lua` turns a handler into the marker `true` and the removed sentinel into `"__varn_removed__"`, and refuses a cycle. A function never travels — the renderer reports an event by the name of the prop that declared it and the runtime finds the function again on this side.
- **The safe area and the keyboard are layout inputs.** The runtime holds them and `SafeArea` and `KeyboardAvoiding` turn them into padding, so a screen avoids the notch and the keyboard with no platform check anywhere in the tree.
- **Layout per module**: `ui/<area>/` holds the Lua, `gui/components/<name>.lua` a component, `renderers/<platform>/` a renderer, `apps/<platform>/` the sample host, `docs/` the reference.
- **An event's payload is what the event carries, and nothing wrapping it.** A value-changing event carries the value itself (`onChange(true)`, `onChange("typed")`), a scroll carries `{ x, y }`, a selection carries `{ item, index }`, and a press carries nothing. A renderer that wraps a value in a table is broken, and the conformance suite says so on all three.
- **Light and dark come from the platform.** The host reports the appearance with the surface and again when it changes, `Runtime:setAppearance` follows it, and an application that passed a theme of its own keeps it. An application never carries a switch of its own for something the reader already set on their device.
- **The chrome is the platform's own proportions.** A bar is 44 high, a list row 60, a section header 34, and the type scale is the theme's — a value chosen per screen is how a screen ends up looking like nothing else on the device.
- **Binding invariants:**
  - A diff never emits an operation for an unchanged subtree. A re-render that changes one leaf produces one update.
  - **A style is compared by value and kept by identity.** A style is written inline at the point of use and is a fresh table on every render, so comparing it by identity marks the whole tree as changed: an update per node over the bridge and a layout that can keep nothing. `gui/diff.lua` names those props in `LITERAL` and `carried` hands the previous table forward when the new one says the same thing.
  - **A handler is not a change a renderer can see.** It travels as a marker, so a fresh closure over the same event is the prop the renderer already holds. The tree still takes the new closure, since that is the one that reads the state the render was made from.
  - **A box keeps its layout across commits.** Sizing a container asks each child for its size, hands it a share and asks again, so a subtree is visited several times per level and a tree that is worked out afresh costs three to its depth. `gui/layout/flex.lua` keeps what a pass produced, answers a repeat of the same question from it, and rebuilds a box only when the layout node's revision moves. A rebuilt box invalidates the boxes above it, since they can no longer stand on a size that is gone.
  - **A layout node is compared on what the engine reads**, never on the props table it came from, and a resolved style with nothing in it is one shared table so a node with no style of its own never looks changed.
  - **A cell is handed over in the order its pool slot was claimed.** Every cell is placed by a frame of its own, so where it sits among its siblings is nothing a reader can see, and reading order would move every row on the screen each time the window slides by one. The order a batch asks for is worked out against what the renderer holds after the removals, since removing a child renumbers every child after it.
  - **What a control is worth is the platform's to answer.** A size written into the tree is a number that was true of one platform on one day, and the engine sends finished frames, so a control drawn larger than the frame it was given spills out of it. A type says its size is `natural.platform` and the runtime asks once, the same way and for the same reason it asks what a string measures.
  - **A box takes no touch of its own.** A screen is a tree of boxes, and one sitting inside something that can be pressed would take the finger meant for it and answer nothing. A box the touch stops at with nothing inside it wanting the point steps out of the way. A scrolling view always keeps its content inside itself: a view only receives a touch within its own bounds, so content drawn past the edge both overlaps what is above it and cannot be pressed.
  - **A press is answered the way the platform answers one**, on all three, since a control that does not react to a finger reads as one that is not listening.
  - **A component owns its look, and the theme owns the values.** A control with no look of its own draws as bare text on every platform, so each type declares the style it has in theme names and a declaration may compute it from the props a caller gave — which is what a button's variant, a divider's colour and a chip's selected state are. A renderer draws a plain widget the style paints, never one the platform has already decorated.
  - **A node is created with a style, even an empty one.** A renderer told nothing leaves its widget at the platform's own defaults, and a label drawn at a size the engine never measured is given a frame a few points short of its own text.
  - **An element in a prop is never mounted**, since only the array part of a spec becomes children. Anything that takes content — screens, sections, a panel, the cells of a table — is a Lua component that builds what it was given into the tree, never a host node handing data to three renderers that each have to know what to do with it.
  - **A screen names the file it wants and nothing else.** The runtime expands an asset name against the bundle, taking the density variant the surface is drawn at, and refuses a name the bundle does not carry. A source with a scheme is left alone for the platform to fetch.
  - **The props of one node arrive in no order**, since a batch carries them as a map. A prop that builds what a node holds is applied before one that chooses among it, or a control loses its selection on whichever batch happens to be ordered that way.
  - **A performance budget is a test, not a hope.** `gui/tests/performance_test.lua` fails when re-rendering the index sends anything at all, when a keystroke costs more than four operations, when a uniform list scrolling one row costs more than twelve, when a scroll reorders a cell that did not move, or when a tree twenty-four deep measures its one string more than a handful of times.
  - A keyed child survives a reorder with its state. Identity comes from the key when there is one and from position when there is not.
  - `setState` schedules a commit and never runs one. Ten calls in a handler produce one diff.
  - A `setState` from inside `render` is an error, not a second commit.
  - The measurement cache is keyed by every input it depends on, and is dropped when a font is registered or the scale changes.
  - A list reuse pool is per item type. A cell of one type is never handed to another.
  - An archive is expanded once into a cache keyed by the hash of its bytes. A partially written cache is discarded rather than trusted.
  - A renderer declares its capabilities at start. A component needing one a renderer lacks fails loudly instead of rendering nothing.
  - **An index in a placement counts the siblings the node is not among.** A renderer detaches the node before it reads the index, or a move to a later position silently does nothing. The conformance suite catches this, and it caught it once already.
  - A component declaring a prop it does not accept is impossible: `docs/components.md` is generated from the declarations themselves by `gui/tools/reference.lua`.
  - Every component the library exposes appears in the sample application, which `gui/tests/sample_test.lua` enforces by name.
  - **A `nil` in the array part of a table cuts the list short at that point.** A conditional child is appended to a list rather than written in place, and a state field is cleared with `gui.none` rather than `nil`, which `setState` would never see.
  - A control with a size of its own does not shrink. A switch is the size the platform draws one at, and squeezing it to make room for a long label leaves something nobody can recognise or hit.
  - A handler runs after the commit, never during one — a list queues what appeared and disappeared and flushes it in `onUpdate`, since a handler is free to call `setState` and a commit may not start inside a commit.
  - `onLayout` is answered by the engine's own layout rather than by a renderer, so a renderer ignores that prop.
  - **A declaration is a promise, and a test keeps it.** `support.host` says its props are the ones a renderer honours and `docs/components.md` is generated from them, so a prop listed there is one a caller writes and believes. `gui/tools/promises.lua` reads every declaration and searches the three renderers and the components for the prop by name, and `gui/tests/promises_test.lua` fails when nothing anywhere reads one. A sweep found two hundred and fifty-four. A prop that exists only in the documentation is worse than one that does not exist, so a new one is either honoured somewhere or it is not declared.
  - **A commit that fails does not take the application with it.** `Runtime:commit` runs the build under `pcall` and restores `committing` either way, then re-raises. A flag left set makes `needsCommit()` answer false forever, so one bad render, one refused batch or one missing asset would leave the application dead while still running.
  - **A failure reaches the host, not the log.** Opening a project runs on a coroutine, so a failure there would be reported where nobody is looking. `launch.start` takes an `onProblem`, every host registers `gui_problem`, and every sample app shows what it is told. A blank screen that says nothing is the defect this closes.
  - **What a handler does is not the runtime's to trust.** `Runtime:dispatch` runs a caller's handler under `pcall` and reports the failure through `onProblem`, since an error escaping into the host's event delivery takes the frame with it.
  - **An overlay is built rather than asked for.** `Modal`, `Sheet`, `Alert`, `ActionSheet`, `Menu`, `Toast`, `Accordion`, `TabBar`, `NavigationStack`, `Drawer`, `Table` and `RadioGroup` are Lua components that build a cover, a scrim and their content out of the host nodes that already exist, so they work on all three with nothing added to a renderer. A node type no renderer builds falls through to a plain box and puts nothing on screen, which is what "I press it and nothing happens" was.
  - **A control reports the number the tree declared, not the position the platform tracks.** A slider maps its range and its step onto whatever the native control counts in and maps back when it reports, so the same Lua slider answers the same values on all three. Reading the position back as the value is how a slider reported a hundredth of what it was dragged to.
  - **A platform with no control for a type builds one out of parts of its own.** The engine sends `segmented`, `rating`, `stepper` and `picker` no children, so what is inside one belongs to the renderer the way a `UISegmentedControl`'s segments belong to UIKit. A type that draws as an empty box is not a renderer that is behind, it is a control nobody can use.
  - **The tree writing a value back is not a person choosing one.** A control set from a prop reports nothing, or a handler that stores what it was given comes round again as a second choice, and a platform that reports a programmatic change down two paths reports it twice. Each such control remembers what was written into it and reports only what was not.

## Lua style

- Match the existing visual, structural and architectural pattern. Compact, professional, consistent.
- Avoid excess vertical space. Use only the blank lines needed to separate reading contexts. **Separate blocks of different responsibility with one blank line.**
- Never leave multiple `if`s, validations, loops, state mutations and returns visually glued together. A function must read with an identifiable beginning, middle and end at a glance.
- Prefer early returns. Avoid unnecessary nesting. **No unnecessary `else` after a `return`.**
- Extract a function only when one is doing too much — never to shrink size or for artificial abstraction that hides the main flow.
- A module returns one table. Locals are declared at the top of the file, and a function that is not part of the module's surface is local.
- **No global writes.** Every module is `local M = {}` and `return M`.

## Comments

- **Every comment is a complete sentence: it starts with a capital letter and ends with a full stop.**
- **A sentence never starts with a lowercase identifier.** Keep the identifier's exact spelling and reword the sentence so it is not the first word.
- **A comment above a function, method, class or module says what it does for the caller, never how it is implemented inside.**
- **Never break one sentence across lines, and never continue a sentence on the next line.** If you need a second sentence, close the first with a full stop and start the next on its own line.
- Comments are objective and natural. Nothing verbose, fragmented or narrative, no decorative banners, and no historical or before/after framing.
- A comment explains intent or context. It never restates what the code literally does, and usage examples belong in the docs.

## Testing and docs

- Every module has tests under `gui/tests/`, run by `python3 run.py test` against a released engine.
- **A renderer is proven by the conformance suite**, not by looking at a screen. All four run the same cases and apply operations identically, and `gui/tests/conformance_test.lua` refuses a suite that does not carry exactly the same case names.
- **A screen is proven by touching it.** `apps/ios/UITests` opens a demo from the index, types into a field, chooses a radio, counts a button, scrolls a list past the bar, opens a section, sorts a table and drives the request. Four of its twelve cases failed while every conformance case passed, because a tree-based case cannot see that a row will not answer a finger.
- **A screen is proven by looking at it.** A tree-based case cannot see a node that reached a renderer and was drawn as nothing, which is what an empty accordion, an invisible badge and a picture that never loaded each were. `python3 run.py shots` captures every screen in both appearances.
- The headless renderer records operations, so the framework is testable without a device.
- **Prose in Markdown is never hard-wrapped.** One paragraph is one line, however long it runs, and a list item is one line with its continuation folded in.
- **A sentence starts with a capital letter.** The product is `Varn GUI` in prose. A sentence never opens with a lowercase identifier — reword it so the identifier is not first.
- **No `;` splitting clauses in documentation either.** Two independent clauses are two sentences. `LICENSE.md` is never reformatted.
- Docs are two-tier. Tier one is the `README.md` next to the code. Tier two is the reference under `docs/`, which carries the complete API and a runnable example of every capability. `docs/components.md` is generated — regenerate it with `gui/tools/reference.lua` rather than editing its table by hand.
- `docs/plan.md` is the build plan, and an item closes only when it is built, tested and documented. Closing one means moving its box in the same change.
