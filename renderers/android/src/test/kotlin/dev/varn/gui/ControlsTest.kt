package dev.varn.gui

import android.app.Activity
import android.widget.DatePicker
import android.widget.FrameLayout
import android.widget.RatingBar
import android.widget.TimePicker
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

/**
 * What every control reports when it is used, which on Android was nothing at all for most of them.
 *
 * A change was wired for a compound button, a slider and a field. A stepper, a rating, a chooser, a
 * date and a time were built, drawn and never reported, so touching one of them changed nothing —
 * which is what "I touch it and nothing happens" was on the phone.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ControlsTest {
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

    private fun control(type: String, props: Map<String, Any?>): android.view.View {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "create", "id" to 1, "type" to type, "props" to JSONObject(props))),
                    JSONObject(mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1)),
                ),
            ),
        )

        return surface.getChildAt(0)
    }

    private fun reported(): List<Any?> = events.filter { it.second == "onChange" }.map { it.third }

    @Test
    fun aStepperCountsInTheStepItWasGiven() {
        val view = control("stepper", mapOf("value" to 5, "step" to 5, "onChange" to true)) as VarnStepperView

        view.getChildAt(2).performClick()

        assertEquals(listOf(10.0), reported())
    }

    @Test
    fun aStepperStopsAtTheBoundsItWasGiven() {
        val view = control(
            "stepper",
            mapOf("value" to 9, "step" to 5, "minimum" to 0, "maximum" to 10, "onChange" to true),
        ) as VarnStepperView

        view.getChildAt(2).performClick()

        assertEquals(listOf(10.0), reported())
    }

    @Test
    fun aChooserReportsTheValueOfWhatWasChosen() {
        val options = JSONArray(
            listOf(
                JSONObject(mapOf("label" to "One", "value" to "1")),
                JSONObject(mapOf("label" to "Two", "value" to "2")),
            ),
        )

        val view = control("picker", mapOf("options" to options, "value" to "1", "onChange" to true))
            as VarnPickerView

        view.setSelection(1)

        assertEquals(listOf("2"), reported())
    }

    @Test
    fun aChooserWrittenToReportsNothing() {
        val options = JSONArray(
            listOf(
                JSONObject(mapOf("label" to "One", "value" to "1")),
                JSONObject(mapOf("label" to "Two", "value" to "2")),
            ),
        )

        control("picker", mapOf("options" to options, "value" to "2", "onChange" to true))

        assertEquals(emptyList<Any?>(), reported())
    }

    @Test
    fun aRatingReportsTheScoreItWasSetTo() {
        val view = control("rating", mapOf("count" to 5, "value" to 2, "onChange" to true)) as RatingBar

        view.onRatingBarChangeListener?.onRatingChanged(view, 4f, true)

        assertEquals(listOf(4.0), reported())
    }

    @Test
    fun aSegmentedControlReportsWhereTheChosenSegmentSits() {
        val segments = JSONArray(listOf("Day", "Week", "Month"))
        val view = control("segmented", mapOf("segments" to segments, "onChange" to true)) as VarnSegmentedView

        view.getChildAt(2).performClick()

        assertEquals(listOf(3), reported())
    }

    @Test
    fun aDateReportsTheDayItWasSetTo() {
        val view = control("datepicker", mapOf("onChange" to true)) as DatePicker

        view.updateDate(2026, 8, 5)

        // A picker chooses what a calendar shows, not a moment on a timeline: an instant carries a zone
        // nobody chose, and reading it back in another one moves the day.
        assertEquals(listOf("2026-09-05"), reported())
    }

    @Test
    fun aTimeReportsTheHourItWasSetTo() {
        val view = control("timepicker", mapOf("onChange" to true)) as TimePicker

        view.hour = 9
        view.minute = 30

        assertEquals("09:30", reported().last())
    }

    @Test
    fun aSegmentWrittenBackReportsNothing() {
        val segments = JSONArray(listOf("Day", "Week", "Month"))
        val view = control("segmented", mapOf("segments" to segments, "onChange" to true)) as VarnSegmentedView

        view.getChildAt(2).performClick()
        renderer.apply(
            JSONArray(
                listOf(JSONObject(mapOf("op" to "update", "id" to 1, "props" to JSONObject(mapOf("selectedIndex" to 3))))),
            ),
        )

        assertEquals(listOf(3), reported())
    }

    /**
     * A field keeps what was typed while the tree catches up, and holds it in itself rather than a tag.
     *
     * A tree answers a keystroke with the value it has just been told, and by the time that lands the
     * reader has typed two more, so "Are you there" arrived as "Are you r". A view tag needs a key that
     * is an application resource id and throws on anything else, which is a crash a device finds and a
     * test does not, so what the field remembers lives in the field.
     */
    @Test
    fun `a field keeps what was typed while the tree catches up`() {
        val field = control("textinput", mapOf("value" to "", "onChange" to true)) as VarnTextField

        field.setText("Are")
        field.setText("Are you")
        field.setText("Are you there")

        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "update", "id" to 1, "props" to JSONObject(mapOf("value" to "Are")))),
                    JSONObject(
                        mapOf("op" to "update", "id" to 1, "props" to JSONObject(mapOf("value" to "Are you"))),
                    ),
                ),
            ),
        )

        assertEquals("nothing the field said is written back to it", "Are you there", field.text.toString())

        renderer.apply(
            JSONArray(
                listOf(JSONObject(mapOf("op" to "update", "id" to 1, "props" to JSONObject(mapOf("value" to ""))))),
            ),
        )

        assertEquals("and a value it never said is a real change", "", field.text.toString())
    }

    /**
     * A field reports one keystroke once, however many times its handler has been bound.
     *
     * A watcher was added rather than set, so a handler that comes and goes — which a conditional one
     * does on every commit that changes it — left the field reporting each keystroke once per binding.
     */
    @Test
    fun `a field reports a keystroke once however often it was bound`() {
        val field = control("textinput", mapOf("value" to "", "onChange" to true)) as VarnTextField

        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(
                        mapOf("op" to "update", "id" to 1, "props" to JSONObject(mapOf("onChange" to true))),
                    ),
                    JSONObject(
                        mapOf("op" to "update", "id" to 1, "props" to JSONObject(mapOf("onChange" to true))),
                    ),
                ),
            ),
        )

        field.setText("a")

        assertEquals("one keystroke is one report", 1, reported().size)
    }
}
