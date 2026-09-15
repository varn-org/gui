package dev.varn.gui

import android.app.Activity
import android.widget.FrameLayout
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner

/**
 * What an editor says about itself, which is what the row of tools over it draws from.
 *
 * A field and an editor both report where the caret is under one name, and a `when` runs the first arm
 * that matches: two arms by that name left the editor's unreachable, so a toolbar on this platform never
 * lit up for what the caret was inside of.
 */
@RunWith(RobolectricTestRunner::class)
class WritingTest {
    private lateinit var surface: FrameLayout
    private lateinit var renderer: VarnRenderer
    private val heard = mutableListOf<Pair<String, JSONObject?>>()

    @Before
    fun setUp() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()

        surface = FrameLayout(activity)
        activity.setContentView(surface)
        heard.clear()

        renderer = VarnRenderer(activity, surface) { _, name, payload ->
            heard.add(name to payload as? JSONObject)
        }
    }

    private fun editor(props: Map<String, Any?>): VarnRichEditor {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(
                        mapOf(
                            "op" to "create",
                            "id" to 1,
                            "type" to "richeditor",
                            "props" to JSONObject(props),
                        ),
                    ),
                    JSONObject(mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1)),
                ),
            ),
        )

        return surface.getChildAt(0) as VarnRichEditor
    }

    @Test
    fun anEditorSaysWhereTheCaretIs() {
        val written = JSONArray(
            listOf(
                JSONObject(mapOf("text" to "one box", "marks" to JSONObject(mapOf("bold" to true)))),
                JSONObject(mapOf("text" to " and no more", "marks" to JSONObject())),
            ),
        )

        val editor = editor(mapOf("value" to written, "onSelectionChange" to true))

        heard.clear()
        editor.setSelection(2, 5)

        val where = heard.lastOrNull { it.first == "onSelectionChange" }?.second

        assertNotNull("an editor must say where the caret is, it reported $heard", where)
        assertEquals(2, where?.getInt("start"))
        assertEquals(5, where?.getInt("end"))
    }

    /** What is on at the caret is what a tool draws itself lit from. */
    @Test
    fun anEditorSaysWhatIsOnAtTheCaret() {
        val written = JSONArray(
            listOf(
                JSONObject(mapOf("text" to "bold", "marks" to JSONObject(mapOf("bold" to true)))),
                JSONObject(mapOf("text" to " plain", "marks" to JSONObject())),
            ),
        )

        val editor = editor(mapOf("value" to written, "onSelectionChange" to true))

        heard.clear()
        editor.setSelection(1, 3)

        val marks = heard.lastOrNull { it.first == "onSelectionChange" }?.second?.optJSONObject("marks")

        assertEquals(true, marks?.optBoolean("bold"))
    }
}
