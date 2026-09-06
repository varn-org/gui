package dev.varn.gui

import android.app.Activity
import android.widget.FrameLayout
import android.widget.SeekBar
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.GraphicsMode

/**
 * What a slider reports, which is the number the tree declared rather than the position it tracks.
 *
 * A SeekBar counts whole positions from zero, so a slider that read the position as the value reported
 * a hundredth of what it was dragged to, and one with any range but nought to a hundred sat at the end
 * of its travel whatever it was given.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SliderTest {
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

    private fun slider(props: Map<String, Any?>): VarnSliderView {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "create", "id" to 1, "type" to "slider", "props" to JSONObject(props))),
                    JSONObject(mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1)),
                ),
            ),
        )

        return surface.getChildAt(0) as VarnSliderView
    }

    /** Drags the control to a fraction of its travel, which is what a finger on it does. */
    private fun drag(view: VarnSliderView, fraction: Double) {
        val listener = shadowOf(view).onSeekBarChangeListener
        listener.onProgressChanged(view, Math.round(view.max * fraction).toInt(), true)
    }

    private fun release(view: VarnSliderView) {
        shadowOf(view).onSeekBarChangeListener.onStopTrackingTouch(view)
    }

    private fun reported(event: String): List<Double> =
        events.filter { it.second == event }.map { (it.third as Number).toDouble() }

    @Test
    fun reportsTheValueInTheRangeItWasGiven() {
        val view = slider(mapOf("minimum" to 0, "maximum" to 10, "value" to 0, "onChange" to true))

        drag(view, 0.5)

        assertEquals(listOf(5.0), reported("onChange"))
    }

    @Test
    fun standsAtThePositionTheValueAsksFor() {
        val view = slider(mapOf("minimum" to 0, "maximum" to 10, "value" to 7.5))

        assertEquals(0.75, view.progress.toDouble() / view.max, 0.001)
    }

    @Test
    fun countsInTheStepItWasGiven() {
        val view = slider(mapOf("minimum" to 0, "maximum" to 10, "step" to 5, "value" to 0, "onChange" to true))

        assertEquals(2, view.max)

        drag(view, 1.0)

        assertEquals(listOf(10.0), reported("onChange"))
    }

    @Test
    fun holdsItsReportUntilTheFingerLiftsWhenItIsNotContinuous() {
        val view = slider(
            mapOf("minimum" to 0, "maximum" to 10, "value" to 0, "continuous" to false, "onChange" to true),
        )

        drag(view, 0.5)
        assertTrue("a slider that is not continuous reports nothing while it is dragged", reported("onChange").isEmpty())

        release(view)
        assertEquals(listOf(5.0), reported("onChange"))
    }

    @Test
    fun reportsWhatItWasLeftAtWhenTheFingerLifts() {
        val view = slider(mapOf("minimum" to 0, "maximum" to 10, "value" to 0, "onCommit" to true))

        drag(view, 0.25)
        release(view)

        assertEquals(listOf(2.5), reported("onCommit"))
    }
}
