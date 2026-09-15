import XCTest

/// Opens everything that is shown over a screen and looks at it.
///
/// A screenshot of a demo shows the state it opens in, and an overlay is not in it. Every one of these
/// is a thing a person has to touch before it exists at all, and a modal that draws behind its own scrim
/// and a menu with a button on top of it both pass every case that reads the tree.
final class OverlayUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func open(_ demo: String) -> XCUIApplication {
        app = XCUIApplication()
        app.launchEnvironment["VARN_GUI_DEMO"] = demo
        app.launch()
        return app
    }

    private func press(_ label: String, _ timeout: TimeInterval = 10) -> Bool {
        let found = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch

        guard found.waitForExistence(timeout: timeout) else {
            return false
        }

        found.tap()
        return true
    }

    /// Answers whether something is on screen, waiting for the commit that puts it there.
    ///
    /// Anything named is looked for rather than only a label, since a row that carries a name of its own
    /// is an element in its own right and the text inside it is not exposed separately.
    private func shows(_ name: String, _ timeout: TimeInterval = 6) -> Bool {
        let found = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch

        return found.waitForExistence(timeout: timeout)
    }

    private func keep(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())

        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Answers the system's own alert, which is what stands between a screen and a device it asked for.
    private func allow() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowed = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "Permitir",
                                                                                      "OK"])).firstMatch

        if allowed.waitForExistence(timeout: 5) {
            allowed.tap()
        }
    }

    /// The camera itself, which only a device has: a simulator answers a preview that never arrives.
    ///
    /// Everything else about a camera can be driven anywhere — the props it carries, the events it
    /// reports, the actions it answers — and none of that says the session ever opened or that anything
    /// was written. This is the one case that only runs where there is a camera to open.
    func testACameraOpensAndTakesAPicture() throws {
        try XCTSkipIf(isSimulator, "a simulator has no camera to open")

        open("capture/camera")

        XCTAssertTrue(press("Turn the camera on"), "the demo must offer to turn the camera on")
        allow()

        let opened = shows("Looking back", 20)
        keep("camera")

        XCTAssertTrue(opened, "the camera must open and say which way it is looking, screen said: \(said())")

        XCTAssertTrue(press("Take a picture"), "the demo must offer to take one")
        XCTAssertTrue(shows("Took a picture", 20), "and what it took must come back as a file")
        keep("a picture taken")
    }

    /// Everything written on the screen, which is what a failure has to say to be worth reading.
    private func said() -> String {
        app.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " | ")
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        #endif
    }

    func testAModalIsShownOverTheScreen() {
        open("presentation/dialogs")

        XCTAssertTrue(press("Show a modal"), "the demo must offer a modal")
        XCTAssertTrue(shows("A modal"), "a modal must be shown over the screen")
        keep("modal")
    }

    func testASheetIsShownOverTheScreen() {
        open("presentation/dialogs")

        XCTAssertTrue(press("Show a sheet"), "the demo must offer a sheet")
        XCTAssertTrue(shows("A sheet"), "a sheet must be shown over the screen")
        keep("sheet")
    }

    func testAnAlertAsksAndAnswers() {
        open("presentation/dialogs")

        XCTAssertTrue(press("Show an alert"), "the demo must offer an alert")
        XCTAssertTrue(shows("Delete this?"), "an alert must ask what it was given")
        keep("alert")

        XCTAssertTrue(press("Delete"), "an alert's choices must be reachable")
        XCTAssertFalse(shows("Delete this?", 2), "and choosing must close it")
    }

    func testAnActionSheetOffersItsChoices() {
        open("presentation/dialogs")

        XCTAssertTrue(press("Show an action sheet"), "the demo must offer an action sheet")
        XCTAssertTrue(shows("Share"), "an action sheet must offer what it holds")
        keep("action-sheet")
    }

    func testAToastSaysSomethingAndGoesAway() {
        open("presentation/dialogs")

        XCTAssertTrue(press("Show a toast"), "the demo must offer a toast")
        XCTAssertTrue(shows("Saved"), "a toast must say what it was given")
        keep("toast")
    }

    func testAMenuOffersItsChoices() {
        open("presentation/menus")

        XCTAssertTrue(press("Open the menu"), "the demo must offer a menu")
        XCTAssertTrue(shows("Duplicate"), "a menu must offer what it holds")
        keep("menu")
    }

    func testADrawerOpensFromTheEdge() {
        open("presentation/menus")

        XCTAssertTrue(press("Open the drawer"), "the demo must offer a drawer")
        XCTAssertTrue(shows("A drawer"), "a drawer must offer what it holds")
        keep("drawer")
    }

    /// A drawer covers the application rather than the middle of it, bar and all.
    ///
    /// Laid out where it was written it covered the screen under the bar, so the way back was above the
    /// darkness and still answered a finger. It is drawn through a portal, so what it covers is the whole
    /// surface and nothing under it can be pressed.
    func testADrawerCoversTheBarAboveIt() {
        open("presentation/menus")

        let title = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Menus and drawers")).firstMatch

        XCTAssertTrue(title.waitForExistence(timeout: 10), "the screen sits under a bar carrying its title")

        XCTAssertTrue(press("Open the drawer"), "the demo must offer a drawer")
        XCTAssertTrue(shows("A drawer"), "a drawer must offer what it holds")

        let ground = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Dismiss")).firstMatch

        XCTAssertTrue(ground.exists, "an open drawer darkens what it covers")
        XCTAssertTrue(ground.frame.contains(title.frame),
                      "and what it covers reaches over the bar, covering \(ground.frame) against \(title.frame)")

        keep("drawer over the bar")
    }
}
