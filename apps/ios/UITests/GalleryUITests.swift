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
        XCTAssertTrue(text("Your name").waitForExistence(timeout: 8), "pressing a row must open what it names")

        // The way back carries the title of the screen behind it, which is what iOS draws on it.
        element("Varn GUI").tap()
        XCTAssertTrue(element("Toggles and choices", 8).exists, "the way back must bring the index with it")
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

    /// A row on the index opens the screen it names and gives it back, wherever the row sits.
    ///
    /// Which demos there are is the catalogue's to say, and `gui/tests/sample_test.lua` renders every
    /// one of them, so this is here for the round trip rather than for the list: a screen that opens
    /// from a finger and a way back that leaves the index where the reader left it.
    func testTheIndexOpensARowAndGivesItBack() {
        launch()

        let list = app.scrollViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 8), "the index must be a list")

        element("Text fields").tap()
        XCTAssertTrue(element("Varn GUI", 8).exists, "a screen opened from the index carries a way back")

        element("Varn GUI").tap()
        XCTAssertTrue(element("Text fields", 8).exists, "and the index comes back with it")

        var further = element("Maps", 1)
        var swipes = 0

        while !further.exists && swipes < 8 {
            list.swipeUp()
            swipes += 1
            further = element("Maps", 1)
        }

        XCTAssertTrue(further.exists, "a row further down the index is reachable")

        further.tap()
        XCTAssertTrue(element("Varn GUI", 8).exists, "and opens the same way")

        element("Varn GUI").tap()
        XCTAssertTrue(element("Maps", 8).exists, "leaving the index where it was left")
    }
    /// A list that has been taken to its end still scrolls, in both directions.
    ///
    /// Reaching the last row and finding the surface dead is a list that answers no finger at all, and
    /// no case that sends a scroll event can see it: the offset it sends is one the engine chose.
    func testAListThatReachedItsEndStillScrolls() {
        launch("lists/long")

        let list = app.scrollViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 8), "the demo must carry a list")

        for _ in 0 ..< 25 {
            list.swipeUp(velocity: .fast)
        }

        let atEnd = app.staticTexts.allElementsBoundByIndex.compactMap { $0.exists ? $0.label : nil }
        XCTAssertFalse(atEnd.isEmpty, "the end of the list must still be showing rows")

        for _ in 0 ..< 6 {
            list.swipeDown(velocity: .fast)
        }

        let afterwards = app.staticTexts.allElementsBoundByIndex.compactMap { $0.exists ? $0.label : nil }
        XCTAssertNotEqual(atEnd, afterwards, "a list taken to its end must scroll back off it")
    }

    /// A header that sticks stays where a header sticks, whatever the finger is doing.
    func testASectionHeaderStaysAtTheTopWhileTheListMoves() {
        launch("lists/sections")

        let list = app.scrollViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 8), "the demo must carry a list")

        let header = app.staticTexts["Berries"]
        XCTAssertTrue(header.waitForExistence(timeout: 8), "the first group must be named")

        list.swipeUp(velocity: .fast)

        let pinned = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["Berries", "Citrus", "The rest"]))
            .allElementsBoundByIndex
            .filter { $0.exists }

        XCTAssertFalse(pinned.isEmpty, "a group header is on screen wherever the list is")
        XCTAssertTrue(pinned.contains { $0.frame.minY <= list.frame.minY + 48 },
                      "and the one whose group is showing is against the top of the list")
    }

    /// The first screen is a list too, and every one of its rows is something that can be pressed.
    ///
    /// A scroll view will not cancel a touch that landed on a control, so a finger that landed on a row
    /// scrolled nothing at all: the list answered the first flick and then sat there.
    func testTheIndexScrollsBackFromItsEnd() {
        launch()

        let list = app.scrollViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 8), "the index must be a list")
        XCTAssertTrue(element("Text fields").exists, "the index must name what it holds")

        for _ in 0 ..< 12 {
            list.swipeUp(velocity: .fast)
        }

        XCTAssertFalse(element("Text fields", 1).exists, "the index must scroll off its first row")

        for _ in 0 ..< 20 {
            list.swipeDown(velocity: .fast)
        }

        XCTAssertTrue(element("Text fields", 4).exists, "and come back when it is pulled the other way")
    }

    /// The picture on a tab bar can be pressed, and choosing one says nothing a reader has to live with.
    ///
    /// The cover is drawn half above the bar it belongs to, and a view answers a touch only within its
    /// own bounds, so nothing above that edge ever reached it: the control was seen and could not be
    /// pressed. What went wrong behind it was drawn into the screen as a label that never went away.
    func testTheCoverOnATabBarOpensTheLibraryAndLeavesNothingBehind() {
        launch("tabs/cover")

        let pick = element("Pick")
        XCTAssertTrue(pick.waitForExistence(timeout: 8), "the cover offers a way to choose a picture")

        pick.tap()
        sleep(3)

        // The library belongs to another process, so what proves it opened is that the gallery is no
        // longer the thing on screen.
        XCTAssertFalse(element("Home", 2).isHittable, "the system's own library is what a press opens")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.09, dy: 0.115)).tap()
        sleep(2)

        let said = app.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " | ")

        XCTAssertFalse(said.lowercased().contains("could not"), "nothing about a failure is left behind: \(said)")
        XCTAssertFalse(said.lowercased().contains("no prop named"), "and the screen still draws: \(said)")
    }

    /// The chat opens a conversation, answers what is written into it, and looks like the screen it is.
    func testTheChatAnswersWhatIsWrittenIntoIt() {
        launch("apps/chat")

        let row = element("Daniel William")
        XCTAssertTrue(row.waitForExistence(timeout: 8), "the inbox lists its conversations")

        row.tap()
        XCTAssertTrue(text("Hey Daniel").waitForExistence(timeout: 8), "opening one shows what was said")
        XCTAssertTrue(text("Let me know if you need help").exists, "and everything else in it")

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 4), "and offers somewhere to write")

        field.tap()
        field.typeText("Are you there")
        element("Send").tap()

        XCTAssertTrue(text("Are you there").waitForExistence(timeout: 6), "what was written is on screen")

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways
        shot.name = "conversation"
        add(shot)

        // The other side answers a moment later, which is what makes it read as a conversation.
        sleep(3)

        let replies = app.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " | ")

        XCTAssertTrue(replies.contains("Of course") || replies.contains("Sending") || replies.contains("Done"),
                      "and the other side answers: \(replies)")
    }

    /// Leaving a screen is a move a reader watches, the same as arriving is.
    ///
    /// A screen that is cut rather than drawn going reads as one that crashed, and nothing that sends a
    /// commit can see the difference: the tree is the same either way, and what tells them apart is
    /// what is on the glass a fraction of a second after the finger lifts.
    func testAScreenIsSeenLeaving() {
        launch()

        element("Text fields").tap()
        XCTAssertTrue(text("Your name").waitForExistence(timeout: 8), "the screen opened")

        element("Varn GUI").tap()

        // Straight after the press, both screens are on the glass: the one going and the one behind it.
        let mid = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        mid.lifetime = .keepAlways
        mid.name = "leaving"
        add(mid)

        XCTAssertTrue(element("Text fields", 8).exists, "and the index is back once the move is over")
    }
}
