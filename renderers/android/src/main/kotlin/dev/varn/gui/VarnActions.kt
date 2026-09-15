package dev.varn.gui

import android.view.View
import android.view.inputmethod.InputMethodManager
import org.json.JSONObject

/** Performs the imperative action a ref asked for, refusing a name the renderer has no answer for. */
object VarnActions {
    fun perform(method: String, view: View, arguments: JSONObject, density: Float): Boolean = when (method) {
        "focus" -> {
            view.requestFocus()
            val manager = view.context.getSystemService(InputMethodManager::class.java)
            manager?.showSoftInput(view, InputMethodManager.SHOW_IMPLICIT)
            true
        }

        "blur" -> {
            view.clearFocus()
            hideKeyboard(view)
            true
        }

        "scrollTo" -> {
            val surface = view as? VarnCollectionView
                ?: throw VarnRendererException("scrollTo needs a scrolling view")

            surface.scrollTo(
                (arguments.optDouble("x", 0.0) * density).toFloat(),
                (arguments.optDouble("y", 0.0) * density).toFloat(),
                arguments.optBoolean("animated", false),
            )

            true
        }

        "capturePhoto", "startRecording", "stopRecording" -> {
            val camera = view as? VarnCameraView ?: throw VarnRendererException("$method needs a camera")

            when (method) {
                "capturePhoto" -> camera.capturePhoto()
                "startRecording" -> camera.startRecording()
                else -> camera.stopRecording()
            }

            true
        }

        "play", "pause" -> {
            val video = view as? VarnVideoView ?: throw VarnRendererException("$method needs a video")

            if (method == "play") video.start() else video.pause()
            true
        }

        "seek" -> {
            if (!arguments.has("seconds")) {
                throw VarnRendererException("seek is asked for a number of seconds")
            }

            val seconds = arguments.optDouble("seconds", 0.0)

            when (view) {
                is VarnAudioView -> view.seek(seconds)
                is VarnVideoView -> view.seekTo((seconds * 1000).toInt())
                else -> throw VarnRendererException("seek needs a sound or a film")
            }

            true
        }

        "toggleMark", "setLink", "clearLink", "copy", "cut", "paste", "selectAll" -> {
            val editor = view as? VarnRichEditor ?: throw VarnRendererException("$method needs an editor")

            editor.requestFocus()

            when (method) {
                "toggleMark" -> editor.toggle(arguments.optString("mark"))
                "setLink" -> editor.link(arguments.optString("url"))
                "clearLink" -> editor.link(null)
                else -> editor.clipboard(method)
            }

            true
        }

        else -> throw VarnRendererException("the renderer has no action named $method")
    }

    /** Takes the keyboard away, whatever it was brought up by. */
    fun hideKeyboard(view: View) {
        val manager = view.context.getSystemService(InputMethodManager::class.java)
        manager?.hideSoftInputFromWindow(view.windowToken, 0)
    }
}

/** Answers the insets the platform reports, which a safe area lays out against. */
object VarnInsets {
    fun of(view: View, density: Float): JSONObject {
        val insets = view.rootWindowInsets
            ?: return JSONObject().put("top", 0).put("right", 0).put("bottom", 0).put("left", 0)

        val bars = insets.getInsets(android.view.WindowInsets.Type.systemBars())

        return JSONObject()
            .put("top", bars.top / density)
            .put("right", bars.right / density)
            .put("bottom", bars.bottom / density)
            .put("left", bars.left / density)
    }
}
