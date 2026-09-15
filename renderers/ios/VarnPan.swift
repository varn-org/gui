import UIKit

/// A drag that claims one axis and leaves the other to whatever is scrolling underneath.
///
/// A `UIScrollView` holds a touch to see whether it is a scroll before anything else gets it, so a
/// recogniser that says nothing loses every drag inside a list. Refusing to run alongside a scroll along
/// the axis this box claims is what makes a slider inside a list draggable sideways while the list still
/// scrolls down.
final class VarnPanRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate {
    var axis: String?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delegate = self
    }

    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        other is UIPanGestureRecognizer == false
    }

    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
        false
    }

    /// Takes the drag from the surface underneath, along the axis this box said it wanted.
    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer,
        shouldRequireFailureOf other: UIGestureRecognizer
    ) -> Bool {
        false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        guard state == .began || state == .changed, let axis, let view else {
            return
        }

        let travelled = translation(in: view)

        // A drag that has gone the other way is not this box's, so it is given up and the surface under
        // it takes the touch — which is a finger meant for the list that started on the slider.
        if axis == "horizontal" && abs(travelled.y) > abs(travelled.x) * 2 {
            state = .cancelled
        }

        if axis == "vertical" && abs(travelled.x) > abs(travelled.y) * 2 {
            state = .cancelled
        }
    }
}
