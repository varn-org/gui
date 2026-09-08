import UIKit

/// The area the system draws its own bars over, which is the one view that says how they are drawn.
///
/// The request belongs to the view rather than to the process, so an area that goes takes it with it and
/// the window falls back to the style the system would have chosen. Without that, a screen asking for
/// light glyphs on its dark bar leaves them light over the white one that replaced it.
///
/// It is given up when the view is released rather than when it leaves its superview, since the renderer
/// moves a view between parents and a screen that is only being reparented has not gone anywhere.
final class VarnSafeAreaView: UIView {
    private weak var host: UIWindow?

    deinit {
        VarnSystemBars.release(ObjectIdentifier(self))
        host?.rootViewController?.setNeedsStatusBarAppearanceUpdate()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        VarnHit.through(super.hitTest(point, with: event), self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        host = window
    }

    func setBarContent(_ value: String?) {
        VarnSystemBars.claim(value, by: ObjectIdentifier(self))
        window?.rootViewController?.setNeedsStatusBarAppearanceUpdate()
    }
}
