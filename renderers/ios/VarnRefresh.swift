import ObjectiveC
import UIKit

/// Puts the platform's own pull to refresh on a scroll view, and reports when it is pulled.
///
/// Pull to refresh belongs to whatever owns the scrolling gesture, so it is attached to the surface a
/// list or a scroll view already has rather than being a widget of its own that nobody could pull.
enum VarnRefresh {
    private final class Reporter: NSObject {
        let report: () -> Void

        init(report: @escaping () -> Void) {
            self.report = report
        }

        @objc func pulled() {
            report()
        }
    }

    private static var reporterKey: UInt8 = 0

    static func control(on view: UIView) -> UIRefreshControl? {
        guard let scroll = view as? UIScrollView else {
            return nil
        }

        if let existing = scroll.refreshControl {
            return existing
        }

        let control = UIRefreshControl()
        scroll.refreshControl = control
        return control
    }

    /// Says what to call when the surface is pulled past the point the platform reports at.
    static func onPull(_ view: UIView, _ report: @escaping () -> Void) {
        guard let control = control(on: view) else {
            return
        }

        let reporter = Reporter(report: report)

        // A target is not retained by the control it is added to, so the control is given the reporter
        // to hold. A table keyed by the view's address outlives the view and is handed to the next one
        // allocated there, and nothing ever emptied it.
        objc_setAssociatedObject(control, &reporterKey, reporter, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        control.removeTarget(nil, action: nil, for: .valueChanged)
        control.addTarget(reporter, action: #selector(Reporter.pulled), for: .valueChanged)
    }

    /// Shows or takes away the spinner, which is what the tree says is happening rather than the finger.
    static func show(_ refreshing: Bool, on view: UIView) {
        guard let control = control(on: view) else {
            return
        }

        if refreshing {
            control.beginRefreshing()
            return
        }

        control.endRefreshing()
    }
}

/// How the system draws the content of its own bars, which is the tree's to decide and the host's to answer.
///
/// A status bar's clock is drawn by the system over whatever the application put behind it, and only the
/// view controller that owns the window may say whether it is drawn light or dark. The tree says which it
/// wants here and the host reads it, the same way a host forwards the back gesture.
enum VarnSystemBars {
    private static var owner: ObjectIdentifier?
    private static var wanted: String?

    /// Records what one area asks for, which stands until that area asks for something else or leaves.
    static func claim(_ content: String?, by claimant: ObjectIdentifier) {
        guard let content else {
            release(claimant)
            return
        }

        owner = claimant
        wanted = content
    }

    /// Gives up what an area asked for, so a screen that has gone does not decide what is over the next one.
    static func release(_ claimant: ObjectIdentifier) {
        guard owner == claimant else {
            return
        }

        owner = nil
        wanted = nil
    }

    /// Answers the style the window should draw its bars in, or the one the system would have chosen.
    ///
    /// A tree that asks for nothing gets `.default`, which UIKit already reads from the appearance, so
    /// light and dark follow the device with nothing in the tree restating it.
    public static var style: UIStatusBarStyle {
        switch wanted {
        case "light": return .lightContent
        case "dark": return .darkContent
        default: return .default
        }
    }
}
