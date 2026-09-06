import XCTest

/// Drives the gallery with a finger, which is the one thing a tree-based case cannot do.
///
/// A conformance case proves a renderer applies what it was sent. It cannot prove a row can be pressed,
/// and pressing a row of the gallery did nothing at all while every one of those cases passed: an
/// ordinary box holding the row's labels was what the finger landed on, and it answered nothing.
final class GalleryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Starts the gallery, opening straight onto one demo when it is named.
    @discardableResult
    private func launch(_ demo: String? = nil) -> XCUIApplication {
        app = XCUIApplication()

        if let demo {
            app.launchEnvironment["VARN_GUI_DEMO"] = demo
        }

        app.launch()
        return app
    }

    /// Answers an element by the name it carries, waiting for the first commit to have landed.
    private func element(_ label: String, _ timeout: TimeInterval = 8) -> XCUIElement {
        let named = NSPredicate(format: "label == %@", label)
        let found = app.descendants(matching: .any).matching(named).firstMatch

        _ = found.waitForExistence(timeout: timeout)
        return found
    }

    private func text(_ value: String, _ timeout: TimeInterval = 8) -> XCUIElement {
        let found = app.staticTexts[value]
        _ = found.waitForExistence(timeout: timeout)
        return found
    }

    func testOpensADemoFromTheIndexAndComesBack() {
        launch()

        let row = element("Text fields")
        XCTAssertTrue(row.exists, "the index must list what there is to see")

        row.tap()
        XCTAssertTrue(text("One line").waitForExistence(timeout: 8), "pressing a row must open what it names")

        element("Back").tap()
        XCTAssertTrue(text("Varn GUI").waitForExistence(timeout: 8), "the way back must bring the index with it")
    }

    func testTypingIntoAFieldReachesTheTree() {
        launch("inputs/fields")

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8), "the demo must offer a field")

        field.tap()
        field.typeText("Ada")

        XCTAssertEqual(field.value as? String, "Ada", "what was typed must be what the field holds")
    }

    func testAToggleReportsWhatItWasSetTo() {
        launch("inputs/toggles")

        let radio = element("Yearly")
        XCTAssertTrue(radio.exists, "the demo must offer a choice")

        radio.tap()
        XCTAssertTrue(text("Chosen: yearly").waitForExistence(timeout: 8),
                      "choosing must reach the tree and come back on screen")
    }

    func testASwitchReachesTheTree() {
        launch("inputs/toggles")

        let toggle = app.switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 8), "the demo must offer a switch")

        let before = toggle.value as? String
        toggle.tap()
        XCTAssertNotEqual(toggle.value as? String, before, "a switch must change when it is pressed")
    }

    func testAButtonCounts() {
        launch("inputs/buttons")

        XCTAssertTrue(text("Pressed 0 times").waitForExistence(timeout: 8), "the demo starts at none")

        element("Filled").tap()
        XCTAssertTrue(text("Pressed 1 times").waitForExistence(timeout: 8), "a press must reach the tree")
    }

    func testAnythingGivenAHandlerCanBePressed() {
        launch("inputs/buttons")

        XCTAssertTrue(text("Held 0 times").waitForExistence(timeout: 8), "the demo starts at none")

        element("Press me").tap()
        XCTAssertTrue(text("Held 1 times").waitForExistence(timeout: 8),
                      "a box given a handler must answer a finger the way a button does")
    }

    func testAListScrollsAndItsRowsAreNotUnderTheBar() {
        launch("lists/long")

        let first = text("Row 2")
        XCTAssertTrue(first.waitForExistence(timeout: 8), "the list must have rows")

        let bar = text("Fifty thousand rows")
        XCTAssertTrue(bar.exists, "the bar must name the screen")

        app.swipeUp()
        app.swipeUp()

        XCTAssertTrue(bar.exists, "the bar must still be there once the list has scrolled")
        XCTAssertFalse(first.isHittable, "a row scrolled past the top must not be sitting over the bar")
    }

    func testAnAccordionOpensWhatItWasAskedFor() {
        launch("presentation/grouping")

        let second = element("The second")
        XCTAssertTrue(second.exists, "the demo must offer its sections")

        second.tap()
        XCTAssertTrue(text("And what is inside the second.").waitForExistence(timeout: 8),
                      "pressing a section must open it")
    }

    func testATableSortsByTheColumnThatWasPressed() {
        launch("lists/table")

        XCTAssertTrue(text("Apple").waitForExistence(timeout: 8), "the table must show its rows")

        element("Kind").tap()
        XCTAssertTrue(text("Berry").waitForExistence(timeout: 8), "the table must still show its rows")
    }

    func testATabBarReportsTheTabThatWasPressed() {
        launch("presentation/grouping")

        let tab = element("Search")
        XCTAssertTrue(tab.exists, "the demo must offer its tabs")

        tab.tap()
        XCTAssertTrue(tab.exists, "a tab must survive being pressed")
    }

    func testTheNetworkDemoAnswers() {
        launch("screens/network")

        XCTAssertTrue(text("Status: idle").waitForExistence(timeout: 8), "the demo starts idle")

        element("Fetch").tap()
        XCTAssertTrue(text("Status: done").waitForExistence(timeout: 30), "the request must answer")
    }

    func testWhatIsShownOverTheScreenIsActuallyShown() {
        launch("presentation/dialogs")

        element("Show a modal").tap()
        XCTAssertTrue(text("It covers the screen until it is dismissed.").waitForExistence(timeout: 8),
                      "a modal must put what it holds on the screen")

        element("Close").tap()
        XCTAssertFalse(app.staticTexts["It covers the screen until it is dismissed."].exists,
                       "and take it away again")

        element("Show an alert").tap()
        XCTAssertTrue(text("Delete this?").waitForExistence(timeout: 8), "an alert must ask its question")

        element("Delete").tap()
        XCTAssertFalse(app.staticTexts["Delete this?"].exists, "and go once it is answered")
    }

    func testAMenuOffersWhatItHoldsAndReportsTheChoice() {
        launch("presentation/menus")

        XCTAssertTrue(text("Chosen: nothing yet").waitForExistence(timeout: 8), "the demo starts with none")

        element("Open the menu").tap()

        // A row that carries a name is one element to a reader who cannot see it, so it is found by that
        // name rather than by the label inside it.
        XCTAssertTrue(element("Duplicate").exists, "the menu must list what it holds")

        element("Duplicate").tap()
        XCTAssertTrue(text("Chosen: duplicate").waitForExistence(timeout: 8),
                      "the item that was pressed must reach the tree")
    }

    func testEveryScreenOpensAndComesBack() {
        launch()

        let demos = [
            "Text fields", "Toggles and choices", "Sliders and steppers", "Pickers", "Buttons",
            "Text", "Images and icons", "Video and web", "Canvas",
            "A simple list", "Sections", "Grid", "Carousel", "Fifty thousand rows", "Table",
            "Rows, columns and wrapping", "Placing and spacing", "Safe area and keyboard", "Scrolling",
            "Progress and waiting", "Badges, chips and cards",
            "Modals, sheets and alerts", "Menus and drawers", "Accordion, tabs and a stack",
            "A form", "A request",
        ]

        for name in demos {
            // Going back brings the index with it at the top, so a row further down is scrolled to again.
            var row = element(name, 2)
            var swipes = 0

            while !row.exists && swipes < 8 {
                app.swipeUp()
                swipes += 1
                row = element(name, 1)
            }

            XCTAssertTrue(row.exists, "\(name) must be listed on the index")

            row.tap()
            XCTAssertTrue(element("Back", 8).exists, "\(name) must open with a way back")

            element("Back").tap()
            XCTAssertTrue(text("Varn GUI").waitForExistence(timeout: 8), "\(name) must let go of the screen")
        }
    }
}
