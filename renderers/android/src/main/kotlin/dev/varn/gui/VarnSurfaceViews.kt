package dev.varn.gui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import org.json.JSONArray

/** A box painted with a run of colours, which is what a screen with a header of its own is built on. */
class VarnGradientView(context: Context) : VarnBoxView(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var colours = intArrayOf()
    private var stops: FloatArray? = null
    private var direction = "down"

    init {
        setWillNotDraw(false)
    }

    fun setColors(values: JSONArray?) {
        val read = mutableListOf<Int>()

        for (index in 0 until (values?.length() ?: 0)) {
            read += VarnStyle.color(values?.optString(index)) ?: continue
        }

        colours = read.toIntArray()
        shade()
    }

    fun setLocations(values: JSONArray?) {
        if (values == null) {
            stops = null
            shade()
            return
        }

        stops = FloatArray(values.length()) { index -> values.optDouble(index).toFloat() }
        shade()
    }

    fun setDirection(value: String?) {
        direction = value ?: "down"
        shade()
    }

    override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
        super.onSizeChanged(width, height, oldWidth, oldHeight)
        shade()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (colours.size < 2 || width == 0 || height == 0) {
            return
        }

        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
    }

    private fun shade() {
        if (colours.size < 2 || width == 0 || height == 0) {
            return
        }

        val wide = width.toFloat()
        val tall = height.toFloat()

        val (from, to) = when (direction) {
            "up" -> (0f to tall) to (0f to 0f)
            "right" -> (0f to 0f) to (wide to 0f)
            "left" -> (wide to 0f) to (0f to 0f)
            "diagonal" -> (0f to 0f) to (wide to tall)
            else -> (0f to 0f) to (0f to tall)
        }

        paint.shader = LinearGradient(
            from.first, from.second, to.first, to.second,
            colours, stops, Shader.TileMode.CLAMP,
        )

        invalidate()
    }
}

/**
 * A box that stands over what is behind it, which is what a bar over a scrolling screen is made of.
 *
 * Android has no blur of a view's own backdrop, so what it draws is the tint at the weight the tree
 * asked for. iOS and the browser blur what is behind the same box, which is why the tint is what
 * carries the colour rather than the blur carrying it.
 */
class VarnBlurView(context: Context) : VarnBoxView(context) {
    private var intensity = 0.85f
    private var tint = Color.TRANSPARENT

    fun setIntensity(value: Float) {
        intensity = value.coerceIn(0f, 1f)
        wash()
    }

    fun setTint(value: String?) {
        tint = VarnStyle.color(value) ?: Color.TRANSPARENT
        wash()
    }

    private fun wash() {
        val alpha = (Color.alpha(tint) * intensity).toInt()

        setBackgroundColor(Color.argb(alpha, Color.red(tint), Color.green(tint), Color.blue(tint)))
    }
}
