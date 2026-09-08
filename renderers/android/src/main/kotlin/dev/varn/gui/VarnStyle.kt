package dev.varn.gui

import android.graphics.Color
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.Typeface
import android.text.TextPaint
import android.util.TypedValue
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.view.ViewOutlineProvider
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
        val italic = style.optString("fontStyle", "") == "italic"

        val weight = style.optString("fontWeight", "400").toIntOrNull() ?: 400

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            return Typeface.create(base, weight, italic)
        }

        val slant = when {
            weight >= 600 && italic -> Typeface.BOLD_ITALIC
            weight >= 600 -> Typeface.BOLD
            italic -> Typeface.ITALIC
            else -> Typeface.NORMAL
        }

        return Typeface.create(base, slant)
    }

    /**
     * Answers the paint a string is drawn with, which is the paint it is measured with as well.
     *
     * Spacing between letters changes how much room a line needs, so measuring without it measures
     * something the reader never sees.
     */
    fun paint(style: JSONObject, density: Float): TextPaint {
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG)

        paint.textSize = (style.optDouble("fontSize", 15.0) * density).toFloat()
        paint.typeface = typeface(style)
        paint.letterSpacing = spacing(style)
        paint.isUnderlineText = style.optString("textDecoration", "") == "underline"
        paint.isStrikeThruText = style.optString("textDecoration", "") == "line-through"

        return paint
    }

    /** Answers the space between letters as the fraction of the size the platform takes it as. */
    private fun spacing(style: JSONObject): Float {
        val declared = style.optDouble("letterSpacing", 0.0)
        val size = style.optDouble("fontSize", 15.0)

        if (declared == 0.0 || size <= 0.0) {
            return 0f
        }

        return (declared / size).toFloat()
    }

    fun apply(style: JSONObject, view: View, type: String, density: Float) {
        applyBox(style, view, density)
        styleText(style, view, density)
        applyShadow(style.optJSONObject("shadow"), view, density)

        view.alpha = style.optDouble("opacity", 1.0).toFloat()
        applyTransform(style.optJSONObject("transform"), view, density)
    }

    /**
     * Lifts a box off the page, which is what separates a card, a sheet, an alert or a drawer from it.
     *
     * The platform draws a shadow from an elevation and the outline of the view, so the radius the tree
     * asked for is what the height is taken from, and a box with no outline of its own is given one.
     */
    private fun applyShadow(shadow: JSONObject?, view: View, density: Float) {
        if (shadow == null) {
            view.elevation = 0f
            return
        }

        val radius = (shadow.optDouble("radius", 0.0) * density).toFloat()
        val offset = (shadow.optDouble("offsetY", 0.0) * density).toFloat()

        color(shadow.opt("color"))?.let {
            view.outlineAmbientShadowColor = it
            view.outlineSpotShadowColor = it
        }

        view.elevation = maxOf(radius, offset)
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
            view.clipToOutline = false
            view.outlineProvider = ViewOutlineProvider.BACKGROUND
            return
        }

        val shape = GradientDrawable()
        shape.cornerRadius = radius
        background?.let { shape.setColor(it) }

        if (border > 0 && borderColor != null) {
            shape.setStroke(border, borderColor)
        }

        view.background = shape

        // A rounded box has to hold what it draws inside its own corners, or a picture that fills it
        // and a child laid out against its edge are drawn square over them.
        applyClipping(style, view, radius)
    }

    /**
     * Says whether a view keeps what it holds inside its own outline.
     *
     * A scrolling view always does: its content is laid out past the edge by definition. A rounded box
     * and a view whose overflow says so do too, and the outline is what the platform clips to.
     */
    private fun applyClipping(style: JSONObject, view: View, radius: Float) {
        val hidden = style.optString("overflow", "") == "hidden"
        val clips = hidden || radius > 0f

        view.outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(outlined: View, outline: Outline) {
                outline.setRoundRect(0, 0, outlined.width, outlined.height, radius)
            }
        }

        view.clipToOutline = clips
    }

    /** Styles a label, which is also how a string is measured: the same paint draws it and sizes it. */
    fun styleText(style: JSONObject, view: View, density: Float) {
        val label = view as? TextView ?: return

        // The engine works in density-independent pixels, so the label is set in the same unit it was
        // measured in. Setting it as scaled pixels would draw it at the reader's font scale and the
        // text would no longer fit the frame it was given.
        label.setTextSize(TypedValue.COMPLEX_UNIT_DIP, style.optDouble("fontSize", 15.0).toFloat())
        label.typeface = typeface(style)
        label.letterSpacing = spacing(style)
        label.paintFlags = decoration(style, label.paintFlags)
        color(style.opt("color"))?.let { label.setTextColor(it) }

        // A line height is a multiple of the size, which is what the other two read it as.
        val leading = style.optDouble("lineHeight", 0.0)
        label.setLineSpacing(0f, if (leading > 0.0) leading.toFloat() else 1f)

        when (style.optString("textAlign", "")) {
            "center" -> label.textAlignment = View.TEXT_ALIGNMENT_CENTER
            "right" -> label.textAlignment = View.TEXT_ALIGNMENT_VIEW_END
            else -> label.textAlignment = View.TEXT_ALIGNMENT_VIEW_START
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            label.justificationMode = if (style.optString("textAlign", "") == "justify") {
                android.text.Layout.JUSTIFICATION_MODE_INTER_WORD
            } else {
                android.text.Layout.JUSTIFICATION_MODE_NONE
            }
        }

        // A label draws its own text, so the padding around it is applied here. Everywhere else the
        // engine has already worked it into the frames of the children.
        val padding = edges(style, "padding", density)
        label.setPadding(padding[3], padding[0], padding[1], padding[2])
    }

    /** Answers the paint flags a decoration asks for, leaving alone the flags it says nothing about. */
    private fun decoration(style: JSONObject, flags: Int): Int {
        val named = style.optString("textDecoration", "")
        val cleared = flags and (Paint.UNDERLINE_TEXT_FLAG or Paint.STRIKE_THRU_TEXT_FLAG).inv()

        return when (named) {
            "underline" -> cleared or Paint.UNDERLINE_TEXT_FLAG
            "line-through" -> cleared or Paint.STRIKE_THRU_TEXT_FLAG
            else -> cleared
        }
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

    /**
     * Answers how far a node travels along one axis, in the pixels the platform moves views by.
     *
     * A travel written as a percentage is a share of the node's own size, which is the only way a panel
     * says it leaves by its own edge without the tree knowing how tall it turned out to be.
     */
    private fun travel(transform: JSONObject, name: String, extent: Int, density: Float): Float {
        val written = transform.opt(name)

        if (written is String && written.endsWith("%")) {
            val percent = written.dropLast(1).toFloatOrNull() ?: return 0f
            return extent * percent / 100f
        }

        return (transform.optDouble(name, 0.0) * density).toFloat()
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

        view.translationX = travel(transform, "translateX", view.width, density)
        view.translationY = travel(transform, "translateY", view.height, density)
        view.scaleX = transform.optDouble("scaleX", 1.0).toFloat()
        view.scaleY = transform.optDouble("scaleY", 1.0).toFloat()
        view.rotation = transform.optDouble("rotate", 0.0).toFloat()
    }
}
