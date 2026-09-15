# 🏛️ Architecture

One Lua program describes an interface. Three renderers draw it with the widgets their platform already ships. This page records the decisions that make those two sentences true, and the alternatives each one was chosen over, so a later change is made knowingly rather than by accident.

## The shape of the system

```
                    app.lua + assets, inside a .vap zip
                                   │
                                   ▼
   ┌───────────────────────────────────────────────────────────┐
   │  varn-gui, written in Lua and identical on every target    │
   │                                                           │
   │   components ──► element tree ──► diff ──► layout ──► ops │
   └───────────────────────────────────────────────────────────┘
                                   │  host.gui_apply(ops)
                                   ▼
   ┌──────────────┬──────────────────────┬─────────────────────┐
   │  UIKit       │  Android View        │  DOM                │
   │  UILabel     │  TextView            │  <span>             │
   │  UIButton    │  MaterialButton      │  <button>           │
   │  UITableView │  RecyclerView        │  virtualised list   │
   └──────────────┴──────────────────────┴─────────────────────┘
                                   │  host.emit("gui.event", …)
                                   ▼
                       handlers back in app.lua
```

Everything above the bridge is one codebase. Everything below it is a thin translator that owns no policy.

## Decision 1: layout is computed in Lua

The renderers receive finished frames, each one relative to the node it sits inside. They never lay anything out.

A renderer that used `UIStackView`, `ConstraintLayout` and CSS flexbox would produce three different results from one description, and the difference would grow with every corner the three engines round differently. Since the promise of the project is that one Lua program looks the same everywhere, the layout engine has to be the part that is shared, not the part that is delegated.

Flexbox is implemented once, in `gui/layout/`, and produces a rect per node. A renderer is then a function from a node and a rect to a native view, which is small enough that three of them stay in agreement.

The cost is that text measurement cannot be done in Lua, since only the platform knows what its font engine will do with a string. Measurement is the single thing that crosses back: a renderer answers `measureText` for a string, a font and a width bound, and the layout engine caches the answer.

**Rejected:** native layout per platform, for the divergence above. **Rejected:** shipping Yoga into all three renderers, since that is a C++ dependency in three build systems and still leaves text measurement platform-specific.

## Decision 2: the bridge carries a batch of operations, not a tree and not a call per widget

A commit produces one `host.gui_apply(ops)` call, where `ops` is a flat array of create, update, move, remove and frame instructions addressed by node id.

The bridge marshals JSON, so its cost is proportional to what crosses it. A screen with two hundred nodes is two hundred encodes and decodes if each widget is its own call, and it is the whole tree on every frame if the tree is resent. A diff sends what changed, which for a typical interaction is a handful of operations.

The renderer keeps the retained tree. Lua keeps the virtual one. Neither reads the other's.

**Rejected:** one call per widget, for the round-trip cost. **Rejected:** resending the tree, for the same reason at a larger scale. **Rejected:** a synchronous read-back API, since it would make a renderer's internals part of the contract.

## Decision 3: the runtime is driven by the platform's own run loop

The host calls `varn_runtime_load_*` once and `varn_runtime_poll` every frame. It never gives the engine a thread.

Because the pump runs on the thread that owns the interface, every `host.*` call from Lua arrives there too. A renderer touches its views directly, with no dispatch, no lock and no chance of a deadlock between a UI thread waiting on the engine and the engine waiting on the UI thread. Timers, sockets, the HTTP client and coroutines all advance in the same tick, which is what lets a screen scroll while a request is in flight.

**Rejected:** running the engine on a background thread and dispatching, since a call that must return a value — the id of a view just created — would have to block the engine on the main thread.

## Decision 4: components are declarative and stateful, and state is explicit

A component is a table with a `render` that returns elements. `setState` marks it dirty and schedules a commit. There are no hooks, no dependency arrays and no implicit subscription: a Lua table with named fields is already readable, and hook rules are a source of bugs that a language without closures-over-render does not need to import.

A commit is scheduled, never synchronous, so ten `setState` calls in one handler produce one diff.

State is a table of named fields and `setState` merges into it, so a field it does not name keeps what it had. `gui.none` is how a field is taken away, since a table cannot carry nil: `self:setState({ problem = gui.none })` leaves nothing where the problem was, and `false` is stored as false rather than as nothing at all.

The runtime is one object and what it does falls into contexts of its own, each a file under `gui/runtime/`: what the engine reads out of a node by name, where a picture comes from, what a batch carries once the tokens a caller wrote have been resolved, and the keyboard. Each of those adds its methods to the same object rather than standing beside it, since a picture resolved on the way out, a style resolved with it and a surface lifted clear of the keyboard are all one commit.

A tree also comes down. `Runtime:stop` unmounts it, which fires every `onUnmount` and so ends whatever each component had asked to happen later. Without that a screen that repeats something — a bar that fills and starts again — holds the engine's loop open for the life of the process, since a pending timer is a reason not to idle.

### The moments a component is told about

Being built and being seen are two different things, which is what iOS and Android both say and what a framework that only reports mounting cannot. A stack keeps the screen under the one on top, a tab bar keeps every tab, and a split view keeps the pane there is no room for, so a screen that has been built is not necessarily one a reader can see.

| Moment | When |
|---|---|
| `onWillMount` | Before the first render, with nothing of it on screen yet. |
| `onMount` | Once the batch that built it has been applied. |
| `onWillAppear` | Before the batch that puts it on screen. |
| `onAppear` | Once that batch has been applied. |
| `onWillDisappear` | Before the batch that takes it off screen. |
| `onDisappear` | Once that batch has been applied. |
| `onUpdate` | After a commit that changed it, with the props it had before. |
| `onWillUnmount` | Before it is taken out of the tree. |
| `onUnmount` | Once it is out. |

The `will` half runs against the tree as it stands and the other half is held until the batch has reached the platform, which is what makes "before" and "after" mean what they say. A component that was built out of sight hears nothing about appearing until it is shown, and one taken down while it was on screen goes from the screen first and is taken down after.

Whether a subtree is on screen is not something it can work out for itself, so whatever is showing it says: `gui.Showing { value = ... }` marks everything under it. `NavigationStack` and `SplitView` do this for the screens and panes they hold, and anything else that keeps several things and shows one — a tab bar, a pager — does the same.

The answer is there for any component to ask, whether or not it declared a moment: `self:visible()`. A component with a visibility callback is rendered again when the answer changes, since the moment is fired from the render that follows, and one that only asks is answered without that, so a question from inside a timer costs nothing. This is what makes a repeating action honest — `self:every(...)` skips a turn taken out of sight rather than ending, so a pulse on a tab nobody is looking at waits instead of asking for a commit every few hundred milliseconds, and it is there again on coming back. A carousel told to play does the same.

### State that several components share

A component's own state is private to it, which is what keeps a screen readable. Two other shapes exist for what is not.

A **context** carries a value down a tree without being threaded through every component in between, and reading it binds the reader: `gui.context(default)` answers one with a `Provider` and a `read`.

```lua
local wearing = gui.theming:read(self)
local route = gui.navigation:read(self)
```

An **observable** is one value several components read and write, with no tree between them:

```lua
local chosen = gui.observable("all")

-- In a render, which is what binds the component that drew it.
local filter = chosen:read(self)

-- In a handler, which renders only the components that read it.
chosen:set("unread")
```

Reading it from a render is what makes the change reach the component that drew the value, rather than the one that happens to own it and everything under that. `get` answers without binding, which is what a handler between renders asks. Writing what is already there is not a change and costs nothing.

## Decision 5: a project is a zip

An application is `app.lua`, the fonts and images it uses, and whatever else it is written out of, inside one archive with a manifest. The archive is expanded once into a cache directory keyed by its content hash, and everything afterwards reads ordinary files.

Fonts have to reach the platform as files on iOS and Android, and images decode fastest from a path, so an in-memory read would copy them to disk anyway. Expanding once makes that explicit and makes a second launch free.

## Decision 6: Lua owns the window and the reuse pools, the renderer owns the scroll view

A list asks its data for an item's type and keeps one reuse pool per type. A cell that scrolls out of the window is handed to the entry that scrolls in, and because a pooled cell keeps its identity in the element tree, the reconciler patches the subtree that is already there rather than building a new one. Reuse is therefore the same machinery as everything else, not a second mechanism beside it.

The alternative was for the renderer to keep the window and ask Lua for the subtree of an index when a cell needs one. That was rejected: it makes every cell a round trip across the bridge during a scroll, and it puts the same windowing arithmetic into three renderers that would then have to agree about it. The renderer contributes what only it can — a native scroll view with a content extent, reporting its offset — and nothing more.

Reuse is opt-in per list. A list of twelve rows does not need a pool, and a list of fifty thousand does. Turning it off is one field rather than a different component.

## What each side owns

| | Lua | Renderer |
|---|---|---|
| Element tree | builds and diffs it | applies operations to a retained mirror |
| Layout | computes every frame | places views at the frames it is given |
| Text metrics | asks, caches | answers for its own font engine |
| Styling | resolves theme and inline styles into concrete values | applies concrete values |
| Events | handles them | reports them with a node id |
| Assets | names them | loads them from the expanded bundle |
| Lifecycle | reacts to it | reports it |
| Lists | keeps the window and the reuse pools | scrolls a content layer and reports the offset |

The rule that keeps this honest: a renderer never decides anything. If a renderer has to choose, the choice belonged in Lua and the three will disagree.
