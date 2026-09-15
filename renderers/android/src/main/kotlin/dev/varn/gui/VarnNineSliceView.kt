package dev.varn.gui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.util.LruCache

/**
 * The frames every nine-slice draws from, decoded once per file however many boxes are painted with one.
 *
 * A screen built out of artwork draws the same frame for every button on it, and decoding the file each
 * time a commit sets the source again is the same work done forty times over.
 */
internal object VarnFrames {
    private const val HELD = 8 * 1024

    private val held = object : LruCache<String, Bitmap>(HELD) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount / 1024
    }

    fun read(path: String): Bitmap? {
        held.get(path)?.let { return it }

        val drawn = BitmapFactory.decodeFile(path) ?: return null

        held.put(path, drawn)
        return drawn
    }
}

/**
 * A box painted with a picture cut into nine, which is what a frame drawn from artwork is.
 *
 * The four corners are drawn at their own size, each edge is stretched along one axis and the middle is
 * stretched both ways. The platform's own `NinePatchDrawable` reads the cuts out of marker pixels compiled
 * into the file rather than taking them as numbers, so the pieces are drawn here instead, which is exact
 * and is the same arithmetic the other two renderers do.
 */
class VarnNineSliceView(context: Context) : VarnBoxView(context) {
    // The pieces are drawn without smoothing, the way the other two draw them: a frame is artwork, and
    // a two-pixel rule drawn larger and smoothed comes out as a smear rather than a rule.
    private val paint = Paint()
    private val from = Rect()
    private val onto = Rect()

    private var picture: Bitmap? = null
    private var perState = mapOf<String, Bitmap>()
    private var cuts = intArrayOf(0, 0, 0, 0)
    private var drawnAt = 1f

    init {
        setWillNotDraw(false)
    }

    fun setSource(path: String?) {
        picture = path?.let { VarnFrames.read(it) }
        invalidate()
    }

    /** Takes the artwork a state is drawn with, which is what makes a frame a button that presses. */
    fun setSources(named: Map<String, String>) {
        perState = named.mapNotNull { (state, path) -> VarnFrames.read(path)?.let { state to it } }.toMap()
        invalidate()
    }

    /** Answers the artwork for how the view is now, which is the plain one where there is none of its own. */
    private fun drawing(): Bitmap? {
        if (!isEnabled) {
            perState["disabled"]?.let { return it }
        }

        if (isPressed) {
            perState["pressed"]?.let { return it }
        }

        if (isHovered) {
            perState["hovered"]?.let { return it }
        }

        if (isFocused) {
            perState["focused"]?.let { return it }
        }

        return picture
    }

    override fun drawableStateChanged() {
        super.drawableStateChanged()
        invalidate()
    }

    /** Takes where the picture is cut, in its own pixels, as top, right, bottom and left. */
    fun setSlice(top: Int, right: Int, bottom: Int, left: Int) {
        cuts = intArrayOf(top, right, bottom, left)
        invalidate()
    }

    /** Says how many points one pixel of the border comes out at, which sets how thick it reads. */
    fun setSliceScale(scale: Float) {
        drawnAt = scale
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val drawn = drawing() ?: return
        val (top, right, bottom, left) = cuts

        if (drawn.width <= left + right || drawn.height <= top + bottom) {
            from.set(0, 0, drawn.width, drawn.height)
            onto.set(0, 0, width, height)
            canvas.drawBitmap(drawn, from, onto, paint)
            return
        }

        val outTop = (top * drawnAt).toInt()
        val outRight = (right * drawnAt).toInt()
        val outBottom = (bottom * drawnAt).toInt()
        val outLeft = (left * drawnAt).toInt()

        val columns = listOf(
            intArrayOf(0, left, 0, outLeft),
            intArrayOf(left, drawn.width - right, outLeft, width - outRight),
            intArrayOf(drawn.width - right, drawn.width, width - outRight, width),
        )

        val rows = listOf(
            intArrayOf(0, top, 0, outTop),
            intArrayOf(top, drawn.height - bottom, outTop, height - outBottom),
            intArrayOf(drawn.height - bottom, drawn.height, height - outBottom, height),
        )

        for (column in columns) {
            for (row in rows) {
                if (column[3] <= column[2] || row[3] <= row[2]) {
                    continue
                }

                from.set(column[0], row[0], column[1], row[1])
                onto.set(column[2], row[2], column[3], row[3])
                canvas.drawBitmap(drawn, from, onto, paint)
            }
        }
    }
}
