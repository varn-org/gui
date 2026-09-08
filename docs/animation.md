# 🎞️ Animation

A change on screen either happens between two frames or it takes time. Anything a reader is meant to follow — a sheet rising, an alert appearing, a screen being pushed — takes time, and this is how that is said.

Only opacity and the transform are animated. Neither moves what the layout worked out, so a node keeps the frame the engine gave it however it is faded, slid, scaled or turned. Nothing here changes where anything is measured to be.

## A change that takes time

A node carries a `transition`, and every later change to its style is drawn over that time rather than applied at once.

```lua
gui.View {
    style = { opacity = self.state.shown and 1 or 0 },
    transition = { duration = 250, easing = "easeOut" },
}
```

| Field | What it says | Default |
|---|---|---|
| `duration` | How long the change takes, in milliseconds or by name | `250` |
| `easing` | The curve it is drawn with | `easeOut` |
| `delay` | How long to wait first, in milliseconds | `0` |

A duration may be written as `instant`, `fast`, `normal` or `slow`, and a transition written as a bare duration is one with everything else left at its default:

```lua
transition = "fast"
transition = 400
```

## Easings

Five, defined once in `gui/style/animation.lua` as the four control points of a cubic bezier and sent to a renderer as those four numbers. Every platform takes exactly that shape — `cubic-bezier` in CSS, `UIViewPropertyAnimator` by its two control points, `PathInterpolator` by the same four — so no renderer ever interprets a name and three of them cannot disagree about what `easeOut` means.

| Name | What it feels like |
|---|---|
| `linear` | The same speed the whole way, which reads as mechanical |
| `easeIn` | Starts slowly and gathers pace, for something leaving |
| `easeOut` | Arrives quickly and settles, for something arriving |
| `easeInOut` | Eases at both ends, for something moving between two places |
| `spring` | Overshoots slightly and comes back, for something being grabbed |

## Arriving and leaving

A node that is created can be given the state it comes *from*:

```lua
gui.View {
    style = { opacity = 1 },
    enter = { opacity = 0, transform = { translateY = 24 } },
    transition = { duration = 250 },
}
```

Leaving is the harder half. A node removed from the tree is gone the moment the commit lands, so an overlay dismissed by a handler would vanish rather than animate away. `Presence` holds what it carries for as long as the exit takes, hands the renderer the state to animate towards, and only then lets it go.

```lua
gui.Presence {
    visible = self.state.open,
    transition = "slideUp",
    duration = 250,

    gui.View { style = { background = "elevated" }, ... },
}
```

## Named moves

A transition may be named rather than written out, which is what a component reaches for.

| Name | Arrives | Leaves |
|---|---|---|
| `none` | At once | At once |
| `fade` | From nothing | To nothing |
| `scale` | From slightly small | To slightly small |
| `slideUp` | From below | Downwards |
| `slideDown` | From above | Upwards |
| `slideLeft` | From the trailing edge | To the trailing edge |
| `slideRight` | From the leading edge | To the leading edge |

`gui.animation.names()` answers all of them, which is what the demo screen is built from.

The named slides travel a short fixed distance, which is what a toast or a card wants. A panel that leaves by its own edge travels further than that, and how far is its own height — which the layout works out and the tree does not know. A travel written as a percentage says so, and the renderer reads it against the node it is moving:

```lua
gui.Presence {
    visible = shown,
    transition = {
        enter = { transform = { translateY = "100%" } },
        exit = { transform = { translateY = "100%" } },
    },
    panel,
}
```

## Two layers, two moves

What is shown over a screen is a ground and a panel, and they do not move the same way. A ground covers the screen and has nowhere to travel to, so it fades where it is. A panel travels, and that travel is what a reader reads as the thing arriving.

Animating both as one node takes the ground with the panel: dismissing a sheet drags the darkness down with it and uncovers the screen from the top while the overlay is still on its way out. Every presented component is therefore two `Presence` layers — a fading ground holding a travelling panel — and the panel is the node that carries the transition, so a travel of its own height means its own and not the screen's.

## What already uses it

Nothing below has to be asked for — it is how these behave.

- `Modal`, `Sheet` and `ActionSheet` rise the whole of their own height from the bottom and go back down it.
- `Alert` and `Menu` scale up and away.
- `Toast` slides in from whichever edge it sits at.
- `Drawer` slides in the whole of its own width from its own side.
- `NavigationStack` pushes a screen the way the platform does: from the trailing edge on iOS, a fade on Android.
- In every one of those the ground behind fades rather than travelling.

## Proving one

The headless renderer records what each node was given, so a test reads it back without a screen:

```lua
local node = renderer:find("view")

assert(node.props.transition.duration == 250)
assert(node.props.enter.opacity == 0)
```

`gui/tests/animation_test.lua` covers the wire shape, that a transition written the same way twice does not mark a node as changed, and that a `Presence` keeps what it holds on screen for the whole of its exit and lets go afterwards.

## Reference and tests

`gui/style/animation.lua` carries the easings and the named moves. `gui/components/presence.lua` is the component. The demo is under **Animation** in the gallery, and the tests are `gui/tests/animation_test.lua`.
