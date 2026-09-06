package dev.varn.gui

import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.VideoView
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
            val manager = view.context.getSystemService(InputMethodManager::class.java)
            manager?.hideSoftInputFromWindow(view.windowToken, 0)
            true
        }

        "scrollTo" -> {
            val x = (arguments.optDouble("x", 0.0) * density).toFloat()
            val y = (arguments.optDouble("y", 0.0) * density).toFloat()
            val animated = arguments.optBoolean("animated", false)

            if (view is VarnCollectionView) {
                view.scrollTo(x, y, animated)
            } else {
                view.scrollTo(x.toInt(), y.toInt())
            }

            true
        }

        "play" -> {
            (view as? VideoView)?.start()
            true
        }

        "pause" -> {
            (view as? VideoView)?.pause()
            true
        }

        else -> throw VarnRendererException("the renderer has no action named $method")
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
