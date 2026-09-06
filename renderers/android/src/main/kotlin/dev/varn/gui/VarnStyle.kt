package dev.varn.gui

import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.text.TextPaint
import android.util.TypedValue
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.widget.TextView
import org.json.JSONObject

/**
 * Turns the resolved style a commit carries into the Android properties that draw it.
 *
 * Nothing here decides anything. A colour arrives as eight hex digits and a size as a number, both
 * already resolved against the theme, so this file only assigns.
 */
object VarnStyle {
    private val families = mutableMapOf<String, Typeface>()

    fun color(value: Any?): Int? {
        val text = value as? String ?: return null
        if (!text.startsWith("#")) {
            return null
        }

        val digits = text.drop(1).let { if (it.length == 6) it + "ff" else it }
        if (digits.length != 8) {
            return null
        }

        val packed = digits.toLongOrNull(16) ?: return null
        val alpha = (packed and 0xff).toInt()
        val rgb = (packed ushr 8).toInt()

        return Color.argb(alpha, (rgb shr 16) and 0xff, (rgb shr 8) and 0xff, rgb and 0xff)
    }

    fun registerFont(family: String, path: String) {
        families[family] = Typeface.createFromFile(path)
    }

    fun typeface(style: JSONObject): Typeface {
        val family = style.optString("fontFamily", "")
        val base = families[family] ?: Typeface.DEFAULT

        val weight = style.optString("fontWeight", "400")
        val bold = weight == "600" || weight == "700" || weight == "800" || weight == "900"

        return if (bold) Typeface.create(base, Typeface.BOLD) else base
    }

    fun paint(style: JSONObject, density: Float): TextPaint {
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG)
        paint.textSize = (style.optDouble("fontSize", 15.0) * density).toFloat()
        paint.typeface = typeface(style)
        return paint
    }

    fun apply(style: JSONObject, view: View, type: String, density: Float) {
        applyBox(style, view, density)
        styleText(style, view, density)

        view.alpha = style.optDouble("opacity", 1.0).toFloat()
        applyTransform(style.optJSONObject("transform"), view, density)
    }

    /**
     * Answers the corner radius a box may actually be drawn with, which is never more than it can hold.
     *
     * A pill is written as a radius larger than any box it could sit in, so it is held to half the
     * smaller side once the box has a size of its own.
     */
    private fun cornerRadius(radius: Float, view: View): Float {
        val limit = minOf(view.width, view.height) / 2f
        return if (limit <= 0f) radius else minOf(radius, limit)
    }

    private fun applyBox(style: JSONObject, view: View, density: Float) {
        val background = color(style.opt("background"))
        val radius = cornerRadius((style.optDouble("radius", 0.0) * density).toFloat(), view)
        val border = (style.optDouble("border", 0.0) * density).toInt()
        val borderColor = color(style.opt("borderColor"))

        if (background == null && radius == 0f && border == 0) {
            view.background = null
            return
        }

        val shape = GradientDrawable()
        shape.cornerRadius = radius
        background?.let { shape.setColor(it) }

        if (border > 0 && borderColor != null) {
            shape.setStroke(border, borderColor)
        }

        view.background = shape
    }

    /** Styles a label, which is also how a string is measured: the same paint draws it and sizes it. */
    fun styleText(style: JSONObject, view: View, density: Float) {
        val label = view as? TextView ?: return

        // The engine works in density-independent pixels, so the label is set in the same unit it was
        // measured in. Setting it as scaled pixels would draw it at the reader's font scale and the
        // text would no longer fit the frame it was given.
        label.setTextSize(TypedValue.COMPLEX_UNIT_DIP, style.optDouble("fontSize", 15.0).toFloat())
        label.typeface = typeface(style)
        color(style.opt("color"))?.let { label.setTextColor(it) }

        when (style.optString("textAlign", "")) {
            "center" -> label.textAlignment = View.TEXT_ALIGNMENT_CENTER
            "right" -> label.textAlignment = View.TEXT_ALIGNMENT_VIEW_END
            else -> label.textAlignment = View.TEXT_ALIGNMENT_VIEW_START
        }

        // A label draws its own text, so the padding around it is applied here. Everywhere else the
        // engine has already worked it into the frames of the children.
        val padding = edges(style, "padding", density)
        label.setPadding(padding[3], padding[0], padding[1], padding[2])
    }

    /** Answers a box property given as one value, a pair, or a value per edge, clockwise from the top. */
    fun edges(style: JSONObject, name: String, density: Float): IntArray {
        val whole = style.optDouble(name, 0.0)
        val horizontal = style.optDouble("${name}Horizontal", whole)
        val vertical = style.optDouble("${name}Vertical", whole)

        val box = doubleArrayOf(
            style.optDouble("${name}Top", vertical),
            style.optDouble("${name}Right", horizontal),
            style.optDouble("${name}Bottom", vertical),
            style.optDouble("${name}Left", horizontal),
        )

        return IntArray(4) { (box[it] * density).toInt() }
    }

    private fun applyTransform(transform: JSONObject?, view: View, density: Float) {
        if (transform == null) {
            view.translationX = 0f
            view.translationY = 0f
            view.scaleX = 1f
            view.scaleY = 1f
            view.rotation = 0f
            return
        }

        view.translationX = (transform.optDouble("translateX", 0.0) * density).toFloat()
        view.translationY = (transform.optDouble("translateY", 0.0) * density).toFloat()
        view.scaleX = transform.optDouble("scaleX", 1.0).toFloat()
        view.scaleY = transform.optDouble("scaleY", 1.0).toFloat()
        view.rotation = transform.optDouble("rotate", 0.0).toFloat()
    }
}
