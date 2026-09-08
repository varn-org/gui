package dev.varn.gui

import android.app.Activity
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

/**
 * Which finger is a press, which is a swipe, and which belongs to the list rather than to the row.
 *
 * A press measured against the view it landed on is cancelled by the view moving, which is what a row
 * does while a scroll settles — the control answers every other tap and ignores the one before it. And
 * a row that answers a press consumes the whole gesture, so a list of pressable rows would not scroll
 * at all unless the surface asks for the finger back once it is clear it is scrolling.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class PressTest {
    private lateinit var context: Activity
    private lateinit var surface: FrameLayout
    private lateinit var renderer: VarnRenderer
    private val events = mutableListOf<Triple<Int, String, Any?>>()

    @Before
    fun setUp() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()

        context = activity
        surface = FrameLayout(activity)
        activity.setContentView(surface)
        events.clear()

        renderer = VarnRenderer(activity, surface) { id, name, payload ->
            events.add(Triple(id, name, payload))
        }
    }

    private fun node(id: Int, type: String, props: Map<String, Any?>, height: Int = 100): View {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "create", "id" to id, "type" to type, "props" to JSONObject(props))),
                    JSONObject(mapOf("op" to "insert", "id" to id, "parent" to 0, "index" to 1)),
                    JSONObject(
                        mapOf("op" to "frame", "id" to id, "x" to 0, "y" to 0, "width" to 300, "height" to height),
                    ),
                ),
            ),
        )

        return surface.getChildAt(surface.childCount - 1)
    }

    /** A touch at a place on the screen, which is where a finger actually is. */
    private fun touch(view: View, action: Int, x: Float, y: Float) {
        val event = MotionEvent.obtain(0, 0, action, x, y, 0)

        // A view answers a touch in its own coordinates, and the two part company the moment the view
        // moves, which is exactly the case this is here for.
        event.offsetLocation(-view.left.toFloat(), -view.top.toFloat())
        view.dispatchTouchEvent(event)
        event.recycle()
    }

    private fun reported(id: Int, name: String) = events.count { it.first == id && it.second == name }

    @Test
    fun `a finger that stays put presses the box`() {
        val box = node(1, "pressable", mapOf("onPressIn" to true, "onPressOut" to true))

        touch(box, MotionEvent.ACTION_DOWN, 40f, 40f)
        assertEquals("a finger landing on it starts a press", 1, reported(1, "onPressIn"))

        touch(box, MotionEvent.ACTION_UP, 42f, 41f)
        assertEquals("and lifting it ends that press", 1, reported(1, "onPressOut"))
    }

    @Test
    fun `a box moving under a still finger is not that finger travelling`() {
        val box = node(2, "pressable", mapOf("onPressIn" to true, "onPressOut" to true, "onSwipe" to true))

        touch(box, MotionEvent.ACTION_DOWN, 40f, 200f)

        // The content slides while a scroll settles, so the row is somewhere else and the finger is not.
        box.offsetTopAndBottom(-120)
        touch(box, MotionEvent.ACTION_MOVE, 40f, 200f)

        assertEquals("the press is not given up because the row moved", 0, reported(2, "onPressOut"))

        touch(box, MotionEvent.ACTION_UP, 40f, 200f)

        assertEquals("it ends where the finger ends", 1, reported(2, "onPressOut"))
        assertEquals("and nothing was swiped", 0, reported(2, "onSwipe"))
    }

    @Test
    fun `a finger that swipes across a box the tree asked about is a swipe rather than a press`() {
        val box = node(3, "pressable", mapOf("onPress" to true, "onSwipe" to true))

        touch(box, MotionEvent.ACTION_DOWN, 40f, 40f)
        touch(box, MotionEvent.ACTION_MOVE, 240f, 44f)
        touch(box, MotionEvent.ACTION_UP, 240f, 44f)

        assertEquals(0, reported(3, "onPress"))
        assertEquals(1, reported(3, "onSwipe"))
        assertEquals("right", (events.last().third as JSONObject).getString("direction"))
    }

    /**
     * A press is given up to the gesture that beat it, never to a distance.
     *
     * A finger on a phone is never still, and a box that answers a press and nothing else has no gesture
     * to give it up to: holding it to the touch slop was a control a reader pressed three times to be
     * heard once.
     */
    @Test
    fun `a box the tree asked no swipe about keeps its press wherever the finger wandered`() {
        val box = node(8, "pressable", mapOf("onPressIn" to true, "onPressOut" to true))

        touch(box, MotionEvent.ACTION_DOWN, 40f, 40f)
        touch(box, MotionEvent.ACTION_MOVE, 200f, 46f)

        assertEquals("the press is not given up for a finger that wandered", 0, reported(8, "onPressOut"))

        touch(box, MotionEvent.ACTION_UP, 200f, 46f)
        assertEquals("it ends where the finger ends", 1, reported(8, "onPressOut"))
    }

    /// A button answers the platform's own rule, which gives a press up when the finger leaves it.
    @Test
    fun `a button keeps its press while the finger is on it`() {
        val button = node(4, "button", mapOf("title" to "Go", "onPress" to true))

        touch(button, MotionEvent.ACTION_DOWN, 40f, 40f)
        assertTrue("a finger landing on it presses it", button.isPressed)

        touch(button, MotionEvent.ACTION_MOVE, 60f, 44f)
        assertTrue("and a finger that wandered inside it is still pressing it", button.isPressed)
    }

    /** A list of pressable rows still scrolls, which it does not while a row holds the whole gesture. */
    @Test
    fun `a list takes the finger back once it is clear it is scrolling`() {
        val list = node(5, "list", mapOf("itemCount" to 20, "contentExtent" to 2000), height = 400)
        val surfaceView = list as VarnCollectionView

        val down = MotionEvent.obtain(0, 0, MotionEvent.ACTION_DOWN, 40f, 300f, 0)
        val moved = MotionEvent.obtain(0, 0, MotionEvent.ACTION_MOVE, 40f, 100f, 0)

        assertFalse("a finger landing on it belongs to what it landed on", surfaceView.onInterceptTouchEvent(down))
        assertTrue("and a finger that travels belongs to the list", surfaceView.onInterceptTouchEvent(moved))

        down.recycle()
        moved.recycle()
    }
}
