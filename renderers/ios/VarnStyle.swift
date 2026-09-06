import UIKit

/// Turns the resolved style a commit carries into the UIKit properties that draw it.
///
/// Nothing here decides anything. A colour arrives as eight hex digits and a size as a number, both
/// already resolved against the theme, so this file only assigns.
enum VarnStyle {
    static func color(_ value: Any?) -> UIColor? {
        guard let text = value as? String, text.hasPrefix("#") else {
            return nil
        }

        var digits = String(text.dropFirst())
        if digits.count == 6 {
            digits += "ff"
        }

        guard digits.count == 8, let packed = UInt32(digits, radix: 16) else {
            return nil
        }

        return UIColor(
            red: CGFloat((packed >> 24) & 0xff) / 255,
            green: CGFloat((packed >> 16) & 0xff) / 255,
            blue: CGFloat((packed >> 8) & 0xff) / 255,
            alpha: CGFloat(packed & 0xff) / 255
        )
    }

    static func font(from style: [String: Any]) -> UIFont {
        let size = VarnValue.number(style["fontSize"]) ?? 15
        let weight = self.weight(style["fontWeight"])

        if let family = style["fontFamily"] as? String,
           let descriptor = UIFont(name: family, size: size) {
            return descriptor
        }

        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    static func weight(_ value: Any?) -> UIFont.Weight {
        switch value as? String {
        case "100": return .ultraLight
        case "200": return .thin
        case "300": return .light
        case "500": return .medium
        case "600": return .semibold
        case "700": return .bold
        case "800": return .heavy
        case "900": return .black
        default: return .regular
        }
    }

    /// Answers a box property given as one value, a pair, or a value per edge, the way the engine reads it.
    ///
    /// A control that draws its own text is not laid out by the engine on the inside, so the padding
    /// around that text is the renderer's to apply. Everything else takes it as a layout inset already.
    static func edges(_ style: [String: Any], _ name: String) -> UIEdgeInsets {
        var box = UIEdgeInsets.zero

        if let whole = VarnValue.number(style[name]) {
            box = UIEdgeInsets(top: whole, left: whole, bottom: whole, right: whole)
        }

        if let horizontal = VarnValue.number(style["\(name)Horizontal"]) {
            box.left = horizontal
            box.right = horizontal
        }

        if let vertical = VarnValue.number(style["\(name)Vertical"]) {
            box.top = vertical
            box.bottom = vertical
        }

        box.top = VarnValue.number(style["\(name)Top"]) ?? box.top
        box.right = VarnValue.number(style["\(name)Right"]) ?? box.right
        box.bottom = VarnValue.number(style["\(name)Bottom"]) ?? box.bottom
        box.left = VarnValue.number(style["\(name)Left"]) ?? box.left

        return box
    }

    /// Answers the corner radius a box may actually be drawn with, which is never more than it can hold.
    ///
    /// A pill is written as a radius larger than any box it could sit in, and a layer whose radius
    /// exceeds half its own bounds draws nothing at all rather than drawing a pill.
    static func cornerRadius(_ radius: CGFloat, in size: CGSize) -> CGFloat {
        let limit = min(size.width, size.height) / 2

        if limit <= 0 {
            return radius
        }

        return min(radius, limit)
    }

    /// Answers whether a view has to keep what it holds inside its own bounds.
    ///
    /// A scrolling view always does: its content is laid out past the edge by definition, and a view
    /// only receives a touch inside its own bounds, so content drawn outside one is content that
    /// overlaps whatever is above it on screen and cannot be pressed. A rounded box and a picture that
    /// fills its frame draw outside it too, so those clip whatever the overflow says.
    static func clips(_ style: [String: Any], _ view: UIView, radius: CGFloat) -> Bool {
        if view is UIScrollView || view is UIImageView {
            return true
        }

        return (style["overflow"] as? String) == "hidden" || radius > 0
    }

    static func apply(_ style: [String: Any], to view: UIView, type: String) {
        view.backgroundColor = color(style["background"]) ?? .clear
        view.alpha = VarnValue.number(style["opacity"]) ?? 1

        let radius = cornerRadius(VarnValue.number(style["radius"]) ?? 0, in: view.bounds.size)

        view.clipsToBounds = clips(style, view, radius: radius)

        view.layer.cornerRadius = radius
        view.layer.borderWidth = VarnValue.number(style["border"]) ?? 0
        view.layer.borderColor = color(style["borderColor"])?.cgColor

        applyShadow(style["shadow"] as? [String: Any], to: view)
        applyText(style, to: view, type: type)
        applyTransform(style["transform"], to: view)
    }

    private static func applyShadow(_ shadow: [String: Any]?, to view: UIView) {
        guard let shadow else {
            view.layer.shadowOpacity = 0
            return
        }

        view.layer.shadowColor = (color(shadow["color"]) ?? .black).cgColor
        view.layer.shadowRadius = VarnValue.number(shadow["radius"]) ?? 0
        view.layer.shadowOffset = CGSize(width: 0, height: VarnValue.number(shadow["offsetY"]) ?? 0)
        view.layer.shadowOpacity = 1
    }

    private static func applyText(_ style: [String: Any], to view: UIView, type: String) {
        let foreground = color(style["color"])
        let padding = edges(style, "padding")

        if let holder = view as? VarnLabelView {
            holder.label.font = font(from: style)
            holder.label.textColor = foreground ?? .label
            holder.insets = padding
            return
        }

        if let rating = view as? VarnRatingView {
            rating.paint(font(from: style), foreground ?? .systemOrange)
            return
        }

        if let label = view as? UILabel {
            label.font = font(from: style)
            label.textColor = foreground ?? .label
            label.textAlignment = alignment(style["textAlign"])
            label.numberOfLines = style["numberOfLines"] as? Int ?? 0
            return
        }

        if let field = view as? VarnTextField {
            field.font = font(from: style)
            field.textColor = foreground ?? .label
            field.textAlignment = alignment(style["textAlign"])
            field.insets = padding
            return
        }

        if let text = view as? UITextView {
            text.font = font(from: style)
            text.textColor = foreground ?? .label
            text.textContainerInset = padding
            text.textContainer.lineFragmentPadding = 0
            return
        }

        if let button = view as? UIButton {
            button.titleLabel?.font = font(from: style)
            button.setTitleColor(foreground ?? .tintColor, for: .normal)
            button.contentEdgeInsets = padding
        }
    }

    private static func alignment(_ value: Any?) -> NSTextAlignment {
        switch value as? String {
        case "center": return .center
        case "right": return .right
        case "justify": return .justified
        default: return .natural
        }
    }

    private static func applyTransform(_ value: Any?, to view: UIView) {
        guard let transform = value as? [String: Any] else {
            view.transform = .identity
            return
        }

        let number = { (name: String, fallback: CGFloat) -> CGFloat in
            VarnValue.number(transform[name]) ?? fallback
        }

        var result = CGAffineTransform.identity
        result = result.translatedBy(x: number("translateX", 0), y: number("translateY", 0))
        result = result.scaledBy(x: number("scaleX", 1), y: number("scaleY", 1))
        result = result.rotated(by: number("rotate", 0) * .pi / 180)

        view.transform = result
    }
}
