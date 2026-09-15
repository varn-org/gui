package dev.varn.gui

import android.app.Activity
import android.view.View
import android.view.accessibility.AccessibilityNodeInfo
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

/**
 * What a box says about itself to a reader who cannot see it.
 *
 * A control the platform draws says this for itself. One the engine draws is a box with a colour in it,
 * and that is what TalkBack reads, so a drawn checkbox that names no role is a checkbox nobody using one
 * can find, let alone tick.
 */
@RunWith(RobolectricTestRunner::class)
class AccessTest {
    private lateinit var surface: FrameLayout
    private lateinit var renderer: VarnRenderer

    @Before
    fun setUp() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()

        surface = FrameLayout(activity)
        activity.setContentView(surface)

        renderer = VarnRenderer(activity, surface) { _, _, _ -> }
    }

    private fun box(props: Map<String, Any?>): View {
        renderer.apply(
            JSONArray(
                listOf(
                    JSONObject(mapOf("op" to "create", "id" to 1, "type" to "pressable", "props" to JSONObject(props))),
                    JSONObject(mapOf("op" to "insert", "id" to 1, "parent" to 0, "index" to 1)),
                ),
            ),
        )

        return surface.getChildAt(0)
    }

    private fun spoken(view: View): AccessibilityNodeInfo {
        val info = AccessibilityNodeInfo.obtain()

        view.onInitializeAccessibilityNodeInfo(info)
        return info
    }

    @Test
    fun aDrawnControlSaysWhatItIsAndWhatItIsDoing() {
        val view = box(
            mapOf(
                "accessibilityLabel" to "Keep it",
                "accessibilityRole" to "checkbox",
                "accessibilityState" to JSONObject(mapOf("checked" to true)),
            ),
        )

        val info = spoken(view)

        assertEquals("Keep it", view.contentDescription)
        assertEquals("android.widget.CheckBox", info.className)
        assertTrue("a checkbox says it can be ticked", info.isCheckable)
        assertTrue("and that it is", info.isChecked)
    }

    @Test
    fun aControlThatCannotBeUsedSaysSo() {
        val view = box(
            mapOf(
                "accessibilityRole" to "button",
                "accessibilityState" to JSONObject(mapOf("disabled" to true)),
            ),
        )

        assertFalse("a control the tree disabled is not one a reader can reach", view.isEnabled)
    }

    @Test
    fun aControlThatHoldsANumberSaysWhatItIsAt() {
        val view = box(
            mapOf(
                "accessibilityRole" to "slider",
                "accessibilityValue" to JSONObject(mapOf("now" to 3, "least" to 0, "most" to 10)),
            ),
        )

        val range = spoken(view).rangeInfo

        assertEquals(3.0f, range?.current ?: -1f, 0.001f)
        assertEquals(0.0f, range?.min ?: -1f, 0.001f)
        assertEquals(10.0f, range?.max ?: -1f, 0.001f)
    }

    @Test
    fun aBoxThatIsNothingInParticularSaysNothing() {
        val view = box(mapOf("accessibilityRole" to "none"))

        assertEquals(
            "a box that is nothing is not held open for a reader",
            View.IMPORTANT_FOR_ACCESSIBILITY_AUTO,
            view.importantForAccessibility,
        )
    }
}
