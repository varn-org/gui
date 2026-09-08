import UIKit

/// Drives a change over time rather than applying it between two frames.
///
/// The engine sends the state a node settles at and how long it should take to get there, so nothing
/// here decides what moves or how far. A curve arrives as its four control points, which is what
/// `UIViewPropertyAnimator` takes, so a name never has to mean the same thing in three places.
enum VarnMotion {
    struct Timing {
        let duration: TimeInterval
        let delay: TimeInterval
        let first: CGPoint
        let second: CGPoint
    }

    static func timing(_ value: Any?) -> Timing? {
        guard let carried = value as? [String: Any] else {
            return nil
        }

        let duration = TimeInterval(VarnValue.number(carried["duration"]) ?? 0) / 1000
        guard duration > 0 else {
            return nil
        }

        let easing = carried["easing"] as? [Any] ?? []
        let point = { (at: Int) -> CGFloat in
            at < easing.count ? (VarnValue.number(easing[at]) ?? 0) : 0
        }

        return Timing(
            duration: duration,
            delay: TimeInterval(VarnValue.number(carried["delay"]) ?? 0) / 1000,
            first: CGPoint(x: point(0), y: point(1)),
            second: CGPoint(x: point(2), y: point(3))
        )
    }

    static func animate(_ timing: Timing, _ changes: @escaping () -> Void) {
        let animator = UIViewPropertyAnimator(
            duration: timing.duration,
            controlPoint1: timing.first,
            controlPoint2: timing.second,
            animations: changes
        )

        animator.startAnimation(afterDelay: timing.delay)
    }

    /// Puts a node on screen in the state it arrives from and moves it to the one it settles at.
    ///
    /// The arrival is drawn a frame after the node is placed, since a view animated before it has a
    /// superview and a frame has nothing to animate from.
    static func arrive(
        _ view: UIView,
        entering: [String: Any],
        settled: [String: Any],
        type: String,
        timing: Timing
    ) {
        var start = settled

        for (key, value) in entering {
            start[key] = value
        }

        VarnStyle.apply(start, to: view, type: type)

        DispatchQueue.main.async {
            animate(timing) {
                VarnStyle.apply(settled, to: view, type: type)
            }
        }
    }
}
