import UIKit

/// A box painted with a run of colours, which is what a screen with a header of its own is built on.
final class VarnGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    private var painted: [CGColor] = []
    private var stops: [NSNumber]?

    private var gradient: CAGradientLayer {
        layer as! CAGradientLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setDirection("down")
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func setColors(_ values: [Any]) {
        painted = values.compactMap { VarnStyle.color($0) }.map(\.cgColor)
        gradient.colors = painted
    }

    func setLocations(_ values: [Any]?) {
        stops = values?.compactMap { VarnValue.number($0).map { NSNumber(value: $0) } }
        gradient.locations = stops
    }

    /// Points the run of colour, which is one of a fixed set so the angle is the same everywhere.
    func setDirection(_ value: String?) {
        switch value {
        case "up":
            gradient.startPoint = CGPoint(x: 0.5, y: 1)
            gradient.endPoint = CGPoint(x: 0.5, y: 0)
        case "right":
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
        case "left":
            gradient.startPoint = CGPoint(x: 1, y: 0.5)
            gradient.endPoint = CGPoint(x: 0, y: 0.5)
        case "diagonal":
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
        default:
            gradient.startPoint = CGPoint(x: 0.5, y: 0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        VarnHit.through(super.hitTest(point, with: event), self)
    }
}

/// A box that blurs the screen behind it, which is what a bar over a scrolling page is made of.
///
/// The blur is the system's own material, so it follows the appearance the way every other one does,
/// and the tint is drawn over it for a bar that carries a colour of its own.
final class VarnBlurView: UIView {
    private let effect = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let content = VarnContentView()
    private let wash = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true
        addSubview(effect)
        addSubview(wash)
        addSubview(content)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Answers the view children are added to, which is above the material rather than inside it.
    var contentView: UIView { content }

    func setIntensity(_ value: CGFloat) {
        effect.alpha = min(1, max(0, value))
    }

    func setTint(_ value: String?) {
        wash.backgroundColor = VarnStyle.color(value)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        effect.frame = bounds
        wash.frame = bounds
        content.frame = bounds
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        VarnHit.through(super.hitTest(point, with: event), self)
    }
}

/// A spinner drawn at the size the engine gave it rather than at one of the two the platform has.
///
/// `UIActivityIndicatorView` draws at its own intrinsic size whatever bounds it is put in, so a box of
/// thirty-two points held a twenty point spinner and the size above it drew no larger. It is scaled
/// inside a view of its own, since the node's own transform is written from its style on every commit
/// and anything set on the node would be wiped by the next one.
final class VarnActivityView: UIView {
    private let indicator = UIActivityIndicatorView(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(indicator)
        indicator.startAnimating()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    var animating: Bool {
        get { indicator.isAnimating }

        set {
            if newValue {
                indicator.startAnimating()
                return
            }

            indicator.stopAnimating()
        }
    }

    var color: UIColor? {
        get { indicator.color }
        set { indicator.color = newValue }
    }

    override var intrinsicContentSize: CGSize {
        indicator.intrinsicContentSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let side = min(bounds.width, bounds.height)
        let drawn = indicator.intrinsicContentSize.width

        indicator.transform = .identity
        indicator.center = CGPoint(x: bounds.midX, y: bounds.midY)

        guard drawn > 0, side > 0 else {
            return
        }

        indicator.transform = CGAffineTransform(scaleX: side / drawn, y: side / drawn)
    }
}
