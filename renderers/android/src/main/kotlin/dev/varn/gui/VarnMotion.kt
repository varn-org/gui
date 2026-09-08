package dev.varn.gui

import android.view.View
import android.view.animation.Interpolator
import android.view.animation.PathInterpolator
import org.json.JSONArray
import org.json.JSONObject

/**
 * Drives a change over time rather than applying it between two frames.
 *
 * The engine sends the state a node settles at and how long it should take to get there, so nothing
 * here decides what moves or how far. A curve arrives as its four control points, which is what
 * `PathInterpolator` takes, so a name never has to mean the same thing in three places.
 */
object VarnMotion {
    class Timing(val duration: Long, val delay: Long, val curve: Interpolator)

    fun timing(value: Any?): Timing? {
        val carried = value as? JSONObject ?: return null
        val duration = carried.optLong("duration", 0)

        if (duration <= 0) {
            return null
        }

        val easing = carried.optJSONArray("easing") ?: JSONArray()
        val point = { at: Int -> easing.optDouble(at, 0.0).toFloat() }

        return Timing(
            duration,
            carried.optLong("delay", 0),
            PathInterpolator(point(0), point(1), point(2), point(3)),
        )
    }

    /**
     * Moves a view to the opacity and the transform a style settles at.
     *
     * Only what does not disturb what the layout worked out is animated, so a node keeps the frame it
     * was given however it is faded, slid or scaled.
     */
    fun animate(view: View, style: JSONObject, timing: Timing) {
        val transform = style.optJSONObject("transform")
        val scale = transform?.optDouble("scaleX", 1.0)?.toFloat() ?: 1f

        view.animate()
            .alpha(style.optDouble("opacity", 1.0).toFloat())
            .translationX((transform?.optDouble("translateX", 0.0)?.toFloat() ?: 0f) * view.resources.displayMetrics.density)
            .translationY((transform?.optDouble("translateY", 0.0)?.toFloat() ?: 0f) * view.resources.displayMetrics.density)
            .scaleX(scale)
            .scaleY(transform?.optDouble("scaleY", 1.0)?.toFloat() ?: 1f)
            .rotation(transform?.optDouble("rotate", 0.0)?.toFloat() ?: 0f)
            .setDuration(timing.duration)
            .setStartDelay(timing.delay)
            .setInterpolator(timing.curve)
            .start()
    }

    /** Puts a node on screen in the state it arrives from and moves it to the one it settles at. */
    fun arrive(view: View, entering: JSONObject, settled: JSONObject, type: String, density: Float, timing: Timing) {
        val start = JSONObject(settled.toString())

        for (key in entering.keys()) {
            start.put(key, entering.get(key))
        }

        VarnStyle.apply(start, view, type, density)
        view.post { animate(view, settled, timing) }
    }
}
