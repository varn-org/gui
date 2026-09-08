import XCTest

/// Opens everything that is shown over a screen and looks at it.
///
/// A screenshot of a demo shows the state it opens in, and an overlay is not in it. Every one of these
/// is a thing a person has to touch before it exists at all, which is why none of them had been looked
/// at: a modal that draws behind its own scrim and a menu with a button on top of it both pass every
/// case that reads the tree.
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
}
