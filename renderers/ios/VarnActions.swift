import UIKit

/// Performs the imperative action a ref asked for, refusing a name the renderer has no answer for.
enum VarnActions {
    static func perform(_ method: String, on view: UIView, arguments: [String: Any]) throws -> Bool {
        switch method {
        case "focus":
            return view.becomeFirstResponder()

        case "blur":
            return view.resignFirstResponder()

        case "scrollTo":
            guard let scroll = view as? UIScrollView else {
                throw RendererError.missing("scrollTo needs a scrolling view")
            }

            let point = CGPoint(x: VarnValue.number(arguments["x"]) ?? 0, y: VarnValue.number(arguments["y"]) ?? 0)
            scroll.setContentOffset(point, animated: arguments["animated"] as? Bool ?? false)
            return true

        case "play":
            (view as? VarnVideoView)?.player.play()
            return true

        case "pause":
            (view as? VarnVideoView)?.player.pause()
            return true

        default:
            throw RendererError.missing("the renderer has no action named \(method)")
        }
    }
}
