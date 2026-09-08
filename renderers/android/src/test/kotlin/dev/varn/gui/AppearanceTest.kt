package dev.varn.gui

import android.app.Activity
import android.view.MotionEvent
import android.widget.FrameLayout
import android.widget.Button
import android.widget.RadioButton
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

/**
 * What a box looks like and what it answers, both of which Android had less of than the other two.
 *
 * Nothing here was drawn or reported at all: every raised surface was flat, since there was no shadow
 * code anywhere, a rounded box drew square over its own corners, a radio reported nothing so a whole
 * radio group was dead, and both edges of a press went nowhere.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class AppearanceTest {
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

    private fun node(type: String, props: Map<String, Any?>): android.view.View {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "create", "id" to 1, "type" to type, "props" to JSONObject(props))),
                    JSONObject(mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1)),
                    JSONObject(mapOf("op" to "frame", "id" to 1, "x" to 0, "y" to 0, "width" to 200, "height" to 100)),
                ),
            ),
        )

        return surface.getChildAt(0)
    }

    /**
     * A file picker asks the host to open a chooser rather than opening one itself.
     *
     * An activity's result belongs to the activity that started it, and the renderer holds no activity,
     * which is what would leak one on a rotation. It declared nothing but a title before this, so it was
     * a bare button that did nothing at all.
     */
    @Test
    fun `a file picker asks for the chooser its kind names`() {
        var asked: android.content.Intent? = null

        renderer.onChoose = { _, intent -> asked = intent }

        val picker = node(
            "filepicker",
            mapOf("kind" to "image", "multiple" to true, "onPick" to true),
        )

        picker.performClick()

        assertTrue("pressing a file picker must ask for a chooser", asked != null)
        assertEquals("a picker of pictures asks for pictures", "image/*", asked?.type)
        assertTrue(
            "and says it takes more than one",
            asked?.getBooleanExtra(android.content.Intent.EXTRA_ALLOW_MULTIPLE, false) == true,
        )
    }

    @Test
    fun `a file picker offers what it was told to accept`() {
        var asked: android.content.Intent? = null

        renderer.onChoose = { _, intent -> asked = intent }

        val picker = node(
            "filepicker",
            mapOf("accept" to JSONArray(listOf("application/pdf", "image/png")), "onPick" to true),
        )

        picker.performClick()

        assertEquals("the first type it was given is the one it opens on", "application/pdf", asked?.type)
        assertEquals(
            "and the rest are offered beside it",
            2,
            asked?.getStringArrayExtra(android.content.Intent.EXTRA_MIME_TYPES)?.size,
        )
    }

    /**
     * A box a finger passes through passes it through everything inside it too.
     *
     * Disabling the box alone left every control inside it answering, which is what a covered screen in
     * a navigation stack is made of: the screen beneath still took the press meant for the one over it.
     */
    @Test
    fun `a box a finger passes through takes nothing inside it either`() {
        val box = node("view", mapOf("pointerEvents" to "none")) as VarnBoxView
        val inside = Button(context)

        inside.setOnClickListener { events.add(Triple(2, "onPress", null)) }
        box.addView(inside)
        inside.layout(0, 0, 100, 50)

        val landed = box.dispatchTouchEvent(MotionEvent.obtain(0, 0, MotionEvent.ACTION_DOWN, 5f, 5f, 0))

        assertTrue("a box told to pass a finger through must not take it", !landed)
        assertEquals("and nothing inside it may answer either", 0, events.size)
    }

    @Test
    fun `a box that takes a finger keeps taking it`() {
        val box = node("view", mapOf("pointerEvents" to "auto")) as VarnBoxView

        assertTrue("a box told nothing of the sort answers the way any box does", !box.passesThrough)
    }

    /**
     * A swipe across a row the tree asked about is that swipe rather than a press.
     *
     * Nothing shorter takes a press away: a finger on a phone is never still, and a row that gave one up
     * for the touch slop was a control a reader pressed three times to be heard once.
     */
    @Test
    fun `a finger that swipes across a box the tree asked about does not press it`() {
        val row = node("pressable", mapOf("onPress" to true, "onPressOut" to true, "onSwipe" to true)) as VarnBoxView
        var pressed = 0

        row.setOnClickListener { pressed += 1 }
        row.layout(0, 0, 390, 60)

        row.dispatchTouchEvent(MotionEvent.obtain(0, 0, MotionEvent.ACTION_DOWN, 10f, 20f, 0))
        val followed = row.dispatchTouchEvent(MotionEvent.obtain(0, 10, MotionEvent.ACTION_MOVE, 200f, 22f, 0))
        row.dispatchTouchEvent(MotionEvent.obtain(0, 20, MotionEvent.ACTION_UP, 200f, 22f, 0))

        assertEquals("a swipe across a row must not press it", 0, pressed)
        assertTrue("and the box gives the finger up rather than following it", !followed)
        assertEquals("as a press that ended", "onPressOut", events.first().second)
    }

    /** And one that stays put is still being followed, so the press it is part of still stands. */
    @Test
    fun `a finger that stays put keeps the press`() {
        val row = node("pressable", mapOf("onPress" to true, "onPressOut" to true)) as VarnBoxView

        row.layout(0, 0, 390, 60)

        row.dispatchTouchEvent(MotionEvent.obtain(0, 0, MotionEvent.ACTION_DOWN, 10f, 20f, 0))
        val kept = row.dispatchTouchEvent(MotionEvent.obtain(0, 10, MotionEvent.ACTION_MOVE, 11f, 21f, 0))

        assertTrue("a finger that stayed put is still a press", kept)
        assertEquals("and the press has not been given up", 0, events.size)
    }

    /** And the swipe it was instead is reported by the way it went, which is what an item acts on. */
    @Test
    fun `a swipe is reported by the way it went`() {
        val row = node("pressable", mapOf("onSwipe" to true)) as VarnBoxView

        row.layout(0, 0, 390, 60)

        row.dispatchTouchEvent(MotionEvent.obtain(0, 0, MotionEvent.ACTION_DOWN, 200f, 30f, 0))
        row.dispatchTouchEvent(MotionEvent.obtain(0, 10, MotionEvent.ACTION_MOVE, 60f, 34f, 0))
        row.dispatchTouchEvent(MotionEvent.obtain(0, 20, MotionEvent.ACTION_UP, 60f, 34f, 0))

        val swipes = events.filter { it.second == "onSwipe" }

        assertEquals("a swipe across a row is reported once", 1, swipes.size)
        assertEquals(
            "and by the way it went",
            "left",
            (swipes.first().third as org.json.JSONObject).getString("direction"),
        )
    }

    @Test
    fun `a raised surface is lifted off the page`() {
        val card = node(
            "view",
            mapOf("style" to JSONObject(mapOf("shadow" to JSONObject(mapOf("radius" to 8, "offsetY" to 2))))),
        )

        assertTrue("a shadow must lift the box off the page, got ${card.elevation}", card.elevation > 0f)
    }

    @Test
    fun `a box with no shadow sits flat`() {
        val plain = node("view", mapOf("style" to JSONObject(mapOf("background" to "#ffffffff"))))

        assertEquals("a box told nothing is not lifted", 0f, plain.elevation)
    }

    @Test
    fun `a rounded box holds what it draws inside its corners`() {
        val rounded = node("view", mapOf("style" to JSONObject(mapOf("radius" to 12, "background" to "#ffffffff"))))

        assertTrue("a rounded box must clip to its own outline", rounded.clipToOutline)
    }

    @Test
    fun `a square box clips nothing`() {
        val square = node("view", mapOf("style" to JSONObject(mapOf("background" to "#ffffffff"))))

        assertTrue("a square box has nothing to clip", !square.clipToOutline)
    }

    @Test
    fun `a radio reports which one was chosen`() {
        val radio = node("radio", mapOf("value" to "monthly", "onSelect" to true)) as RadioButton

        radio.isChecked = true

        assertEquals("choosing a radio must be reported", 1, events.size)
        assertEquals("and reported as a choice", "onSelect", events.first().second)
    }

    @Test
    fun `a press reports both of its edges`() {
        val box = node("pressable", mapOf("onPressIn" to true, "onPressOut" to true))

        box.dispatchTouchEvent(MotionEvent.obtain(0, 0, MotionEvent.ACTION_DOWN, 5f, 5f, 0))
        box.dispatchTouchEvent(MotionEvent.obtain(0, 10, MotionEvent.ACTION_UP, 5f, 5f, 0))

        assertEquals("both edges of a press must be reported", 2, events.size)
        assertEquals("the first is the finger landing", "onPressIn", events[0].second)
        assertEquals("the second is the finger leaving", "onPressOut", events[1].second)
    }

    @Test
    fun `a line count survives the frame that follows it`() {
        val label = node("text", mapOf("text" to "long enough to wrap", "numberOfLines" to 2)) as android.widget.TextView

        // A frame always follows the props, and a count worked out from its height is not the count the
        // tree asked for.
        assertEquals("the line count the tree asked for must survive the frame", 2, label.maxLines)
    }

    @Test
    fun `a bar is drawn at the thickness it was asked for`() {
        val bar = node("progress", mapOf("value" to 0.5, "thickness" to 2)) as android.widget.ProgressBar

        assertTrue("a bar must take the thickness it was given, got ${bar.minimumHeight}", bar.minimumHeight > 0)
    }

    @Test
    fun `a switch keeps a colour for each of its two states`() {
        val toggle = node("switch", mapOf("value" to false, "onColor" to "#34c759ff", "offColor" to "#ff3b30ff"))
        val tint = (toggle as android.widget.Switch).trackTintList

        val on = tint?.getColorForState(intArrayOf(android.R.attr.state_checked), 0)
        val off = tint?.getColorForState(intArrayOf(), 0)

        assertNotEquals("a switch must show a different colour in each state", on, off)
    }
}
