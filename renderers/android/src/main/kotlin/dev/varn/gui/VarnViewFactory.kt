package dev.varn.gui

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.*

/** Builds the Android view that stands for one node type. */
object VarnViewFactory {
    fun make(context: Context, type: String): View = when (type) {
        "text", "richtext", "badge", "chip", "icon", "tooltip", "avatar" -> TextView(context)
        "image" -> ImageView(context)
        // A button carries no look of its own, since the style a commit carries is what paints it.
        "button" -> Button(context).apply {
            isAllCaps = false
            minWidth = 0
            minHeight = 0
            background = null
            stateListAnimator = null
            setPadding(0, 0, 0, 0)
        }
        "textinput", "searchbar" -> EditText(context)
        "textarea" -> EditText(context).apply { isSingleLine = false; minLines = 3 }
        // One scrolling surface serves every scrolling type, since the engine sends all of them the same thing.
        "scroll", "list", "sectionlist", "grid", "carousel" -> VarnCollectionView(context)
        "switch" -> Switch(context)
        "checkbox" -> CheckBox(context)
        "radio" -> RadioButton(context)
        "slider" -> VarnSliderView(context)
        "progress" -> ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal)
        "activity" -> ProgressBar(context)
        "picker" -> VarnPickerView(context)
        "datepicker" -> DatePicker(context)
        "timepicker" -> TimePicker(context)
        "rating" -> RatingBar(context)
        "segmented" -> VarnSegmentedView(context)
        // A radio group holds the radios the engine placed, so it is a box rather than a linear layout.
        "stepper" -> VarnStepperView(context)
        "filepicker" -> Button(context)
        "colorpicker", "refresh" -> View(context)
        "webview" -> WebView(context)
        "video" -> VideoView(context)
        "canvas" -> VarnCanvasView(context)
        "divider" -> View(context)

        // A box is what the rest are: the engine positions them and their style paints them.
        else -> VarnBoxView(context)
    }

    /** Answers the view children are added to, which for a scrolling view is not the view itself. */
    fun contentView(view: View): ViewGroup {
        if (view is VarnCollectionView) {
            return view.content
        }

        return view as ViewGroup
    }
}

/**
 * The plain box everything else is built from.
 *
 * The engine sends finished frames, so this never measures or arranges anything: a child is placed
 * exactly where it was told to go.
 */
open class VarnBoxView(context: Context) : ViewGroup(context) {
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        for (index in 0 until childCount) {
            val child = getChildAt(index)
            val params = child.layoutParams

            child.layout(child.left, child.top, child.left + params.width, child.top + params.height)
        }
    }

    override fun onMeasure(widthSpec: Int, heightSpec: Int) {
        setMeasuredDimension(
            MeasureSpec.getSize(widthSpec),
            MeasureSpec.getSize(heightSpec),
        )

        for (index in 0 until childCount) {
            val child = getChildAt(index)
            val params = child.layoutParams

            child.measure(
                MeasureSpec.makeMeasureSpec(params.width, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(params.height, MeasureSpec.EXACTLY),
            )
        }
    }
}

/**
 * A value with a button either side of it, which is what Android has in place of a stepper.
 *
 * The engine sizes it, so the three parts simply share the width it was given.
 */
class VarnStepperView(context: Context) : VarnBoxView(context) {
    private val less = Button(context).apply { text = "\u2212" }
    private val more = Button(context).apply { text = "+" }
    private val readout = TextView(context).apply { gravity = android.view.Gravity.CENTER }

    var value: Double = 0.0
        private set

    var step: Double = 1.0
    var minimum: Double = Double.NEGATIVE_INFINITY
    var maximum: Double = Double.POSITIVE_INFINITY
    var onValueChange: ((Double) -> Unit)? = null

    init {
        addView(less)
        addView(readout)
        addView(more)

        less.setOnClickListener { move(-step) }
        more.setOnClickListener { move(step) }
        show()
    }

    fun setValue(next: Double) {
        value = next.coerceIn(minimum, maximum)
        show()
    }

    private fun move(by: Double) {
        setValue(value + by)
        onValueChange?.invoke(value)
    }

    private fun show() {
        readout.text = if (value == value.toLong().toDouble()) value.toLong().toString() else value.toString()
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val height = bottom - top
        val side = minOf(height, (right - left) / 3)

        less.layout(0, 0, side, height)
        readout.layout(side, 0, right - left - side, height)
        more.layout(right - left - side, 0, right - left, height)
    }
}

/**
 * A row of segments that reports a choice once, and reports nothing for a choice written into it.
 *
 * A RadioGroup checked programmatically runs its listener down two paths and reports twice, and the
 * tree writing back the segment a handler just chose would come round again as a second choice.
 */
class VarnSegmentedView(context: Context) : RadioGroup(context) {
    private var written = 0

    var onChoose: ((Int) -> Unit)? = null

    init {
        orientation = HORIZONTAL

        setOnCheckedChangeListener { group, checked ->
            val at = group.indexOfChild(group.findViewById(checked)) + 1

            if (at > 0 && at != written) {
                written = at
                onChoose?.invoke(at)
            }
        }
    }

    /** Shows the segment at a position as the chosen one. */
    fun choose(index: Int) {
        if (index <= 0 || index > childCount) {
            return
        }

        written = index
        check(getChildAt(index - 1).id)
    }
}

/**
 * A chooser that reports the value of what was chosen rather than where it sat in the list.
 *
 * An option carries a label a reader sees and a value a handler is given, and the platform's own
 * adapter holds only the labels, so the values are kept here to be reported by.
 */
class VarnPickerView(context: Context) : Spinner(context) {
    private var written: String? = null

    var values: List<String> = emptyList()
    var onChoose: ((String) -> Unit)? = null

    init {
        onItemSelectedListener = object : OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val chosen = values.getOrNull(position) ?: return

                // The tree writing a value back is not a person choosing one, so the first selection
                // after a write is the write arriving rather than a choice to report.
                if (chosen == written) {
                    written = null
                    return
                }

                onChoose?.invoke(chosen)
            }

            override fun onNothingSelected(parent: AdapterView<*>?) = Unit
        }
    }

    /** Shows the option carrying a value as the chosen one. */
    fun choose(value: String?) {
        val at = values.indexOf(value)
        if (at < 0) {
            return
        }

        written = value
        setSelection(at)
    }
}

/**
 * A slider that reports the number a caller asked for rather than the position the platform tracks.
 *
 * A SeekBar counts whole positions from zero, so the range and the step a tree declares are mapped onto
 * one here and mapped back when the value is reported. Reading the position as the value leaves every
 * slider with a range other than nought to one hundred at one end of its travel.
 */
class VarnSliderView(context: Context) : SeekBar(context) {
    private var current: Double = 0.0

    var minimum: Double = 0.0
        set(value) {
            field = value
            reposition()
        }

    var maximum: Double = 1.0
        set(value) {
            field = value
            reposition()
        }

    var step: Double? = null
        set(value) {
            field = value
            reposition()
        }

    var continuous: Boolean = true

    var onValueChange: ((Double) -> Unit)? = null
    var onValueCommit: ((Double) -> Unit)? = null

    init {
        setOnSeekBarChangeListener(object : OnSeekBarChangeListener {
            override fun onProgressChanged(bar: SeekBar, position: Int, fromUser: Boolean) {
                if (!fromUser) {
                    return
                }

                current = valueAt(position)

                if (continuous) {
                    onValueChange?.invoke(current)
                }
            }

            override fun onStartTrackingTouch(bar: SeekBar) = Unit

            override fun onStopTrackingTouch(bar: SeekBar) {
                if (!continuous) {
                    onValueChange?.invoke(current)
                }

                onValueCommit?.invoke(current)
            }
        })

        reposition()
    }

    fun setValue(next: Double) {
        current = next
        reposition()
    }

    /** How many positions the travel is divided into, which is the step when one was declared. */
    private fun positions(): Int {
        val span = maximum - minimum
        if (span <= 0.0) {
            return 1
        }

        val stepping = step
        if (stepping != null && stepping > 0.0) {
            return maxOf(1, Math.round(span / stepping).toInt())
        }

        return FINE
    }

    private fun valueAt(position: Int): Double = minimum + (maximum - minimum) * position / positions()

    private fun reposition() {
        val span = maximum - minimum
        max = positions()
        progress = if (span <= 0.0) 0 else Math.round((current - minimum) / span * positions()).toInt()
    }

    private companion object {
        /** The travel of a slider with no step, fine enough that a drag reads as continuous. */
        const val FINE = 1000
    }
}
