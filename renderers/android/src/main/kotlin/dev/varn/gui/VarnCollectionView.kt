package dev.varn.gui

import android.content.Context
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.OverScroller

/**
 * The scrolling surface a list, a grid and a carousel are all drawn on.
 *
 * The engine decides which entries exist, which cell serves each one and where every cell sits, so
 * this holds the scrollable extent and reports the offset back. Reuse happens on the other side of
 * the bridge, where a cell that leaves the window is handed to the entry that takes its place.
 */
class VarnCollectionView(context: Context) : VarnBoxView(context) {
    val content = VarnBoxView(context)

    var onScroll: ((Float, Float) -> Unit)? = null

    private val scroller = OverScroller(context)
    private var horizontal = false
    private var extent = 0f
    private var offset = 0f
    private var enabled = true
    private var last = 0f

    init {
        addView(content)
        isClickable = true
    }

    /** Records the axis the surface scrolls along, which decides what the extent measures. */
    fun setHorizontal(value: Boolean) {
        horizontal = value
        requestLayout()
    }

    /** Records how far the surface scrolls, which is every entry the engine knows about. */
    fun setContentExtent(value: Float) {
        extent = value
        requestLayout()
    }

    fun setScrollEnabled(value: Boolean) {
        enabled = value
    }

    /** Moves to an offset the engine has already worked out, which is what a ref reaches through. */
    fun scrollTo(x: Float, y: Float, animated: Boolean) {
        val target = if (horizontal) x else y

        if (!animated) {
            apply(target)
            return
        }

        scroller.startScroll(0, offset.toInt(), 0, (target - offset).toInt())
        postInvalidateOnAnimation()
    }

    override fun computeScroll() {
        if (scroller.computeScrollOffset()) {
            apply(scroller.currY.toFloat())
            postInvalidateOnAnimation()
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!enabled) {
            return false
        }

        val position = if (horizontal) event.x else event.y

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                last = position
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                apply(offset + (last - position))
                last = position
                return true
            }
        }

        return super.onTouchEvent(event)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val width = if (horizontal) maxOf(extent.toInt(), right - left) else right - left
        val height = if (horizontal) bottom - top else maxOf(extent.toInt(), bottom - top)

        content.layoutParams = ViewGroup.LayoutParams(width, height)
        content.layout(0, 0, width, height)
        place()
    }

    private fun apply(next: Float) {
        val room = maxOf(0f, extent - if (horizontal) width.toFloat() else height.toFloat())
        val clamped = next.coerceIn(0f, room)

        if (clamped == offset) {
            return
        }

        offset = clamped
        place()
        onScroll?.invoke(if (horizontal) offset else 0f, if (horizontal) 0f else offset)
    }

    /** Moves the content layer under the viewport, which is what scrolling a retained tree is. */
    private fun place() {
        content.translationX = if (horizontal) -offset else 0f
        content.translationY = if (horizontal) 0f else -offset
    }

    /** Answers the view the engine parents its cells to, which is the layer that scrolls. */
    fun contentView(): View = content
}
