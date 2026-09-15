import UIKit

/// A view that reports a key it was given, which is what a key event reaches on this platform.
///
/// UIKit delivers a key press up the responder chain from whatever has focus, so a view is told about
/// one only while it is the first responder. That is the same contract the other two platforms have and
/// the one the tree is written to: a key reaches whatever has focus.
protocol VarnKeyed: UIResponder {
    var onKey: ((String, [String: Any]) -> Void)? { get set }
}

/// A view that says when the keyboard has reached it and when it has gone.
///
/// A control the platform draws paints its own focus ring. One the engine draws cannot, since nothing
/// told it, and using a keyboard is then a reader pressing keys at a screen that never says where they
/// are. `wanted` is what makes a box a stop on the way through at all.
protocol VarnFocusing: UIView {
    var onFocusChange: ((Bool) -> Void)? { get set }
    var wanted: Bool { get set }
}

/// The name each key is reported under, which is the one published set of names for them.
///
/// A browser names a key in `KeyboardEvent.key`, iOS gives a HID usage and Android a key code, and the
/// three agree about nothing. The browser's names are what the tree reads, so the other two are mapped
/// onto them rather than each reporting whatever its own platform calls a key.
enum VarnKeys {
    private static let named: [UIKeyboardHIDUsage: String] = [
        .keyboardReturnOrEnter: "Enter",
        .keypadEnter: "Enter",
        .keyboardEscape: "Escape",
        .keyboardTab: "Tab",
        .keyboardDeleteOrBackspace: "Backspace",
        .keyboardDeleteForward: "Delete",
        .keyboardSpacebar: " ",
        .keyboardUpArrow: "ArrowUp",
        .keyboardDownArrow: "ArrowDown",
        .keyboardLeftArrow: "ArrowLeft",
        .keyboardRightArrow: "ArrowRight",
        .keyboardHome: "Home",
        .keyboardEnd: "End",
        .keyboardPageUp: "PageUp",
        .keyboardPageDown: "PageDown",
    ]

    /// Answers what one key is called and what was held down with it.
    static func payload(of key: UIKey) -> [String: Any] {
        let flags = key.modifierFlags

        return [
            "key": named[key.keyCode] ?? (key.charactersIgnoringModifiers.isEmpty
                ? "Unidentified" : key.charactersIgnoringModifiers),
            "shift": flags.contains(.shift),
            "ctrl": flags.contains(.control),
            "alt": flags.contains(.alternate),
            "meta": flags.contains(.command),
            "repeat": false,
        ]
    }

    /// Reports every key of a press, answering whether anything was listening for one.
    static func report(_ presses: Set<UIPress>, as name: String, to view: VarnKeyed) -> Bool {
        guard let onKey = view.onKey else {
            return false
        }

        var told = false

        for press in presses {
            guard let key = press.key else {
                continue
            }

            onKey(name, payload(of: key))
            told = true
        }

        return told
    }
}
