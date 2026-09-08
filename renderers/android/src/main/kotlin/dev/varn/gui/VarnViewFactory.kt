package dev.varn.gui

import android.annotation.SuppressLint
import android.app.AlertDialog
import android.content.Context
import android.text.Editable
import android.text.TextWatcher
import android.graphics.Color
import android.graphics.Rect
import android.media.MediaPlayer
import android.view.MotionEvent
import android.view.TouchDelegate
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.*
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** Builds the Android view that stands for one node type. */
object VarnViewFactory {
    fun make(context: Context, type: String): View = when (type) {
        "text", "richtext", "badge", "tooltip" -> TextView(context)
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
        "textinput", "searchbar" -> VarnTextField(context)
        "textarea" -> VarnTextField(context).apply { isSingleLine = false; minLines = 3 }
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
        "filepicker" -> VarnFilePicker(context)
        "colorpicker" -> VarnColorView(context)
        "webview" -> WebView(context)
        "video" -> VarnVideoView(context)
        "audio" -> VarnAudioView(context)
        "canvas" -> VarnCanvasView(context)
        "gradient" -> VarnGradientView(context)
        "blur" -> VarnBlurView(context)
        "map" -> VarnMapView(context)
        "location" -> VarnLocationView(context)
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
 * How far a finger has gone since it landed, which is what a swipe is and a press is not.
 *
 * The distance is measured against the screen rather than against the view, since a view inside a list
 * moves under a finger that has not moved at all. It is the distance a page is dragged by rather than
 * the one a touch wanders by, because a finger on a phone is never still and a press held to that
 * shorter one is a control a reader has to press three times to be heard once.
 */
class VarnPressTravel(context: Context) {
    private val slop = ViewConfiguration.get(context).scaledPagingTouchSlop
    private var at: Pair<Float, Float>? = null

    val landed: Boolean
        get() = at != null

    fun began(event: MotionEvent) {
        at = event.rawX to event.rawY
    }

    fun ended() {
        at = null
    }

    fun swept(event: MotionEvent): Boolean {
        val landed = at ?: return false

        return abs(event.rawX - landed.first) > slop || abs(event.rawY - landed.second) > slop
    }

    fun directionOf(event: MotionEvent): String {
        val landed = at ?: return "right"
        val across = event.rawX - landed.first
        val down = event.rawY - landed.second

        if (abs(across) >= abs(down)) {
            return if (across < 0) "left" else "right"
        }

        return if (down < 0) "up" else "down"
    }
}

/**
 * A field that remembers what it has told the tree since it was last written to.
 *
 * A tree answers a keystroke with the value it has just been told, and by the time that lands the
 * reader has typed two more: writing it back puts the field where it was and everything typed since is
 * gone. What the field itself said is not news, and anything it never said is a real change.
 */
class VarnTextField(context: Context) : EditText(context) {
    private val said = LinkedHashSet<String>()

    /**
     * Told what was typed, by the one watcher this field ever has.
     *
     * A watcher is added rather than set, so binding the handler again — which a prop that comes and
     * goes does — left the field reporting every keystroke once per binding.
     */
    var onTyped: ((String) -> Unit)? = null

    init {
        addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(text: Editable) {
                reported(text.toString())
                onTyped?.invoke(text.toString())
            }

            override fun beforeTextChanged(text: CharSequence, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(text: CharSequence, start: Int, before: Int, count: Int) = Unit
        })
    }

    fun reported(text: String) {
        said += text

        while (said.size > SAID) {
            said.remove(said.first())
        }
    }

    fun echoed(text: String) = said.contains(text)

    fun written() {
        said.clear()
    }

    private companion object {
        const val SAID = 64
    }
}

/**
 * The plain box everything else is built from.
 *
 * The engine sends finished frames, so this never measures or arranges anything: a child is placed
 * exactly where it was told to go.
 */
open class VarnBoxView(context: Context) : ViewGroup(context) {
    /**
     * The range the surface holds this box against its leading edge over, which a header is given.
     *
     * A header placed from the tree follows a finger a commit late, which is a header drifting over the
     * rows it is meant to cover. The range is what the tree knows and the offset is what the surface
     * knows, so each says the part it has.
     */
    var pinned: Pair<Float, Float>? = null

    /** Answers where it sits for an offset, which is against the edge until its range runs out. */
    fun held(offset: Float, extent: Int): Float {
        val range = pinned ?: return offset

        return min(max(offset, range.first), max(range.first, range.second - extent))
    }

    /** How far outside its own box this one answers a finger, which is what a small control needs. */
    var slop: Int = 0
        set(value) {
            field = value
            (parent as? VarnBoxView)?.refreshSlop()
        }

    /** Told when a finger lands on this box and when it leaves, which a press reports both edges of. */
    var onPressIn: (() -> Unit)? = null
    var onPressOut: (() -> Unit)? = null

    /** Told the way a finger went when it went far enough to be a swipe rather than a press. */
    var onSwipe: ((String) -> Unit)? = null

    /**
     * Whether a finger passes through this box and everything inside it.
     *
     * Refusing to dispatch is what makes it pass through: the platform carries on to the next sibling,
     * which is what the other two renderers do for the same prop. Disabling the box alone left every
     * control inside it answering a finger that should never have reached it.
     */
    var passesThrough = false

    private var reaching: VarnSlopDelegate? = null
    private val travel = VarnPressTravel(context)
    private var swept: String? = null

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (passesThrough) {
            return false
        }

        return super.dispatchTouchEvent(event)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        // A box nothing is listening to answers a finger the way any other box does, which is not at all.
        if (!isClickable) {
            return super.onTouchEvent(event)
        }

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                travel.began(event)
                alpha = 0.55f
                onPressIn?.invoke()
            }

            // A swipe across a row is the row being swiped rather than pressed, and nothing else takes
            // a press away: a view gives one up when the touch leaves its bounds, and the surface takes
            // the whole gesture when it turns into a scroll.
            MotionEvent.ACTION_MOVE -> {
                if (onSwipe != null && travel.swept(event)) {
                    swept = travel.directionOf(event)
                    release()

                    val cancelled = MotionEvent.obtain(event)
                    cancelled.action = MotionEvent.ACTION_CANCEL
                    super.onTouchEvent(cancelled)
                    cancelled.recycle()

                    return false
                }
            }

            MotionEvent.ACTION_UP -> {
                release()

                swept?.let { onSwipe?.invoke(it) }
                swept = null
            }

            MotionEvent.ACTION_CANCEL -> {
                release()
                swept = null
            }
        }

        return super.onTouchEvent(event)
    }

    /** Ends the press once, wherever it ended, so a finger is never reported as having left twice. */
    private fun release() {
        if (!travel.landed) {
            return
        }

        travel.ended()
        animate().alpha(1f).setDuration(220).start()
        onPressOut?.invoke()
    }

    /** Answers the way a finger went, which is whichever axis it went furthest along. */
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        for (index in 0 until childCount) {
            val child = getChildAt(index)
            val params = child.layoutParams

            child.layout(child.left, child.top, child.left + params.width, child.top + params.height)
        }

        refreshSlop()
    }

    /**
     * Tells this box which of its children answer a finger from outside their own bounds.
     *
     * A view only ever receives a touch inside itself, and the platform's answer to that is a delegate
     * on the view above it. A view holds one delegate, so one holds every child that asked for slop.
     */
    private fun refreshSlop() {
        val reaches = (0 until childCount)
            .map { getChildAt(it) }
            .filterIsInstance<VarnBoxView>()
            .filter { it.slop > 0 }

        if (reaches.isEmpty()) {
            if (reaching != null) {
                touchDelegate = null
                reaching = null
            }

            return
        }

        val delegate = reaching ?: VarnSlopDelegate(this).also {
            reaching = it
            touchDelegate = it
        }

        delegate.hold(reaches)
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
 * A swatch showing the colour that was chosen, which opens the three sliders that choose another.
 *
 * Android ships no colour picker of its own, so this is the whole of one: a box in the current colour
 * and a dialog behind it. What it answers is the eight hex digits every renderer reads a colour as, so
 * the three platforms report the same thing for the same gesture.
 */
class VarnColorView(context: Context) : View(context) {
    var onChoose: ((String) -> Unit)? = null

    var color: Int = Color.BLACK
        set(value) {
            field = value
            setBackgroundColor(value)
        }

    init {
        setBackgroundColor(color)
        isClickable = true
        setOnClickListener { open() }
    }

    private fun open() {
        val holder = LinearLayout(context)
        holder.orientation = LinearLayout.VERTICAL
        holder.setPadding(48, 32, 48, 8)

        val parts = intArrayOf(Color.red(color), Color.green(color), Color.blue(color))
        val bars = List(parts.size) { at ->
            SeekBar(context).apply {
                max = 255
                progress = parts[at]
                holder.addView(this)
            }
        }

        AlertDialog.Builder(context)
            .setTitle("Colour")
            .setView(holder)
            .setNegativeButton(android.R.string.cancel, null)
            .setPositiveButton(android.R.string.ok) { _, _ ->
                color = Color.rgb(bars[0].progress, bars[1].progress, bars[2].progress)
                onChoose?.invoke(String.format("#%06xff", color and 0xffffff))
            }
            .show()
    }
}

/**
 * Hands a box the touches that land just outside the children that asked to answer them.
 *
 * The platform's own delegate carries one view, and a box holds many, so this stands in for all of
 * them. Only a touch outside a child's own bounds is claimed, since one inside already reaches it.
 */
class VarnSlopDelegate(private val host: VarnBoxView) : TouchDelegate(Rect(), host) {
    private var reaches: List<VarnBoxView> = emptyList()
    private var receiving: View? = null

    fun hold(views: List<VarnBoxView>) {
        reaches = views
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val x = event.x.toInt()
        val y = event.y.toInt()

        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            receiving = reaching(x, y)
        }

        val target = receiving ?: return false

        if (event.actionMasked == MotionEvent.ACTION_UP || event.actionMasked == MotionEvent.ACTION_CANCEL) {
            receiving = null
        }

        val moved = MotionEvent.obtain(event)
        moved.setLocation((x - target.left).toFloat(), (y - target.top).toFloat())

        val handled = target.dispatchTouchEvent(moved)
        moved.recycle()

        return handled
    }

    private fun reaching(x: Int, y: Int): View? = reaches.firstOrNull {
        it.visibility == View.VISIBLE
            && !Rect(it.left, it.top, it.right, it.bottom).contains(x, y)
            && Rect(it.left - it.slop, it.top - it.slop, it.right + it.slop, it.bottom + it.slop).contains(x, y)
    }
}

/**
 * Plays what it was given, holding what it was told until the player is ready to be told it.
 *
 * A player answers none of this before it is prepared, and it reports being prepared to one listener,
 * so every one of these setting its own left whichever arrived last replacing the rest.
 */
class VarnVideoView(context: Context) : VideoView(context), VarnReleasing {
    var muted: Boolean = false
        set(value) { field = value; settle() }

    var volume: Float = 1f
        set(value) { field = value; settle() }

    var looping: Boolean = false
        set(value) { field = value; settle() }

    var rate: Float = 1f
        set(value) { field = value; settle() }

    private var player: MediaPlayer? = null

    init {
        setOnPreparedListener {
            player = it
            settle()
        }
    }

    override fun release() {
        stopPlayback()
        player = null
    }

    private fun settle() {
        val ready = player ?: return
        val level = if (muted) 0f else volume

        ready.setVolume(level, level)
        ready.isLooping = looping

        if (rate > 0f) {
            ready.playbackParams = ready.playbackParams.setSpeed(rate)
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
