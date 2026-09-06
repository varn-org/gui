package dev.varn.gui

import android.app.Activity
import android.view.View
import android.widget.EditText
import android.widget.RadioButton
import android.widget.FrameLayout
import android.widget.Switch
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

/**
 * The conformance cases of gui/bridge/conformance.lua, run against the real Android renderer.
 *
 * The names match the Lua suite exactly, and gui/tests/conformance_test.lua asserts that they still do,
 * so a case added on one side cannot be forgotten on the other.
 *
 * The graphics are the real ones rather than the stubs, since a renderer that answers what a string
 * measures cannot be checked against a Paint that returns nothing.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ConformanceTest {
    private lateinit var surface: FrameLayout
    private lateinit var renderer: VarnRenderer
    private val events = mutableListOf<Triple<Int, String, Any?>>()

    @Before
    fun setUp() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()

        surface = FrameLayout(activity)
        activity.setContentView(surface)
        events.clear()

        renderer = VarnRenderer(activity, surface) { id, name, payload ->
            events.add(Triple(id, name, payload))
        }
    }

    private fun apply(vararg ops: Map<String, Any?>) = renderer.apply(JSONArray(ops.map(::JSONObject)))

    /** The tree a renderer built, read back the way the Lua suite reads its own. */
    private fun tree(holder: View? = null): List<View> {
        val container = if (holder == null) surface else VarnViewFactory.contentView(holder)
        return (0 until container.childCount).map { container.getChildAt(it) }
    }

    private fun only(views: List<View>): View {
        assertEquals("expected one root", 1, views.size)
        return views[0]
    }

    private fun refuses(message: String, run: () -> Unit) {
        try {
            run()
            fail(message)
        } catch (problem: RuntimeException) {
            // The batch was refused, which is what the case is asserting.
        }
    }

    @Test
    fun testCreatesAndAttachesARoot() {
        apply(
            mapOf("op" to "create", "id" to 1, "type" to "view", "props" to JSONObject()),
            mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1),
        )

        val root = only(tree())
        assertTrue("the root must be the node that was created", root is VarnBoxView)
        assertEquals("a fresh root has no children", 0, tree(root).size)
    }

    @Test
    fun testNestsChildrenInTheOrderTheyWereInserted() {
        apply(
            mapOf("op" to "create", "id" to 1, "type" to "view", "props" to JSONObject()),
            mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1),
            mapOf("op" to "create", "id" to 2, "type" to "text", "props" to JSONObject(mapOf("text" to "a"))),
            mapOf("op" to "insert", "id" to 2, "parent" to 1, "index" to 1),
            mapOf("op" to "create", "id" to 3, "type" to "text", "props" to JSONObject(mapOf("text" to "b"))),
            mapOf("op" to "insert", "id" to 3, "parent" to 1, "index" to 2),
        )

        val children = tree(only(tree()))
        assertEquals("the first child must come first", "a", (children[0] as TextView).text.toString())
        assertEquals("the second child must come second", "b", (children[1] as TextView).text.toString())
    }

    @Test
    fun testUpdatesOnlyThePropsItWasGiven() {
        apply(
            mapOf(
                "op" to "create", "id" to 1, "type" to "view",
                "props" to JSONObject(mapOf("style" to JSONObject(mapOf("opacity" to 1.0)), "testID" to "root")),
            ),
            mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1),
            mapOf(
                "op" to "update", "id" to 1,
                "props" to JSONObject(mapOf("style" to JSONObject(mapOf("opacity" to 0.5)))),
            ),
        )

        val root = only(tree())
        assertEquals("the changed prop must be applied", 0.5f, root.alpha, 0.001f)
        assertEquals("an untouched prop must survive", "root", root.tag)
    }

    @Test
    fun testDropsAPropAnUpdateMarkedRemoved() {
        apply(
            mapOf("op" to "create", "id" to 1, "type" to "view", "props" to JSONObject(mapOf("testID" to "root"))),
            mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1),
            mapOf("op" to "update", "id" to 1, "props" to JSONObject(mapOf("testID" to "__varn_removed__"))),
        )

        assertNull("a removed prop must be gone", only(tree()).tag)
    }

    @Test
    fun testMovesAChildWithoutRebuildingIt() {
        apply(
            mapOf("op" to "create", "id" to 1, "type" to "view", "props" to JSONObject()),
            mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1),
            mapOf("op" to "create", "id" to 2, "type" to "text", "props" to JSONObject(mapOf("text" to "a"))),
            mapOf("op" to "insert", "id" to 2, "parent" to 1, "index" to 1),
            mapOf("op" to "create", "id" to 3, "type" to "text", "props" to JSONObject(mapOf("text" to "b"))),
            mapOf("op" to "insert", "id" to 3, "parent" to 1, "index" to 2),
        )

        val root = only(tree())
        val before = tree(root)[0]

        apply(mapOf("op" to "move", "id" to 2, "parent" to 1, "index" to 2))

        val children = tree(root)
        assertEquals("the moved node must leave its place", "b", (children[0] as TextView).text.toString())
        assertEquals("the moved node must arrive at the new one", "a", (children[1] as TextView).text.toString())
        assertSame("a move must keep the widget it moved", before, children[1])
    }

    @Test
    fun testRemovesASubtreeWhole() {
        apply(
            mapOf("op" to "create", "id" to 1, "type" to "view", "props" to JSONObject()),
            mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1),
            mapOf("op" to "create", "id" to 2, "type" to "view", "props" to JSONObject()),
            mapOf("op" to "insert", "id" to 2, "parent" to 1, "index" to 1),
            mapOf("op" to "create", "id" to 3, "type" to "text", "props" to JSONObject(mapOf("text" to "deep"))),
            mapOf("op" to "insert", "id" to 3, "parent" to 2, "index" to 1),
        )

        apply(
            mapOf("op" to "remove", "id" to 3),
            mapOf("op" to "remove", "id" to 2),
        )

        assertEquals("the subtree must be gone", 0, tree(only(tree())).size)
        refuses("a removed node must be forgotten") { renderer.invoke(2, "focus", JSONObject()) }
    }

    @Test
    fun testPlacesANodeAtTheFrameItWasGiven() {
        apply(
            mapOf("op" to "create", "id" to 1, "type" to "view", "props" to JSONObject()),
            mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1),
            mapOf("op" to "frame", "id" to 1, "x" to 12, "y" to 24, "width" to 100, "height" to 40),
        )

        val density = surface.context.resources.displayMetrics.density
        val node = only(tree())

        assertEquals("the node must sit where it was placed", (12 * density).toInt(), node.left)
        assertEquals("the node must sit where it was placed", (24 * density).toInt(), node.top)
        assertEquals("the node must take the size it was given", (100 * density).toInt(), node.width)
        assertEquals("the node must take the size it was given", (40 * density).toInt(), node.height)
    }

    @Test
    fun testReparentsANodeRatherThanDuplicatingIt() {
        apply(
            mapOf("op" to "create", "id" to 1, "type" to "view", "props" to JSONObject()),
            mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1),
            mapOf("op" to "create", "id" to 2, "type" to "view", "props" to JSONObject()),
            mapOf("op" to "insert", "id" to 2, "parent" to 0, "index" to 2),
            mapOf("op" to "create", "id" to 3, "type" to "text", "props" to JSONObject(mapOf("text" to "moved"))),
            mapOf("op" to "insert", "id" to 3, "parent" to 1, "index" to 1),
        )

        apply(mapOf("op" to "move", "id" to 3, "parent" to 2, "index" to 1))

        val roots = tree()
        assertEquals("the old parent must have let go", 0, tree(roots[0]).size)
        assertEquals("the new parent must have taken it", 1, tree(roots[1]).size)
        assertEquals("the node itself must have moved", "moved", (tree(roots[1])[0] as TextView).text.toString())
    }

    @Test
    fun testRefusesABatchThatBreaksTheContract() {
        refuses("an update with no props must be refused") { apply(mapOf("op" to "update", "id" to 1)) }
        refuses("an unknown operation must be refused") { apply(mapOf("op" to "nonsense", "id" to 1)) }
    }

    @Test
    fun testAnswersAMeasurementForAString() {
        val size = renderer.measureText("hello", JSONObject(mapOf("fontSize" to 16)), null)

        assertTrue("a measurement must carry a width", size.getDouble("width") > 0)
        assertTrue("a measurement must carry a height", size.getDouble("height") > 0)
    }

    @Test
    fun testAnswersAFiniteMeasurementHoweverItIsBounded() {
        for (bound in listOf(0.0, 1.0, 40.0, null)) {
            val size = renderer.measureText("a longer sentence", JSONObject(mapOf("fontSize" to 16)), bound)
            val width = size.getDouble("width")
            val height = size.getDouble("height")

            assertTrue("a measurement must be finite at bound $bound", width.isFinite() && height.isFinite())
            assertTrue("a line of text is never zero high, at bound $bound", height > 0)
        }
    }

    @Test
    fun testReportsAnEventAsWhatTheEventCarries() {
        apply(
            mapOf(
                "op" to "create", "id" to 1, "type" to "switch",
                "props" to JSONObject(mapOf("value" to false, "onChange" to true)),
            ),
            mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1),
            mapOf(
                "op" to "create", "id" to 2, "type" to "textinput",
                "props" to JSONObject(mapOf("value" to "", "onChange" to true)),
            ),
            mapOf("op" to "insert", "id" to 2, "parent" to 0, "index" to 2),
        )

        (tree()[0] as Switch).isChecked = true

        val changed = events.last()
        assertEquals("a change is reported by the name of the prop that declared it", "onChange", changed.second)
        assertEquals("a change carries the value itself, not a table holding it", true, changed.third)

        (tree()[1] as EditText).setText("typed")

        val typed = events.last()
        assertEquals("a field reports its text the same way", "onChange", typed.second)
        assertEquals("a change carries the value itself", "typed", typed.third)
    }

    @Test
    fun testReadsARadioValueAsItsIdentityRatherThanItsState() {
        apply(
            mapOf(
                "op" to "create", "id" to 1, "type" to "radio",
                "props" to JSONObject(mapOf("value" to "monthly", "selected" to true)),
            ),
            mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1),
            mapOf(
                "op" to "create", "id" to 2, "type" to "radio",
                "props" to JSONObject(mapOf("value" to "yearly", "selected" to false)),
            ),
            mapOf("op" to "insert", "id" to 2, "parent" to 0, "index" to 2),
        )

        val chosen = tree()[0] as RadioButton
        val other = tree()[1] as RadioButton

        assertEquals("the chosen radio must be the one marked selected", true, chosen.isChecked)
        assertEquals("the other radio must be left alone", false, other.isChecked)
    }

    @Test
    fun testLeavesAFieldAloneWhenItsValueHasNotChanged() {
        apply(
            mapOf(
                "op" to "create", "id" to 1, "type" to "textinput",
                "props" to JSONObject(mapOf("value" to "Ada", "onChange" to true)),
            ),
            mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1),
        )

        val field = tree()[0] as EditText
        field.setSelection(1)

        apply(mapOf("op" to "update", "id" to 1, "props" to JSONObject(mapOf("value" to "Ada"))))

        assertEquals("the field must hold the value it was given", "Ada", field.text.toString())
        assertEquals("the caret must not have moved", 1, field.selectionStart)
    }

    @Test
    fun testDeclaresWhatItCanDo() {
        val known = listOf(
            "text", "image", "list", "scroll", "input", "video", "webview", "canvas",
            "picker", "datepicker", "haptics", "safearea", "fontBytes",
        )

        for (name in renderer.capabilities.keys) {
            assertTrue("$name is not a capability the contract names", known.contains(name))
        }

        assertEquals("a renderer that draws text must say so", true, renderer.capabilities["text"])
    }
}
