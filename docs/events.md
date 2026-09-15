# 🔔 Events and moments

What an application is told, and when. This page is the whole of it: every event a node reports, every moment a component is told about, everything the host tells the engine, and — at the end — what the platforms offer that is deliberately not here, with the reason.

It is written against what UIKit, SwiftUI, the Android view system, Compose and Flutter each report, so a reader coming from any of them can find what they are looking for or find out why it is missing.

## Where an event comes from

Three places, and they behave differently.

- **A node reports** through a handler prop: `onPress`, `onChange`, `onScroll`. The handler is a Lua function that never leaves this side — the renderer reports by the name of the prop and the runtime finds the function again here. A handler runs after the commit, never during one, and one that throws is reported through `onProblem` rather than taken out on the frame it was called from.
- **A component is told** about a moment in its own life: mounting, appearing, updating, pausing. These are methods on the definition rather than props, since they belong to the component rather than to whoever wrote it into a tree.
- **The host tells the engine** about the world: the surface resized, the appearance changed, the keyboard came up, an address arrived. None of that is a node, so it reaches a screen through `gui.environment` or through a component moment.

## What a node reports

### A finger

| Event | Carries | What it is |
|---|---|---|
| `onPress` | nothing | A tap that ended inside the box |
| `onDoublePress` | nothing | Two taps inside the time the platform counts as one gesture |
| `onLongPress` | nothing | A press held past the platform's own threshold |
| `onPressIn` | nothing | The finger landing |
| `onPressOut` | nothing | The finger lifting or leaving |
| `onSwipe` | `"left"`, `"right"`, `"up"`, `"down"` | A finger that travelled far enough to be a swipe rather than a press |
| `onPanStart` / `onPanMove` / `onPanEnd` | `{ x, y, dx, dy }` | A finger following a path, in points against the box's own origin |
| `onHoverIn` / `onHoverOut` | nothing | A mouse, a trackpad or a stylus arriving over the box and leaving it |
| `onContextPress` | `{ x, y }` | A pointer's second button, or a finger held, which every platform means one thing by |

A drag is the one gesture a box has to claim. `panAxis` says which axis it is claiming, and the surface under it keeps the other — a slider inside a list is dragged sideways while the list still scrolls down. The claim is made where the platform makes one: a recogniser that refuses to run alongside a scroll on iOS, `requestDisallowInterceptTouchEvent` once the finger passes the platform's own threshold on Android, and a captured pointer with `touch-action` on the page.

A press and a swipe are told apart by the distance the platform itself allows a tap, not by a number chosen here: UIKit fires wherever the finger is lifted inside the control, Android gives a click up when the touch leaves the view, and a browser raises `click` for any pointer that went down and came up on one element. A double press is the platform's own detector, since how long two taps may be apart is the platform's to decide.

A hover is a pointer resting somewhere without pressing, which a finger cannot do. All three raise the same pair around a tap, so each renderer tells the two apart before it reports.

### A keyboard

| Event | Carries |
|---|---|
| `onKeyDown` / `onKeyUp` | `{ key, shift, ctrl, alt, meta, repeat }` |

A key reaches **whatever has focus**, which is what all three platforms deliver one to: UIKit sends it up the responder chain from the first responder, Android to the focused view, a browser to the focused element. A box that is listening for one takes focus so that it can be reached.

`key` is named the way `KeyboardEvent.key` names it, which is the only published set of names for keys: a printable key carries the character itself (`"a"`, `"A"`, `" "`), and everything else carries a name — `Enter`, `Escape`, `Tab`, `Backspace`, `Delete`, `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`, `Home`, `End`, `PageUp`, `PageDown`. A key none of that covers is `Unidentified` rather than whatever the platform happens to call it.

### Typing

| Event | Carries |
|---|---|
| `onChange` | the value itself |
| `onSubmit` | nothing |
| `onFocus` / `onBlur` | nothing |
| `onSelectionChange` | `{ start, end, marks }` |

`autoFocus` takes the keyboard as the screen opens, which is what a search screen and a form with one field are.

A box that is not a field says the same two things: `onFocus` and `onBlur` reach any box, and `focusable` is what makes one a stop on the way through with a keyboard at all. A control drawn by the engine cannot draw a focus ring without them, which is the whole of using one from a keyboard.

A field reports focus whether or not a screen asked, because the engine lifts a focused field clear of the keyboard and only learns which field that is from the field itself.

`onSelectionChange` counts in characters on every platform, and `marks` is what is on at the caret — empty for a plain field and the marks for a rich editor.

### Scrolling

| Event | Carries |
|---|---|
| `onScroll` | `{ x, y }` |
| `onScrollEnd` | `{ x, y }` |
| `onRefresh` | nothing |
| `onEndReached` | nothing |

A surface reports its offset when a screen asks, and also when the engine has a use for the answer: something under it watching to be seen, or a keyboard it has to lift a field clear of. It reports once more the moment it starts being asked, so nothing is worked out against an offset nobody has ever reported.

### Being seen

| Event | Carries | What it is |
|---|---|---|
| `onEnterView` | nothing | The box came into what the reader can see |
| `onExitView` | nothing | It left |
| `onItemAppear` / `onItemDisappear` | `{ item, index }` | An entry of a list entered or left its window |

This is not a screen appearing. A stack keeps a screen mounted and shown while a box inside it is scrolled a thousand points away. The engine works it out from the frames it laid out and the offsets it is told, clipped by every scroller between the box and the surface.

### Everything else

| Event | On | Carries |
|---|---|---|
| `onLayout` | anything | `{ x, y, width, height }`, answered by the engine rather than a renderer |
| `onSelect` | a list, a table, a radio | `{ item, index }` or the value |
| `onCommit` | a slider | the value it was left at |
| `onLoad` / `onError` | a picture, a film, a sound, a page | what arrived or what went wrong |
| `onReady` / `onProgress` / `onEnd` | a sound, a film, a recorder | how long it is, where it is, that it finished |
| `onCapture` / `onRecord` | a camera | the file it produced |
| `onFinish` | a recorder | the file it produced |
| `onPick` | a file chooser | one file per call |
| `onRegionChange` / `onMarkerPress` | a map | where it moved to, which mark was pressed |
| `onWillLoad` | a web view | the address it started |

## What a component is told

Eleven moments, in two groups.

| Moment | When |
|---|---|
| `onWillMount` | Before it is built, against the tree as it stands |
| `onMount` | After the batch that built it has reached the platform |
| `onWillAppear` / `onAppear` | Before and after whatever is showing it says it is shown |
| `onUpdate` | After a commit that changed it, carrying the props it had before |
| `onWillDisappear` / `onDisappear` | Before and after it stops being shown |
| `onWillUnmount` / `onUnmount` | Before and after it is taken down |
| `onPause` | The application is going away, carrying which of the two states it is going to |
| `onResume` | The application has come back |

Being built and being seen are two different things. A stack keeps the screen under the one on top and a tab bar keeps every tab, so a component that only hears about mounting loads work for screens a reader never looks at. `self:visible()` answers the question at any moment, and `gui.Showing` is what says it.

A component may not be given a method named `ref`, `after`, `every`, `setState` or `visible`, since the engine would then call the caller's — which is a screen that draws nothing with nothing saying why. It is refused where it is written.

## What the host tells the engine

None of this is a node. It reaches a screen through `gui.environment`, through a component moment, or through a context.

| What | Where it is read |
|---|---|
| The surface resized, or the phone turned | `environment.width`, `environment.height`, `environment.breakpoint` |
| Light or dark | `environment.appearance` |
| The safe area | `environment.insets`, and `SafeArea` turns it into padding |
| The keyboard | `KeyboardAvoiding`, and the engine lifts the focused field itself |
| The application's state | `environment.state`, and `onPause` / `onResume` |
| Memory is short | The engine gives back what it can work out again |
| An address arrived | `environment.address`, and `gui.navigation` |
| The system's own back press | `NavigationStack`'s `onBack` |
| A failure anywhere | `onProblem`, which every host shows |

Every one of these reaches the tree inside a guard, so a handler that throws is reported rather than taken out on the frame the host called from.

## What is deliberately not here

Each of these exists on at least one platform and is not built, with the reason. A reader looking for one will find it here rather than finding nothing.

- **A pinch (`onPinch`).** All three platforms have one and it is a real capability. What a pinch needs beyond a drag is a second pointer and an arbitration between scaling and scrolling that differs again on each of the three, and nothing in the library needs it: a drag is what a slider and a swipe action are, and a pinch is what a photograph viewer is. It is written down here rather than attempted in passing.
- **The platform's own long-press menu.** `onLongPress` reports the press, and what a menu is made of is `gui.Menu` drawn through a portal. The system's own menu is a different control on each of the three, with a different set of what may be in it, and offering it would be three things behind one name.
- **A completion for an ordinary transition.** A node carries a `transition` and every later style change is drawn over it, and nothing reports when one has finished. What is shown over a screen reports both ends of both moves through `gui.Presence`, which is where a caller needs the moment — the other case is an animation nobody is waiting on.
- **Drag and drop between applications.** A capability of the desktop and of a tablet, with a payload contract, a drop target contract and a permissions model. It is out of scope for a phone-first library and would be half a capability if it were built for one platform.
- **A hinge, and where a folding phone is folded.** Only Android has an API for one, in `androidx.window`, and every application consuming this renderer would have to carry it. A fold is read as what it is to a tree: a width that changed.

## Reference and tests

Every event listed here is declared in [components.md](components.md), which is generated from the declarations themselves, and `gui/tests/promises_test.lua` holds each of them to being honoured by all three renderers. `gui/tests/events_test.lua` drives the ones this page introduces and the eleven moments a component is told about, `gui/tests/application_test.lua` drives the three states an application is in, and `gui/tests/seeing_test.lua` drives what a box can say about being seen.
