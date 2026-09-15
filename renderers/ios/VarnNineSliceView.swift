import UIKit

/// A box painted with a picture cut into nine, which is what a frame drawn from artwork is.
///
/// The platform has this already: a layer told where the middle of its contents is keeps the four corners
/// at their own size, stretches each edge along one axis and stretches the middle both ways. Drawing the
/// pieces by hand would be the same picture a commit later, since the layer resizes with the view and
/// nothing here has to hear about it.
///
/// It is a control rather than a plain view because a frame is how a button is drawn from artwork, and
/// the platform reports the two edges of a press through a control and through nothing else. A plain
/// view is told a press happened once the finger has already lifted, so a frame that goes down when it
/// is held would go down as it was let go.
final class VarnNineSliceView: UIControl {
    private var picture: UIImage?
    private var perState: [String: UIImage] = [:]
    private var cuts = UIEdgeInsets.zero
    private var drawnAt: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)

        layer.contentsGravity = .resize
        // The pieces are drawn without smoothing, the way the other two draw them: a frame is artwork,
        // and a two-pixel rule drawn larger and smoothed comes out as a smear rather than a rule.
        layer.magnificationFilter = .nearest
        layer.minificationFilter = .nearest
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func setSource(_ image: UIImage?) {
        picture = image
        redraw()
    }

    /// Takes the artwork a state is drawn with, which is what makes a frame a button that presses.
    func setSources(_ pictures: [String: UIImage]) {
        perState = pictures
        redraw()
    }

    /// Answers the artwork for how the control is now, which is the plain one where there is none of its own.
    private var drawing: UIImage? {
        if !isEnabled, let held = perState["disabled"] {
            return held
        }

        if isHighlighted, let held = perState["pressed"] {
            return held
        }

        if isFocused, let held = perState["focused"] {
            return held
        }

        return picture
    }

    override var isHighlighted: Bool {
        didSet { redraw() }
    }

    override var isEnabled: Bool {
        didSet { redraw() }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        redraw()
    }

    func setSlice(_ insets: UIEdgeInsets) {
        cuts = insets
        redraw()
    }

    /// Says how many points one pixel of the border comes out at, which is what sets how thick it reads.
    func setSliceScale(_ scale: CGFloat) {
        drawnAt = scale
        redraw()
    }

    /// A picture cut wider than itself has nothing left in the middle to stretch, so it draws as itself.
    private func redraw() {
        guard let drawn = drawing?.cgImage else {
            layer.contents = nil
            return
        }

        let width = CGFloat(drawn.width)
        let height = CGFloat(drawn.height)

        guard width > cuts.left + cuts.right, height > cuts.top + cuts.bottom else {
            layer.contents = drawn
            layer.contentsCenter = CGRect(x: 0, y: 0, width: 1, height: 1)
            layer.contentsScale = 1 / drawnAt
            return
        }

        layer.contents = drawn
        layer.contentsCenter = CGRect(
            x: cuts.left / width,
            y: cuts.top / height,
            width: (width - cuts.left - cuts.right) / width,
            height: (height - cuts.top - cuts.bottom) / height
        )

        // A layer draws its contents at one pixel per `contentsScale` points and keeps the pieces outside
        // the middle at that size, so this is what decides how thick the border comes out.
        layer.contentsScale = 1 / drawnAt
    }
}
