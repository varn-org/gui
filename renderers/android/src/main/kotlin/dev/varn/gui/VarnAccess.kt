package dev.varn.gui

import android.view.View
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject
import java.util.WeakHashMap

/**
 * What a box says about itself to a reader who cannot see it.
 *
 * A control the platform draws says all of this for itself. One the engine draws is a box with a colour
 * in it, and that is what TalkBack reads unless the tree says otherwise — so a drawn checkbox that says
 * nothing is a checkbox nobody using it can find, let alone tick.
 *
 * What a view says is held beside it rather than on it. A node is rebuilt for every announcement while a
 * prop arrives once, so the three props are gathered into one delegate, and that delegate is found again
 * through a map held only as long as the view is — a view tag is refused for any key that is not an
 * application resource id, and this renderer declares none.
 */
object VarnAccess {
    /** What the platform calls each role, which is the class a control of that kind would have been. */
    private val CLASSES = mapOf(
        "button" to "android.widget.Button",
        "link" to "android.widget.Button",
        "checkbox" to "android.widget.CheckBox",
        "radio" to "android.widget.RadioButton",
        "switch" to "android.widget.Switch",
        "slider" to "android.widget.SeekBar",
        "progressbar" to "android.widget.ProgressBar",
        "image" to "android.widget.ImageView",
        "search" to "android.widget.EditText",
        "tab" to "android.widget.TabWidget",
        "list" to "android.widget.ListView",
        "listitem" to "android.view.View",
        "header" to "android.view.View",
    )

    private val spoken = WeakHashMap<View, Spoken>()

    fun role(view: View, named: String?) {
        held(view).role = named

        view.importantForAccessibility = if (named != null && named != "none") {
            View.IMPORTANT_FOR_ACCESSIBILITY_YES
        } else {
            View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
        }
    }

    fun state(view: View, given: JSONObject?) {
        val about = held(view)

        about.checked = given?.takeIf { it.has("checked") }?.optBoolean("checked")
        about.selected = given?.optBoolean("selected") == true
        view.isEnabled = given?.optBoolean("disabled") != true
    }

    fun reading(view: View, given: JSONObject?) {
        held(view).reading = given
    }

    private fun held(view: View): Spoken {
        spoken[view]?.let { return it }

        val made = Spoken()

        spoken[view] = made
        view.accessibilityDelegate = made

        return made
    }

    class Spoken : View.AccessibilityDelegate() {
        var role: String? = null
        var checked: Boolean? = null
        var selected: Boolean = false
        var reading: JSONObject? = null

        override fun onInitializeAccessibilityNodeInfo(host: View, info: AccessibilityNodeInfo) {
            super.onInitializeAccessibilityNodeInfo(host, info)

            CLASSES[role]?.let { info.className = it }

            checked?.let { ticked ->
                info.isCheckable = true
                info.isChecked = ticked
            }

            info.isSelected = selected

            val given = reading ?: return

            if (given.has("text")) {
                info.stateDescription = given.optString("text")
                return
            }

            if (!given.has("now")) {
                return
            }

            info.rangeInfo = AccessibilityNodeInfo.RangeInfo(
                AccessibilityNodeInfo.RangeInfo.RANGE_TYPE_FLOAT,
                given.optDouble("least", 0.0).toFloat(),
                given.optDouble("most", 1.0).toFloat(),
                given.optDouble("now", 0.0).toFloat(),
            )
        }
    }
}
