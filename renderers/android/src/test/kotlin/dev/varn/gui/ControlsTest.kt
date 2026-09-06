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

        assertEquals(listOf("2026-09-05T00:00:00Z"), reported())
    }

    @Test
    fun aTimeReportsTheHourItWasSetTo() {
        val view = control("timepicker", mapOf("onChange" to true)) as TimePicker

        view.hour = 9
        view.minute = 30

        assertEquals("1970-01-01T09:30:00Z", reported().last())
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
}
