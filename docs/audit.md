# 🔍 Audit

Everything a full read of the project turned up, why it is wrong, and what closes it. An item closes only when it is built, exercised by a test and described in the documentation.

Status: `[ ]` open · `[~]` in progress · `[x]` closed

---

## A. A declaration that promises what nothing delivers

`support.host` says its `props` are "the props a renderer honours" and `docs/components.md` is generated from those declarations, so the reference documents every one of them. A sweep of the three renderers and the Lua that builds on them found **two hundred and fifty-four props and events that nothing read at all**, and forty more honoured on one or two platforms out of three. Every one of them is a promise the documentation makes and the code does not keep.

- [x] **A1. Make the lie impossible.** `gui/tools/promises.lua` reads every declaration, searches the three renderers and the components for the prop by name, and `gui/tests/promises_test.lua` fails when a declared prop is honoured by nothing. The count went from two hundred and fifty-four to nought, and it stays there because the suite says so.
- [x] **A2. The presentation family does nothing at all.** `Modal`, `Sheet`, `Alert`, `ActionSheet`, `Menu` and `Toast` were node types no renderer built: they fell through to a plain box, and `visible` was not applied on iOS at all. Pressing "Show a modal" in the gallery changed state, re-rendered and put nothing on screen — this is the "I press it and nothing happens" that was reported. They are Lua components in `gui/components/presentation.lua` that build an overlay out of the host nodes that already exist, so they work on all three with nothing added to a renderer. `gui/tests/presentation_test.lua` covers hidden and visible, dismissal, detents, an alert's answers, an action sheet's cancel, a menu's selection and a toast's action.
- [x] **A3. `RefreshControl` does nothing.** Pull to refresh is a scroll view behaviour on every platform, so `refreshing` and `onRefresh` belong to the renderer that owns the scroll view, which is where they are read now.
- [x] **A4. A field ignores most of what it is told.** `autoCapitalize`, `autoCorrect`, `maxLength` and `placeholderColor` are honoured on all three. A limit refuses the keystroke as it is typed rather than trimming the text afterwards, which would put the caret back to the end and lose the one that followed. `clearButton`, `selection` and `onSelectionChange` were removed rather than built.
- [x] **A5. A video ignores everything but its source.** `muted`, `loop`, `autoplay`, `controls`, `volume`, `rate`, `poster` and `onEnd` drive the platform player. The events nothing could report were removed.
- [x] **A6. A web view ignores everything but its content.** `javaScriptEnabled` is honoured. `baseUrl` and the four events were removed rather than built.
- [x] **A7. A control's colours are dropped.** `Switch.onColor/offColor/thumbColor`, `Slider.trackColor/thumbColor` and `ProgressBar.color/trackColor` tint the platform control on all three.
- [x] **A8. A slider and a stepper ignore their step.** Both snap to the step they were given, so a stepper counting in fives never reports a four.
- [x] **A9. Text ignores how it should be cut.** `numberOfLines` is honoured. `ellipsis`, `selectable`, `adjustsFontSizeToFit` and `minimumFontScale` were removed rather than built, so nothing is promised that is not drawn.
- [x] **A10. An image ignores its tint, its fallback and its events.** `tint` and `resizeMode` are honoured on all three. `blurRadius`, `fallback`, `onLoad` and `onError` were removed.
- [x] **A11. What is left is removed rather than kept.** Everything the sweep named that was not worth building is no longer declared, and `docs/components.md` was regenerated from what remains.

## B. Failures that stop the application

- [x] **B1. A commit that fails freezes the application for good.** `Runtime:commit` set `committing` before the work and cleared it after, so an error anywhere in between left it set. `schedule` returns early while it is set, so no later change ever asked for a commit again: `needsCommit()` answered false forever and the screen never moved. One bad render, one refused batch or one missing asset and the application was dead while still running. It runs the build under `pcall` now and restores the flag either way, proven by a component that throws once.
- [x] **B2. A failure at start leaves a blank screen and says nothing.** `launch.start` runs the whole opening on a coroutine, so a failure there reached the engine's log and nowhere a reader could see. It takes an `onProblem`, all three hosts register `gui_problem`, and the iOS, Android and web sample apps each show what they are told.
- [x] **B3. An error from a handler escapes into the host.** `Runtime:dispatch` runs a caller's handler under `pcall` and reports the failure through `onProblem`, so the rest of the frame survives one bad handler and nothing unwinds through the host's own event delivery.
- [x] **B4. Binding an event twice on iOS reports it twice.** `VarnProps.bind` appended a reporter and a gesture recogniser every time it ran, and it runs again whenever a handler appears after being absent. A handler that came and went left one press reporting two, three, four times. A reporter now replaces the one it stands in for and takes back what that one listened through, which is what the web already did.
- [x] **B5. A slider on Android reports a hundredth of what it was dragged to.** The renderer set the SeekBar's `max` from `maximum` and its `progress` from the value times a hundred, so a slider with the default range of nought to one had a travel of one position and reported the position it stood at rather than the value. `VarnSliderView` maps the declared range and step onto the platform's positions and maps back when it reports, and it honours `continuous` and `onCommit` the way iOS does. `renderers/android/src/test/kotlin/dev/varn/gui/SliderTest.kt` covers the range, the step, the position and both ways of reporting.

## C. Code nothing uses

- [x] **C1. `natural.declaredFor`** was called by nothing. It was there for a test that no longer asks.
- [x] **C2. `color.withAlpha`** was called by nothing.
- [x] **C3. `Theme:readableOn`** was called by nothing. `color.readable` stays, since it is `gui.color.readable` in `docs/styling.md` and a component picking its own text colour reaches for it.
- [x] **C4. `gui/components/navigation.lua`** was an empty module the library still required and the reference still rendered an empty table for, left behind when its components became the containers and the presentation family.

## D. Documentation

- [x] **D1. `CLAUDE.md`** carries what this audit establishes as binding: a declaration is a promise a test keeps, a commit that fails does not take the application with it, a failure reaches the host rather than the log, what a handler does is not the runtime's to trust, an overlay is built rather than asked for, and a control reports the number the tree declared.
- [x] **D2. `docs/components.md`** is regenerated from the declarations, and its `Node` column says which components are host nodes and which build themselves out of the others.
- [x] **D3. `docs/bridge.md`** carries a section on what a renderer honours, grouped by what the platform has to be asked for.
- [x] **D4. This page** records what was found and what is left.

## E. What the sweep could not see

Closing the list above did not make the project perfect, and these are the things found while closing it that are worth a change of their own rather than a line in this one.

- [x] **E1. A control that reported nothing on Android.** `bindChange` answered a compound button, a slider and a field. A stepper, a rating, a chooser, a date, a time and a segmented control were built, drawn and never reported `onChange` at all, so touching one of them changed nothing. All six report now, a stepper stays inside the bounds it was given, and a chooser and a segmented control are written to without reporting the write back as a choice. `renderers/android/src/test/kotlin/dev/varn/gui/ControlsTest.kt` covers all of it.
- [x] **E2. A chooser on iOS offered no choice, and a rating could not be set.** `Picker` was a button showing the first option's label and opening nothing, and `Rating` was a label drawn as stars. A chooser opens the platform's own menu and reports the value of what was picked, and a rating is a row of stars that reports the one tapped. `renderers/ios/tests/ControlsTests.swift` covers both, including the write that must not report.
- [x] **E3. Three controls drew as an empty box on the web.** A segmented control, a rating and a stepper have no element behind them, and `segments`, `options` and `count` were declared structural and never applied, so all three drew nothing and reported nothing and a chooser listed no options. The renderer builds each out of parts of its own, and `renderers/web/tests/controls.test.js` covers what they hold, what they report and the rebuild that must replace rather than add.
- [x] **E4. Every slider on the page stood at nought.** A range input counts nought to a hundred in ones until it is told otherwise, and a batch carries its props as a map, so a value of four tenths applied before the step was rounded to nought and stayed there. `minimum`, `maximum` and `step` are applied before the value the way the props that build a control already were, and the shim the suite runs against models the clamp and the step so the case fails without the fix.
- [ ] **E5. The promises tool matches a name, not a component.** A prop is proven kept when anything anywhere reads that name, so an event shared by twenty components is kept by whichever one honours it. That is how E1, E2 and E3 stayed hidden behind a passing suite. It catches a name nothing reads, which is what it was built for, and it cannot catch a component that does not honour a name its neighbour does.
- [ ] **E6. `Icon` has no glyph.** It draws its name as text, since a glyph needs an icon set and which one to ship is a product decision rather than a defect.
- [ ] **E7. The system back gesture does not reach Lua.** Swiping back on iOS and pressing back on Android do not pop a `NavigationStack`.
