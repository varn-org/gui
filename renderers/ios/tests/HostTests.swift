import XCTest
import UIKit
@testable import VarnGUIRenderer

/// What the host sets up around the surface, and what it gives back when it is finished with it.
///
/// A host event is delivered by the engine's loop rather than in place, so a tree only comes down on a
/// tick, and what was set up to watch the window outlives the surface unless it is taken off.
final class HostTests: XCTestCase {
    /// Stands in for the engine, keeping every call in the order it was made.
    private final class Engine: VarnRuntimeDriving {
        var calls: [String] = []
        var registered: [String] = []

        @discardableResult func register(_ name: String, _ handler: @escaping (String) -> String?) -> Bool {
            registered.append(name)
            return true
        }

        @discardableResult func emit(_ name: String, _ jsonArgument: String) -> Bool {
            calls.append("emit:\(name)")
            return true
        }

        @discardableResult func load(source: String, chunkName: String) -> Int32 {
            calls.append("load")
            return 0
        }

        @discardableResult func poll() -> Bool {
            calls.append("poll")
            return true
        }
    }

    private var surface: UIView!
    private var engine: Engine!
    private var host: VarnGUIHost!

    override func setUp() {
        super.setUp()

        surface = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        engine = Engine()
        host = VarnGUIHost(runtime: engine, surface: surface)

        try? host.start(
            archive: URL(fileURLWithPath: "/archive.vap"),
            framework: URL(fileURLWithPath: "/framework"),
            cache: URL(fileURLWithPath: "/cache")
        )
    }

    override func tearDown() {
        host = nil
        super.tearDown()
    }

    /// The tree comes down on a tick, so the pump has to be given one before it is taken away.
    func testStoppingDeliversTheTreeComingDown() {
        engine.calls.removeAll()
        host.stop()

        let stopped = engine.calls.firstIndex(of: "emit:gui.stop")
        let polled = engine.calls.firstIndex(of: "poll")

        XCTAssertNotNil(stopped, "the host says it is finished: \(engine.calls)")
        XCTAssertNotNil(polled, "and the loop is given a tick: \(engine.calls)")
        XCTAssertTrue(polled! > stopped!, "the tick comes after it is said: \(engine.calls)")
    }

    /// A notification is keyed by the token the observer answered, never by the object that took it.
    func testWhatWatchesTheWindowIsGivenBackWithIt() {
        host.stop()
        engine.calls.removeAll()

        NotificationCenter.default.post(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: CGRect(x: 0, y: 500, width: 390, height: 344)]
        )

        XCTAssertEqual(engine.calls, [], "a stopped host reports nothing more")
        XCTAssertEqual(surface.gestureRecognizers ?? [], [], "and the surface is left as it was found")
    }

    /// Everything the engine may call is there before the application that calls it is loaded.
    func testTheCallsAreRegisteredBeforeTheApplicationIsLoaded() {
        XCTAssertTrue(engine.registered.contains("gui_apply"), "the batch is applied through the host")
        XCTAssertTrue(engine.registered.contains("gui_surface"), "the surface is described to it")
        XCTAssertEqual(engine.calls.filter { $0 == "load" }.count, 1, "and the application is loaded once")
    }
}
