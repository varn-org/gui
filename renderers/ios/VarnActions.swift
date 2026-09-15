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

        case "play", "pause":
            guard let video = view as? VarnVideoView else {
                throw RendererError.missing("\(method) needs a video")
            }

            if method == "play" {
                video.player.play()
            } else {
                video.player.pause()
            }

            return true

        case "seek":
            guard let seconds = VarnValue.number(arguments["seconds"]).map(Double.init) else {
                throw RendererError.malformed("seek is asked for a number of seconds")
            }

            if let sound = view as? VarnAudioView {
                sound.seek(to: seconds)
                return true
            }

            guard let video = view as? VarnVideoView else {
                throw RendererError.missing("seek needs a sound or a film")
            }

            video.seek(to: seconds)
            return true

        case "capturePhoto", "startRecording", "stopRecording":
            guard let camera = view as? VarnCameraView else {
                throw RendererError.missing("\(method) needs a camera")
            }

            if method == "capturePhoto" {
                camera.capturePhoto()
            } else if method == "startRecording" {
                camera.startRecording()
            } else {
                camera.stopRecording()
            }

            return true

        case "toggleMark", "setLink", "clearLink", "copy", "cut", "paste", "selectAll":
            guard let editor = view as? VarnRichEditor else {
                throw RendererError.missing("\(method) needs an editor")
            }

            return edit(method, on: editor, arguments: arguments)

        default:
            throw RendererError.missing("the renderer has no action named \(method)")
        }
    }

    /// Applies what a toolbar asked of an editor, which is a mark, a link or the clipboard.
    private static func edit(_ method: String, on editor: VarnRichEditor, arguments: [String: Any]) -> Bool {
        editor.becomeFirstResponder()

        switch method {
        case "toggleMark":
            guard let mark = arguments["mark"] as? String else {
                return false
            }

            editor.toggle(mark)

        case "setLink":
            editor.link(arguments["url"] as? String ?? "")

        case "clearLink":
            editor.link(nil)

        case "selectAll":
            editor.selectAll(nil)
            editor.report()

        case "copy":
            editor.copy(nil)

        case "cut":
            editor.cut(nil)

        default:
            editor.paste(nil)
        }

        return true
    }
}
