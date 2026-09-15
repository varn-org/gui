import UIKit

/// What a box says about itself to a reader who cannot see it.
///
/// A control the platform draws says all of this for itself. One the engine draws is a box with a colour
/// in it, and that is what a screen reader hears unless the tree says otherwise — so a drawn checkbox
/// that says nothing is a checkbox nobody using VoiceOver can find, let alone tick.
enum VarnAccess {
    /// Answers the traits a role is carried as, since UIKit describes a control by what it behaves like.
    static func traits(_ role: String?) -> UIAccessibilityTraits {
        switch role {
        case "button", "checkbox", "radio", "switch":
            return .button
        case "link":
            return .link
        case "header":
            return .header
        case "image":
            return .image
        case "search":
            return .searchField
        case "slider", "progressbar":
            return .adjustable
        case "tab":
            return [.button, .selected]
        default:
            return .none
        }
    }

    /// Applies what a box is doing, which UIKit says partly in traits and partly in the value.
    ///
    /// There is no trait for being ticked, so a box that is ticked says so the way VoiceOver reads one:
    /// in the value beside the name. A box that cannot be used stops being reachable rather than being
    /// announced and then refusing the touch.
    static func state(_ view: UIView, _ given: [String: Any]?) {
        guard let given else {
            view.accessibilityTraits.remove(.notEnabled)
            view.accessibilityTraits.remove(.selected)
            return
        }

        if let disabled = given["disabled"] as? Bool, disabled {
            view.accessibilityTraits.insert(.notEnabled)
        } else {
            view.accessibilityTraits.remove(.notEnabled)
        }

        if let selected = given["selected"] as? Bool, selected {
            view.accessibilityTraits.insert(.selected)
        } else {
            view.accessibilityTraits.remove(.selected)
        }

        if let checked = given["checked"] as? Bool {
            view.accessibilityValue = checked ? "1" : "0"
        }
    }

    /// Applies what a box that holds a number is at, which is what lets a reader step one by voice.
    static func reading(_ view: UIView, _ given: [String: Any]?) {
        guard let given else {
            return
        }

        if let said = given["text"] as? String {
            view.accessibilityValue = said
            return
        }

        guard let now = VarnValue.number(given["now"]) else {
            return
        }

        let least = VarnValue.number(given["least"])
        let most = VarnValue.number(given["most"])

        if let least, let most, most > least {
            view.accessibilityValue = "\(Int(((now - least) / (most - least)) * 100))%"
            return
        }

        view.accessibilityValue = VarnAccess.said(now)
    }

    /// Answers a number as a reader hears it, which drops a fraction that is not there.
    private static func said(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }

        return String(value)
    }
}
