package dev.varn.gui

import android.content.Context
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.widget.OverScroller
import android.widget.ProgressBar
import kotlin.math.abs

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
    var onScrollEnd: ((Float, Float) -> Unit)? = null
    var onRefresh: (() -> Unit)? = null

    /** Whether a drag past an edge stretches and springs back, which is what a rubber band is. */
    var bounces = true

    /** Whether dragging takes the keyboard away, which a caller asks for per surface. */
    var dismissesKeyboard = false

    /** Whether letting go settles on a whole page rather than wherever the finger stopped. */
    var paging = false

    private val scroller = OverScroller(context)
    private val scrolls = ViewConfiguration.get(context).scaledTouchSlop
    private val spinner = VarnSpinnerView(context)
    private var horizontal = false
    private var extent = 0f
    private var offset = 0f
    private var enabled = true
    private var last = 0f
    private var stretch = 0f
    private var refreshing = false

    init {
        addView(content)
        addView(spinner)
        isClickable = true
        isVerticalScrollBarEnabled = true
        isHorizontalScrollBarEnabled = false
        scrollBarStyle = SCROLLBARS_INSIDE_OVERLAY
    }

    fun setShowsIndicator(value: Boolean) {
        isVerticalScrollBarEnabled = value && !horizontal
        isHorizontalScrollBarEnabled = value && horizontal
    }

    /** Shows or takes away the spinner, which is what the tree says is happening rather than the finger. */
    fun showRefreshing(value: Boolean) {
        refreshing = value
        spinner.visibility = if (value) View.VISIBLE else View.GONE

        if (!value) {
            settle()
        }
    }

    // The platform draws the indicator from what the surface says it holds, which is the whole extent
    // rather than the part of it that is realised.
    override fun computeVerticalScrollRange(): Int = if (horizontal) height else extent.toInt()

    override fun computeVerticalScrollOffset(): Int = if (horizontal) 0 else offset.toInt()

    override fun computeVerticalScrollExtent(): Int = height

    override fun computeHorizontalScrollRange(): Int = if (horizontal) extent.toInt() else width

    override fun computeHorizontalScrollOffset(): Int = if (horizontal) offset.toInt() else 0

    override fun computeHorizontalScrollExtent(): Int = width

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

    /**
     * Takes the finger from what is inside once it is clear that it is scrolling rather than pressing.
     *
     * A child that answers a press consumes the whole gesture, so a list whose rows are pressable does
     * not scroll at all unless the surface asks for the touch back. Waiting for the finger to travel is
     * what leaves a press a press: the child keeps everything shorter than that.
     */
    override fun onInterceptTouchEvent(event: MotionEvent): Boolean {
        if (!enabled) {
            return false
        }

        val position = if (horizontal) event.x else event.y

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> last = position

            MotionEvent.ACTION_MOVE -> if (abs(position - last) > scrolls) {
                last = position
                return true
            }
        }

        return false
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
                drag(last - position)
                last = position
                return true
            }

            MotionEvent.ACTION_UP,
            MotionEvent.ACTION_CANCEL -> {
                release()
                return true
            }
        }

        return super.onTouchEvent(event)
    }

    /**
     * Moves under the finger, stretching past an edge rather than stopping dead at it.
     *
     * The stretch is damped, so the further it is pulled the less it gives, which is what a rubber band
     * feels like on both platforms.
     */
    private fun drag(by: Float) {
        if (dismissesKeyboard) {
            VarnActions.hideKeyboard(this)
        }

        val room = maxOf(0f, extent - if (horizontal) width.toFloat() else height.toFloat())
        val next = offset + stretch + by

        if (!bounces || (next >= 0f && next <= room)) {
            stretch = 0f
            apply(next)
            return
        }

        val past = if (next < 0f) next else next - room
        stretch = past / 2

        apply(if (next < 0f) 0f else room)
        place()
        spinner.translationY = maxOf(0f, -stretch) - spinner.height
    }

    /** Lets go, which springs the stretch back and refreshes when it was pulled far enough. */
    private fun release() {
        val settled = if (paging) glide() else offset

        onScrollEnd?.invoke(if (horizontal) settled else 0f, if (horizontal) 0f else settled)

        val pulled = -stretch

        if (onRefresh != null && !refreshing && !horizontal && pulled >= REFRESH) {
            onRefresh?.invoke()
        }

        settle()
    }

    private fun settle() {
        stretch = 0f
        place()
        spinner.translationY = -spinner.height.toFloat()
    }

    /**
     * Glides to the page nearest where the finger stopped, answering the one it comes to rest on.
     *
     * A surface that pages comes to rest on a whole one, which is what a carousel is: the offset it
     * reports is where it is going rather than where it was let go of.
     */
    private fun glide(): Float {
        val viewport = if (horizontal) width.toFloat() else height.toFloat()

        if (viewport <= 0f) {
            return offset
        }

        val room = maxOf(0f, extent - viewport)
        val target = (Math.round(offset / viewport) * viewport).coerceIn(0f, room)

        scroller.startScroll(0, offset.toInt(), 0, (target - offset).toInt())
        postInvalidateOnAnimation()

        return target
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
        content.translationX = if (horizontal) -offset + stretch else 0f
        content.translationY = if (horizontal) 0f else -offset + stretch

        hold()
    }

    /**
     * Keeps every box the tree pinned against the leading edge as the surface moves under it.
     *
     * The tree cannot do this: a commit follows a finger rather than leading it, so a header placed
     * from there drifts across the rows it is meant to cover on every flick.
     */
    fun hold() {
        for (index in 0 until content.childCount) {
            val box = content.getChildAt(index) as? VarnBoxView ?: continue

            if (box.pinned == null) {
                continue
            }

            box.bringToFront()

            if (horizontal) {
                box.translationX = box.held(offset, box.width) - box.left
                continue
            }

            box.translationY = box.held(offset, box.height) - box.top
        }
    }

    /** Answers the view the engine parents its cells to, which is the layer that scrolls. */
    fun contentView(): View = content

    private companion object {
        /** How far the surface has to be pulled past its top before letting go asks for a refresh. */
        const val REFRESH = 72f
    }
}

/** The spinner shown while a surface is being pulled, and while what it asked for is on its way. */
class VarnSpinnerView(context: Context) : ProgressBar(context) {
    init {
        isIndeterminate = true
        visibility = View.GONE
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
    }
}
